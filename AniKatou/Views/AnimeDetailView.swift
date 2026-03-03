import SwiftUI

struct AnimeDetailView: View {
    let animeId: String
    @StateObject private var viewModel = AnimeDetailViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDescriptionExpanded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView().padding()
                } else if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).padding()
                } else if let details = viewModel.animeDetails?.data.anime.info ?? viewModel.offlineAnimeDetails.map(offlineToDetails) {
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: details.image)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 160, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 8)

                        VStack(spacing: 12) {
                            Text(details.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal)

                            if let jTitle = details.moreInfo?.japanese {
                                Text(jTitle)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    if let type = details.type { InfoPill(text: type, icon: "film") }
                                    if let status = details.status { InfoPill(text: status, icon: "dot.radiowaves.left.and.right") }
                                    if let rating = details.rating { InfoPill(text: rating, icon: "star.fill") }
                                }
                                .padding(.horizontal)
                            }

                            Button(action: { viewModel.toggleLibrary() }) {
                                Label(viewModel.isInLibrary ? "In Library" : "Add to Library", systemImage: viewModel.isInLibrary ? "books.vertical.fill" : "books.vertical")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.gray)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical)
                    .background(
                        AsyncImage(url: URL(string: details.image)) { image in
                            image.resizable().aspectRatio(contentMode: .fill).blur(radius: 20).opacity(0.3)
                        } placeholder: {
                            Color.clear
                        }
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(colorScheme == .dark ? .black : .white),
                                    Color(colorScheme == .dark ? .black : .white).opacity(0.8),
                                    Color(colorScheme == .dark ? .black : .white).opacity(0.6)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    )

                    if let description = details.description {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                                .padding(.top, 16)

                            Text(isDescriptionExpanded ? description : getTruncatedDescription(description))
                                .font(.body)
                                .padding(.horizontal)

                            if shouldShowMoreButton(for: description) {
                                Button(isDescriptionExpanded ? "Show Less" : "Show More") {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isDescriptionExpanded.toggle()
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 8)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        if let genres = details.moreInfo?.genres, !genres.isEmpty { InfoRow(title: "Genres", content: genres.joined(separator: ", ")) }
                        if let studios = details.moreInfo?.studios, !studios.isEmpty { InfoRow(title: "Studios", content: studios.joined(separator: ", ")) }
                        if let aired = details.moreInfo?.aired { InfoRow(title: "Aired", content: aired) }
                        if let duration = details.moreInfo?.duration { InfoRow(title: "Duration", content: duration) }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if !viewModel.episodeGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Episodes")
                                    .font(.title3)
                                    .fontWeight(.bold)

                                if viewModel.episodeGroups.count > 1 {
                                    Spacer()
                                    Menu {
                                        ForEach(Array(viewModel.episodeGroups.enumerated()), id: \.element.id) { index, group in
                                            Button(group.title) { viewModel.selectGroup(index) }
                                        }
                                    } label: {
                                        HStack {
                                            Text(viewModel.episodeGroups[viewModel.selectedGroupIndex].title)
                                            Image(systemName: "chevron.up.chevron.down")
                                        }
                                        .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding(.horizontal)

                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.currentEpisodes) { episode in
                                    HStack(spacing: 12) {
                                        NavigationLink(destination: EpisodeView(
                                            episodeId: episode.id,
                                            animeId: animeId,
                                            animeTitle: details.name,
                                            episodeNumber: "\(episode.number)",
                                            episodeTitle: episode.title,
                                            thumbnailURL: nil
                                        )) {
                                            EpisodeRow(episode: episode)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            Task {
                                                await viewModel.downloadEpisode(animeId: animeId, animeTitle: details.name, episode: episode)
                                            }
                                        } label: {
                                            Image(systemName: "arrow.down.circle")
                                                .font(.title3)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.loadAnimeDetails(animeId: animeId)
        }
        .alert("Download", isPresented: Binding(
            get: { viewModel.downloadMessage != nil },
            set: { if !$0 { viewModel.downloadMessage = nil } }
        )) {
            Button("OK") { viewModel.downloadMessage = nil }
        } message: {
            Text(viewModel.downloadMessage ?? "")
        }
    }

    private func offlineToDetails(_ offline: OfflineAnimeDetails) -> AnimeDetails {
        AnimeDetails(
            id: offline.id,
            name: offline.title,
            poster: offline.image,
            description: offline.description,
            stats: AnimeStats(rating: offline.rating, quality: nil, type: offline.type, duration: nil, episodes: nil),
            moreInfo: AnimeMoreInfo(
                japanese: nil,
                aired: offline.releaseDate,
                premiered: nil,
                duration: nil,
                status: offline.status,
                malscore: nil,
                genres: offline.genres,
                studios: nil,
                producers: nil
            ),
            anilistId: nil
        )
    }

    private func getTruncatedDescription(_ description: String) -> String {
        let sentences = description.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if sentences.count <= 3 {
            return description
        }

        return sentences.prefix(3).joined(separator: ". ") + "."
    }

    private func shouldShowMoreButton(for description: String) -> Bool {
        let sentences = description.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return sentences.count > 3
    }
}

private struct InfoPill: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
    }
}

private struct InfoRow: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(content)
                .font(.body)
        }
    }
}

private struct EpisodeRow: View {
    let episode: EpisodeInfo

    var body: some View {
        HStack(spacing: 12) {
            Color.gray
                .overlay(
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                )
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Episode \(episode.number)\(episode.title.map { ": \($0)" } ?? "")")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let title = episode.title {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                if let isFiller = episode.isFiller, isFiller {
                    Text("Filler")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
