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

#Preview {
    NavigationView {
        HomeView()
    }
} 