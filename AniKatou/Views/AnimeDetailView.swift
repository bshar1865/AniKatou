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
                    // Header Section
                    HStack(alignment: .top, spacing: 16) {
                        // Cover Art
                        AsyncImage(url: URL(string: details.image)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 160, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 8)
                        
                        // Title and Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(details.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(3)
                            
                            if let type = details.type {
                                Label(type, systemImage: "film")
                                    .font(.subheadline)
                            }
                            
                            if let status = details.status {
                                Label(status, systemImage: "dot.radiowaves.left.and.right")
                                    .font(.subheadline)
                            }
                            
                            if let releaseDate = details.releaseDate {
                                Label(releaseDate, systemImage: "calendar")
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                            
                            // Bookmark Button
                            Button(action: {
                                if let anime = viewModel.animeToBookmarkItem() {
                                    withAnimation {
                                        BookmarkManager.shared.toggleBookmark(anime)
                                        isBookmarked = BookmarkManager.shared.isBookmarked(anime)
                                    }
                                    NotificationCenter.default.post(name: NSNotification.Name("BookmarksDidChange"), object: nil)
                                }
                            }) {
                                Label(isBookmarked ? "Bookmarked" : "Bookmark", systemImage: isBookmarked ? "bookmark.fill" : "bookmark")
                                    .font(.subheadline)
                                    .foregroundColor(isBookmarked ? Color(.systemBackground) : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(isBookmarked ? Color.primary : Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    
                    // Genres
                    if let genres = details.genres, !genres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(genres, id: \.self) { genre in
                                    Text(genre)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.secondary.opacity(0.2))
                                        .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Description
                    if let description = details.description {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Text(description)
                                .font(.body)
                                .padding(.horizontal)
                        }
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
            updateBookmarkState()
        }
        .onReceive(viewModel.$animeDetails) { _ in
            Task {
                updateBookmarkState()
            }
        }
    }
    
    @MainActor
    private func updateBookmarkState() {
        if let anime = viewModel.animeToBookmarkItem() {
            isBookmarked = BookmarkManager.shared.isBookmarked(anime)
        }
    }
}

#Preview {
    NavigationView {
        AnimeDetailView(animeId: "example-id")
    }
} 