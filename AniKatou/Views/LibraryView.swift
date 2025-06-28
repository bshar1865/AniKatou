import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel = BookmarksViewModel()
    @State private var isGridView = true
    @State private var watchHistory: [WatchProgress] = []
    @State private var selectedTab = 0
    @State private var showingRemoveAlert = false
    @State private var itemToRemove: Any?
    @State private var removeType: RemoveType = .continueWatching
    
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
                                    .contextMenu {
                                        Button("Remove from Continue Watching", role: .destructive) {
                                            removeFromContinueWatching(progress)
                                        }
                                        
                                        Button("Open Episode") {
                                            // NavigationLink will handle this automatically
                                        }
                                    }
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
                
                // AniList Collections Section
                VStack(spacing: 20) {
                    HStack {
                        Text("AniList")
                            .font(.title)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // AniList Collections Cards
                    VStack(spacing: 12) {
                        // Watching Collection
                        NavigationLink(destination: AniListCollectionView(status: .current, title: "Watching")) {
                            AniListCollectionCard(
                                title: "Watching",
                                icon: "play.circle.fill",
                                color: .green,
                                count: 0 // TODO: Get from AniList
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Plan to Watch Collection
                        NavigationLink(destination: AniListCollectionView(status: .planning, title: "Plan to Watch")) {
                            AniListCollectionCard(
                                title: "Plan to Watch",
                                icon: "clock.circle.fill",
                                color: .blue,
                                count: 0 // TODO: Get from AniList
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Completed Collection
                        NavigationLink(destination: AniListCollectionView(status: .completed, title: "Completed")) {
                            AniListCollectionCard(
                                title: "Completed",
                                icon: "checkmark.circle.fill",
                                color: .purple,
                                count: 0 // TODO: Get from AniList
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Paused Collection
                        NavigationLink(destination: AniListCollectionView(status: .paused, title: "Paused")) {
                            AniListCollectionCard(
                                title: "Paused",
                                icon: "pause.circle.fill",
                                color: .orange,
                                count: 0 // TODO: Get from AniList
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Dropped Collection
                        NavigationLink(destination: AniListCollectionView(status: .dropped, title: "Dropped")) {
                            AniListCollectionCard(
                                title: "Dropped",
                                icon: "xmark.circle.fill",
                                color: .red,
                                count: 0 // TODO: Get from AniList
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Rewatching Collection
                        NavigationLink(destination: AniListCollectionView(status: .repeating, title: "Rewatching")) {
                            AniListCollectionCard(
                                title: "Rewatching",
                                icon: "repeat.circle.fill",
                                color: .indigo,
                                count: 0 // TODO: Get from AniList
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadWatchHistory()
        }
        .alert("Remove Item", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                confirmRemove()
            }
        } message: {
            switch removeType {
            case .continueWatching:
                Text("Remove this item from Continue Watching?")
            case .bookmark:
                Text("Remove this anime from your collection?")
            }
        }
        .refreshable {
            loadWatchHistory()
        }
    }
    
    private func loadWatchHistory() {
        // Clean up finished episodes first
        WatchProgressManager.shared.cleanupFinishedEpisodes()
        watchHistory = WatchProgressManager.shared.getWatchHistory()
    }
    
    private func removeFromContinueWatching(_ progress: WatchProgress) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        itemToRemove = progress
        removeType = .continueWatching
        showingRemoveAlert = true
    }
    
    private func removeBookmark(_ anime: AnimeItem) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        itemToRemove = anime
        removeType = .bookmark
        showingRemoveAlert = true
    }
    
    private func confirmRemove() {
        switch removeType {
        case .continueWatching:
            if let progress = itemToRemove as? WatchProgress {
                WatchProgressManager.shared.removeProgress(for: progress.animeID, episodeID: progress.episodeID)
                loadWatchHistory()
            }
        case .bookmark:
            if let anime = itemToRemove as? AnimeItem {
                BookmarkManager.shared.removeBookmark(anime)
                // Post notification to update UI
                NotificationCenter.default.post(
                    name: NSNotification.Name("BookmarksDidChange"),
                    object: nil,
                    userInfo: ["animeId": anime.id]
                )
            }
        }
        showingRemoveAlert = false
        itemToRemove = nil
    }
}

enum RemoveType {
    case continueWatching
    case bookmark
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
    
    private static let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
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
                    LazyVGrid(columns: Self.gridColumns, spacing: 20) {
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

// MARK: - AniList Components

struct AniListCollectionCard: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
                .frame(width: 60, height: 60)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(count) anime")
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
}

struct AniListCollectionView: View {
    let status: AniListStatus
    let title: String
    @StateObject private var viewModel = AniListAuthViewModel()
    @State private var isGridView = true
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        Group {
            if viewModel.isAuthenticated {
                if viewModel.isLoading {
                    ProgressView("Loading \(title)...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let items = viewModel.getLibraryForStatus(status)
                    
                    if items.isEmpty {
                        ContentUnavailableView(
                            "No \(title)",
                            systemImage: status.icon,
                            description: Text("Your \(title.lowercased()) list is empty")
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(items) { item in
                                    AniListAnimeCard(item: item)
                                }
                            }
                            .padding()
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Not Connected",
                    systemImage: "person.circle",
                    description: Text("Connect your AniList account in Settings to view your \(title.lowercased()) list")
                )
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if viewModel.isAuthenticated {
                Task {
                    await viewModel.loadUserLibrary()
                }
            }
        }
    }
}

struct AniListAnimeCard: View {
    let item: AniListLibraryItem
    @State private var showingAniListDetails = false
    
    var body: some View {
        Button(action: {
            showingAniListDetails = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Cover Image
                if let imageURL = item.imageURL {
                    CachedAsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                            .overlay(ProgressView())
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Color.gray
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white)
                                .font(.system(size: 32))
                        )
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(item.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    // Progress
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(item.progressText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    // Score
                    if item.score != nil && item.score! > 0 {
                        HStack {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(item.scoreText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    // Status Badge
                    HStack {
                        Image(systemName: item.status.icon)
                            .font(.caption)
                            .foregroundColor(item.status.statusColor)
                        Text(item.status.displayName)
                            .font(.caption)
                            .foregroundColor(item.status.statusColor)
                        Spacer()
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingAniListDetails) {
            AniListAnimeDetailView(item: item)
        }
    }
}

struct AniListAnimeDetailView: View {
    let item: AniListLibraryItem
    @Environment(\.dismiss) private var dismiss
    @State private var searchResults: [AnimeItem] = []
    @State private var isSearching = false
    @State private var searchError: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // AniList Info Section
                    VStack(spacing: 16) {
                        // Cover Image
                        if let imageURL = item.imageURL {
                            CachedAsyncImage(url: URL(string: imageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray
                                    .overlay(ProgressView())
                            }
                            .frame(width: 200, height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Title and Info
                        VStack(spacing: 8) {
                            Text(item.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            if item.romajiTitle != item.title {
                                Text(item.romajiTitle)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Status and Progress
                            HStack(spacing: 16) {
                                Label(item.status.displayName, systemImage: item.status.icon)
                                    .foregroundColor(item.status.statusColor)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(item.status.statusColor.opacity(0.1))
                                    .cornerRadius(8)
                                
                                Label(item.progressText, systemImage: "play.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                            
                            if let score = item.score, score > 0 {
                                Label(item.scoreText, systemImage: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // Search for Streaming Section
                    VStack(spacing: 16) {
                        Text("Find on Streaming Service")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Search for this anime on your streaming service to watch episodes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            Task {
                                await searchForAnime()
                            }
                        }) {
                            HStack {
                                if isSearching {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                                Text(isSearching ? "Searching..." : "Search for Episodes")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .disabled(isSearching)
                        
                        if let error = searchError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Search Results
                        if !searchResults.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Search Results")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(searchResults) { anime in
                                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                            HStack(spacing: 12) {
                                                // Thumbnail
                                                CachedAsyncImage(url: URL(string: anime.poster)) { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    Color.gray
                                                }
                                                .frame(width: 60, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                
                                                // Info
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(anime.name)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .lineLimit(2)
                                                    
                                                    if let episodes = anime.episodes {
                                                        Text("\(episodes) episodes")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    if let type = anime.type {
                                                        Text(type)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(12)
                                            .background(Color(.tertiarySystemBackground))
                                            .cornerRadius(12)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                }
                .padding()
            }
            .navigationTitle("AniList Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func searchForAnime() async {
        isSearching = true
        searchError = nil
        searchResults = []
        
        do {
            // Try searching with the main title first
            var results = try await APIService.shared.searchAnime(query: item.title)
            
            // If no results, try with romaji title
            if results.isEmpty, item.romajiTitle != item.title {
                results = try await APIService.shared.searchAnime(query: item.romajiTitle)
            }
            
            // If still no results, try with a shorter version of the title
            if results.isEmpty {
                let shortTitle = item.title.components(separatedBy: " ").prefix(3).joined(separator: " ")
                if shortTitle.count >= 3 {
                    results = try await APIService.shared.searchAnime(query: shortTitle)
                }
            }
            
            await MainActor.run {
                searchResults = results
                isSearching = false
                
                if results.isEmpty {
                    searchError = "No matching anime found on streaming service. Try searching manually in the Search tab."
                }
            }
        } catch {
            await MainActor.run {
                searchError = "Search failed: \(error.localizedDescription)"
                isSearching = false
            }
        }
    }
}

extension AniListStatus {
    var statusColor: Color {
        switch self {
        case .current:
            return .green
        case .planning:
            return .blue
        case .completed:
            return .purple
        case .dropped:
            return .red
        case .paused:
            return .orange
        case .repeating:
            return .pink
        }
    }
} 