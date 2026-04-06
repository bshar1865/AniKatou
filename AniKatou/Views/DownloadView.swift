import SwiftUI

struct DownloadView: View {
    var body: some View {
        DownloadsListView()
            .navigationTitle("Downloads")
    }
}

struct DownloadsListView: View {
    @StateObject private var manager = HLSDownloadManager.shared
    @State private var pendingGroupRemoval: AnimeDownloadGroup?
    @State private var confirmedGroupRemoval: AnimeDownloadGroup?

    private var groups: [AnimeDownloadGroup] {
        let grouped = Dictionary(grouping: manager.downloads, by: { $0.animeId })
        return grouped.compactMap { animeId, items in
            guard let first = items.first else { return nil }
            let sortedItems = items.sorted {
                (Double($0.episodeNumber) ?? 0) < (Double($1.episodeNumber) ?? 0)
            }
            return AnimeDownloadGroup(id: animeId, animeId: animeId, animeTitle: first.animeTitle, items: sortedItems)
        }
        .sorted { $0.animeTitle.localizedCaseInsensitiveCompare($1.animeTitle) == .orderedAscending }
    }

    private var activeCount: Int {
        manager.downloads.filter { $0.state == .queued || $0.state == .downloading }.count
    }

    private var completedCount: Int {
        manager.downloads.filter { $0.state == .completed }.count
    }

    private var failedCount: Int {
        manager.downloads.filter { $0.state == .failed }.count
    }

    private var hasOnlyFailures: Bool {
        failedCount > 0 && activeCount == 0 && completedCount == 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if groups.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Start a download from an episode in anime details")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                } else {
                    if hasOnlyFailures {
                        failureOnlyState
                    }

                    ForEach(groups) { group in
                        DownloadGroupCard(group: group, manager: manager) {
                            pendingGroupRemoval = group
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .confirmationDialog(
            "Remove downloads for \(pendingGroupRemoval?.animeTitle ?? "")?",
            isPresented: Binding(
                get: { pendingGroupRemoval != nil },
                set: { if !$0 { pendingGroupRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Continue", role: .destructive) {
                confirmedGroupRemoval = pendingGroupRemoval
                pendingGroupRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                pendingGroupRemoval = nil
            }
        } message: {
            Text("This will remove every queued, failed, and saved episode for this anime.")
        }
        .alert("Remove All Downloads", isPresented: Binding(
            get: { confirmedGroupRemoval != nil },
            set: { if !$0 { confirmedGroupRemoval = nil } }
        )) {
            Button("Remove All", role: .destructive) {
                if let group = confirmedGroupRemoval {
                    manager.removeDownloads(for: group.animeId)
                }
                confirmedGroupRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                confirmedGroupRemoval = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var failureOnlyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Downloads Need Attention", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.red)

            Text("Your recent downloads did not finish. Reconnect to the internet and retry, or remove failed items you no longer need.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct AnimeDownloadGroup: Identifiable {
    let id: String
    let animeId: String
    let animeTitle: String
    let items: [HLSDownloadItem]

    var activeCount: Int {
        items.filter { $0.state == .queued || $0.state == .downloading }.count
    }

    var completedCount: Int {
        items.filter { $0.state == .completed }.count
    }

    var failedCount: Int {
        items.filter { $0.state == .failed }.count
    }

    var averageProgress: Double {
        guard !items.isEmpty else { return 0 }
        return items.map(\.progress).reduce(0, +) / Double(items.count)
    }
}

private struct DownloadGroupCard: View {
    let group: AnimeDownloadGroup
    @ObservedObject var manager: HLSDownloadManager
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                NavigationLink(destination: DownloadAnimeDetailView(animeId: group.animeId, animeTitle: group.animeTitle, manager: manager)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.animeTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text("\(group.items.count) episodes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                NavigationLink(destination: AnimeDetailView(animeId: group.animeId)) {
                    Image(systemName: "info.circle")
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.blue)
                .buttonStyle(.borderless)

                Button("Remove", role: .destructive) {
                    onRemove()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
            }

            ProgressView(value: group.averageProgress)
                .tint(group.failedCount > 0 ? .red : .blue)

            HStack(spacing: 8) {
                GroupStatusPill(label: "Active", value: group.activeCount, tint: .blue)
                GroupStatusPill(label: "Completed", value: group.completedCount, tint: .green)
                if group.failedCount > 0 {
                    GroupStatusPill(label: "Failed", value: group.failedCount, tint: .red)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct GroupStatusPill: View {
    let label: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text("\(label) \(value)")
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(.tertiarySystemBackground)))
    }
}

private struct DownloadAnimeDetailView: View {
    let animeId: String
    let animeTitle: String
    @ObservedObject var manager: HLSDownloadManager

    private var items: [HLSDownloadItem] {
        manager.downloads
            .filter { $0.animeId == animeId }
            .sorted { (Double($0.episodeNumber) ?? 0) < (Double($1.episodeNumber) ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Episodes",
                        systemImage: "tray",
                        description: Text("This anime has no downloads right now.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                } else {
                    ForEach(items) { item in
                        DownloadEpisodeRow(
                            item: item,
                            animeId: animeId,
                            animeTitle: animeTitle,
                            onAction: {
                                if item.state == .queued || item.state == .downloading {
                                    manager.cancelDownload(item)
                                } else {
                                    manager.removeDownload(item)
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .navigationTitle(animeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: AnimeDetailView(animeId: animeId)) {
                    Text("Details")
                }
            }
        }
    }
}

private struct DownloadEpisodeRow: View {
    let item: HLSDownloadItem
    let animeId: String
    let animeTitle: String
    let onAction: () -> Void

    private var isActive: Bool {
        item.state == .queued || item.state == .downloading
    }

    private var actionLabel: String {
        isActive ? "Stop" : "Remove"
    }

    private var actionRole: ButtonRole? {
        isActive ? nil : .destructive
    }

    private var tintColor: Color {
        item.state == .failed ? .red : .blue
    }

    private var canPlay: Bool {
        item.state == .completed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Episode \(item.episodeNumber)")
                    .font(.headline)

                Spacer()

                StateBadge(text: statusTitle, tint: badgeTint)
            }

            ProgressView(value: item.progress)
                .tint(tintColor)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Watch to EPISODE \(item.episodeNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if item.state == .completed, let sizeText = downloadSizeText() {
                        Text("Used \(sizeText)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 10)

                if canPlay {
                    NavigationLink(destination: EpisodeView(
                        episodeId: item.episodeId,
                        animeId: animeId,
                        animeTitle: animeTitle,
                        episodeNumber: item.episodeNumber,
                        episodeTitle: nil,
                        thumbnailURL: nil
                    )) {
                        Text("Play")
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                } else {
                    Button(actionLabel, role: actionRole) {
                        onAction()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(isActive ? .orange : .red)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func downloadSizeText() -> String? {
        let bytes = downloadSizeBytes()
        guard bytes > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func downloadSizeBytes() -> Int64 {
        guard let path = item.localPath else { return 0 }
        let url = URL(fileURLWithPath: path)
        return fileSize(at: url)
    }

    private func fileSize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        if !isDirectory.boolValue {
            if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                return Int64(fileSize)
            }
            return 0
        }

        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(fileSize)
            }
        }
        return total
    }

    private var statusTitle: String {
        switch item.state {
        case .queued: return "Preparing"
        case .downloading: return "Downloading"
        case .completed: return "Saved offline"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    private var badgeTint: Color {
        switch item.state {
        case .queued: return .gray
        case .downloading: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

private struct StateBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
    }
}

#Preview {
    NavigationStack {
        DownloadView()
    }
}


