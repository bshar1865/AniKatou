import Foundation
import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [AnimeItem] = []
    @Published var popularAnimes: [AnimeItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var hasNextPage = false
    @Published var totalPages = 1
    
    private var searchTask: Task<Void, Never>?
    private let debounceInterval: UInt64 = 800_000_000 // 0.8 seconds
    
    private func filterNSFWContent(_ animes: [AnimeItem]) -> [AnimeItem] {
        animes.filter { !$0.containsNSFWContent }
    }
    
    func search(query: String) async {
        guard !query.isEmpty else {
            await clearResults()
            return
        }
        
        // Cancel any previous search task
        await cleanupSearch()
        
        // Create new search task
        let task = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            self.isLoading = true
            self.errorMessage = nil
            
            do {
                let results = try await APIService.shared.searchAnime(query: query)
                
                guard !Task.isCancelled else { return }
                self.searchResults = filterNSFWContent(results)
            } catch let error as APIError {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.message
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = "Failed to search: \(error.localizedDescription)"
            }
            
            guard !Task.isCancelled else { return }
            self.isLoading = false
        }
        
        searchTask = task
    }
    
    func loadNextPage(query: String) async {
        guard hasNextPage, !isLoading else { return }
        await search(query: query)
    }
    
    // Made public for access from SearchView
    func cleanupSearch() async {
        searchTask?.cancel()
        searchTask = nil
        await MainActor.run {
            isLoading = false
        }
    }
    
    func clearResults() async {
        await cleanupSearch()
        await MainActor.run {
            searchResults = []
            errorMessage = nil
        }
    }
    
    deinit {
        // Since we can't use async in deinit, we'll create a task
        // that will be automatically cancelled if needed
        Task { @MainActor [weak self] in
            await self?.cleanupSearch()
        }
    }
} 