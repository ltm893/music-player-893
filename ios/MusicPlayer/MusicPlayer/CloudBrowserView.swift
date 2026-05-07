import SwiftUI

private struct FolderContent {
    var subFolders: [CloudFolder]
    var files: [CloudFile]
}

struct CloudBrowserView: View {

    @ObservedObject var service: CloudService
    var localTracks: [Track]
    var onDownloaded: (URL) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var rootFolders: [CloudFolder] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var expandedKeys: Set<String> = []
    @State private var contents: [String: FolderContent] = [:]
    @State private var loadingKeys: Set<String> = []
    @State private var showSync = false
    @State private var currentLocalTracks: [Track] = []

    private var missingCount: Int { service.syncResult?.missingCount ?? 0 }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading…")
                } else if let error = errorMessage {
                    ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
                } else {
                    List {
                        ForEach(rootFolders) { folder in
                            rootFolderSection(folder)
                        }
                        if rootFolders.isEmpty {
                            Text("No folders found.").foregroundColor(.secondary)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.navyBlue)
            .background(Color.appBackground)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Button { showSync = true } label: {
                        HStack(spacing: 6) {
                            Text("Music")
                                .font(.headline)
                                .foregroundColor(.primary)
                            ZStack(alignment: .topTrailing) {
                                if service.isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "arrow.2.circlepath")
                                        .font(.footnote)
                                        .foregroundColor(.accentColor)
                                }
                                if missingCount > 0 {
                                    Text("\(missingCount)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(3)
                                        .background(Color.orange)
                                        .clipShape(Circle())
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                    }
                    .disabled(service.isSyncing)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await service.signOut() } } label: {
                        Text("Sign Out").font(.caption)
                    }
                }
            }
            .task {
                currentLocalTracks = localTracks
                await loadRoot()
            }
            .sheet(isPresented: $showSync) {
                SyncView(
                    service: service,
                    localTracks: currentLocalTracks,
                    onDownloaded: { url in
                        onDownloaded(url)
                        currentLocalTracks.append(Track(url: url))
                    }
                )
                .onDisappear {
                    Task { await service.sync(localTracks: currentLocalTracks) }
                }
            }
        }
    }

    // MARK: - Root Section

    private func rootFolderSection(_ folder: CloudFolder) -> some View {
        Section {
            rootFolderBody(folder)
        } header: {
            folderHeaderRow(folder: folder)
        }
    }

    @ViewBuilder
    private func rootFolderBody(_ folder: CloudFolder) -> some View {
        if expandedKeys.contains(folder.key) {
            folderExpandedContent(folder, indent: 16, loadingText: "Loading…")
        }
    }

    private func folderToggleRow(_ folder: CloudFolder, indent: CGFloat) -> some View {
        let depth = max(0, Int((indent - 16) / 16))
        let folderIcon = depth == 0 ? "opticaldisc" : "folder"
        let tone = max(0.45, 1.0 - (Double(depth) * 0.12))
        return HStack(spacing: 6) {
            Image(systemName: expandedKeys.contains(folder.key) ? "chevron.down" : "chevron.right")
                .font(.caption2)
                .foregroundColor(Color.navyBlue.opacity(tone))
            Image(systemName: folderIcon)
                .foregroundColor(Color.navyBlue.opacity(tone))
            Text(folder.name)
                .font(.subheadline)
                .foregroundColor(Color.navyBlue.opacity(tone))
            Spacer()
        }
        .padding(.leading, indent)
        .contentShape(Rectangle())
        .onTapGesture { toggleFolder(folder) }
    }

    private func folderExpandedContent(_ folder: CloudFolder, indent: CGFloat, loadingText: String? = nil) -> AnyView {
        let resolvedLoadingText = loadingText ?? "Loading…"
        guard expandedKeys.contains(folder.key) else {
            return AnyView(EmptyView())
        }

        if loadingKeys.contains(folder.key) {
            return AnyView(
                HStack {
                    Spacer()
                    ProgressView(resolvedLoadingText)
                    Spacer()
                }
            )
        }

        guard let content = contents[folder.key] else {
            return AnyView(EmptyView())
        }

        return AnyView(
            Group {
                ForEach(content.subFolders) { sub in
                    folderToggleRow(sub, indent: indent)
                    folderExpandedContent(sub, indent: indent + 16)
                }
                let mp3s = content.files.filter(\.isMp3)
                ForEach(mp3s) { file in
                    trackRow(file, indent: indent)
                }
                if content.subFolders.isEmpty && mp3s.isEmpty {
                    Text("Empty folder")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.leading, indent)
                }
            }
        )
    }

    private func trackRow(_ file: CloudFile, indent: CGFloat = 16) -> some View {
        let depth = max(0, Int((indent - 16) / 16))
        let tone = max(0.5, 1.0 - (Double(depth) * 0.12))
        return HStack {
            Image(systemName: "music.note").foregroundColor(Color.navyBlue.opacity(tone))
            Text(file.displayTitle)
                .font(.body)
                .foregroundColor(Color.navyBlue.opacity(tone))
                .lineLimit(1)
            Spacer()
        }
        .padding(.leading, indent)
    }

    private func folderHeaderRow(folder: CloudFolder) -> some View {
        Button {
            toggleFolder(folder)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: expandedKeys.contains(folder.key) ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Color.navyBlue)
                Text(folder.name)
                    .font(.subheadline)
                    .foregroundColor(Color.navyBlue)
                    .textCase(nil)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data Actions

    private func loadRoot() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await service.listFiles(prefix: "Music/")
            rootFolders = result.folders
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleFolder(_ folder: CloudFolder) {
        if expandedKeys.contains(folder.key) {
            expandedKeys.remove(folder.key)
        } else {
            expandedKeys.insert(folder.key)
            if contents[folder.key] == nil {
                Task { await loadContents(for: folder) }
            }
        }
    }

    private func loadContents(for folder: CloudFolder) async {
        loadingKeys.insert(folder.key)
        do {
            let result = try await service.listFiles(prefix: folder.key)
            contents[folder.key] = FolderContent(subFolders: result.folders, files: result.files)
        } catch {
            errorMessage = error.localizedDescription
            contents[folder.key] = FolderContent(subFolders: [], files: [])
        }
        loadingKeys.remove(folder.key)
    }
}
