import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section(title: "Trending", animes: viewModel.trendingAnimes)
                section(title: "Latest Episodes", animes: viewModel.latestEpisodeAnimes)
                section(title: "Top Airing", animes: viewModel.topAiringAnimes)
                section(title: "Most Popular", animes: viewModel.mostPopularAnimes)
                section(title: "Top Upcoming", animes: viewModel.topUpcomingAnimes)
                section(title: "Latest Completed", animes: viewModel.latestCompletedAnimes)
                section(title: "Top 10 Today", animes: viewModel.top10Today)
            }
            .padding(.vertical)
        }
        .navigationTitle("Home")
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading...")
            }
        }
        .refreshable {
            await viewModel.loadHomeData()
        }
        .task {
            await viewModel.loadHomeData()
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Retry") {
                Task { await viewModel.loadHomeData() }
            }
            Button("Dismiss", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
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
                    LazyHStack(spacing: 12) {
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
