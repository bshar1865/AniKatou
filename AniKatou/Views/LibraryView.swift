import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel = LibraryCollectionViewModel()
    @State private var watchHistory: [WatchProgress] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                NavigationLink(destination: DownloadView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Downloads")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Manage downloaded episodes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                if !watchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Continue Watching")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(watchHistory.prefix(15)) { progress in
                                    NavigationLink(destination: EpisodeView(
                                        episodeId: progress.episodeID,
                                        animeId: progress.animeID,
                                        animeTitle: progress.title,
                                        episodeNumber: progress.episodeNumber,
                                        episodeTitle: nil,
                                        thumbnailURL: progress.thumbnailURL
                                    )) {
                                        ContinueWatchingCard(progress: progress)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("My Library")
                            .font(.title3)
                            .fontWeight(.bold)
                        Spacer()
                        NavigationLink("See All") {
                            CollectionsDetailView(viewModel: viewModel)
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal)

                    if viewModel.libraryItems.isEmpty {
                        ContentUnavailableView(
                            "Library Is Empty",
                            systemImage: "books.vertical",
                            description: Text("Open any anime and tap Add to Library")
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.libraryItems.prefix(12)) { anime in
                                NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                    HStack(spacing: 12) {
                                        CachedAsyncImage(url: URL(string: anime.image)) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray.overlay(ProgressView())
                                        }
                                        .frame(width: 76, height: 108)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(anime.title)
                                                .font(.headline)
                                                .lineLimit(2)
                                            if let type = anime.type {
                                                Text(type)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Library")
        .onAppear {
            WatchProgressManager.shared.cleanupFinishedEpisodes()
            watchHistory = WatchProgressManager.shared.getWatchHistory()
        }
        .refreshable {
            WatchProgressManager.shared.cleanupFinishedEpisodes()
            watchHistory = WatchProgressManager.shared.getWatchHistory()
        }
    }
}

private struct ContinueWatchingCard: View {
    let progress: WatchProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: URL(string: progress.thumbnailURL ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.overlay(Image(systemName: "play.rectangle.fill").foregroundColor(.white))
            }
            .frame(width: 220, height: 124)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(progress.title)
                .font(.headline)
                .lineLimit(1)
            Text("Episode \(progress.episodeNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ProgressView(value: progress.progressPercentage)
                .tint(.blue)

            Text(progress.formattedTimestamp)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 220, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
