import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                        
                        Button("Retry") {
                            handleSearchTextChange(searchText)
                        }
                        .foregroundColor(.blue)
                    }
                } else if viewModel.searchResults.isEmpty && !searchText.isEmpty && !viewModel.isLoading {
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
        .refreshable {
            if !searchText.isEmpty {
                handleSearchTextChange(searchText)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $searchText, prompt: "Search anime...")
        .onChange(of: searchText) { newValue in
            handleSearchTextChange(newValue)
        }
        .onDisappear {
            cancelCurrentSearch()
        }
    }
    
    private func cancelCurrentSearch() {
        searchTask?.cancel()
        searchTask = nil
        
        Task { @MainActor [weak viewModel] in
            await viewModel?.cleanupSearch()
        }
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        // Cancel previous search task
        searchTask?.cancel()
        searchTask = nil
        
        guard !newValue.isEmpty else {
            Task { @MainActor [weak viewModel] in
                await viewModel?.clearResults()
            }
            return
        }
        
        // Create new search task with debounce
        searchTask = Task { @MainActor [weak viewModel] in
            guard let viewModel = viewModel else { return }
            
            do {
                try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds debounce
                if !Task.isCancelled {
                    await viewModel.search(query: newValue)
                }
            } catch {
                #if DEBUG
                print("Search task cancelled")
                #endif
            }
        }
    }
}

struct AnimeCard: View {
    let anime: AnimeItem
    
    var body: some View {
        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: anime.image)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .foregroundColor(Color.gray.opacity(0.3))
                            .frame(width: 70, height: 100)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 100)
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .frame(width: 70, height: 100)
                    @unknown default:
                        EmptyView()
                    }
                }
                .cornerRadius(8)
                .shadow(radius: 2)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(anime.title)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.vertical, 4)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .padding(.trailing, 4)
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