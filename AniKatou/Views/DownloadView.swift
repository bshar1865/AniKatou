import SwiftUI

struct DownloadView: View {
    @StateObject private var manager = HLSDownloadManager.shared

    var body: some View {
        List {
            if manager.downloads.isEmpty {
                ContentUnavailableView(
                    "No Downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Start a download from an episode in anime details")
                )
            } else {
                ForEach(manager.downloads) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        NavigationLink(destination: AnimeDetailView(animeId: item.animeId)) {
                            Text(item.animeTitle)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)

                        Text("Episode \(item.episodeNumber)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ProgressView(value: item.progress)
                            .tint(item.state == .failed ? .red : .blue)

                        HStack {
                            Text(statusText(for: item))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if item.state == .downloading || item.state == .queued {
                                Button("Cancel") { manager.cancelDownload(item) }
                                    .font(.caption)
                            }
                            Button("Remove", role: .destructive) { manager.removeDownload(item) }
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Downloads")
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
