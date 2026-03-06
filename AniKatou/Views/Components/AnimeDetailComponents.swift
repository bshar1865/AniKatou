import SwiftUI

struct AnimeDetailHeroSection: View {
    let details: AnimeDetails
    let isInLibrary: Bool
    let toggleLibrary: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: details.image)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    LinearGradient(colors: [Color.gray.opacity(0.28), Color.gray.opacity(0.12)], startPoint: .top, endPoint: .bottom)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 290)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.05), Color.black.opacity(0.28), Color.black.opacity(0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                HStack(alignment: .bottom, spacing: 16) {
                    AsyncImage(url: URL(string: details.image)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.gray.opacity(0.25))
                    }
                    .frame(width: 136, height: 196)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 10)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(details.title)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                            .lineLimit(3)

                        if let jTitle = details.moreInfo?.japanese, !jTitle.isEmpty {
                            Text(jTitle)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.82))
                                .lineLimit(2)
                        }

                        HStack(spacing: 8) {
                            if let type = details.type {
                                AnimeDetailPill(text: type, icon: "film.stack")
                            }
                            if let status = details.status {
                                AnimeDetailPill(text: status, icon: "sparkle")
                            }
                            if let rating = details.rating {
                                AnimeDetailPill(text: rating, icon: "star.fill")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            HStack(spacing: 12) {
                Button(action: toggleLibrary) {
                    Label(isInLibrary ? "In Library" : "Add to Library", systemImage: isInLibrary ? "books.vertical.fill" : "books.vertical")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isInLibrary ? Color.green : Color.blue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }
}

struct AnimeDescriptionCard: View {
    let description: String
    let isExpanded: Bool
    let toggleExpanded: () -> Void

    private var shortDescription: String {
        guard description.count > 180 else { return description }
        return String(description.prefix(180)) + "..."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Description", systemImage: "text.alignleft")
                .font(.headline)

            Text(isExpanded ? description : shortDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)

            if description.count > 180 {
                Button(isExpanded ? "Show Less" : "Show More", action: toggleExpanded)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct AnimeMetadataCard: View {
    let details: AnimeDetails
    let totalEpisodes: Int

    private var formattedEpisodeText: String? {
        if let episodes = details.stats?.episodes {
            if let sub = episodes.sub, let dub = episodes.dub {
                return "Sub \(sub) / Dub \(dub)"
            }
            if let sub = episodes.sub {
                return "\(sub)"
            }
            if let dub = episodes.dub {
                return "Dub \(dub)"
            }
        }

        return totalEpisodes > 0 ? "\(totalEpisodes)" : nil
    }

    private var metadataItems: [(String, String)] {
        var items: [(String, String)] = []

        if let episodeText = formattedEpisodeText {
            items.append(("Episodes", episodeText))
        }
        if let genres = details.moreInfo?.genres, !genres.isEmpty {
            items.append(("Genres", genres.joined(separator: ", ")))
        }
        if let studios = details.moreInfo?.studios, !studios.isEmpty {
            items.append(("Studios", studios.joined(separator: ", ")))
        }
        if let aired = details.moreInfo?.aired, !aired.isEmpty {
            items.append(("Aired", aired))
        }
        if let duration = details.moreInfo?.duration ?? details.stats?.duration, !duration.isEmpty {
            items.append(("Duration", duration))
        }
        return items
    }

    var body: some View {
        if !metadataItems.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Label("Details", systemImage: "square.grid.2x2")
                    .font(.headline)

                VStack(spacing: 12) {
                    ForEach(Array(metadataItems.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 14) {
                            Text(item.0)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 68, alignment: .leading)

                            Text(item.1)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

struct AnimeEpisodeSectionHeader: View {
    let title: String
    let currentGroupTitle: String
    let showsGroupMenu: Bool
    let groups: [EpisodeGroup]
    let isSelecting: Bool
    let onSelectGroup: (Int) -> Void
    let onToggleSelection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.bold))

                Spacer()

                Button(isSelecting ? "Done" : "Select", action: onToggleSelection)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.accentColor)
            }

            if showsGroupMenu {
                Menu {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        Button(group.title) {
                            onSelectGroup(index)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.caption)
                        Text(currentGroupTitle)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
            }
        }
    }
}

struct AnimeEpisodeCard: View {
    let episode: EpisodeInfo
    let isDownloaded: Bool
    let downloadItem: HLSDownloadItem?
    let reservesTrailingAccessorySpace: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Episode \(episode.number)")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let isFiller = episode.isFiller, isFiller {
                        AnimeEpisodeBadge(text: "Filler", tint: .orange)
                    }
                }

                if let title = episode.title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    statusBadge
                }
            }
            .padding(.trailing, reservesTrailingAccessorySpace ? 48 : 0)

            if let item = downloadItem,
               item.state == .queued || item.state == .downloading {
                AnimeEpisodeProgressBar(progress: item.progress)
                    .frame(height: 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isDownloaded {
            AnimeEpisodeBadge(text: "Downloaded", tint: .green)
        } else if let item = downloadItem {
            AnimeEpisodeBadge(text: stateText(for: item), tint: stateColor(for: item))
        }
    }

    private func stateText(for item: HLSDownloadItem) -> String {
        switch item.state {
        case .queued:
            return "Queued"
        case .downloading:
            return "Downloading \(Int(item.progress * 100))%"
        case .completed:
            return "Downloaded"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }

    private func stateColor(for item: HLSDownloadItem) -> Color {
        switch item.state {
        case .completed:
            return .green
        case .failed:
            return .red
        case .queued, .downloading:
            return .blue
        case .cancelled:
            return .orange
        }
    }
}

struct AnimeEpisodeSelectableRow: View {
    let episode: EpisodeInfo
    let isSelected: Bool
    let isDownloaded: Bool
    let downloadItem: HLSDownloadItem?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isSelected ? .accentColor : .secondary)

            AnimeEpisodeCard(
                episode: episode,
                isDownloaded: isDownloaded,
                downloadItem: downloadItem,
                reservesTrailingAccessorySpace: false
            )
        }
    }
}

struct AnimeEpisodeDownloadButton: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(tint)
            .frame(width: 38, height: 38)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

struct AnimeEpisodeSelectionButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.headline)
                Text("Queue \(count)")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                Capsule()
                    .fill(count == 0 ? Color.gray : Color.blue)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
        }
        .disabled(count == 0)
    }
}

private struct AnimeDetailPill: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.14), in: Capsule())
    }
}

private struct AnimeEpisodeBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct AnimeEpisodeProgressBar: View {
    let progress: Double

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.blue.opacity(0.12))

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: proxy.size.width * clampedProgress)
            }
        }
    }
}

