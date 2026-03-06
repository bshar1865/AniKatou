import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if searchText.isEmpty {
                    searchHomeContent
                } else {
                    searchResultsContent
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
        .onChange(of: searchText) { _, newValue in
            handleSearchTextChange(newValue)
        }
        .onDisappear {
            cancelCurrentSearch()
        }
        .task {
            await viewModel.loadPopularAnime()
        }
    }

    @ViewBuilder
    private var searchHomeContent: some View {
        if !viewModel.searchHistory.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Searches")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button("Clear") {
                        viewModel.clearSearchHistory()
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)

                VStack(spacing: 8) {
                    ForEach(viewModel.searchHistory, id: \.self) { query in
                        HStack {
                            Button {
                                searchText = query
                                handleSearchTextChange(query)
                            } label: {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.secondary)
                                    Text(query)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }

                            Button {
                                viewModel.removeFromSearchHistory(query)
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            Divider()
                .padding(.vertical)
        }

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
        } else if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 220)
        }
    }

    @ViewBuilder
    private var searchResultsContent: some View {
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
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            handleSearchTextChange(searchText)
                        }
                        .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
            } else if viewModel.searchResults.isEmpty && searchText.count >= 3 {
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

    private func cancelCurrentSearch() {
        searchTask?.cancel()
        searchTask = nil

        Task { @MainActor [weak viewModel] in
            await viewModel?.cleanupSearch()
        }
    }

    private func handleSearchTextChange(_ newValue: String) {
        searchTask?.cancel()
        searchTask = nil

        guard !newValue.isEmpty else {
            Task { @MainActor [weak viewModel] in
                await viewModel?.clearResults()
            }
            return
        }

        searchTask = Task { @MainActor [weak viewModel] in
            guard let viewModel = viewModel else { return }

            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                if !Task.isCancelled {
                    await viewModel.search(query: newValue)
                }
            } catch {
            }
        }
    }
}
