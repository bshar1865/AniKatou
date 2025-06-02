import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
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
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(viewModel.bookmarkedAnimes) { anime in
                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                            BookmarkCard(anime: anime)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct BookmarkCard: View {
    let anime: AnimeItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: anime.image)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(anime.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            if let type = anime.type {
                Text(type)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationView {
        HomeView()
    }
} 