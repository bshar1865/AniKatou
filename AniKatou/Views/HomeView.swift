import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    private var hasContent: Bool {
        !viewModel.trendingAnimes.isEmpty ||
        !viewModel.latestEpisodeAnimes.isEmpty ||
        !viewModel.topAiringAnimes.isEmpty ||
        !viewModel.mostPopularAnimes.isEmpty ||
        !viewModel.latestCompletedAnimes.isEmpty ||
        !viewModel.top10Today.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if hasContent {
                    section(title: "Trending", animes: viewModel.trendingAnimes)
                    section(title: "Latest Episodes", animes: viewModel.latestEpisodeAnimes)
                    section(title: "Top Airing", animes: viewModel.topAiringAnimes)
                    section(title: "Most Popular", animes: viewModel.mostPopularAnimes)
                    section(title: "Latest Completed", animes: viewModel.latestCompletedAnimes)
                    section(title: "Top 10 Today", animes: viewModel.top10Today)
                } else if !viewModel.isLoading {
                    homeEmptyState
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: SearchView()) {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search")
            }
        }
        .overlay {
            if viewModel.isLoading && !hasContent {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .refreshable {
            await viewModel.loadHomeData()
        }
        .task {
            await viewModel.loadHomeData()
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
}
