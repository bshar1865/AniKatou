import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if searchText.isEmpty {
                    // Show popular anime when no search
                    if !viewModel.popularAnimes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Popular Anime")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 16) {
                                ForEach(viewModel.popularAnimes) { anime in
                                    NavigationLink(destination: AnimeDetailView(animeId: anime.id)) {
                                        AnimeCard(anime: anime)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    // Search Results
                    VStack(spacing: 16) {
                        if viewModel.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Searching...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                        } else if let error = viewModel.errorMessage {
                            if error == APIError.searchQueryTooShort.message {
                                // Show minimum character requirement
                                VStack(spacing: 12) {
                                    Image(systemName: "character.cursor.ibeam")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("Keep typing...")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("At least 3 characters needed")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            } else {
                                // Show error with retry button
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.red)
                                    Text(error)
                                        .foregroundColor(.red)
                                    Button("Retry") {
                                        handleSearchTextChange(searchText)
                                    }
                                    .foregroundColor(.blue)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            }
                        } else if viewModel.searchResults.isEmpty && searchText.count >= 3 {
                            // No results found (only show when query is valid)
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("No results found")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Try different keywords")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            // Search results grid
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
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            if !searchText.isEmpty {
                handleSearchTextChange(searchText)
            } else {
                await viewModel.loadPopularAnime()
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
        .task {
            await viewModel.loadPopularAnime()
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
        
        // Create new search task with shorter debounce
        searchTask = Task { @MainActor [weak viewModel] in
            guard let viewModel = viewModel else { return }
            
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds debounce
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
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
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