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
        ZStack {
            Color.black.edgesIgnoringSafeArea(Edge.Set.all)
            content
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.loadStreamingSources(episodeId: episodeId)
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let streamingData = viewModel.streamingData?.data {
                if AppSettings.shared.useCustomPlayer,
                   let bestSource = streamingData.sources.first, // You can improve this to use preferred quality
                   let url = URL(string: bestSource.url) {
                    CustomVideoPlayerView(
                        videoURL: url,
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
                } else {
                    VideoPlayerView(
                        streamingData: streamingData,
                        animeId: animeId,
                        episodeId: episodeId,
                        animeTitle: animeTitle,
                        episodeNumber: episodeNumber,
                        episodeTitle: episodeTitle,
                        thumbnailURL: thumbnailURL
                    ) {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: viewModel.streamingData) { _, newValue in
            if newValue?.data != nil {
                showPlayer = true
            }
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
        }
    }
} 