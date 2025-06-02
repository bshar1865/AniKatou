import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                        Text("No results found")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(viewModel.searchResults) { anime in
                            AnimeCard(anime: anime)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search anime...")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await viewModel.search(query: newValue)
                }
            }
        }
    }
}

struct AnimeCard: View {
    let anime: AnimeItem
    
    var body: some View {
        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: anime.image)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
                .frame(width: 80, height: 120)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(anime.title)
                        .font(.headline)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
}

#Preview {
    NavigationView {
        SearchView()
    }
} 