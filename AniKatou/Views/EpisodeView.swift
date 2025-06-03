import SwiftUI
import AVKit
import AVFoundation

class CustomPlayerViewController: AVPlayerViewController {
    var onDismiss: (() -> Void)?
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            print("\n[Player] Dismissing player controller")
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
                    print("\n==================== STREAMING DATA START ====================")
                    print("\n[Setup] Starting player setup for episode: \(episodeId)")
                    
                    print("\n[Data] Complete streaming data dump:")
                    dump(streamingData)
                    
                    print("\n[Sources] Video sources dump:")
                    streamingData.sources.forEach { source in
                        print("\nSource:")
                        dump(source)
                    }
                    
                    print("\n[Subtitles] Complete subtitles dump:")
                    if let subtitles = streamingData.subtitles {
                        dump(subtitles)
                    } else {
                        print("No subtitles available")
                    }
                    
                    print("\n[Headers] Complete headers dump:")
                    if let headers = streamingData.headers {
                        dump(headers)
                    } else {
                        print("Using default headers")
                    }
                    
                    print("\n==================== STREAMING DATA END ====================\n")
                    
                    setupPlayer(with: streamingData)
                }
        }
    }
    
    private func setupPlayer(with streamingData: StreamingData) {
        print("\n==================== PLAYER SETUP START ====================")
        print("\n[Player] Setting up player")
        
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
            return
        }
        
        print("\n[Source] Selected source:")
        dump(source)
        
        // Configure headers
        let headers: [String: String] = streamingData.headers ?? [
            "Origin": "https://megacloud.club",
            "Referer": "https://megacloud.club/",
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
        
        print("\n==================== SUBTITLE PROCESSING START ====================")
        
        // Handle subtitles
        if let subtitles = streamingData.subtitles {
            print("\n[Subtitles] Available subtitles:")
            dump(subtitles)
            
            if let englishSubtitle = subtitles.first(where: { $0.lang.lowercased() == "english" || $0.lang.lowercased() == "en" }) {
                print("\n[Subtitles] Selected English subtitle:")
                dump(englishSubtitle)
                
                if let subtitleURL = URL(string: englishSubtitle.url) {
                    print("\n[Subtitles] Loading subtitle from URL: \(subtitleURL)")
                    
                    // Create subtitle asset
                    let subtitleAsset = AVURLAsset(url: subtitleURL)
                    
                    // Load subtitle asset
                    Task {
                        do {
                            print("\n[Subtitles] Loading subtitle content...")
                            let subtitleData = try Data(contentsOf: subtitleURL)
                            if let content = String(data: subtitleData, encoding: .utf8) {
                                print("\n[Subtitles] Raw subtitle content:")
                                print(content)
                            }
                            
                            print("\n[Subtitles] Loading subtitle asset tracks...")
                            try await subtitleAsset.load(.tracks)
                            let textTracks = subtitleAsset.tracks(withMediaType: .text)
                            print("\n[Subtitles] Text tracks found: \(textTracks.count)")
                            
                            for (index, track) in textTracks.enumerated() {
                                print("\n[Subtitles] Track #\(index + 1) details:")
                                dump(track)
                            }
                            
                            if let subtitleTrack = textTracks.first {
                                print("\n[Composition] Creating composition...")
                                let composition = AVMutableComposition()
                                
                                // Add video track
                                if let videoTrack = asset.tracks(withMediaType: .video).first,
                                   let compositionVideoTrack = composition.addMutableTrack(
                                    withMediaType: .video,
                                    preferredTrackID: kCMPersistentTrackID_Invalid
                                   ) {
                                    try await videoTrack.load(.timeRange)
                                    try compositionVideoTrack.insertTimeRange(
                                        videoTrack.timeRange,
                                        of: videoTrack,
                                        at: .zero
                                    )
                                    print("\n[Composition] Video track added")
                                    dump(compositionVideoTrack)
                                }
                                
                                // Add audio track
                                if let audioTrack = asset.tracks(withMediaType: .audio).first,
                                   let compositionAudioTrack = composition.addMutableTrack(
                                    withMediaType: .audio,
                                    preferredTrackID: kCMPersistentTrackID_Invalid
                                   ) {
                                    try await audioTrack.load(.timeRange)
                                    try compositionAudioTrack.insertTimeRange(
                                        audioTrack.timeRange,
                                        of: audioTrack,
                                        at: .zero
                                    )
                                    print("\n[Composition] Audio track added")
                                    dump(compositionAudioTrack)
                                }
                                
                                // Add subtitle track
                                if let compositionSubtitleTrack = composition.addMutableTrack(
                                    withMediaType: .text,
                                    preferredTrackID: kCMPersistentTrackID_Invalid
                                ) {
                                    try await subtitleTrack.load(.timeRange)
                                    try compositionSubtitleTrack.insertTimeRange(
                                        subtitleTrack.timeRange,
                                        of: subtitleTrack,
                                        at: .zero
                                    )
                                    print("\n[Composition] Subtitle track added")
                                    dump(compositionSubtitleTrack)
                                    
                                    print("\n[Composition] Final composition details:")
                                    dump(composition)
                                }
                                
                                // Update player item
                                await MainActor.run {
                                    print("\n[Player] Updating player item with composition")
                                    let newPlayerItem = AVPlayerItem(asset: composition)
                                    if let player = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController?.presentedViewController as? AVPlayerViewController {
                                        player.player?.replaceCurrentItem(with: newPlayerItem)
                                        print("\n[Player] Player item updated successfully")
                                    } else {
                                        print("\n[Error] Failed to get player controller")
                                    }
                                }
                            } else {
                                print("\n[Error] No text tracks found in subtitle asset")
                            }
                        } catch {
                            print("\n[Error] Subtitle processing failed:")
                            dump(error)
                        }
                    }
                } else {
                    print("\n[Error] Invalid subtitle URL")
                }
            } else {
                print("\n[Subtitles] No English subtitle found")
            }
        } else {
            print("\n[Subtitles] No subtitles available")
        }
        
        print("\n==================== SUBTITLE PROCESSING END ====================")
        
        // Create and configure player
        print("\n[Player] Creating AVPlayer")
        let player = AVPlayer(playerItem: playerItem)
        player.actionAtItemEnd = AppSettings.shared.autoplayEnabled ? .advance : .pause
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = 1.0
        
        // Present player
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            print("\n[Player] Presenting player controller")
            let playerViewController = CustomPlayerViewController()
            playerViewController.player = player
            playerViewController.modalPresentationStyle = .fullScreen
            playerViewController.showsPlaybackControls = true
            
            // Add playback end observer
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerViewController.player?.currentItem,
                queue: .main
            ) { _ in
                print("\n[Player] Playback ended")
                player.seek(to: .zero)
                if AppSettings.shared.autoplayEnabled {
                    player.play()
                    print("\n[Player] Auto-playing next item")
                }
            }
            
            // Set dismiss callback
            playerViewController.onDismiss = {
                print("\n[Player] Cleaning up player")
                player.pause()
                player.replaceCurrentItem(with: nil)
                dismiss()
            }
            
            rootViewController.present(playerViewController, animated: true) {
                print("\n[Player] Player presented, starting playback")
                player.play()
            }
        } else {
            print("\n[Error] Failed to present player controller")
        }
        
        print("\n==================== PLAYER SETUP END ====================")
    }
}

#Preview {
    EpisodeView(episodeId: "example-episode-id")
} 