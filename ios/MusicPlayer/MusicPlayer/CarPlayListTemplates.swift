//
//  CarPlayListTemplates.swift
//  MusicPlayer
//
//  Nested CPListTemplate hierarchy (Option 2): folders via pushTemplate,
//  Play all / Shuffle per folder, single-tap plays one track.
//

import CarPlay
import Foundation

@MainActor
enum CarPlayListTemplates {

    static func rootListTemplate(library: LocalLibraryRoot) -> CPListTemplate {
        listTemplate(title: "Music", node: nil, library: library)
    }

    static func folderListTemplate(node: LocalFolderNode) -> CPListTemplate {
        listTemplate(title: node.name, node: node, library: nil)
    }

    // MARK: - Template assembly

    private static func listTemplate(
        title: String,
        node: LocalFolderNode?,
        library: LocalLibraryRoot?
    ) -> CPListTemplate {
        var sections: [CPListSection] = []

        if let node {
            if node.showsPlayButtons, !node.allTracks.isEmpty {
                sections.append(playControlsSection(tracks: node.allTracks))
            }
            if !node.children.isEmpty {
                sections.append(CPListSection(items: node.children.map { folderItem($0) }))
            }
            if !node.directTracks.isEmpty {
                let playCount = node.showsPlayButtons && !node.allTracks.isEmpty ? 2 : 0
                let budget = itemBudget(playControls: playCount, folderItems: node.children.count)
                sections.append(CPListSection(items: trackListItems(node.directTracks, itemBudget: budget)))
            }
        } else if let library {
            let folderCount = library.folders.count
            if !library.rootTracks.isEmpty {
                let budget = itemBudget(playControls: 0, folderItems: folderCount)
                sections.append(CPListSection(items: trackListItems(library.rootTracks, itemBudget: budget)))
            }
            if !library.folders.isEmpty {
                sections.append(CPListSection(items: library.folders.map { folderItem($0) }))
            }
        }

        if sections.isEmpty {
            let hint = CPListItem(text: "No tracks", detailText: "Add music on your iPhone")
            hint.handler = { _, completion in completion() }
            sections = [CPListSection(items: [hint])]
        }

        let template = CPListTemplate(title: title, sections: sections)
        CarPlayNowPlayingItemRegistry.sync()
        return template
    }

    private static func playControlsSection(tracks: [Track]) -> CPListSection {
        let playAll = CPListItem(text: "Play All", detailText: "\(tracks.count) songs")
        playAll.handler = { _, completion in
            Task { @MainActor in
                CarPlayPlayableContentAdapter.shared.player?.playAll(tracks)
                completion()
            }
        }

        let shuffle = CPListItem(text: "Shuffle", detailText: "\(tracks.count) songs")
        shuffle.handler = { _, completion in
            Task { @MainActor in
                CarPlayPlayableContentAdapter.shared.player?.playShuffle(tracks)
                completion()
            }
        }

        return CPListSection(items: [playAll, shuffle])
    }

    private static func folderItem(_ node: LocalFolderNode) -> CPListItem {
        let count = node.allTracks.count
        let detail = count == 1 ? "1 song" : "\(count) songs"
        let item = CPListItem(text: node.name, detailText: detail)
        item.accessoryType = .disclosureIndicator
        item.handler = { _, completion in
            Task { @MainActor in
                guard let interface = CarPlaySceneDelegate.connectedInterface else {
                    completion()
                    return
                }
                let template = folderListTemplate(node: node)
                interface.pushTemplate(template, animated: true) { _, _ in }
                completion()
            }
        }
        return item
    }

    // MARK: - CarPlay list limits

    /// CarPlay caps total rows per `CPListTemplate` (often ~10); paginate with “More Songs”.
    private static func itemBudget(playControls: Int, folderItems: Int) -> Int {
        max(0, CPListTemplate.maximumItemCount - playControls - folderItems)
    }

    private static func trackListItems(_ tracks: [Track], itemBudget: Int) -> [CPListItem] {
        guard itemBudget > 0, !tracks.isEmpty else { return [] }
        if tracks.count <= itemBudget {
            return tracks.map { trackItem($0) }
        }
        let visibleCount = itemBudget - 1
        var items = tracks.prefix(visibleCount).map { trackItem($0) }
        items.append(moreTracksItem(Array(tracks.dropFirst(visibleCount))))
        return items
    }

    private static func moreTracksItem(_ remainingTracks: [Track]) -> CPListItem {
        let detail = remainingTracks.count == 1 ? "1 more song" : "\(remainingTracks.count) more songs"
        let item = CPListItem(text: "More Songs", detailText: detail)
        item.accessoryType = .disclosureIndicator
        item.handler = { _, completion in
            Task { @MainActor in
                guard let interface = CarPlaySceneDelegate.connectedInterface else {
                    completion()
                    return
                }
                let template = tracksPageListTemplate(tracks: remainingTracks)
                interface.pushTemplate(template, animated: true) { _, _ in }
                completion()
            }
        }
        return item
    }

    private static func tracksPageListTemplate(tracks: [Track]) -> CPListTemplate {
        let items = trackListItems(tracks, itemBudget: CPListTemplate.maximumItemCount)
        let template = CPListTemplate(title: "Songs", sections: [CPListSection(items: items)])
        CarPlayNowPlayingItemRegistry.sync()
        return template
    }

    private static func trackItem(_ track: Track) -> CPListItem {
        let item = CPListItem(text: track.title, detailText: nil)
        item.handler = { _, completion in
            Task { @MainActor in
                CarPlayPlayableContentAdapter.shared.player?.play(track)
                completion()
            }
        }
        CarPlayNowPlayingItemRegistry.register(item, trackURL: track.url)
        return item
    }
}
