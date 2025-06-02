import SwiftUI

struct AnimeDetailView: View {
    let animeId: String
    @StateObject private var viewModel = AnimeDetailViewModel()
    @State private var isBookmarked = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if let details = viewModel.animeDetails?.data.anime.info {
                    // Header Image
                    ZStack(alignment: .topTrailing) {
                        AsyncImage(url: URL(string: details.image)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray
                        }
                        .frame(height: 200)
                        .clipped()
                        
                        // Bookmark Button
                        Button(action: {
                            if let anime = viewModel.animeToBookmarkItem() {
                                BookmarkManager.shared.toggleBookmark(anime)
                                isBookmarked.toggle()
                                NotificationCenter.default.post(name: NSNotification.Name("BookmarksDidChange"), object: nil)
                            }
                        }) {
                            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                    
                    // Title and Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(details.title)
                            .font(.title)
                            .padding(.horizontal)
                        
                        if let type = details.type {
                            Label(type, systemImage: "film")
                                .padding(.horizontal)
                        }
                        
                        if let status = details.status {
                            Label(status, systemImage: "dot.radiowaves.left.and.right")
                                .padding(.horizontal)
                        }
                        
                        if let releaseDate = details.releaseDate {
                            Label(releaseDate, systemImage: "calendar")
                                .padding(.horizontal)
                        }
                        
                        if let genres = details.genres, !genres.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(genres, id: \.self) { genre in
                                        Text(genre)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.secondary.opacity(0.2))
                                            .cornerRadius(16)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Description
                    if let description = details.description {
                        Text(description)
                            .padding()
                    }
                    
                    // Episodes Section
                    if !viewModel.episodes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Episodes")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.episodes) { episode in
                                NavigationLink(destination: EpisodeView(episodeId: episode.id)) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Episode \(episode.number)")
                                                .font(.headline)
                                            if let title = episode.title {
                                                Text(title)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAnimeDetails(id: animeId)
            isBookmarked = viewModel.isBookmarked()
        }
    }
}

#Preview {
    NavigationView {
        AnimeDetailView(animeId: "example-id")
    }
} 