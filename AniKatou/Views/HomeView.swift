import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showError = false
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.trendingAnimes.isEmpty {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading anime...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                VStack(spacing: 24) {
                    // Sections
                    animeSection(
                        title: "Trending Now",
                        animes: viewModel.trendingAnimes,
                        emptyMessage: "No trending anime available"
                    )
                    
                    animeSection(
                        title: "Latest Episodes",
                        animes: viewModel.latestEpisodeAnimes,
                        emptyMessage: "No latest episodes available"
                    )
                    
                    animeSection(
                        title: "Top 10 Today",
                        animes: viewModel.top10Today,
                        emptyMessage: "No top anime available",
                        showRank: true
                    )
                    
                    animeSection(
                        title: "Most Popular",
                        animes: viewModel.mostPopularAnimes,
                        emptyMessage: "No popular anime available"
                    )
                    
                    animeSection(
                        title: "Top Upcoming",
                        animes: viewModel.topUpcomingAnimes,
                        emptyMessage: "No upcoming anime available"
                    )
                    
                    animeSection(
                        title: "Top Airing",
                        animes: viewModel.topAiringAnimes,
                        emptyMessage: "No airing anime available"
                    )
                    
                    animeSection(
                        title: "Most Favorite",
                        animes: viewModel.mostFavoriteAnimes,
                        emptyMessage: "No favorite anime available"
                    )
                    
                    animeSection(
                        title: "Latest Completed",
                        animes: viewModel.latestCompletedAnimes,
                        emptyMessage: "No completed anime available"
                    )
                }
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.loadHomeData()
        }
        .alert("Error", isPresented: $showError) {
            Button("Retry") {
                Task {
                    await viewModel.loadHomeData()
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Failed to load content")
        }
        .onChange(of: viewModel.errorMessage) { oldValue, newValue in
            showError = newValue != nil
        }
        .task {
            if viewModel.trendingAnimes.isEmpty {
                await viewModel.loadHomeData()
            }
        }
    }
    
    private func animeSection(
        title: String,
        animes: [AnimeItem],
        emptyMessage: String,
        showRank: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !animes.isEmpty {
                HStack {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    NavigationLink(destination: AnimeListView(title: title, animes: animes)) {
                        Text("See All")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Array(animes.enumerated()), id: \.element.id) { index, anime in
                            NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                if showRank {
                                    ZStack(alignment: .topLeading) {
                                        AnimeCard(anime: anime, width: 160)
                                        
                                        Text("#\(index + 1)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.7))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .padding(4)
                                    }
                                } else {
                                    AnimeCard(anime: anime, width: 160)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else if !viewModel.isLoading {
                Text(emptyMessage)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }
}

#Preview {
    NavigationView {
        HomeView()
    }
} 