import SwiftUI

struct ContinueWatchingView: View {
    @State private var continueWatching: [WatchProgress] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !continueWatching.isEmpty {
                Text("Continue Watching")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(continueWatching, id: \.episodeId) { progress in
                            NavigationLink(destination: EpisodeView(
                                animeId: progress.animeId,
                                episodeId: progress.episodeId,
                                episodeNumber: progress.episodeNumber
                            )) {
                                ContinueWatchingCard(progress: progress)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            continueWatching = WatchProgressManager.shared.getContinueWatching()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            continueWatching = WatchProgressManager.shared.getContinueWatching()
        }
    }
}

struct ContinueWatchingCard: View {
    let progress: WatchProgress
    @State private var animeDetails: AnimeDetails?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let details = animeDetails {
                AsyncImage(url: URL(string: details.image)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
                .frame(width: 160, height: 90)
                .clipped()
                .cornerRadius(8)
                .overlay(
                    GeometryReader { geometry in
                        ZStack(alignment: .bottom) {
                            // Progress bar
                            Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(height: 3)
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * progress.progress, height: 3)
                        }
                    }
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(details.title)
                        .font(.caption)
                        .lineLimit(1)
                    
                    Text("Episode \(progress.episodeNumber)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Color.gray
                    .frame(width: 160, height: 90)
                    .cornerRadius(8)
            }
        }
        .frame(width: 160)
        .task {
            do {
                let result = try await APIService.shared.getAnimeDetails(id: progress.animeId)
                animeDetails = result.data.anime.info
            } catch {
                print("Failed to load anime details: \(error)")
            }
        }
    }
}

#Preview {
    NavigationView {
        ContinueWatchingView()
    }
} 