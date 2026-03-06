import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel = LibraryCollectionViewModel()
    @StateObject private var downloadManager = HLSDownloadManager.shared

    private var activeDownloads: Int {
        downloadManager.downloads.filter { $0.state == .queued || $0.state == .downloading }.count
    }

    private var completedDownloads: Int {
        downloadManager.downloads.filter { $0.state == .completed }.count
    }

    private var libraryOfflineCount: Int {
        viewModel.libraryItems.reduce(0) { partialResult, anime in
            partialResult + downloadManager.downloadedEpisodeCount(for: anime.id)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                downloadsCard
                librarySection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .navigationTitle("Library")
    }

    private var downloadsCard: some View {
        NavigationLink(destination: DownloadView()) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 42, height: 42)

                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Downloads")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Offline queue and saved episodes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    libraryStatChip(title: "Active", value: "\(activeDownloads)", tint: .blue)
                    libraryStatChip(title: "Completed", value: "\(completedDownloads)", tint: .green)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "My Library", symbol: "books.vertical")
                Spacer()
                NavigationLink("See All") {
                    CollectionsDetailView(viewModel: viewModel)
                }
                .font(.subheadline)
            }

            if viewModel.libraryItems.isEmpty {
                ContentUnavailableView(
                    "Library Is Empty",
                    systemImage: "books.vertical",
                    description: Text("Open any anime and tap Add to Library")
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            } else {
                if libraryOfflineCount == 0 {
                    offlineTipCard
                }

                LazyVStack(spacing: 10) {
                    ForEach(viewModel.libraryItems.prefix(12)) { anime in
                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                            LibraryRowCard(anime: anime, offlineEpisodeCount: downloadManager.downloadedEpisodeCount(for: anime.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var offlineTipCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No Offline Episodes Yet", systemImage: "wifi.slash")
                .font(.headline)
                .foregroundColor(.orange)

            Text("Your library is saved, but no episodes are available offline yet. Download episodes from anime details if you want them to work without internet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
    }

    private func sectionHeader(title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.blue)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
        }
    }

    private func libraryStatChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint.opacity(0.9))
                .frame(width: 7, height: 7)
            Text(title)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

private struct LibraryRowCard: View {
    let anime: AnimeItem
    let offlineEpisodeCount: Int

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: URL(string: anime.image), maxPixelSize: 500) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.overlay(ProgressView())
            }
            .frame(width: 72, height: 102)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(anime.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if offlineEpisodeCount > 0 {
                        Label("Offline \(offlineEpisodeCount)", systemImage: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if let type = anime.type, !type.isEmpty {
                        Text(type)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let rating = anime.rating, !rating.isEmpty {
                        Label(rating, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

