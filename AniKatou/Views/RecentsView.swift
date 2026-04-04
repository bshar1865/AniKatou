import SwiftUI

struct RecentsView: View {
    var body: some View {
        RecentsListView()
            .navigationTitle("Recents")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct RecentsListView: View {
    @State private var watchHistory: [WatchProgress] = []
    @State private var selectedProgressForDelete: WatchProgress?
    @State private var showDeleteProgressAlert = false

    var body: some View {
        List {
            if watchHistory.isEmpty {
                ContentUnavailableView(
                    "No Recent Episodes",
                    systemImage: "clock",
                    description: Text("Start watching an episode to see it here.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
                .listRowSeparator(.hidden)
            } else {
                ForEach(watchHistory) { progress in
                    NavigationLink(destination: EpisodeView(
                        episodeId: progress.episodeID,
                        animeId: progress.animeID,
                        animeTitle: progress.title,
                        episodeNumber: progress.episodeNumber,
                        episodeTitle: nil,
                        thumbnailURL: progress.thumbnailURL
                    )) {
                        RecentEpisodeRow(progress: progress, coverURL: coverURL(for: progress))
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            selectedProgressForDelete = progress
                            showDeleteProgressAlert = true
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            reloadWatchHistory()
        }
        .onAppear {
            reloadWatchHistory()
        }
        .alert("Remove from Recents?", isPresented: $showDeleteProgressAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let progress = selectedProgressForDelete {
                    WatchProgressManager.shared.removeProgress(for: progress.animeID, episodeID: progress.episodeID)
                    reloadWatchHistory()
                }
                selectedProgressForDelete = nil
            }
        } message: {
            Text("This episode entry will be removed.")
        }
    }

    private func reloadWatchHistory() {
        WatchProgressManager.shared.cleanupFinishedEpisodes()
        watchHistory = WatchProgressManager.shared.getWatchHistory()
    }

    private func coverURL(for progress: WatchProgress) -> String? {
        if let libraryAnime = LibraryManager.shared.libraryItems.first(where: { $0.id == progress.animeID }) {
            return libraryAnime.poster
        }
        if let cachedAnime = OfflineManager.shared.getCachedAnimeDetails(progress.animeID) {
            return cachedAnime.image
        }
        return progress.thumbnailURL
    }
}

private struct RecentEpisodeRow: View {
    let progress: WatchProgress
    let coverURL: String?

    private var clampedProgress: Double {
        min(max(progress.progressPercentage, 0), 1)
    }

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: URL(string: coverURL ?? ""), maxPixelSize: 300) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
                    .overlay(Image(systemName: "play.rectangle.fill").foregroundColor(.white))
            }
            .frame(width: 64, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(progress.title)
                    .font(.headline)
                    .lineLimit(1)

                Text("Watch to EPISODE \(progress.episodeNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary.opacity(0.12))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue)
                            .frame(width: geo.size.width * clampedProgress)
                    }
                }
                .frame(height: 5)

                Text(progress.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        RecentsView()
    }
}

