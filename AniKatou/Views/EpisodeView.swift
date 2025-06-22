import SwiftUI
import AVKit
import AVFoundation

class CustomPlayerViewController: AVPlayerViewController {
    var onDismiss: (() -> Void)?
    private var subtitleOverlay: SubtitleOverlayView?
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
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
                    setupPlayer(with: streamingData)
                }
        }
    }
    
    private func setupPlayer(with streamingData: StreamingData) {
        // Find best quality source
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
              let url = URL(string: source.url) else {
            viewModel.errorMessage = "Failed to get valid video source"
            return
        }
        
        // Configure headers
        let headers: [String: String] = streamingData.headers ?? [:]
        
        // Create video asset
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": headers,
            "AVURLAssetHTTPUserAgentKey": headers["User-Agent"] ?? ""
        ])
        
        // Create player item
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 10
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        // Create and configure player
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = 1.0
        
        // Handle intro/outro skipping
        if let intro = streamingData.intro {
            // Add observer for intro
            let introObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { [weak player] time in
                let currentTime = time.seconds
                if currentTime >= Double(intro.start) && currentTime < Double(intro.end) {
                    if AppSettings.shared.autoSkipIntro {
                        player?.seek(to: CMTime(seconds: Double(intro.end), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                    }
                }
            }
            
            // Store observer for cleanup
            viewModel.timeObservers.append((player: player, observer: introObserver))
        }
        
        if let outro = streamingData.outro {
            // Add observer for outro
            let outroObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { [weak player] time in
                let currentTime = time.seconds
                if currentTime >= Double(outro.start) && currentTime < Double(outro.end) {
                    if AppSettings.shared.autoSkipOutro {
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
            // Look for English subtitles
            let selectedSubtitle = tracks.first { track in
                // Handle complex language strings like "English" or "English - Text (Region)"
                let langParts = track.lang.components(separatedBy: " - ")
                let mainLang = langParts[0].lowercased()
                return mainLang.contains("english")
            }
            
            if let subtitle = selectedSubtitle,
               let subtitleURL = URL(string: subtitle.url) {
                // Load subtitles asynchronously
                Task {
                    do {
                        let cues = try await SubtitleManager.shared.loadSubtitles(from: subtitleURL)
                        
                        // Add subtitle overlay to player if it's already presented
                        await MainActor.run {
                            if let playerController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController?.presentedViewController as? CustomPlayerViewController {
                                let overlay = SubtitleManager.shared.createSubtitleOverlay(for: cues, player: player)
                                playerController.addSubtitleOverlay(overlay)
                            }
                        }
                    } catch {
                        print("Error details: \(error)")
                    }
                }
            }
        }
        
        // Present player
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
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
                player.seek(to: .zero)
            }
            
            // Set dismiss callback
            playerViewController.onDismiss = {
                player.pause()
                player.removeTimeObserver(timeObserver)
                NotificationCenter.default.removeObserver(playerViewController)
                player.replaceCurrentItem(with: nil)
                dismiss()
            }
            
            rootViewController.present(playerViewController, animated: true) {
                player.play()
            }
        } else {
            viewModel.errorMessage = "Failed to present video player"
        }
    }
} 