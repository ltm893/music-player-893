//
//  CarPlayPlayableContentAdapter.swift
//  MusicPlayer
//
//  Holds the shared PlayerViewModel reference so CarPlay (CPTemplate) UI can
//  list tracks and start playback. Dashboard / Now Playing still use
//  MPNowPlayingInfoCenter from PlayerViewModel.
//

import Foundation

@MainActor
final class CarPlayPlayableContentAdapter {

    static let shared = CarPlayPlayableContentAdapter()

    weak var player: PlayerViewModel?

    private init() {}

    func register(with player: PlayerViewModel) {
        self.player = player
        CarPlaySceneDelegate.rebuildRootList(animated: false)
    }

    func reloadFromPlayer() {
        CarPlaySceneDelegate.rebuildRootList(animated: true)
    }
}
