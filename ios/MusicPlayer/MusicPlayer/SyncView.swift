import SwiftUI

struct SyncView: View {

    @ObservedObject var service: CloudService
    var localTracks: [Track]
    var onDownloaded: (URL) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var downloadingKeys: Set<String> = []
    @State private var downloadingAll = false
    @State private var downloadAllProgress: (done: Int, total: Int) = (0, 0)
    @State private var currentLocalTracks: [Track] = []

    private var result: SyncResult? { service.syncResult }

    var body: some View {
        NavigationStack {
            Group {
                if service.isSyncing {
                    syncingView
                } else if let result {
                    syncResultView(result)
                } else {
                    syncingView
                }
            }
            .navigationTitle("Sync")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.navyBlue)
            .foregroundStyle(Color.navyBlue)
            .background(Color.appBackground)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await service.sync(localTracks: currentLocalTracks) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(service.isSyncing || downloadingAll)
                }
            }
            .task {
                currentLocalTracks = localTracks
                await service.sync(localTracks: currentLocalTracks)
            }
        }
    }

    private var syncingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Checking cloud…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func syncResultView(_ result: SyncResult) -> some View {
        List {
            Section {
                SyncSummaryRow(
                    cloudTotal: result.totalCloud,
                    synced:     result.synced.count,
                    missing:    result.missingCount,
                    localOnly:  result.localOnly.count,
                    checkedAt:  result.checkedAt
                )
                .listRowBackground(Color.appBackground)
            }

            if !result.cloudOnly.isEmpty {
                Section {
                    if downloadingAll {
                        HStack {
                            ProgressView()
                            Text("Downloading \(downloadAllProgress.done) / \(downloadAllProgress.total)…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            Task { await downloadAllMissing(result.cloudOnly) }
                        } label: {
                            Label("Download All Missing (\(result.missingCount))",
                                  systemImage: "arrow.down.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Color.navyBlue)
                        }
                        .tint(Color.navyBlue)
                    }
                }

                Section("Not Downloaded — \(result.missingCount)") {
                    ForEach(result.cloudOnly) { item in
                        SyncItemRow(
                            item:          item,
                            isDownloading: downloadingKeys.contains(item.file.key)
                        ) {
                            Task { await downloadOne(item) }
                        }
                    }
                }
            }

            if !result.synced.isEmpty {
                Section("On Device — \(result.synced.count)") {
                    ForEach(result.synced) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.file.displayTitle)
                                    .font(.body).foregroundColor(Color.navyBlue).lineLimit(1)
                                if !item.subfolder.isEmpty {
                                    Text(item.subfolder)
                                        .font(.caption).foregroundColor(Color.navyBlue.opacity(0.6))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !result.localOnly.isEmpty {
                Section("Local Only — \(result.localOnly.count)") {
                    ForEach(result.localOnly) { track in
                        HStack(spacing: 10) {
                            Image(systemName: "iphone").foregroundColor(Color.navyBlue)
                            Text(track.title)
                                .font(.body).foregroundColor(Color.navyBlue).lineLimit(1)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    private func downloadOne(_ item: SyncItem) async {
        downloadingKeys.insert(item.file.key)
        do {
            let url = try await service.downloadTrack(item.file, subfolder: item.subfolderOrNil)
            onDownloaded(url)
            currentLocalTracks.append(Track(url: url))
            await service.sync(localTracks: currentLocalTracks)
        } catch {
            service.errorMessage = "Download failed: \(error.localizedDescription)"
        }
        downloadingKeys.remove(item.file.key)
    }

    private func downloadAllMissing(_ items: [SyncItem]) async {
        downloadingAll = true
        downloadAllProgress = (0, items.count)
        await withTaskGroup(of: URL?.self) { group in
            for item in items {
                group.addTask { try? await self.service.downloadTrack(item.file, subfolder: item.subfolderOrNil) }
            }
            for await url in group {
                downloadAllProgress.done += 1
                if let url {
                    onDownloaded(url)
                    currentLocalTracks.append(Track(url: url))
                }
            }
        }
        downloadingAll = false
        await service.sync(localTracks: currentLocalTracks)
    }
}

// MARK: - Summary Row

private struct SyncSummaryRow: View {
    let cloudTotal: Int
    let synced: Int
    let missing: Int
    let localOnly: Int
    let checkedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                statBadge(value: cloudTotal, label: "Cloud",   color: .accentColor)
                statBadge(value: synced,     label: "Synced",  color: .green)
                statBadge(value: missing,    label: "Missing", color: missing > 0 ? .orange : .secondary)
            }
            Text("Checked \(checkedAt.formatted(.relative(presentation: .named)))")
                .font(.caption)
                .foregroundColor(Color.navyBlue.opacity(0.6))
        }
        .padding(.vertical, 4)
    }

    private func statBadge(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title2.weight(.semibold)).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}

// MARK: - Sync Item Row

private struct SyncItemRow: View {
    let item: SyncItem
    let isDownloading: Bool
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle").foregroundColor(Color.navyBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.file.displayTitle)
                    .font(.body).foregroundColor(Color.navyBlue).lineLimit(1)
                if !item.subfolder.isEmpty {
                    Text(item.subfolder)
                        .font(.caption).foregroundColor(Color.navyBlue.opacity(0.6))
                }
            }
            Spacer()
            if isDownloading {
                ProgressView()
            } else {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.to.line").foregroundColor(Color.navyBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}
