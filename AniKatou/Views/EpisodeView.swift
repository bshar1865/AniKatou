import SwiftUI
import AVKit

class CustomPlayerViewController: AVPlayerViewController {
    var onDismiss: (() -> Void)?
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            onDismiss?()
        }
    }
}

struct EpisodeView: View {
    let episodeId: String
    @StateObject private var viewModel = EpisodeViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
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
                    Color.clear
                        .onAppear {
                            setupPlayer(with: streamingData)
                        }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.loadStreamingSources(episodeId: episodeId)
        }
    }
    
    private func setupPlayer(with streamingData: StreamingData) {
        // Find the best quality source based on settings
        let preferredQuality = AppSettings.shared.preferredQuality
        let source = streamingData.sources.first { source in
            source.quality?.lowercased() == preferredQuality.lowercased()
        } ?? streamingData.sources.sorted { (s1, s2) in
            guard let q1 = s1.quality?.replacingOccurrences(of: "p", with: ""),
                  let q2 = s2.quality?.replacingOccurrences(of: "p", with: ""),
                  let quality1 = Int(q1),
                  let quality2 = Int(q2) else { return false }
            return abs(quality1 - Int(preferredQuality.replacingOccurrences(of: "p", with: ""))!) <
                   abs(quality2 - Int(preferredQuality.replacingOccurrences(of: "p", with: ""))!)
        }.first ?? streamingData.sources.first
        
        guard let source = source,
              let url = URL(string: source.url) else { return }
        
        // Configure headers with secure defaults
        let headers: [String: String] = streamingData.headers ?? [
            "Origin": "https://megacloud.club",
            "Referer": "https://megacloud.club/",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1"
        ]
        
        // Create asset with headers and optimize for streaming
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": headers,
            "AVURLAssetHTTPUserAgentKey": headers["User-Agent"] ?? ""
        ])
        
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 10
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        // Create and configure player
        let player = AVPlayer(playerItem: playerItem)
        player.actionAtItemEnd = AppSettings.shared.autoplayEnabled ? .advance : .pause
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = 1.0
        
        // Present the video player
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            let playerViewController = CustomPlayerViewController()
            playerViewController.player = player
            playerViewController.modalPresentationStyle = .fullScreen
            playerViewController.showsPlaybackControls = true
            
            // Add observer for playback end
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerViewController.player?.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                if AppSettings.shared.autoplayEnabled {
                    player.play()
                }
            }
            
            // Set dismiss callback
            playerViewController.onDismiss = {
                player.pause()
                player.replaceCurrentItem(with: nil)
                dismiss()
            }
            
            rootViewController.present(playerViewController, animated: true) {
                player.play()
            }
        }
    }
}

#Preview {
    EpisodeView(episodeId: "example-episode-id")
} 