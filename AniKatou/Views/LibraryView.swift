import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel = BookmarksViewModel()
    @State private var isGridView = true
    @State private var watchHistory: [WatchProgress] = []
    @State private var selectedTab = 0
    
    private static let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Continue Watching Section
                if !watchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Continue Watching")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text("\(watchHistory.count) in progress")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 20) {
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
                } else {
                    ContentUnavailableView(
                        "No Continue Watching",
                        systemImage: "play.rectangle",
                        description: Text("Start watching anime to see your progress here")
                    )
                }
                
                // Collections Section
                VStack(spacing: 20) {
                    HStack {
                        Text("Collections")
                            .font(.title)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Single Collections Card
                    NavigationLink(destination: CollectionsDetailView(viewModel: viewModel)) {
                        HStack(spacing: 16) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                                .frame(width: 60, height: 60)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Collections")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("\(viewModel.bookmarkedAnimes.count) bookmarked anime")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .navigationTitle("Library")
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

// MARK: - Collections View
private struct CollectionsView: View {
    let viewModel: BookmarksViewModel
    let isGridView: Bool
    
    private static let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Enhanced View Toggle
            HStack {
                Text("Collections")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Modern View Toggle
                HStack(spacing: 4) {
                    Button(action: { withAnimation(.spring()) { /* TODO: Update grid state */ } }) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isGridView ? .white : .primary)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isGridView ? Color.blue : Color(.tertiarySystemBackground))
                            )
                    }
                    
                    Button(action: { withAnimation(.spring()) { /* TODO: Update grid state */ } }) {
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
            
            // Collection Categories
            VStack(spacing: 24) {
                // Bookmarks Collection
                CollectionSection(
                    title: "Bookmarks",
                    icon: "bookmark.fill",
                    iconColor: .blue,
                    animeList: viewModel.bookmarkedAnimes,
                    isGridView: isGridView,
                    emptyMessage: "No bookmarked anime yet",
                    emptyDescription: "Bookmark anime to add them to your collection"
                )
                
                // Future Plans Collection
                CollectionSection(
                    title: "Plan to Watch",
                    icon: "clock.fill",
                    iconColor: .orange,
                    animeList: [], // Placeholder for future plans
                    isGridView: isGridView,
                    emptyMessage: "No planned anime",
                    emptyDescription: "Add anime to your watch list"
                )
            }
        }
    }
}

// MARK: - AniList View
private struct AniListView: View {
    @State private var isConnected = false
    @State private var showingAniListAuth = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Section Header
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                Text("AniList Integration")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if isConnected {
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            // AniList Content
            VStack(spacing: 16) {
                if isConnected {
                    // Connected state - show AniList lists
                    VStack(spacing: 12) {
                        AniListListItem(title: "Watching", count: 12, icon: "play.circle.fill", color: .blue)
                        AniListListItem(title: "Completed", count: 45, icon: "checkmark.circle.fill", color: .green)
                        AniListListItem(title: "Plan to Watch", count: 23, icon: "clock.fill", color: .orange)
                        AniListListItem(title: "Dropped", count: 3, icon: "xmark.circle.fill", color: .red)
                    }
                    .padding(.horizontal)
                } else {
                    // Not connected state
                    VStack(spacing: 16) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.purple)
                        
                        VStack(spacing: 8) {
                            Text("Connect to AniList")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Sync your anime lists and watch progress with AniList")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: { showingAniListAuth = true }) {
                            HStack {
                                Image(systemName: "link")
                                Text("Connect AniList Account")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.purple)
                            .cornerRadius(12)
                        }
                    }
                    .padding(24)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Collection Section Component
private struct CollectionSection: View {
    let title: String
    let icon: String
    let iconColor: Color
    let animeList: [AnimeItem]
    let isGridView: Bool
    let emptyMessage: String
    let emptyDescription: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title2)
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(animeList.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Content
            if animeList.isEmpty {
                ContentUnavailableView(
                    emptyMessage,
                    systemImage: icon,
                    description: Text(emptyDescription)
                )
                .padding(.horizontal)
            } else {
                if isGridView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 20) {
                        ForEach(animeList) { anime in
                            NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                AnimeCard(anime: anime, width: 160)
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(animeList) { anime in
                            NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                AnimeListItem(anime: anime, collectionType: title)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - AniList Integration Section
private struct AniListSection: View {
    @State private var isConnected = false
    @State private var showingAniListAuth = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                Text("AniList Integration")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if isConnected {
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            // AniList Content
            VStack(spacing: 16) {
                if isConnected {
                    // Connected state - show AniList lists
                    VStack(spacing: 12) {
                        AniListListItem(title: "Watching", count: 12, icon: "play.circle.fill", color: .blue)
                        AniListListItem(title: "Completed", count: 45, icon: "checkmark.circle.fill", color: .green)
                        AniListListItem(title: "Plan to Watch", count: 23, icon: "clock.fill", color: .orange)
                        AniListListItem(title: "Dropped", count: 3, icon: "xmark.circle.fill", color: .red)
                    }
                    .padding(.horizontal)
                } else {
                    // Not connected state
                    VStack(spacing: 16) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.purple)
                        
                        VStack(spacing: 8) {
                            Text("Connect to AniList")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Sync your anime lists and watch progress with AniList")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: { showingAniListAuth = true }) {
                            HStack {
                                Image(systemName: "link")
                                Text("Connect AniList Account")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.purple)
                            .cornerRadius(12)
                        }
                    }
                    .padding(24)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - AniList List Item
private struct AniListListItem: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Updated Anime List Item
private struct AnimeListItem: View {
    let anime: AnimeItem
    let collectionType: String
    
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
                    Image(systemName: collectionIcon)
                        .font(.caption)
                        .foregroundColor(collectionColor)
                    Text(collectionType)
                        .font(.caption)
                        .foregroundColor(collectionColor)
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
    
    private var collectionIcon: String {
        switch collectionType {
        case "Bookmarks": return "bookmark.fill"
        case "Plan to Watch": return "clock.fill"
        default: return "folder.fill"
        }
    }
    
    private var collectionColor: Color {
        switch collectionType {
        case "Bookmarks": return .blue
        case "Plan to Watch": return .orange
        default: return .purple
        }
    }
}

private struct ContinueWatchingCard: View {
    let progress: WatchProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail with overlay
            ZStack(alignment: .bottomLeading) {
                if let thumbnailURL = progress.thumbnailURL {
                    CachedAsyncImage(url: URL(string: thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                            .overlay(ProgressView())
                    }
                    .frame(width: 200, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Color.gray
                        .overlay(
                            Image(systemName: "play.rectangle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 32))
                        )
                        .frame(width: 200, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Play button overlay
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .bold))
                    )
                    .offset(x: 8, y: -8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(progress.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                // Episode info
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Episode \(progress.episodeNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                // Progress bar
                VStack(spacing: 4) {
                    ProgressView(value: progress.progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(height: 4)
                    
                    HStack {
                        Text(progress.formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDuration(progress.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 200)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
} 