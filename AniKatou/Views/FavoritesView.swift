import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel = LibraryCollectionViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Favourites")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text("\(viewModel.libraryItems.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(.tertiarySystemBackground)))
                }
                .padding(.horizontal)

                if viewModel.libraryItems.isEmpty {
                    ContentUnavailableView(
                        "No Favourites Yet",
                        systemImage: "heart",
                        description: Text("Open any anime and tap Add to Favourites")
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.libraryItems) { anime in
                            NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                AnimeCard(anime: anime)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 14)
        }
        .navigationTitle("Favourites")
    }
}

#Preview {
    FavoritesView()
}

