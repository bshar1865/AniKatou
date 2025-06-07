import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                    
                    Button("Retry") {
                        Task {
                            await viewModel.loadHomeData()
                        }
                    }
                    .foregroundColor(.blue)
                }
            } else {
                VStack(spacing: 24) {
                    // Trending Section
                    if !viewModel.trendingAnimes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Trending Now")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.trendingAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            BookmarkCard(anime: anime)
                                                .frame(width: 160)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Latest Episodes Section
                    if !viewModel.latestEpisodeAnimes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Latest Episodes")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.latestEpisodeAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            BookmarkCard(anime: anime)
                                                .frame(width: 160)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Top 10 Today Section
                    if !viewModel.top10Today.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top 10 Today")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(Array(viewModel.top10Today.enumerated()), id: \.element.id) { index, anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            ZStack(alignment: .topLeading) {
                                                BookmarkCard(anime: anime)
                                                    .frame(width: 160)
                                                
                                                Text("#\(index + 1)")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                                    .background(Color.black.opacity(0.7))
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .padding(4)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Most Popular Section
                    if !viewModel.mostPopularAnimes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Most Popular")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.mostPopularAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            BookmarkCard(anime: anime)
                                                .frame(width: 160)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Top Upcoming Section
                    if !viewModel.topUpcomingAnimes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top Upcoming")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.topUpcomingAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            BookmarkCard(anime: anime)
                                                .frame(width: 160)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Top Airing Section
                    if !viewModel.topAiringAnimes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top Airing")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.topAiringAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            BookmarkCard(anime: anime)
                                                .frame(width: 160)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Most Favorite Section
                    if !viewModel.mostFavoriteAnimes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Most Favorite")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.mostFavoriteAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            BookmarkCard(anime: anime)
                                                .frame(width: 160)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Latest Completed Section
                    if !viewModel.latestCompletedAnimes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Latest Completed")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.latestCompletedAnimes) { anime in
                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                            BookmarkCard(anime: anime)
                                                .frame(width: 160)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadHomeData()
        }
        .refreshable {
            await viewModel.loadHomeData()
        }
    }
}

#Preview {
    NavigationView {
        HomeView()
    }
} 