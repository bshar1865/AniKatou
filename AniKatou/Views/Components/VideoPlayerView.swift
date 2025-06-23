import SwiftUI
import AVKit
import AVFoundation

// --- Moved from EpisodeView.swift ---
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
// --- End moved class ---

struct VideoPlayerView: UIViewControllerRepresentable {
    let streamingData: StreamingData
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> CustomPlayerViewController {
        let playerController = CustomPlayerViewController()
        playerController.onDismiss = onDismiss
        setupPlayer(for: playerController, context: context)
        return playerController
    }
    
    func updateUIViewController(_ uiViewController: CustomPlayerViewController, context: Context) {
        // No-op
    }
    
    private func setupPlayer(for playerController: CustomPlayerViewController, context: Context) {
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
            return
        }
        let headers: [String: String] = streamingData.headers ?? [:]
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": headers,
            "AVURLAssetHTTPUserAgentKey": headers["User-Agent"] ?? ""
        ])
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 10
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = 1.0
        playerController.player = player
        playerController.modalPresentationStyle = .fullScreen
        playerController.showsPlaybackControls = true
        // Handle intro/outro skipping
        if let intro = streamingData.intro {
            let introObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { [weak player] time in
                let currentTime = time.seconds
                if currentTime >= Double(intro.start) && currentTime < Double(intro.end) {
                    if AppSettings.shared.autoSkipIntro {
                        player?.seek(to: CMTime(seconds: Double(intro.end), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                    }
                }
            }
            context.coordinator.timeObservers.append((player: player, observer: introObserver))
        }
        if let outro = streamingData.outro {
            let outroObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { [weak player] time in
                let currentTime = time.seconds
                if currentTime >= Double(outro.start) && currentTime < Double(outro.end) {
                    if AppSettings.shared.autoSkipOutro {
                        player?.seek(to: CMTime(seconds: Double(outro.end), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                    }
                }
            }
            context.coordinator.timeObservers.append((player: player, observer: outroObserver))
        }
        // Handle subtitles
        if AppSettings.shared.subtitlesEnabled,
           let tracks = streamingData.tracks?.filter({ !$0.lang.lowercased().contains("thumbnail") }) {
            let selectedSubtitle = tracks.first { track in
                let langParts = track.lang.components(separatedBy: " - ")
                let mainLang = langParts[0].lowercased()
                return mainLang.contains("english")
            }
            if let subtitle = selectedSubtitle,
               let subtitleURL = URL(string: subtitle.url) {
                Task {
                    do {
                        let cues = try await SubtitleManager.shared.loadSubtitles(from: subtitleURL)
                        await MainActor.run {
                            let overlay = SubtitleManager.shared.createSubtitleOverlay(for: cues, player: player)
                            playerController.addSubtitleOverlay(overlay)
                        }
                    } catch {
                        print("Error details: \(error)")
                    }
                }
            }
        }
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
                if #available(iOS 15.0, *) {
                    var config = UIButton.Configuration.filled()
                    config.baseBackgroundColor = .systemBackground.withAlphaComponent(0.7)
                    config.cornerStyle = .medium
                    config.title = "Skip Intro"
                    config.titleAlignment = .center
                    config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
                    skipIntroButton.configuration = config
                } else {
                    skipIntroButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
                }
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
                if #available(iOS 15.0, *) {
                    var config = UIButton.Configuration.filled()
                    config.baseBackgroundColor = .systemBackground.withAlphaComponent(0.7)
                    config.cornerStyle = .medium
                    config.title = "Skip Outro"
                    config.titleAlignment = .center
                    config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
                    skipOutroButton.configuration = config
                } else {
                    skipOutroButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
                }
                skipOutroButton.addAction(UIAction { [weak player] _ in
                    player?.seek(to: CMTime(seconds: Double(outro.end), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                }, for: .touchUpInside)
                skipButtonsView.addArrangedSubview(skipOutroButton)
            }
            playerController.contentOverlayView?.addSubview(skipButtonsView)
            NSLayoutConstraint.activate([
                skipButtonsView.topAnchor.constraint(equalTo: playerController.contentOverlayView!.topAnchor, constant: 16),
                skipButtonsView.trailingAnchor.constraint(equalTo: playerController.contentOverlayView!.trailingAnchor, constant: -16)
            ])
        }
        // Add modern floating close button
        let closeButton = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        let closeImage = UIImage(systemName: "xmark", withConfiguration: config)
        closeButton.setImage(closeImage, for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 16 // For a 32x32 button
        closeButton.layer.masksToBounds = true
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addAction(UIAction { _ in
            playerController.dismiss(animated: true) {
                playerController.onDismiss?()
            }
        }, for: .touchUpInside)
        // Add shadow
        closeButton.layer.shadowColor = UIColor.black.cgColor
        closeButton.layer.shadowOpacity = 0.3
        closeButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        closeButton.layer.shadowRadius = 4
        playerController.contentOverlayView?.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: playerController.contentOverlayView!.topAnchor, constant: 24),
            closeButton.leadingAnchor.constraint(equalTo: playerController.contentOverlayView!.leadingAnchor, constant: 24),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        // Add observers for playback status and end
        let timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { [weak playerController] _ in
            if player.currentItem?.status == .failed {
                playerController?.dismiss(animated: true)
                onDismiss()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerController.player?.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
        }
        // Set dismiss callback
        playerController.onDismiss = {
            player.pause()
            player.removeTimeObserver(timeObserver)
            NotificationCenter.default.removeObserver(playerController)
            player.replaceCurrentItem(with: nil)
            onDismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var timeObservers: [(player: AVPlayer, observer: Any)] = []
        deinit {
            for (player, observer) in timeObservers {
                player.removeTimeObserver(observer)
            }
            timeObservers.removeAll()
        }
    }
} 