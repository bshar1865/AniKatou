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
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.gray)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Description Section
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
                    if !viewModel.episodeGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Episodes")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                if viewModel.episodeGroups.count > 1 {
                                    Spacer()
                                    
                                    Menu {
                                        ForEach(Array(viewModel.episodeGroups.enumerated()), id: \.element.id) { index, group in
                                            Button(action: {
                                                viewModel.selectedGroupIndex = index
                                            }) {
                                                if index == viewModel.selectedGroupIndex {
                                                    Label(group.title, systemImage: "checkmark")
                                                } else {
                                                    Text(group.title)
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(viewModel.episodeGroups[viewModel.selectedGroupIndex].title)
                                                .font(.headline)
                                            Image(systemName: "chevron.up.chevron.down")
                                        }
                                        .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Episodes List
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.currentEpisodes) { episode in
                                    NavigationLink(destination: EpisodeView(episodeId: episode.id)) {
                                        HStack(spacing: 12) {
                                            // Episode Thumbnail
                                            if let thumbnail = viewModel.getThumbnail(for: episode.number) {
                                                AsyncImage(url: URL(string: thumbnail)) { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    Color.gray
                                                }
                                                .frame(width: 100, height: 56) // 16:9 aspect ratio but smaller
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Episode \(episode.number)\(episode.title.map { ": \($0)" } ?? "")")
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                
                                                if let title = episode.title {
                                                    Text(title)
                                                        .font(.subheadline)
                                                        .foregroundColor(.gray)
                                                        .lineLimit(2)
                                                }
                                                
                                                if episode.isFiller == true {
                                                    Text("Filler")
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2)
                                                        .background(Color.orange)
                                                        .cornerRadius(4)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "play.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.title2)
                                        }
                                        .padding()
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal)
                                }
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