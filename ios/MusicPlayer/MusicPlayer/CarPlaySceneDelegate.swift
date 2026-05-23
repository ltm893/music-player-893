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

    private(set) static weak var connectedInterface: CPInterfaceController?

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
        CarPlayNowPlayingItemRegistry.clear()
        let player = CarPlayPlayableContentAdapter.shared.player
        let tracks = player?.tracks ?? []
        let library = LocalLibraryTree.build(from: tracks)
        let list = CarPlayListTemplates.rootListTemplate(library: library)
        interfaceController.setRootTemplate(list, animated: animated) { _, _ in }
    }

    @MainActor
    static func rebuildRootList(animated: Bool) {
        guard let ic = connectedInterface else { return }
        installRootList(into: ic, animated: animated)
    }
}
