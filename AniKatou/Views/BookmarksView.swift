import SwiftUI

struct BookmarksView: View {
    @StateObject private var viewModel = BookmarksViewModel()
    @State private var isGridView = true
    
    private static let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
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
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.large)
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