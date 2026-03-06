import SwiftUI

private struct EpisodeRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct AnimeDetailView: View {
    let animeId: String

    @StateObject private var viewModel = AnimeDetailViewModel()
    @StateObject private var downloadManager = HLSDownloadManager.shared
    @State private var isDescriptionExpanded = false
    @State private var isSelectingEpisodes = false
    @State private var selectedEpisodeIDs: Set<String> = []
    @State private var episodeRowFrames: [String: CGRect] = [:]

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
            ContentUnavailableView(
                "Anime Unavailable",
                systemImage: "wifi.slash",
                description: Text(error)
            )
            .padding(.top, 40)
        } else if let details = resolvedDetails {
            AnimeDetailHeroSection(
                details: details,
                isInLibrary: viewModel.isInLibrary,
                toggleLibrary: { viewModel.toggleLibrary() }
            )

            if let description = details.description {
                AnimeDescriptionCard(
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

            AnimeMetadataCard(details: details, totalEpisodes: viewModel.totalEpisodeCount)
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
                        episodeRowFrames = [:]
                    },
                    onToggleSelection: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSelectingEpisodes.toggle()
                            if !isSelectingEpisodes {
                                selectedEpisodeIDs.removeAll()
                                episodeRowFrames = [:]
                            }
                        }
                    }
                )
                .padding(.horizontal)

                Group {
                    if isSelectingEpisodes {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.currentEpisodes) { episode in
                                let downloadItem = downloadManager.downloads.first(where: { $0.episodeId == episode.id })
                                let isDownloaded = downloadManager.isEpisodeDownloaded(episode.id)
                                let isSelectableForDownload = isSelectable(isDownloaded: isDownloaded, item: downloadItem)

                                AnimeEpisodeSelectableRow(
                                    episode: episode,
                                    isSelected: selectedEpisodeIDs.contains(episode.id),
                                    isDownloaded: isDownloaded,
                                    downloadItem: downloadItem
                                )
                                .opacity(isSelectableForDownload ? 1 : 0.55)
                                .contentShape(Rectangle())
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.preference(
                                            key: EpisodeRowFramePreferenceKey.self,
                                            value: [episode.id: proxy.frame(in: .named("episodeSelectionList"))]
                                        )
                                    }
                                )
                                .onTapGesture {
                                    guard isSelectableForDownload else { return }
                                    toggleSelection(for: episode.id)
                                }
                            }
                        }
                        .coordinateSpace(name: "episodeSelectionList")
                        .onPreferenceChange(EpisodeRowFramePreferenceKey.self) { frames in
                            episodeRowFrames = frames
                        }
                        .simultaneousGesture(selectionDragGesture)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.currentEpisodes) { episode in
                                let downloadItem = downloadManager.downloads.first(where: { $0.episodeId == episode.id })
                                let isDownloaded = downloadManager.isEpisodeDownloaded(episode.id)
                                let anime = animeItem(from: details)

                                ZStack(alignment: .topTrailing) {
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
                                            downloadItem: downloadItem,
                                            reservesTrailingAccessorySpace: true
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
                                    .padding(.top, 16)
                                    .padding(.trailing, 16)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var selectionDragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 20, coordinateSpace: .named("episodeSelectionList")))
            .onChanged { value in
                switch value {
                case .second(true, let drag?):
                    selectEpisode(at: drag.location)
                default:
                    break
                }
            }
    }

    private func selectEpisode(at location: CGPoint) {
        guard let matchedID = episodeRowFrames.first(where: { $0.value.contains(location) })?.key,
              let episode = viewModel.currentEpisodes.first(where: { $0.id == matchedID }) else {
            return
        }

        let downloadItem = downloadManager.downloads.first(where: { $0.episodeId == episode.id })
        let isDownloaded = downloadManager.isEpisodeDownloaded(episode.id)
        guard isSelectable(isDownloaded: isDownloaded, item: downloadItem) else {
            return
        }

        selectedEpisodeIDs.insert(episode.id)
    }

    private func toggleSelection(for episodeID: String) {
        if selectedEpisodeIDs.contains(episodeID) {
            selectedEpisodeIDs.remove(episodeID)
        } else {
            selectedEpisodeIDs.insert(episodeID)
        }
    }

    private func isSelectable(isDownloaded: Bool, item: HLSDownloadItem?) -> Bool {
        !isDownloaded && item?.state != .queued && item?.state != .downloading
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
            case .queued:
                return "clock"
            case .downloading:
                return "hourglass"
            case .failed:
                return "arrow.clockwise"
            case .cancelled:
                return "arrow.down"
            case .completed:
                return "checkmark.circle.fill"
            }
        }
        return "arrow.down"
    }

    private func downloadButtonColor(isDownloaded: Bool, item: HLSDownloadItem?) -> Color {
        if isDownloaded { return .green }
        if let item, item.state == .failed { return .red }
        if let item, item.state == .queued { return .orange }
        return .accentColor
    }
}

