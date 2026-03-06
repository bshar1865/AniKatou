import SwiftUI

struct AnimeDetailView: View {
    let animeId: String

    @StateObject private var viewModel = AnimeDetailViewModel()
    @StateObject private var downloadManager = HLSDownloadManager.shared
    @State private var isDescriptionExpanded = false
    @State private var isSelectingEpisodes = false
    @State private var selectedEpisodeIDs: Set<String> = []

    private var resolvedDetails: AnimeDetails? {
        viewModel.animeDetails?.data.anime.info ?? viewModel.offlineAnimeDetails.map(offlineToDetails)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 18) {
                    content
                }
                .padding(.top, 12)
                .padding(.bottom, isSelectingEpisodes ? 94 : 24)
            }
            .background(Color(.systemGroupedBackground))

            if isSelectingEpisodes, let details = resolvedDetails {
                AnimeEpisodeSelectionButton(count: selectedEpisodeIDs.count) {
                    let selectedIDsInCurrentGroup = Set(viewModel.currentEpisodes.map(\.id))
                    selectedEpisodeIDs = selectedEpisodeIDs.intersection(selectedIDsInCurrentGroup)
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
                .padding(.trailing, 18)
                .padding(.bottom, 16)
            }
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
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .padding(.top, 40)
        } else if let error = viewModel.errorMessage {
            Text(error)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()
        } else if let details = resolvedDetails {
            AnimeDetailHeroSection(
                details: details,
                isInLibrary: viewModel.isInLibrary,
                isOfflineMode: viewModel.isOfflineMode,
                toggleLibrary: { viewModel.toggleLibrary() }
            )

            if let description = details.description {
                AnimeSynopsisCard(
                    description: normalizedDescription(description),
                    isExpanded: isDescriptionExpanded,
                    toggleExpanded: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDescriptionExpanded.toggle()
                        }
                    }
                )
                .padding(.horizontal)
            }

            AnimeMetadataCard(details: details)
                .padding(.horizontal)

            episodesSection(details)
        }
    }

    @ViewBuilder
    private func episodesSection(_ details: AnimeDetails) -> some View {
        if !viewModel.episodeGroups.isEmpty {
            VStack(spacing: 12) {
                AnimeEpisodeSectionHeader(
                    title: "Episodes",
                    currentGroupTitle: viewModel.episodeGroups[viewModel.selectedGroupIndex].title,
                    showsGroupMenu: viewModel.episodeGroups.count > 1,
                    groups: viewModel.episodeGroups,
                    isSelecting: isSelectingEpisodes,
                    onSelectGroup: { index in
                        viewModel.selectGroup(index)
                        selectedEpisodeIDs.removeAll()
                    },
                    onToggleSelection: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSelectingEpisodes.toggle()
                            if !isSelectingEpisodes {
                                selectedEpisodeIDs.removeAll()
                            }
                        }
                    }
                )
                .padding(.horizontal)

                LazyVStack(spacing: 12) {
                    ForEach(viewModel.currentEpisodes) { episode in
                        let downloadItem = downloadManager.downloads.first(where: { $0.episodeId == episode.id })
                        let isDownloaded = downloadManager.isEpisodeDownloaded(episode.id)
                        let anime = animeItem(from: details)

                        if isSelectingEpisodes {
                            Button {
                                if selectedEpisodeIDs.contains(episode.id) {
                                    selectedEpisodeIDs.remove(episode.id)
                                } else {
                                    selectedEpisodeIDs.insert(episode.id)
                                }
                            } label: {
                                AnimeEpisodeSelectableRow(
                                    episode: episode,
                                    isSelected: selectedEpisodeIDs.contains(episode.id),
                                    isDownloaded: isDownloaded,
                                    downloadItem: downloadItem
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            HStack(spacing: 10) {
                                NavigationLink(destination: EpisodeView(
                                    episodeId: episode.id,
                                    animeId: animeId,
                                    animeTitle: details.name,
                                    episodeNumber: "\(episode.number)",
                                    episodeTitle: episode.title,
                                    thumbnailURL: nil
                                )) {
                                    AnimeEpisodeCard(
                                        episode: episode,
                                        isDownloaded: isDownloaded,
                                        downloadItem: downloadItem
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task {
                                        await viewModel.downloadEpisode(anime: anime, episodesToCache: viewModel.currentEpisodes, episode: episode)
                                    }
                                } label: {
                                    AnimeEpisodeDownloadButton(
                                        symbol: downloadButtonSymbol(isDownloaded: isDownloaded, item: downloadItem),
                                        tint: downloadButtonColor(isDownloaded: isDownloaded, item: downloadItem)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isDownloadButtonDisabled(isDownloaded: isDownloaded, item: downloadItem))
                            }
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

    private func isDownloadButtonDisabled(isDownloaded: Bool, item: HLSDownloadItem?) -> Bool {
        isDownloaded || item?.state == .queued || item?.state == .downloading
    }

    private func downloadButtonSymbol(isDownloaded: Bool, item: HLSDownloadItem?) -> String {
        if isDownloaded { return "checkmark.circle.fill" }
        if let item {
            switch item.state {
            case .queued, .downloading:
                return "hourglass"
            case .failed:
                return "arrow.clockwise.circle"
            case .cancelled:
                return "arrow.down.circle"
            case .completed:
                return "checkmark.circle.fill"
            }
        }
        return "arrow.down.circle"
    }

    private func downloadButtonColor(isDownloaded: Bool, item: HLSDownloadItem?) -> Color {
        if isDownloaded { return .green }
        if let item, item.state == .failed { return .red }
        return .accentColor
    }
}
