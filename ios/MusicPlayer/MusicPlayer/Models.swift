import Foundation

// MARK: - CloudFolder

struct CloudFolder: Identifiable {
    let id = UUID()
    let key: String
    let name: String
    let hasMp3s: Bool
    let hasSubFolders: Bool

    init(key: String, hasMp3s: Bool, hasSubFolders: Bool) {
        self.key           = key
        self.hasMp3s       = hasMp3s
        self.hasSubFolders = hasSubFolders
        self.name          = key.split(separator: "/").last.map(String.init) ?? key
    }
}

// MARK: - CloudFile

struct CloudFile: Identifiable {
    let id = UUID()
    let key: String
    let size: Int
    let name: String

    init(key: String, size: Int) {
        self.key  = key
        self.size = size
        self.name = key.split(separator: "/").last.map(String.init) ?? key
    }

    var isMp3: Bool { name.lowercased().hasSuffix(".mp3") }
    var displayTitle: String { name.replacingOccurrences(of: ".mp3", with: "") }

    private var keyParts: [String] {
        key.split(separator: "/").map(String.init)
    }

    /// Full path under `Music/`, including filename.
    /// Example: Music/A/B/song.mp3 -> A/B/song.mp3
    var musicRelativePath: String? {
        var parts = keyParts
        if parts.first == "Music" { parts.removeFirst() }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "/")
    }

    /// Folder path under `Music/`, excluding filename.
    /// Example: Music/A/B/song.mp3 -> A/B
    var musicRelativeFolder: String? {
        guard let relativePath = musicRelativePath else { return nil }
        let fileName = name
        guard relativePath.count > fileName.count else { return nil }
        let folder = String(relativePath.dropLast(fileName.count + 1))
        return folder.isEmpty ? nil : folder
    }
}

// MARK: - SyncItem

struct SyncItem: Identifiable {
    let id = UUID()
    let file: CloudFile
    let subfolder: String
    let isLocal: Bool

    var subfolderOrNil: String? { subfolder.isEmpty ? nil : subfolder }
}

// MARK: - SyncResult

struct SyncResult {
    let cloudOnly:  [SyncItem]
    let synced:     [SyncItem]
    let localOnly:  [Track]
    let checkedAt:  Date

    var missingCount: Int { cloudOnly.count }
    var totalCloud:   Int { cloudOnly.count + synced.count }
}
