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
                            HStack {
                                Text("Trending Now")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                NavigationLink(destination: AnimeListView(title: "Trending Now", animes: viewModel.trendingAnimes)) {
                                    Text("See All")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.trendingAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            AnimeCard(anime: anime, width: 160)
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
                            HStack {
                                Text("Latest Episodes")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                NavigationLink(destination: AnimeListView(title: "Latest Episodes", animes: viewModel.latestEpisodeAnimes)) {
                                    Text("See All")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.latestEpisodeAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            AnimeCard(anime: anime, width: 160)
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
                            HStack {
                                Text("Top 10 Today")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                NavigationLink(destination: AnimeListView(title: "Top 10 Today", animes: viewModel.top10Today)) {
                                    Text("See All")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(Array(viewModel.top10Today.enumerated()), id: \.element.id) { index, anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
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
                            HStack {
                                Text("Most Popular")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                NavigationLink(destination: AnimeListView(title: "Most Popular", animes: viewModel.mostPopularAnimes)) {
                                    Text("See All")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.mostPopularAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            AnimeCard(anime: anime, width: 160)
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
                            HStack {
                                Text("Top Upcoming")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                NavigationLink(destination: AnimeListView(title: "Top Upcoming", animes: viewModel.topUpcomingAnimes)) {
                                    Text("See All")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.topUpcomingAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            AnimeCard(anime: anime, width: 160)
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
                            HStack {
                                Text("Top Airing")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                NavigationLink(destination: AnimeListView(title: "Top Airing", animes: viewModel.topAiringAnimes)) {
                                    Text("See All")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.topAiringAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            AnimeCard(anime: anime, width: 160)
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
                            HStack {
                                Text("Most Favorite")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                NavigationLink(destination: AnimeListView(title: "Most Favorite", animes: viewModel.mostFavoriteAnimes)) {
                                    Text("See All")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.mostFavoriteAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            AnimeCard(anime: anime, width: 160)
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
                            HStack {
                                Text("Latest Completed")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                NavigationLink(destination: AnimeListView(title: "Latest Completed", animes: viewModel.latestCompletedAnimes)) {
                                    Text("See All")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.latestCompletedAnimes) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            AnimeCard(anime: anime, width: 160)
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