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
}

struct DownloadView: View {
    @StateObject private var manager = HLSDownloadManager.shared

    private var groups: [AnimeDownloadGroup] {
        let grouped = Dictionary(grouping: manager.downloads, by: { $0.animeId })
        return grouped.compactMap { animeId, items in
            guard let first = items.first else { return nil }
            let sortedItems = items.sorted {
                (Int($0.episodeNumber) ?? 0) < (Int($1.episodeNumber) ?? 0)
            }
            return AnimeDownloadGroup(id: animeId, animeId: animeId, animeTitle: first.animeTitle, items: sortedItems)
        }
        .sorted { $0.animeTitle.localizedCaseInsensitiveCompare($1.animeTitle) == .orderedAscending }
    }

    var body: some View {
        List {
            if groups.isEmpty {
                ContentUnavailableView(
                    "No Downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Start a download from an episode in anime details")
                )
            } else {
                ForEach(groups) { group in
                    HStack(spacing: 10) {
                        NavigationLink(destination: DownloadAnimeDetailView(animeId: group.animeId, animeTitle: group.animeTitle, manager: manager)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group.animeTitle)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("\(group.items.count) episodes | \(group.completedCount) completed | \(group.activeCount) active")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button("Remove", role: .destructive) {
                            manager.removeDownloads(for: group.animeId)
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .navigationTitle("Downloads")
    }
}

private struct DownloadAnimeDetailView: View {
    let animeId: String
    let animeTitle: String
    @ObservedObject var manager: HLSDownloadManager

    private var items: [HLSDownloadItem] {
        manager.downloads
            .filter { $0.animeId == animeId }
            .sorted { (Int($0.episodeNumber) ?? 0) < (Int($1.episodeNumber) ?? 0) }
    }

    var body: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 8) {
                Text("Episode \(item.episodeNumber)")
                    .font(.headline)

                ProgressView(value: item.progress)
                    .tint(item.state == .failed ? .red : .blue)

                HStack {
                    Text(statusText(for: item))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(actionLabel(for: item), role: item.state == .failed || item.state == .cancelled || item.state == .completed ? .destructive : nil) {
                        if item.state == .queued || item.state == .downloading {
                            manager.cancelDownload(item)
                        } else {
                            manager.removeDownload(item)
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle(animeTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func actionLabel(for item: HLSDownloadItem) -> String {
        (item.state == .queued || item.state == .downloading) ? "Cancel" : "Remove"
    }

    private func statusText(for item: HLSDownloadItem) -> String {
        switch item.state {
        case .queued:
            return "Queued"
        case .downloading:
            return "Downloading \(Int(item.progress * 100))%"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed: \(item.errorMessage ?? "Unknown error")"
        case .cancelled:
            return "Cancelled"
        }
    }
}

#Preview {
    NavigationStack {
        DownloadView()
    }
}
