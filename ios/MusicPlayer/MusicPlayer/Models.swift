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

    var cloudSubfolder: String? {
        let parts = key.split(separator: "/")
        guard parts.count >= 3 else { return nil }
        return String(parts[parts.count - 2])
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
