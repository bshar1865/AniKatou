import SwiftUI

struct BookmarksView: View {
    @StateObject private var viewModel = BookmarksViewModel()
    @State private var isGridView = true
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            if viewModel.bookmarkedAnimes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                    
                    Text("No bookmarks yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Bookmarked anime will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 16) {
                    // View toggle
                    HStack {
                        Text("Your Bookmarks")
                            .font(.title2)
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
                            ForEach(viewModel.bookmarkedAnimes) { anime in
                                NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                    AnimeCard(anime: anime)
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // List View
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.bookmarkedAnimes) { anime in
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
            }
        }
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        BookmarksView()
    }
} 