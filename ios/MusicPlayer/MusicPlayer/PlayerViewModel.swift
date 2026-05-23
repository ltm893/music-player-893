//
//  PlayerViewModel.swift
//  MusicPlayer
//
//  Created by Louis Melchiorre on 3/17/26.
//

import Foundation
import Combine
import AVFoundation
import MediaPlayer
import UIKit

@MainActor
class PlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {

    // MARK: - Published State

    @Published var tracks: [Track] = []
    @Published var currentTrack: Track? = nil
    @Published var isPlaying: Bool = false
    @Published var isShuffled: Bool = false

    // Progress bar
    @Published var currentTime: Double = 0
    @Published var duration:    Double = 0

    // MARK: - Private

    private var player: AVAudioPlayer?
    private var queue: [Track] = []
    private var queueIndex: Int = 0
    private var progressTimer: Timer?

    /// Resolved once at init — FileManager lookup is not free.
    private let documentsURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]

    // MARK: - Init

    override init() {
        super.init()
        configureAudioSession()
        setupRemoteControls()
        loadTracksFromDisk()
        CarPlayPlayableContentAdapter.shared.register(with: self)
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private nonisolated func handleInterruption(notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeVal)
        else { return }

        if type == .ended {
            let optionsVal = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsVal)
            if options.contains(.shouldResume) {
                Task { @MainActor in self.resume() }
            }
        }
    }

    @objc private nonisolated func handleRouteChange(notification: Notification) {
        guard
            let info = notification.userInfo,
            let reasonVal = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonVal)
        else { return }

        switch reason {
        case .oldDeviceUnavailable:
            Task { @MainActor in self.pause() }
        case .newDeviceAvailable:
            Task { @MainActor in if self.isPlaying { self.resume() } }
        default:
            break
        }
    }

    // MARK: - Lock Screen / Remote Controls

    private func setupRemoteControls() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.resume(); return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause(); return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.isPlaying ? self.pause() : self.resume()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipNext(); return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipBack(); return .success
        }

        // Enable lock screen scrubbing
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let e = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: e.positionTime)
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            CarPlayNowPlayingItemRegistry.sync()
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle:             track.title,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let player = player {
            info[MPMediaItemPropertyPlaybackDuration]         = player.duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        CarPlayNowPlayingItemRegistry.sync()

        let trackURL = track.url
        Task(priority: .utility) { [trackURL] in
            let art = await Self.albumArt(for: trackURL)
            guard self.currentTrack?.url == trackURL else { return }
            var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            updated[MPMediaItemPropertyArtwork] = art
            MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
        }
    }

    private nonisolated static func albumArt(for url: URL) async -> MPMediaItemArtwork? {
        let asset = AVURLAsset(url: url)
        guard let metadata = try? await asset.load(.commonMetadata) else { return nil }

        for item in metadata {
            guard item.commonKey == .commonKeyArtwork else { continue }
            guard let data = try? await item.load(.dataValue),
                  let image = UIImage(data: data) else { continue }
            return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        return nil
    }

    // MARK: - Progress Timer

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                self.duration    = player.duration
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Seek

    func seek(to time: Double) {
        guard let player else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
        currentTime = clamped
        updateNowPlayingInfo()
    }

    // MARK: - Track Grouping

    var groupedTracks: [(key: String, tracks: [Track])] {
        let grouped = Dictionary(grouping: tracks) { $0.folder ?? "" }
        return grouped.keys
            .sorted { a, b in a.isEmpty ? true : b.isEmpty ? false : a < b }
            .map { (key: $0, tracks: grouped[$0]!) }
    }

    // MARK: - Disk

    func loadTracksFromDisk() {
        guard let enumerator = FileManager.default.enumerator(
            at: documentsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var found: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "mp3" { found.append(url) }
        }
        tracks = found
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { Track(url: $0) }
        CarPlayPlayableContentAdapter.shared.reloadFromPlayer()
    }

    func importTrack(from sourceURL: URL) {
        let resolvedDocs   = documentsURL.resolvingSymlinksInPath()
        let resolvedSource = sourceURL.resolvingSymlinksInPath()
        if resolvedSource.path.hasPrefix(resolvedDocs.path) {
            loadTracksFromDisk(); return
        }
        let destination = documentsURL.appendingPathComponent(sourceURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            loadTracksFromDisk(); return
        }
        do {
            let accessed = sourceURL.startAccessingSecurityScopedResource()
            defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            loadTracksFromDisk()
        } catch {
            print("Import failed: \(error)")
        }
    }

    func deleteTrack(_ track: Track) {
        if currentTrack == track { stop() }
        try? FileManager.default.removeItem(at: track.url)
        loadTracksFromDisk()
    }

    // MARK: - Playback Controls

    /// Single-track playback; clears any active folder queue.
    func play(_ track: Track) {
        queue = []
        queueIndex = 0
        isShuffled = false
        startPlayback(track)
    }

    private func startPlayback(_ track: Track) {
        do {
            player = try AVAudioPlayer(contentsOf: track.url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            currentTrack = track
            isPlaying    = true
            duration     = player?.duration ?? 0
            currentTime  = 0
            startProgressTimer()
            updateNowPlayingInfo()
        } catch {
            print("Playback error: \(error)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
        updateNowPlayingInfo()
    }

    func resume() {
        player?.play()
        isPlaying = true
        startProgressTimer()
        updateNowPlayingInfo()
    }

    func stop() {
        player?.stop()
        player = nil
        currentTrack = nil
        isPlaying    = false
        isShuffled   = false
        currentTime  = 0
        duration     = 0
        queue = []; queueIndex = 0
        stopProgressTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        CarPlayNowPlayingItemRegistry.sync()
    }

    // MARK: - Skip Controls

    func skipNext() {
        if !queue.isEmpty {
            let next = queueIndex + 1
            if next < queue.count { queueIndex = next; startPlayback(queue[queueIndex]) }
        } else if let current = currentTrack,
                  let idx = tracks.firstIndex(of: current),
                  idx + 1 < tracks.count {
            play(tracks[idx + 1])
        }
    }

    func skipBack() {
        // If more than 3 seconds in, restart; otherwise go to previous
        if let player, player.currentTime > 3 {
            seek(to: 0); return
        }
        if !queue.isEmpty {
            let prev = queueIndex - 1
            if prev >= 0 { queueIndex = prev; startPlayback(queue[queueIndex]) }
            else { seek(to: 0) }
        } else if let current = currentTrack,
                  let idx = tracks.firstIndex(of: current) {
            if idx > 0 { play(tracks[idx - 1]) }
            else { seek(to: 0) }
        }
    }

    // MARK: - Queue Playback

    func playAll(_ tracksToQueue: [Track]) {
        guard !tracksToQueue.isEmpty else { return }
        isShuffled = false
        queue = tracksToQueue
        queueIndex = 0
        startPlayback(queue[0])
    }

    func playShuffle(_ tracksToQueue: [Track]) {
        guard !tracksToQueue.isEmpty else { return }
        isShuffled = true
        queue = tracksToQueue.shuffled()
        queueIndex = 0
        startPlayback(queue[0])
    }

    private func playNext() {
        queueIndex += 1
        if queueIndex < queue.count {
            startPlayback(queue[queueIndex])
        } else {
            queue = []; queueIndex = 0
            currentTrack = nil; isPlaying = false
            currentTime  = 0; duration = 0
            stopProgressTimer()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if self.queueIndex + 1 < self.queue.count {
                self.playNext()
            } else {
                self.stop()
            }
        }
    }
}
