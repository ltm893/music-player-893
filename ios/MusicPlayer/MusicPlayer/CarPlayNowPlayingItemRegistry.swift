//
//  CarPlayNowPlayingItemRegistry.swift
//  MusicPlayer
//
//  Keeps weak refs to track rows across the root + pushed folder templates so we
//  can update CPListItem now-playing visuals when the current track changes without
//  rebuilding the whole template stack.
//

import CarPlay
import Foundation

@MainActor
enum CarPlayNowPlayingItemRegistry {

    private struct Entry {
        weak var listItem: CPListItem?
        let trackURL: URL
    }

    private static var entries: [Entry] = []

    /// Call before building a new root list (replaces the whole template hierarchy).
    static func clear() {
        entries.removeAll()
    }

    static func register(_ item: CPListItem, trackURL: URL) {
        entries.append(Entry(listItem: item, trackURL: trackURL.standardizedFileURL))
    }

    /// Updates playing indicator on all known track rows to match the shared player.
    static func sync() {
        entries.removeAll { $0.listItem == nil }

        let vm = CarPlayPlayableContentAdapter.shared.player
        let currentURL = vm?.currentTrack?.url.standardizedFileURL
        let isPlaying = vm?.isPlaying ?? false

        for entry in entries {
            guard let item = entry.listItem else { continue }
            let matches = currentURL != nil && entry.trackURL == currentURL
            if matches {
                item.playingIndicatorLocation = .leading
                item.isPlaying = isPlaying
            } else {
                item.isPlaying = false
            }
        }
    }
}
