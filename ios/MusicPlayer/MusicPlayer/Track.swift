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

    init(url: URL) {
        self.id  = UUID()
        self.url = url
        let docs   = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let parent = url.deletingLastPathComponent()
        self.folder = parent.standardized == docs.standardized ? nil : parent.lastPathComponent
    }

    /// Explicit nonisolated == so Track's Equatable conformance works in
    /// nonisolated contexts even when SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
    nonisolated static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}
