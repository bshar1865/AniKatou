import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        ScrollView {
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
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(viewModel.searchResults) { anime in
                        NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                            AnimeCard(anime: anime)
                        }
                    }
                }
                .padding()
            }
        }
        .refreshable {
            if !searchText.isEmpty {
                handleSearchTextChange(searchText)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $searchText, prompt: "Search anime...")
        .onChange(of: searchText) { oldValue, newValue in
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
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: anime.image)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(anime.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            if let type = anime.type {
                Text(type)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationView {
        SearchView()
    }
} 