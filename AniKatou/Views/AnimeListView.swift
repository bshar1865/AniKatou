import SwiftUI

struct AnimeListView: View {
    let title: String
    let animes: [AnimeItem]
    @State private var isGridView = true
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // View toggle
                HStack {
                    Text(title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isGridView.toggle()
                        }
                    }) {
                        Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                if isGridView {
                    // Grid View
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(animes) { anime in
                            NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                AnimeCard(anime: anime)
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    // List View
                    LazyVStack(spacing: 12) {
                        ForEach(animes) { anime in
                            NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                HStack(spacing: 12) {
                                    // Thumbnail
                                    CachedAsyncImage(url: URL(string: anime.image)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray
                                            .overlay(
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle())
                                            )
                                    }
                                    .frame(width: 100, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    // Info
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(anime.title)
                                            .font(.headline)
                                            .lineLimit(2)
                                            .foregroundColor(.primary)
                                        
                                        if let type = anime.type {
                                            Text(type)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if let episodes = anime.episodes?.sub {
                                            Text("\(episodes) Episodes")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        AnimeListView(
            title: "Trending Now",
            animes: [
                AnimeItem(
                    id: "preview1",
                    name: "Sample Anime 1",
                    jname: nil,
                    poster: "https://example.com/image1.jpg",
                    duration: "24 min",
                    type: "TV",
                    rating: "PG-13",
                    episodes: EpisodeCount(sub: 12, dub: nil),
                    isNSFW: false,
                    genres: ["Action", "Adventure"]
                ),
                AnimeItem(
                    id: "preview2",
                    name: "Sample Anime 2",
                    jname: nil,
                    poster: "https://example.com/image2.jpg",
                    duration: "24 min",
                    type: "Movie",
                    rating: "PG-13",
                    episodes: nil,
                    isNSFW: false,
                    genres: ["Drama", "Romance"]
                )
            ]
        )
    }
} 