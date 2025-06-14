import SwiftUI

struct AnimeDetailView: View {
    let animeId: String
    @StateObject private var viewModel = AnimeDetailViewModel()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if let details = viewModel.animeDetails?.data.anime.info {
                    // Header Section
                    VStack(spacing: 16) {
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
                        VStack(spacing: 12) {
                            Text(details.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal)
                            
                            if let jTitle = details.moreInfo?.japanese {
                                Text(jTitle)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            // Info Pills
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    if let type = details.type {
                                        InfoPill(text: type, icon: "film")
                                    }
                                    if let status = details.status {
                                        InfoPill(text: status, icon: "dot.radiowaves.left.and.right")
                                    }
                                    if let rating = details.rating {
                                        InfoPill(text: rating, icon: "star.fill")
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Bookmark Button
                            Button(action: { viewModel.toggleBookmark() }) {
                                Label(viewModel.isBookmarked ? "Bookmarked" : "Bookmark", systemImage: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.gray)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical)
                    .background(
                        AsyncImage(url: URL(string: details.image)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 20)
                                .opacity(0.3)
                        } placeholder: {
                            Color.clear
                        }
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(colorScheme == .dark ? .black : .white),
                                    Color(colorScheme == .dark ? .black : .white).opacity(0.8),
                                    Color(colorScheme == .dark ? .black : .white).opacity(0.6)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    )
                    
                    // Description Section
                    if let description = details.description {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                                .padding(.top, 16)
                            
                            Text(description)
                                .font(.body)
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                        }
                    }
                    
                    // Additional Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 12) {
                            if let genres = details.moreInfo?.genres, !genres.isEmpty {
                                InfoRow(title: "Genres", content: genres.joined(separator: ", "))
                            }
                            if let studios = details.moreInfo?.studios, !studios.isEmpty {
                                InfoRow(title: "Studios", content: studios.joined(separator: ", "))
                            }
                            if let producers = details.moreInfo?.producers, !producers.isEmpty {
                                InfoRow(title: "Producers", content: producers.joined(separator: ", "))
                            }
                            if let aired = details.moreInfo?.aired {
                                InfoRow(title: "Aired", content: aired)
                            }
                            if let premiered = details.moreInfo?.premiered {
                                InfoRow(title: "Premiered", content: premiered)
                            }
                            if let duration = details.moreInfo?.duration {
                                InfoRow(title: "Duration", content: duration)
                            }
                            if let score = details.moreInfo?.malscore {
                                InfoRow(title: "MAL Score", content: score)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    
                    // Episodes Section
                    if !viewModel.episodeGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Episodes")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                if viewModel.episodeGroups.count > 1 {
                                    Spacer()
                                    
                                    Menu {
                                        ForEach(Array(viewModel.episodeGroups.enumerated()), id: \.element.id) { index, group in
                                            Button(action: { viewModel.selectedGroupIndex = index }) {
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
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.currentEpisodes) { episode in
                                    NavigationLink(destination: EpisodeView(episodeId: episode.id)) {
                                        EpisodeRow(episode: episode, thumbnail: viewModel.getThumbnail(for: episode.number), thumbnailState: viewModel.thumbnailLoadingState)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAnimeDetails(id: animeId)
        }
    }
}

// Helper Views
private struct InfoPill: View {
    let text: String
    let icon: String
    
    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
    }
}

private struct InfoRow: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(content)
                .font(.body)
        }
    }
}

private struct EpisodeRow: View {
    let episode: EpisodeInfo
    let thumbnail: String?
    let thumbnailState: AnimeDetailViewModel.ThumbnailLoadingState
    
    var body: some View {
        HStack(spacing: 12) {
            // Episode Thumbnail
            Group {
                if case .loading = thumbnailState {
                    Color.gray
                        .overlay(ProgressView())
                } else if let thumbnail = thumbnail {
                    AsyncImage(url: URL(string: thumbnail)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                    }
                } else {
                    Color.gray
                        .overlay(
                            Image(systemName: "play.rectangle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                        )
                }
            }
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
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
}

#Preview {
    NavigationView {
        AnimeDetailView(animeId: "example-id")
    }
} 