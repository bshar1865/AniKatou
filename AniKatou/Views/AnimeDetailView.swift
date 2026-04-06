import SwiftUI

private enum DetailTab {
    case description
    case episodes
}

struct AnimeDetailView: View {
    let animeId: String

    @StateObject private var viewModel = AnimeDetailViewModel()
    @StateObject private var downloadManager = HLSDownloadManager.shared
    @State private var isDescriptionExpanded = false
    @State private var selectedTab: DetailTab = .description
    @State private var pendingDownloadedEpisodeRemoval: HLSDownloadItem?

    private var resolvedDetails: AnimeDetails? {
        viewModel.animeDetails?.data.anime.info ?? viewModel.offlineAnimeDetails.map(offlineToDetails)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                content
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
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
        .alert("Remove Downloaded Episode", isPresented: Binding(
            get: { pendingDownloadedEpisodeRemoval != nil },
            set: { if !$0 { pendingDownloadedEpisodeRemoval = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let item = pendingDownloadedEpisodeRemoval {
                    downloadManager.removeDownload(item)
                }
                pendingDownloadedEpisodeRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDownloadedEpisodeRemoval = nil
            }
        } message: {
            Text("Remove this downloaded episode from your device?")
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

            AnimeDetailSegmentedControl(selectedTab: $selectedTab)
                .padding(.horizontal)

            if selectedTab == .description {
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

                AnimeMetadataCard(
                    details: details,
                    totalEpisodes: viewModel.totalEpisodeCount,
                    nextEpisodeText: formattedNextEpisodeText
                )
                .padding(.horizontal)
            } else {
                episodesSection(details)
            }
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
                    onSelectGroup: { index in
                        viewModel.selectGroup(index)
                    },
                    onDownloadAll: {
                        let anime = animeItem(from: details)
                        Task {
                            await viewModel.downloadSelectedEpisodes(
                                anime: anime,
                                episodesToCache: viewModel.currentEpisodes,
                                selectedEpisodes: viewModel.currentEpisodes
                            )
                        }
                    }
                )
                .padding(.horizontal)

                LazyVStack(spacing: 12) {
                    ForEach(viewModel.currentEpisodes) { episode in
                        let downloadItem = downloadManager.downloads.first(where: { $0.episodeId == episode.id })
                        let isDownloaded = downloadManager.isEpisodeDownloaded(episode.id)
                        let completedDownload = downloadManager.downloadedItem(for: episode.id)

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
                                reservesTrailingAccessorySpace: false
                            )
                        }
                        .buttonStyle(.plain)
                        .onLongPressGesture {
                            guard let completedDownload else { return }
                            pendingDownloadedEpisodeRemoval = completedDownload
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var formattedNextEpisodeText: String? {
        guard let schedule = viewModel.nextEpisodeSchedule else { return nil }
        if let seconds = schedule.secondsUntilAiring, seconds > 0 {
            let days = seconds / 86400
            if days > 0 {
                return "In \(days) day\(days == 1 ? "" : "s")"
            }
            let hours = max(1, seconds / 3600)
            return "In \(hours) hour\(hours == 1 ? "" : "s")"
        }
        if let iso = schedule.airingISOTimestamp, let date = ISO8601DateFormatter().date(from: iso) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return nil
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
}

private struct AnimeDetailSegmentedControl: View {
    @Binding var selectedTab: DetailTab

    var body: some View {
        HStack(spacing: 26) {
            segmentButton(title: "Description", tab: .description)
            segmentButton(title: "Episodes", tab: .episodes)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        
    }

    private func segmentButton(title: String, tab: DetailTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline.weight(selectedTab == tab ? .semibold : .regular))
                    .foregroundColor(selectedTab == tab ? .primary : .secondary)

                Capsule()
                    .fill(selectedTab == tab ? Color.blue : Color.clear)
                    .frame(height: 4)
                    .frame(maxWidth: 54)
            }
        }
        .buttonStyle(.plain)
    }
}

