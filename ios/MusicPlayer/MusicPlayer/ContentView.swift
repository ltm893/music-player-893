import SwiftUI

struct ContentView: View {

    @StateObject private var vm      = PlayerViewModel()
    @StateObject private var cloud   = CloudService()
    @State private var showCloud     = false
    @State private var showLogin     = false
    @State private var expandedFolders: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Track List ──────────────────────────────────────────
                if vm.tracks.isEmpty {
                    ContentUnavailableView(
                        "No Tracks",
                        systemImage: "music.note",
                        description: Text("Tap the cloud icon to browse and download tracks ☁️")
                    )
                } else {
                    List {
                        ForEach(vm.groupedTracks, id: \.key) { group in
                            let isExpanded = expandedFolders.contains(group.key)

                            Section {
                                if isExpanded {
                                    ForEach(group.tracks) { track in
                                        TrackRow(
                                            track: track,
                                            isPlaying: vm.isPlaying && vm.currentTrack == track
                                        ) {
                                            if vm.currentTrack == track {
                                                vm.isPlaying ? vm.pause() : vm.resume()
                                            } else {
                                                vm.play(track)
                                            }
                                        }
                                        .listRowBackground(Color.appBackground)
                                    }
                                    .onDelete { offsets in
                                        offsets.map { group.tracks[$0] }.forEach { vm.deleteTrack($0) }
                                    }
                                }
                            } header: {
                                HStack {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if expandedFolders.contains(group.key) {
                                                expandedFolders.remove(group.key)
                                            } else {
                                                expandedFolders.insert(group.key)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                                .font(.caption2)
                                                .foregroundColor(Color.navyBlue)
                                            Text(group.key.isEmpty ? "Library" : group.key)
                                                .font(.headline)
                                                .foregroundColor(Color.navyBlue)
                                                .textCase(nil)
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    Spacer()

                                    let isGroupActive   = vm.isPlaying && group.tracks.contains(where: { $0 == vm.currentTrack })
                                    let isPlayActive    = isGroupActive && !vm.isShuffled
                                    let isShuffleActive = isGroupActive && vm.isShuffled

                                    Button { vm.playAll(group.tracks) } label: {
                                        Label("Play", systemImage: "play.fill")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .buttonStyle(DirectoryButtonStyle(isActive: isPlayActive))
                                    .controlSize(.mini)

                                    Button { vm.playShuffle(group.tracks) } label: {
                                        Label("Shuffle", systemImage: "shuffle")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .buttonStyle(DirectoryButtonStyle(isActive: isShuffleActive))
                                    .controlSize(.mini)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground)
                }

                // ── Player Bar ──────────────────────────────────────────
                if let track = vm.currentTrack {
                    PlayerBar(
                        title:       track.title,
                        isPlaying:   vm.isPlaying,
                        currentTime: vm.currentTime,
                        duration:    vm.duration,
                        onSkipBack:  { vm.skipBack() },
                        onPlayPause: { vm.isPlaying ? vm.pause() : vm.resume() },
                        onSkipNext:  { vm.skipNext() },
                        onStop:      { vm.stop() },
                        onSeek:      { vm.seek(to: $0) }
                    )
                }
            }
            .navigationTitle("Music")
            .tint(Color.navyBlue)
            .background(Color.appBackground)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if cloud.isSignedIn { showCloud = true }
                        else { showLogin = true }
                    } label: {
                        Image(systemName: "icloud.and.arrow.down")
                    }
                }
            }
            .onChange(of: cloud.isSignedIn) { _, signedIn in
                if signedIn { Task { await cloud.sync(localTracks: vm.tracks) } }
            }
            .sheet(isPresented: $showLogin) {
                LoginView(service: cloud)
                    .onDisappear { if cloud.isSignedIn { showCloud = true } }
            }
            .sheet(isPresented: $showCloud) {
                CloudBrowserView(
                    service: cloud,
                    localTracks: vm.tracks,
                    onDownloaded: { vm.importTrack(from: $0) }
                )
                .onDisappear {
                    Task { await cloud.sync(localTracks: vm.tracks) }
                }
            }
        }
    }
}

// MARK: - Track Row

private struct TrackRow: View {
    let track: Track
    let isPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle")
                    .font(.title2)
                    .foregroundColor(Color.navyBlue)
                Text(track.title)
                    .foregroundColor(Color.navyBlue)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Player Bar

private struct PlayerBar: View {
    let title:       String
    let isPlaying:   Bool
    let currentTime: Double
    let duration:    Double
    let onSkipBack:  () -> Void
    let onPlayPause: () -> Void
    let onSkipNext:  () -> Void
    let onStop:      () -> Void
    let onSeek:      (Double) -> Void

    @State private var isScrubbing = false
    @State private var scrubTime:  Double = 0

    private var displayTime: Double { isScrubbing ? scrubTime : currentTime }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .foregroundColor(Color.navyBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                VStack(spacing: 2) {
                    Slider(
                        value: Binding(
                            get: { displayTime },
                            set: { newVal in scrubTime = newVal; isScrubbing = true }
                        ),
                        in: 0...(duration > 0 ? duration : 1),
                        onEditingChanged: { editing in
                            if !editing { onSeek(scrubTime); isScrubbing = false }
                        }
                    )
                    .tint(Color.navyBlue)
                    .padding(.horizontal, 20)

                    HStack {
                        Text(formatTime(displayTime))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(Color.navyBlue.opacity(0.6))
                    .padding(.horizontal, 22)
                }

                HStack(spacing: 32) {
                    Button(action: onSkipBack) {
                        Image(systemName: "backward.fill").font(.title2).foregroundColor(Color.navyBlue)
                    }
                    Button(action: onPlayPause) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44)).foregroundColor(Color.navyBlue)
                    }
                    Button(action: onSkipNext) {
                        Image(systemName: "forward.fill").font(.title2).foregroundColor(Color.navyBlue)
                    }
                    Button(action: onStop) {
                        Image(systemName: "stop.fill").font(.title2).foregroundColor(Color.navyBlue.opacity(0.6))
                    }
                }
                .padding(.bottom, 16)
            }
            .background(.ultraThinMaterial)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview {
    ContentView()
}
