import SwiftUI

struct EpisodeView: View {
    let episodeId: String
    let animeId: String
    let animeTitle: String
    let episodeNumber: String
    let episodeTitle: String?
    let thumbnailURL: String?

    @StateObject private var viewModel = EpisodeViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showPlayer = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.edgesIgnoringSafeArea(.all)
            content

            if let notice = viewModel.playbackNotice {
                playbackNoticeBanner(notice)
                    .padding(.top, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.loadStreamingSources(episodeId: episodeId)
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let localURL = viewModel.localPlaybackURL {
                CustomVideoPlayerView(
                    videoURL: localURL,
                    headers: nil,
                    subtitleTracks: viewModel.localSubtitleTracks,
                    intro: viewModel.localIntro,
                    outro: viewModel.localOutro,
                    animeId: animeId,
                    episodeId: episodeId,
                    animeTitle: animeTitle,
                    episodeNumber: episodeNumber,
                    episodeTitle: episodeTitle,
                    thumbnailURL: thumbnailURL,
                    onDismiss: {
                        dismiss()
                    }
                )
            } else if let streamingData = viewModel.streamingData?.data,
                      let sourceURL = preferredStreamingURL(from: streamingData) {
                CustomVideoPlayerView(
                    videoURL: sourceURL,
                    headers: streamingData.headers,
                    subtitleTracks: streamingData.tracks,
                    intro: streamingData.intro,
                    outro: streamingData.outro,
                    animeId: animeId,
                    episodeId: episodeId,
                    animeTitle: animeTitle,
                    episodeNumber: episodeNumber,
                    episodeTitle: episodeTitle,
                    thumbnailURL: thumbnailURL,
                    onDismiss: {
                        dismiss()
                    }
                )
            }
        }
        .onChange(of: viewModel.streamingData) { _, newValue in
            if newValue?.data.sources.isEmpty == false {
                showPlayer = true
            }
        }
        .onChange(of: viewModel.localPlaybackURL) { _, newValue in
            if newValue != nil {
                showPlayer = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Preparing playback...")
                .foregroundColor(.white)
        } else if let error = viewModel.errorMessage {
            VStack {
                Spacer()

            VStack(spacing: 16) {
                Text(error)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Button("Retry") {
                    Task {
                        await viewModel.loadStreamingSources(episodeId: episodeId)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func preferredStreamingURL(from streamingData: StreamingData) -> URL? {
        let preferredQuality = AppSettings.shared.preferredQuality.replacingOccurrences(of: "p", with: "")
        let preferredValue = Int(preferredQuality) ?? 1080

        let source = streamingData.sources.first { source in
            source.quality?.lowercased() == AppSettings.shared.preferredQuality.lowercased()
        } ?? streamingData.sources.sorted { lhs, rhs in
            let leftValue = Int((lhs.quality ?? "0").replacingOccurrences(of: "p", with: "")) ?? 0
            let rightValue = Int((rhs.quality ?? "0").replacingOccurrences(of: "p", with: "")) ?? 0
            return abs(leftValue - preferredValue) < abs(rightValue - preferredValue)
        }.first ?? streamingData.sources.first

        guard let urlString = source?.url else { return nil }
        return URL(string: urlString)
    }

    private func playbackNoticeBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.9), in: Capsule())
    }
}
