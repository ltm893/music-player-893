//
//  CarPlaySceneDelegate.swift
//  MusicPlayer
//
//  Audio apps must use `templateApplicationScene(_:didConnect:)` (no CPWindow).
//  Navigation apps use `...didConnect:to:` instead (Apple HIG / docs).
//  You must call `setRootTemplate` before `didConnect` returns — async `Task` can crash.
//

import CarPlay
import Foundation

final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {

    private static weak var connectedInterface: CPInterfaceController?

    private static func runOnMainActorSync<T>(_ body: @MainActor () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated(body)
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated(body)
        }
    }

    /// Audio / non-navigation CarPlay — two-parameter connect (no `CPWindow`).
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        Self.runOnMainActorSync {
            Self.connectedInterface = interfaceController
            Self.installRootList(into: interfaceController, animated: false)
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        Self.runOnMainActorSync {
            if Self.connectedInterface === interfaceController {
                Self.connectedInterface = nil
            }
        }
    }

    @MainActor
    private static func installRootList(into interfaceController: CPInterfaceController, animated: Bool) {
        let player = CarPlayPlayableContentAdapter.shared.player
        let tracks = player?.tracks ?? []

        let items: [CPListItem] = tracks.map { track in
            let item = CPListItem(text: track.title, detailText: track.folder)
            item.handler = { _, completion in
                Task { @MainActor in
                    CarPlayPlayableContentAdapter.shared.player?.play(track)
                    completion()
                }
            }
            return item
        }

        let sections: [CPListSection]
        if items.isEmpty {
            let hint = CPListItem(text: "No tracks", detailText: "Add music on your iPhone")
            hint.handler = { _, completion in completion() }
            sections = [CPListSection(items: [hint])]
        } else {
            sections = [CPListSection(items: items)]
        }

        let list = CPListTemplate(title: "Music", sections: sections)
        interfaceController.setRootTemplate(list, animated: animated) { _, _ in }
    }

    @MainActor
    static func rebuildRootList(animated: Bool) {
        guard let ic = connectedInterface else { return }
        installRootList(into: ic, animated: animated)
    }
}
