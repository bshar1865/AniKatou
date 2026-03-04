import SwiftUI

struct AnimeDetailView: View {
    let animeId: String
    @StateObject private var viewModel = AnimeDetailViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDescriptionExpanded = false
    @State private var isSelectingEpisodes = false
    @State private var selectedEpisodeIDs: Set<String> = []

    private var resolvedDetails: AnimeDetails? {
        viewModel.animeDetails?.data.anime.info ?? viewModel.offlineAnimeDetails.map(offlineToDetails)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView().padding()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if let details = resolvedDetails {
                    headerSection(details)
                    descriptionSection(details)
                    metadataSection(details)
                    episodesSection(details)
                }
            }
            .padding(.bottom, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.loadAnimeDetails(animeId: animeId)
        }
        .onAppear {
            viewModel.refreshLibraryState()
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

    @ViewBuilder
    private func headerSection(_ details: AnimeDetails) -> some View {
        VStack(spacing: 14) {
            AsyncImage(url: URL(string: details.image)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(width: 170, height: 245)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 8)

            Text(details.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if let jTitle = details.moreInfo?.japanese {
                Text(jTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let type = details.type { InfoPill(text: type, icon: "film") }
                    if let status = details.status { InfoPill(text: status, icon: "dot.radiowaves.left.and.right") }
                    if let rating = details.rating { InfoPill(text: rating, icon: "star.fill") }
                }
                .padding(.horizontal, 16)
            }

            Button(action: { viewModel.toggleLibrary() }) {
                Label(
                    viewModel.isInLibrary ? "In Library" : "Add to Library",
                    systemImage: viewModel.isInLibrary ? "books.vertical.fill" : "books.vertical"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(viewModel.isInLibrary ? Color.green : Color.blue)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                AsyncImage(url: URL(string: details.image)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
                .blur(radius: 20)
                .opacity(0.24)

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(colorScheme == .dark ? .black : .white),
                        Color(colorScheme == .dark ? .black : .white).opacity(0.88),
                        Color(colorScheme == .dark ? .black : .white).opacity(0.62)
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            }
        )
    }

    @ViewBuilder
    private func descriptionSection(_ details: AnimeDetails) -> some View {
        if let description = details.description {
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)

                Text(isDescriptionExpanded ? normalizedDescription(description) : truncatedDescription(description))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if shouldShowMoreButton(for: description) {
                    Button(isDescriptionExpanded ? "Show Less" : "Show More") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDescriptionExpanded.toggle()
                        }
                    }
                    .font(.subheadline)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func metadataSection(_ details: AnimeDetails) -> some View {
        let genres = details.moreInfo?.genres ?? []
        let studios = details.moreInfo?.studios ?? []
        let aired = details.moreInfo?.aired
        let duration = details.moreInfo?.duration

        if !genres.isEmpty || !studios.isEmpty || aired != nil || duration != nil {
            VStack(alignment: .leading, spacing: 10) {
                if !genres.isEmpty {
                    InfoRow(title: "Genres", content: genres.joined(separator: ", "))
                }
                if !studios.isEmpty {
                    InfoRow(title: "Studios", content: studios.joined(separator: ", "))
                }
                if let aired {
                    InfoRow(title: "Aired", content: aired)
                }
                if let duration {
                    InfoRow(title: "Duration", content: duration)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func episodesSection(_ details: AnimeDetails) -> some View {
        if !viewModel.episodeGroups.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Episodes")
                        .font(.headline)

                    Spacer()

                    if viewModel.episodeGroups.count > 1 {
                        Menu {
                            ForEach(Array(viewModel.episodeGroups.enumerated()), id: \.element.id) { index, group in
                                Button(group.title) { viewModel.selectGroup(index) }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.episodeGroups[viewModel.selectedGroupIndex].title)
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .font(.subheadline)
                        }
                    }

                    Button(isSelectingEpisodes ? "Done" : "Select") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSelectingEpisodes.toggle()
                            if !isSelectingEpisodes {
                                selectedEpisodeIDs.removeAll()
                            }
                        }
                    }
                    .font(.subheadline)

                    if isSelectingEpisodes {
                        Button("Download \(selectedEpisodeIDs.count)") {
                            let selectedEpisodes = viewModel.currentEpisodes.filter { selectedEpisodeIDs.contains($0.id) }
                            let anime = animeItem(from: details)
                            Task {
                                await viewModel.downloadSelectedEpisodes(
                                    anime: anime,
                                    episodesToCache: viewModel.currentEpisodes,
                                    selectedEpisodes: selectedEpisodes
                                )
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .disabled(selectedEpisodeIDs.isEmpty)
                    }
                }
                .padding(.horizontal)

                LazyVStack(spacing: 10) {
                    ForEach(viewModel.currentEpisodes) { episode in
                        let downloaded = HLSDownloadManager.shared.isEpisodeDownloaded(episode.id)
                        let anime = animeItem(from: details)

                        HStack(spacing: 10) {
                            if isSelectingEpisodes {
                                Button {
                                    if selectedEpisodeIDs.contains(episode.id) {
                                        selectedEpisodeIDs.remove(episode.id)
                                    } else {
                                        selectedEpisodeIDs.insert(episode.id)
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: selectedEpisodeIDs.contains(episode.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedEpisodeIDs.contains(episode.id) ? .blue : .secondary)
                                        EpisodeRow(episode: episode, isDownloaded: downloaded)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink(destination: EpisodeView(
                                    episodeId: episode.id,
                                    animeId: animeId,
                                    animeTitle: details.name,
                                    episodeNumber: "\(episode.number)",
                                    episodeTitle: episode.title,
                                    thumbnailURL: nil
                                )) {
                                    EpisodeRow(episode: episode, isDownloaded: downloaded)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                Task {
                                    await viewModel.downloadEpisode(anime: anime, episodesToCache: viewModel.currentEpisodes, episode: episode)
                                }
                            } label: {
                                Image(systemName: downloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                                    .font(.title3)
                                    .foregroundColor(downloaded ? .green : .primary)
                            }
                            .disabled(downloaded)
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
            }
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

    private func animeItem(from details: AnimeDetails) -> AnimeItem {
        AnimeItem(
            id: details.id,
            name: details.name,
            jname: details.moreInfo?.japanese,
            poster: details.poster,
            duration: details.stats?.duration,
            type: details.type,
            rating: details.stats?.rating,
            episodes: details.stats?.episodes,
            isNSFW: false,
            genres: details.moreInfo?.genres,
            anilistId: details.anilistId
        )
    }

    private func normalizedDescription(_ description: String) -> String {
        description
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func truncatedDescription(_ description: String) -> String {
        let normalized = normalizedDescription(description)
        if normalized.count <= 140 {
            return normalized
        }
        return String(normalized.prefix(140)) + "..."
    }

    private func shouldShowMoreButton(for description: String) -> Bool {
        normalizedDescription(description).count > 140
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
            .background(Color.gray.opacity(0.16))
            .cornerRadius(12)
    }
}

private struct InfoRow: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(content)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

private struct EpisodeRow: View {
    let episode: EpisodeInfo
    let isDownloaded: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Episode \(episode.number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let title = episode.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if let isFiller = episode.isFiller, isFiller {
                        Text("Filler")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(5)
                    }
                    if isDownloaded {
                        Text("Downloaded")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
