//
//  Track.swift
//  MusicPlayer
//
//  Created by Louis Melchiorre on 3/17/26.
//

import Foundation

struct Track: Identifiable, Equatable {
    let id: UUID
    let url: URL

    /// Display name — filename without extension.
    var title: String {
        url.deletingPathExtension().lastPathComponent
    }

    /// Folder name if stored in a subfolder, nil if at Documents root.
    /// Stored at init time so FileManager is only called once per Track.
    let folder: String?
    let relativePath: String

    init(url: URL) {
        self.id  = UUID()
        self.url = url
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .resolvingSymlinksInPath()
        let resolvedURL = url.resolvingSymlinksInPath()
        let parent = resolvedURL.deletingLastPathComponent()

        let docsPath = docs.path
        let fullPath = resolvedURL.path
        if fullPath.hasPrefix(docsPath + "/") {
            let relative = String(fullPath.dropFirst(docsPath.count + 1))
            self.relativePath = relative
            let folderPath = String(relative.dropLast(resolvedURL.lastPathComponent.count + 1))
            self.folder = folderPath.isEmpty ? nil : folderPath
        } else {
            self.relativePath = resolvedURL.lastPathComponent
            self.folder = parent.standardized == docs.standardized ? nil : parent.lastPathComponent
        }
    }

    /// Explicit nonisolated == so Track's Equatable conformance works in
    /// nonisolated contexts even when SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
    nonisolated static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}
