import SwiftUI

struct BookmarksView: View {
    @StateObject private var viewModel = BookmarksViewModel()
    @State private var isGridView = true
    @State private var watchHistory: [WatchProgress] = []
    
    private static let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Continue Watching Section
                if !watchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Continue Watching")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(watchHistory.prefix(10)) { progress in
                                    NavigationLink(destination: EpisodeView(
                                        episodeId: progress.episodeID,
                                        animeId: progress.animeID,
                                        animeTitle: progress.title,
                                        episodeNumber: progress.episodeNumber,
                                        episodeTitle: nil,
                                        thumbnailURL: progress.thumbnailURL
                                    )) {
                                        ContinueWatchingCard(progress: progress)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Bookmarks Section
                if viewModel.bookmarkedAnimes.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark.slash",
                        description: Text("Your bookmarked anime will appear here")
                    )
                } else {
                    VStack(spacing: 16) {
                        // View toggle
                        HStack {
                            Text("Your Bookmarks")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: { withAnimation { isGridView.toggle() } }) {
                                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        if isGridView {
                            LazyVGrid(columns: Self.gridColumns, spacing: 16) {
                                ForEach(viewModel.bookmarkedAnimes) { anime in
                                    NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                        AnimeCard(anime: anime, width: 160)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.bookmarkedAnimes) { anime in
                                    NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                        AnimeListItem(anime: anime)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadWatchHistory()
        }
        .refreshable {
            loadWatchHistory()
        }
    }
    
    private func loadWatchHistory() {
        watchHistory = WatchProgressManager.shared.getWatchHistory()
    }
}

private struct AnimeListItem: View {
    let anime: AnimeItem
    
    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: URL(string: anime.image)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
                    .overlay(ProgressView())
            }
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
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
}

private struct ContinueWatchingCard: View {
    let progress: WatchProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            if let thumbnailURL = progress.thumbnailURL {
                CachedAsyncImage(url: URL(string: thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                        .overlay(ProgressView())
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Color.gray
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                    )
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Title
            Text(progress.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            // Episode info
            Text("Episode \(progress.episodeNumber)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Progress bar
            ProgressView(value: progress.progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(height: 2)
            
            // Time info
            HStack {
                Text(progress.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatDuration(progress.duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120)
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, secs)
    }
} 