import SwiftUI

struct CollectionsDetailView: View {
    let viewModel: LibraryCollectionViewModel
    @State private var isGridView = true
    @State private var showingRemoveAlert = false
    @State private var itemToRemove: AnimeItem?

    private static let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("Library")
                        .font(.title)
                        .fontWeight(.bold)

                    Spacer()

                    Button(action: { withAnimation { isGridView.toggle() } }) {
                        Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)

                if viewModel.libraryItems.isEmpty {
                    ContentUnavailableView(
                        "Library Is Empty",
                        systemImage: "books.vertical",
                        description: Text("Anime you save will appear here")
                    )
                } else if isGridView {
                    LazyVGrid(columns: Self.gridColumns, spacing: 20) {
                        ForEach(viewModel.libraryItems) { anime in
                            NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                AnimeCard(anime: anime, width: 160)
                            }
                            .contextMenu {
                                Button("Remove from Library", role: .destructive) {
                                    itemToRemove = anime
                                    showingRemoveAlert = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.libraryItems) { anime in
                            NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                row(anime)
                            }
                            .contextMenu {
                                Button("Remove from Library", role: .destructive) {
                                    itemToRemove = anime
                                    showingRemoveAlert = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Library")
        .alert("Remove From Library", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let anime = itemToRemove {
                    LibraryManager.shared.remove(anime)
                }
                itemToRemove = nil
            }
        } message: {
            Text("This anime will be removed from your library.")
        }
    }

    private func row(_ anime: AnimeItem) -> some View {
        HStack(spacing: 16) {
            CachedAsyncImage(url: URL(string: anime.image)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.overlay(ProgressView())
            }
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Text(anime.title)
                    .font(.headline)
                    .lineLimit(2)

                if let type = anime.type {
                    Text(type)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Saved to Library")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
