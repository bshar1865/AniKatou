import SwiftUI

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

struct DownloadView: View {
    @StateObject private var manager = HLSDownloadManager.shared

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                summaryCard

                if groups.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Start a download from an episode in anime details")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                } else {
                    ForEach(groups) { group in
                        DownloadGroupCard(group: group, manager: manager)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .navigationTitle("Downloads")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overview")
                .font(.headline)

            HStack(spacing: 8) {
                downloadStatChip(title: "Total", value: "\(manager.downloads.count)", tint: .secondary)
                downloadStatChip(title: "Active", value: "\(activeCount)", tint: .blue)
                downloadStatChip(title: "Completed", value: "\(completedCount)", tint: .green)
                if failedCount > 0 {
                    downloadStatChip(title: "Failed", value: "\(failedCount)", tint: .red)
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

    private func downloadStatChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint.opacity(0.92))
                .frame(width: 7, height: 7)
            Text(title)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

private struct DownloadGroupCard: View {
    let group: AnimeDownloadGroup
    @ObservedObject var manager: HLSDownloadManager

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

                Button("Remove", role: .destructive) {
                    manager.removeDownloads(for: group.animeId)
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
                        DownloadEpisodeRow(item: item, onAction: {
                            if item.state == .queued || item.state == .downloading {
                                manager.cancelDownload(item)
                            } else {
                                manager.removeDownload(item)
                            }
                        })
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .navigationTitle(animeTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DownloadEpisodeRow: View {
    let item: HLSDownloadItem
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
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 10)

                Button(actionLabel, role: actionRole) {
                    onAction()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(isActive ? .orange : .red)
                .controlSize(.small)
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

    private var statusText: String {
        switch item.state {
        case .queued:
            return "Preparing this episode for offline playback"
        case .downloading:
            return "Downloading \(Int(item.progress * 100))%"
        case .completed:
            return "Saved offline and ready without internet"
        case .failed:
            return item.errorMessage ?? "Needs internet to continue"
        case .cancelled:
            return "Stopped before completion"
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
