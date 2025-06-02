import SwiftUI
import AVKit

struct EpisodeView: View {
    let episodeId: String
    @StateObject private var viewModel = EpisodeViewModel()
    @State private var player: AVPlayer?
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
                        VideoPlayer(player: player)
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
        .statusBar(hidden: true)
        .navigationBarHidden(true)
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
        playerItem.preferredForwardBufferDuration = 10
        
        // Create and configure player
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        player?.actionAtItemEnd = AppSettings.shared.autoplayEnabled ? .advance : .pause
        player?.automaticallyWaitsToMinimizeStalling = true
        
        // Start playback
        player?.play()
    }
    
    private func cleanup() {
        player?.pause()
        player = nil
    }
}

struct VideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = true
        controller.entersFullScreenWhenPlaybackBegins = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.updatesNowPlayingInfoCenter = true
        
        // Force landscape orientation
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        }
        
        return controller
    }
    
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
}

#Preview {
    EpisodeView(episodeId: "example-episode-id")
} 