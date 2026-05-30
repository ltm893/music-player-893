import Foundation
import Combine

// CloudFolder, CloudFile, SyncResult live in Models.swift

// MARK: - Auth errors

enum CloudAuthError: LocalizedError {
    case invalidCredentials
    case noToken
    case networkError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:  return "Incorrect email or password."
        case .noToken:             return "Not signed in."
        case .networkError(let m): return "Network error: \(m)"
        case .unknown(let m):      return m
        }
    }
}

// MARK: - CloudService

@MainActor
class CloudService: ObservableObject {

    // MARK: - Published State

    @Published var isSignedIn:   Bool    = false
    @Published var errorMessage: String? = nil

    // MARK: - Sync State

    @Published var isSyncing:  Bool        = false
    @Published var syncResult: SyncResult? = nil

    // MARK: - Config — loaded from dliv_outputs.json, never hardcoded

    private let apiUrl:          String
    private let userPoolId:      String
    private let appClientId:     String
    private let cognitoEndpoint: URL
    private let session = URLSession.shared

    // MARK: - Keychain keys

    private let kIdToken      = "cloud.idToken"
    private let kAccessToken  = "cloud.accessToken"
    private let kRefreshToken = "cloud.refreshToken"

    private let documentsURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]

    /// Coalesces concurrent refresh calls — only one Cognito request in flight at a time.
    /// Any caller that arrives while a refresh is already running awaits the same Task
    /// instead of firing a second request (which Cognito may reject on rotation).
    private var refreshTask: Task<String, Error>?

    // MARK: - Init

    init() {
        guard
            let url     = Bundle.main.url(forResource: "dliv_outputs", withExtension: "json"),
            let data    = try? Data(contentsOf: url),
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let auth    = json["auth"]  as? [String: Any],
            let api     = json["api"]   as? [String: Any],
            let baseUrl = api["base_url"]              as? String,
            let poolId  = auth["user_pool_id"]         as? String,
            let client  = auth["user_pool_client_id"]  as? String,
            let region  = json["aws_region"]           as? String
        else {
            fatalError("dliv_outputs.json missing or malformed — add it to the Xcode target")
        }

        self.apiUrl          = baseUrl
        self.userPoolId      = poolId
        self.appClientId     = client
        self.cognitoEndpoint = URL(string: "https://cognito-idp.\(region).amazonaws.com/")!

        isSignedIn = loadToken(key: kIdToken) != nil
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        let body: [String: Any] = [
            "AuthFlow": "USER_PASSWORD_AUTH",
            "AuthParameters": ["USERNAME": email, "PASSWORD": password],
            "ClientId": appClientId
        ]
        let result = try await cognitoRequest(target: "InitiateAuth", body: body)

        guard
            let authResult   = result["AuthenticationResult"] as? [String: Any],
            let idToken      = authResult["IdToken"]          as? String,
            let accessToken  = authResult["AccessToken"]      as? String,
            let refreshToken = authResult["RefreshToken"]     as? String
        else { throw CloudAuthError.invalidCredentials }

        saveToken(key: kIdToken,      value: idToken)
        saveToken(key: kAccessToken,  value: accessToken)
        saveToken(key: kRefreshToken, value: refreshToken)
        isSignedIn = true
    }

    func signOut() async {
        refreshTask?.cancel()
        refreshTask  = nil
        deleteToken(key: kIdToken)
        deleteToken(key: kAccessToken)
        deleteToken(key: kRefreshToken)
        isSignedIn   = false
        syncResult   = nil
        errorMessage = nil
    }

    // MARK: - Token management

    private func idToken() async throws -> String {
        if let token = loadToken(key: kIdToken), !isTokenExpired(token) {
            return token
        }
        guard loadToken(key: kRefreshToken) != nil else {
            await signOut()
            throw CloudAuthError.noToken
        }
        return try await coalesceRefresh()
    }

    /// Returns the in-flight refresh Task if one exists, otherwise creates a new one.
    /// Clears itself on completion so the next expiry triggers a fresh request.
    private func coalesceRefresh() async throws -> String {
        if let existing = refreshTask {
            return try await existing.value
        }
        let task = Task<String, Error> { [weak self] in
            guard let self else { throw CloudAuthError.noToken }
            return try await self.performRefresh()
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh() async throws -> String {
        guard let refreshToken = loadToken(key: kRefreshToken) else {
            await signOut()
            throw CloudAuthError.noToken
        }
        let body: [String: Any] = [
            "AuthFlow": "REFRESH_TOKEN_AUTH",
            "AuthParameters": ["REFRESH_TOKEN": refreshToken],
            "ClientId": appClientId
        ]
        let result = try await cognitoRequest(target: "InitiateAuth", body: body)

        guard
            let authResult  = result["AuthenticationResult"] as? [String: Any],
            let idToken     = authResult["IdToken"]          as? String,
            let accessToken = authResult["AccessToken"]      as? String
        else { await signOut(); throw CloudAuthError.noToken }

        saveToken(key: kIdToken,      value: idToken)
        saveToken(key: kAccessToken,  value: accessToken)
        return idToken
    }

    // MARK: - Cognito REST call

    private func cognitoRequest(target: String, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: cognitoEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1",                 forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityProviderService.\(target)", forHTTPHeaderField: "X-Amz-Target")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudAuthError.networkError("No HTTP response")
        }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        if http.statusCode != 200 {
            let message = json["message"] as? String ?? "Unknown error"
            if http.statusCode == 400,
               let code = json["__type"] as? String,
               code.contains("NotAuthorized") || code.contains("UserNotFound") {
                throw CloudAuthError.invalidCredentials
            }
            throw CloudAuthError.networkError(message)
        }
        return json
    }

    // MARK: - JWT expiry check

    private func isTokenExpired(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return true }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard
            let data    = Data(base64Encoded: base64),
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let exp     = payload["exp"] as? TimeInterval
        else { return true }
        return Date().timeIntervalSince1970 > exp - 60
    }

    // MARK: - Keychain helpers

    private func saveToken(key: String, value: String) {
        let data  = Data(value.utf8)
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecValueData: data]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadToken(key: String) -> String? {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key,
                                      kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteToken(key: String) {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - API Helpers

    private func apiRequest(path: String) async throws -> Data {
        guard let url = URL(string: apiUrl + path) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue(try await idToken(), forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            throw NSError(
                domain: "CloudAPI",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"]
            )
        }
        return data
    }

    // MARK: - File Listing

    func listFiles(prefix: String = "") async throws -> (folders: [CloudFolder], files: [CloudFile]) {
        let path = prefix.isEmpty
            ? "files"
            : "files?prefix=\(prefix.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? prefix)"
        let data = try await apiRequest(path: path)

        let json       = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let rawFolders = json?["folders"] as? [[String: Any]] ?? []
        let rawFiles   = json?["files"]   as? [[String: Any]] ?? []

        let folders = rawFolders.compactMap { d -> CloudFolder? in
            guard let key = d["key"] as? String else { return nil }
            return CloudFolder(
                key:           key,
                hasMp3s:       d["hasMp3s"]      as? Bool ?? false,
                hasSubFolders: d["hasSubFolders"] as? Bool ?? false
            )
        }
        let files = rawFiles.compactMap { d -> CloudFile? in
            guard let key = d["key"] as? String else { return nil }
            return CloudFile(key: key, size: d["size"] as? Int ?? 0)
        }
        return (folders, files)
    }

    // MARK: - Sync

    func sync(localTracks: [Track]) async {
        guard isSignedIn else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let cloudFiles = try await fetchAllMp3s(under: "Music/")

            let localPaths = Set(localTracks.map { $0.relativePath.lowercased() })
            let cloudPaths = Set(cloudFiles.compactMap { $0.musicRelativePath?.lowercased() })

            var cloudOnly: [SyncItem] = []
            var synced:    [SyncItem] = []

            for file in cloudFiles {
                let item = SyncItem(
                    file:      file,
                    subfolder: file.musicRelativeFolder ?? "",
                    isLocal:   file.musicRelativePath.map { localPaths.contains($0.lowercased()) } ?? false
                )
                if item.isLocal { synced.append(item) }
                else            { cloudOnly.append(item) }
            }

            let localOnly = localTracks.filter {
                !cloudPaths.contains($0.relativePath.lowercased())
            }

            let sortedCloudOnly = cloudOnly.sorted {
                $0.subfolder == $1.subfolder
                    ? $0.file.name < $1.file.name
                    : $0.subfolder < $1.subfolder
            }

            syncResult = SyncResult(
                cloudOnly: sortedCloudOnly,
                synced:    synced,
                localOnly: localOnly,
                checkedAt: Date()
            )
        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }
    }

    private func fetchAllMp3s(under prefix: String) async throws -> [CloudFile] {
        let result = try await listFiles(prefix: prefix)
        var mp3s   = result.files.filter(\.isMp3)

        try await withThrowingTaskGroup(of: [CloudFile].self) { group in
            for folder in result.folders {
                group.addTask { try await self.fetchAllMp3s(under: folder.key) }
            }
            for try await subFiles in group {
                mp3s.append(contentsOf: subFiles)
            }
        }
        return mp3s
    }

    // MARK: - Download

    func presignedURL(for key: String) async throws -> URL {
        let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        let data    = try await apiRequest(path: "files/\(encoded)")
        let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let urlString = json?["url"] as? String, let url = URL(string: urlString) else {
            throw URLError(.badServerResponse)
        }
        return url
    }

    func downloadTrack(_ file: CloudFile, subfolder: String? = nil) async throws -> URL {
        let presigned = try await presignedURL(for: file.key)

        let (tempURL, response) = try await URLSession.shared.download(from: presigned)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let destDir: URL
        if let subfolder, !subfolder.isEmpty {
            destDir = documentsURL.appendingPathComponent(subfolder, isDirectory: true)
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        } else {
            destDir = documentsURL
        }

        let dest = destDir.appendingPathComponent(file.name)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }
}
