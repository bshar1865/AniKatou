import SwiftUI
import AVKit

struct EpisodeView: View {
    let animeId: String
    let episodeId: String
    let episodeNumber: Int
    @StateObject private var viewModel = EpisodeViewModel()
    @State private var player: AVPlayer?
    @State private var timeObserverToken: Any?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading...")
                            .foregroundColor(.white)
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Text(error)
                                .foregroundColor(.red)
                            
                            Button("Retry") {
                                Task {
                                    await viewModel.loadStreamingSources(episodeId: episodeId)
                                }
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    } else if let streamingData = viewModel.streamingData?.data {
                        BasicVideoPlayer(player: player)
                            .edgesIgnoringSafeArea(.all)
                            .onAppear {
                                setupPlayer(with: streamingData)
                            }
                            .onDisappear {
                                cleanup()
                            }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadStreamingSources(episodeId: episodeId)
        }
    }
    
    private func setupPlayer(with streamingData: StreamingData) {
        // Find the best quality source based on settings
        let preferredQuality = AppSettings.shared.preferredQuality
        let source = streamingData.sources.first { source in
            source.quality?.lowercased() == preferredQuality.lowercased()
        } ?? streamingData.sources.first
        
        guard let source = source,
              let url = URL(string: source.url) else { return }
        
        // Configure headers
        let headers: [String: String] = [
            "Origin": "https://megacloud.club",
            "Referer": "https://megacloud.club/",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1"
        ]
        
        // Create asset with headers
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": headers
        ])
        
        let playerItem = AVPlayerItem(asset: asset)
        
        // Create and configure player
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        // Restore previous progress
        if let progress = WatchProgressManager.shared.getProgress(animeId: animeId, episodeId: episodeId) {
            player?.seek(to: CMTime(seconds: progress.timestamp, preferredTimescale: 1))
        }
        
        // Add time observer for progress tracking
        let interval = CMTime(seconds: 5, preferredTimescale: 1)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let currentTime = time.seconds
            if let duration = player?.currentItem?.duration.seconds, duration.isFinite {
                WatchProgressManager.shared.saveProgress(
                    animeId: animeId,
                    episodeId: episodeId,
                    episodeNumber: episodeNumber,
                    timestamp: currentTime,
                    duration: duration
                )
            }
        }
        
        player?.actionAtItemEnd = .pause // Disable autoplay in preview
        #if !DEBUG
        player?.actionAtItemEnd = AppSettings.shared.autoplayEnabled ? .advance : .pause
        #endif
        
        player?.play()
    }
    
    private func cleanup() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
    }
}

struct BasicVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        return controller
    }
    
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
}

#Preview {
    NavigationView {
        EpisodeView(
            animeId: "example-anime-id",
            episodeId: "example-episode-id",
            episodeNumber: 1
        )
    }
} 