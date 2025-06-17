import SwiftUI
import AVKit
import AVFoundation

class CustomPlayerViewController: AVPlayerViewController {
    var onDismiss: (() -> Void)?
    private var subtitleOverlay: SubtitleOverlayView?
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            print("\n[Player] Dismissing player controller")
            onDismiss?()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self,
                                            selector: #selector(handleMemoryWarning),
                                            name: UIApplication.didReceiveMemoryWarningNotification,
                                            object: nil)
    }
    
    @objc private func handleMemoryWarning() {
        print("\n[Memory] Received memory warning, cleaning up resources")
        player?.currentItem?.asset.cancelLoading()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func addSubtitleOverlay(_ overlay: SubtitleOverlayView) {
        subtitleOverlay?.removeFromSuperview()
        subtitleOverlay = overlay
        
        guard let contentView = view.subviews.first else { return }
        contentView.addSubview(overlay)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            overlay.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
}

struct EpisodeView: View {
    let episodeId: String
    @StateObject private var viewModel = EpisodeViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(Edge.Set.all)
            
            content
        }
        .navigationBarBackButtonHidden(true)
        .task {
            print("\n[Init] Loading streaming sources for episode: \(episodeId)")
            await viewModel.loadStreamingSources(episodeId: episodeId)
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Loading...")
                .foregroundColor(.white)
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 16) {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                
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
                    print("\n[Setup] Starting player setup for episode: \(episodeId)")
                    setupPlayer(with: streamingData)
                }
        }
    }
    
    private func setupPlayer(with streamingData: StreamingData) {
        print("\n==================== PLAYER SETUP START ====================")
        
        // Find best quality source
        let preferredQuality = AppSettings.shared.preferredQuality
        print("\n[Quality] Preferred quality: \(preferredQuality)")
        
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
              let url = URL(string: source.url) else {
            print("\n[Error] Failed to get valid source URL")
            viewModel.errorMessage = "Failed to get valid video source"
            return
        }
        
        print("\n[Source] Selected source:")
        dump(source)
        
        // Configure headers
        let headers: [String: String] = streamingData.headers ?? [
            "Origin": "https://megacloud.blog",
            "Referer": "https://megacloud.blog/",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1"
        ]
        
        print("\n[Headers] Using headers:")
        dump(headers)
        
        // Create video asset
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": headers,
            "AVURLAssetHTTPUserAgentKey": headers["User-Agent"] ?? ""
        ])
        
        print("\n[Asset] Created video asset with URL: \(url)")
        
        // Create player item
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 10
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        // Create and configure player
        print("\n[Player] Creating AVPlayer")
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = 1.0
        
        // Handle subtitles
        if AppSettings.shared.subtitlesEnabled,
           let tracks = streamingData.tracks?.filter({ !$0.lang.lowercased().contains("thumbnail") }) {
            print("\n[Subtitles Debug] Subtitle handling started")
            print("[Subtitles Debug] Subtitles enabled in settings: \(AppSettings.shared.subtitlesEnabled)")
            print("[Subtitles Debug] Available subtitles: \(tracks.count)")
            print("[Subtitles Debug] Available languages: \(tracks.map { $0.lang }.joined(separator: ", "))")
            
            let preferredLanguage = AppSettings.shared.preferredSubtitlesLanguage
            print("\n[Subtitles Debug] Looking for subtitles in preferred language: \(preferredLanguage)")
            
            // Try to find subtitles in preferred language, fallback to English
            let selectedSubtitle = tracks.first { track in
                // Handle complex language strings like "English" or "English - Text (Region)"
                let langParts = track.lang.components(separatedBy: " - ")
                let mainLang = langParts[0].lowercased()
                return mainLang.contains(preferredLanguage.lowercased())
            } ?? tracks.first { track in
                let langParts = track.lang.components(separatedBy: " - ")
                let mainLang = langParts[0].lowercased()
                return mainLang.contains("english")
            }
            
            if let subtitle = selectedSubtitle,
               let subtitleURL = URL(string: subtitle.url) {
                print("\n[Subtitles Debug] Selected subtitle:")
                print("Language: \(subtitle.lang)")
                print("URL: \(subtitle.url)")
                
                // Load subtitles asynchronously
                Task {
                    do {
                        print("\n[Subtitles Debug] Loading subtitle content...")
                        let cues = try await SubtitleManager.shared.loadSubtitles(from: subtitleURL)
                        print("[Subtitles Debug] Successfully loaded \(cues.count) subtitle cues")
                        
                        // Add subtitle overlay to player if it's already presented
                        await MainActor.run {
                            if let playerController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController?.presentedViewController as? CustomPlayerViewController {
                                let overlay = SubtitleManager.shared.createSubtitleOverlay(for: cues, player: player)
                                playerController.addSubtitleOverlay(overlay)
                                print("[Subtitles Debug] Added subtitle overlay to existing player")
                            }
                        }
                    } catch {
                        print("\n[Subtitles Debug] Failed to load subtitles: \(error)")
                        print("Error details: \(error)")
                    }
                }
            } else {
                print("\n[Subtitles Debug] No suitable subtitles found for preferred language (\(preferredLanguage)) or English")
            }
        } else {
            print("\n[Subtitles Debug] Subtitles disabled or not available")
            print("Subtitles enabled in settings: \(AppSettings.shared.subtitlesEnabled)")
            print("Subtitles in streaming data: \(streamingData.tracks != nil)")
        }
        
        // Present player
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            print("\n[Player Debug] Setting up player presentation")
            let playerViewController = CustomPlayerViewController()
            playerViewController.player = player
            playerViewController.modalPresentationStyle = .fullScreen
            playerViewController.showsPlaybackControls = true
            
            // Add observers
            let timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { [weak playerViewController] _ in
                // Monitor playback status
                if player.currentItem?.status == .failed {
                    print("\n[Error] Playback failed: \(player.currentItem?.error?.localizedDescription ?? "Unknown error")")
                    Task { @MainActor in
                        viewModel.errorMessage = "Playback failed. Please try again."
                        playerViewController?.dismiss(animated: true)
                    }
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerViewController.player?.currentItem,
                queue: .main
            ) { _ in
                print("\n[Player] Playback ended")
                player.seek(to: .zero)
                print("\n[Player] Seeking to start")
            }
            
            // Set dismiss callback
            playerViewController.onDismiss = {
                print("\n[Player] Cleaning up player")
                player.pause()
                player.removeTimeObserver(timeObserver)
                NotificationCenter.default.removeObserver(playerViewController)
                player.replaceCurrentItem(with: nil)
                dismiss()
            }
            
            rootViewController.present(playerViewController, animated: true) {
                print("\n[Player] Player presented, starting playback")
                player.play()
            }
        } else {
            print("\n[Error] Failed to present player controller")
            viewModel.errorMessage = "Failed to present video player"
        }
        
        print("\n==================== PLAYER SETUP END ====================")
    }
}

#Preview {
    EpisodeView(episodeId: "example-episode-id")
} 