import SwiftUI

struct CollectionsDetailView: View {
    let viewModel: BookmarksViewModel
    @State private var isGridView = true
    @State private var showingRemoveAlert = false
    @State private var itemToRemove: AnimeItem?
    
    private static let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // View Toggle
                HStack {
                    Text("Collections")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Modern View Toggle
                    HStack(spacing: 4) {
                        Button(action: { withAnimation(.spring()) { isGridView.toggle() } }) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isGridView ? .white : .primary)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isGridView ? Color.blue : Color(.tertiarySystemBackground))
                                )
                        }
                        
                        Button(action: { withAnimation(.spring()) { isGridView.toggle() } }) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(!isGridView ? .white : .primary)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(!isGridView ? Color.blue : Color(.tertiarySystemBackground))
                                )
                        }
                    }
                    .padding(4)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Collections Content
                if viewModel.bookmarkedAnimes.isEmpty {
                    ContentUnavailableView(
                        "No Collections",
                        systemImage: "bookmark.slash",
                        description: Text("Your bookmarked anime will appear here")
                    )
                } else {
                    if isGridView {
                        LazyVGrid(columns: Self.gridColumns, spacing: 20) {
                            ForEach(viewModel.bookmarkedAnimes) { anime in
                                NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                    AnimeCard(anime: anime, width: 160)
                                }
                                .contextMenu {
                                    Button("Remove from Collection", role: .destructive) {
                                        removeBookmark(anime)
                                    }
                                    
                                    Button("Open Anime") {
                                        // NavigationLink will handle this automatically
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.bookmarkedAnimes) { anime in
                                NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                    AnimeListItem(anime: anime)
                                }
                                .contextMenu {
                                    Button("Remove from Collection", role: .destructive) {
                                        removeBookmark(anime)
                                    }
                                    
                                    Button("Open Anime") {
                                        // NavigationLink will handle this automatically
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("Collections")
        .navigationBarTitleDisplayMode(.large)
        .alert("Remove Bookmark", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                confirmRemove()
            }
        } message: {
            Text("Remove this anime from your collection?")
        }
    }
    
    private func removeBookmark(_ anime: AnimeItem) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        itemToRemove = anime
        showingRemoveAlert = true
    }
    
    private func confirmRemove() {
        if let anime = itemToRemove {
            BookmarkManager.shared.removeBookmark(anime)
            // Post notification to update UI
            NotificationCenter.default.post(
                name: NSNotification.Name("BookmarksDidChange"),
                object: nil,
                userInfo: ["animeId": anime.id]
            )
        }
        showingRemoveAlert = false
        itemToRemove = nil
    }
}

private struct AnimeListItem: View {
    let anime: AnimeItem
    
    var body: some View {
        HStack(spacing: 16) {
            CachedAsyncImage(url: URL(string: anime.image)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
                    .overlay(ProgressView())
            }
            .frame(width: 120, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(anime.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                if let type = anime.type {
                    HStack {
                        Image(systemName: "film")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(type)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let episodes = anime.episodes?.sub {
                    HStack {
                        Image(systemName: "play.rectangle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(episodes) Episodes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Bookmarked")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
} 