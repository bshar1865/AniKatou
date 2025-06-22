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
        let headers: [String: String] = streamingData.headers ?? [:]
        
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
        
        // Handle intro/outro skipping
        if let intro = streamingData.intro {
            print("\n[Player] Found intro: \(intro.start) - \(intro.end)")
            
            // Add observer for intro
            let introObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { [weak player] time in
                let currentTime = time.seconds
                if currentTime >= Double(intro.start) && currentTime < Double(intro.end) {
                    if AppSettings.shared.autoSkipIntro {
                        print("\n[Player] Auto-skipping intro")
                        player?.seek(to: CMTime(seconds: Double(intro.end), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                    }
                }
            }
            
            // Store observer for cleanup
            viewModel.timeObservers.append((player: player, observer: introObserver))
        }
        
        if let outro = streamingData.outro {
            print("\n[Player] Found outro: \(outro.start) - \(outro.end)")
            
            // Add observer for outro
            let outroObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { [weak player] time in
                let currentTime = time.seconds
                if currentTime >= Double(outro.start) && currentTime < Double(outro.end) {
                    if AppSettings.shared.autoSkipOutro {
                        print("\n[Player] Auto-skipping outro")
                        player?.seek(to: CMTime(seconds: Double(outro.end), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                    }
                }
            }
            
            // Store observer for cleanup
            viewModel.timeObservers.append((player: player, observer: outroObserver))
        }
        
        // Handle subtitles
        if AppSettings.shared.subtitlesEnabled,
           let tracks = streamingData.tracks?.filter({ !$0.lang.lowercased().contains("thumbnail") }) {
            print("\n[Subtitles Debug] Subtitle handling started")
            print("[Subtitles Debug] Subtitles enabled in settings: \(AppSettings.shared.subtitlesEnabled)")
            print("[Subtitles Debug] Available subtitles: \(tracks.count)")
            print("[Subtitles Debug] Available languages: \(tracks.map { $0.lang }.joined(separator: ", "))")
            
            // Look for English subtitles
            let selectedSubtitle = tracks.first { track in
                // Handle complex language strings like "English" or "English - Text (Region)"
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
                print("\n[Subtitles Debug] No English subtitles found")
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
            
            // Add skip buttons if auto-skip is disabled
            if !AppSettings.shared.autoSkipIntro || !AppSettings.shared.autoSkipOutro {
                let skipButtonsView = UIStackView()
                skipButtonsView.axis = .vertical
                skipButtonsView.spacing = 8
                skipButtonsView.translatesAutoresizingMaskIntoConstraints = false
                
                if let intro = streamingData.intro, !AppSettings.shared.autoSkipIntro {
                    let skipIntroButton = UIButton(type: .system)
                    skipIntroButton.setTitle("Skip Intro", for: .normal)
                    skipIntroButton.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
                    skipIntroButton.layer.cornerRadius = 4
                    skipIntroButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
                    skipIntroButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
                    
                    skipIntroButton.addAction(UIAction { [weak player] _ in
                        print("\n[Player] Skipping intro")
                        player?.seek(to: CMTime(seconds: Double(intro.end), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                    }, for: .touchUpInside)
                    
                    skipButtonsView.addArrangedSubview(skipIntroButton)
                }
                
                if let outro = streamingData.outro, !AppSettings.shared.autoSkipOutro {
                    let skipOutroButton = UIButton(type: .system)
                    skipOutroButton.setTitle("Skip Outro", for: .normal)
                    skipOutroButton.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
                    skipOutroButton.layer.cornerRadius = 4
                    skipOutroButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
                    skipOutroButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
                    
                    skipOutroButton.addAction(UIAction { [weak player] _ in
                        print("\n[Player] Skipping outro")
                        player?.seek(to: CMTime(seconds: Double(outro.end), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                    }, for: .touchUpInside)
                    
                    skipButtonsView.addArrangedSubview(skipOutroButton)
                }
                
                playerViewController.contentOverlayView?.addSubview(skipButtonsView)
                NSLayoutConstraint.activate([
                    skipButtonsView.topAnchor.constraint(equalTo: playerViewController.contentOverlayView!.topAnchor, constant: 16),
                    skipButtonsView.trailingAnchor.constraint(equalTo: playerViewController.contentOverlayView!.trailingAnchor, constant: -16)
                ])
            }
            
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