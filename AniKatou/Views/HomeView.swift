import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var downloadManager = HLSDownloadManager.shared
    @State private var watchHistory: [WatchProgress] = []
    @State private var selectedProgressForDelete: WatchProgress?
    @State private var showDeleteProgressAlert = false

    private var hasContent: Bool {
        !viewModel.trendingAnimes.isEmpty ||
        !viewModel.latestEpisodeAnimes.isEmpty ||
        !viewModel.topAiringAnimes.isEmpty ||
        !viewModel.mostPopularAnimes.isEmpty ||
        !viewModel.latestCompletedAnimes.isEmpty ||
        !viewModel.top10Today.isEmpty
    }

    private var offlineLibraryItems: [AnimeItem] {
        LibraryManager.shared.libraryItems.filter { downloadManager.downloadedEpisodeCount(for: $0.id) > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                continueWatchingSection

                if OfflineManager.shared.isOfflineMode && !offlineLibraryItems.isEmpty {
                    section(title: "Available Offline", animes: offlineLibraryItems)
                }

                if hasContent {
                    section(title: "Trending", animes: viewModel.trendingAnimes)
                    section(title: "Latest Episodes", animes: viewModel.latestEpisodeAnimes)
                    section(title: "Top Airing", animes: viewModel.topAiringAnimes)
                    section(title: "Most Popular", animes: viewModel.mostPopularAnimes)
                    section(title: "Latest Completed", animes: viewModel.latestCompletedAnimes)
                    section(title: "Top 10 Today", animes: viewModel.top10Today)
                } else if watchHistory.isEmpty && offlineLibraryItems.isEmpty && !viewModel.isLoading {
                    homeEmptyState
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Home")
        .overlay {
            if viewModel.isLoading && !hasContent && watchHistory.isEmpty && offlineLibraryItems.isEmpty {
                ProgressView("Loading...")
            }
        }
        .refreshable {
            reloadWatchHistory()
            await viewModel.loadHomeData()
        }
        .task {
            reloadWatchHistory()
            await viewModel.loadHomeData()
        }
        .alert("Remove from Continue Watching?", isPresented: $showDeleteProgressAlert) {
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

    @ViewBuilder
    private var continueWatchingSection: some View {
        if !watchHistory.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Continue Watching", symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90")

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
                                HomeContinueWatchingCard(progress: progress, coverURL: coverURL(for: progress))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Remove from Continue Watching", role: .destructive) {
                                    selectedProgressForDelete = progress
                                    showDeleteProgressAlert = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var homeEmptyState: some View {
        ContentUnavailableView(
            "Home Needs Internet",
            systemImage: "wifi.slash",
            description: Text(viewModel.errorMessage ?? "Connect to the internet to load the latest anime sections.")
        )
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    @ViewBuilder
    private func section(title: String, animes: [AnimeItem]) -> some View {
        if !animes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink(destination: AnimeListView(title: title, animes: animes)) {
                    HStack {
                        Text(title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(animes.prefix(12)) { anime in
                            NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                AnimeCard(anime: anime, width: 140)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func reloadWatchHistory() {
        WatchProgressManager.shared.cleanupFinishedEpisodes()
        watchHistory = WatchProgressManager.shared.getWatchHistory()
    }

    private func sectionHeader(title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.blue)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal)
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

private struct HomeContinueWatchingCard: View {
    let progress: WatchProgress
    let coverURL: String?

    private var clampedProgress: Double {
        min(max(progress.progressPercentage, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: URL(string: coverURL ?? ""), maxPixelSize: 600) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.overlay(Image(systemName: "play.rectangle.fill").foregroundColor(.white))
                }
                .frame(width: 136, height: 194)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.65)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 136, height: 194)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Ep \(progress.episodeNumber)")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45))
                    .clipShape(Capsule())
                    .padding(8)
            }

            Text(progress.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .foregroundColor(.primary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue)
                        .frame(width: geo.size.width * clampedProgress)
                }
            }
            .frame(height: 6)

            Text(progress.formattedTimestamp)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 136, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
