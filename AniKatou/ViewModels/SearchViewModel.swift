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
    
    func loadPopularAnime() async {
        guard popularAnimes.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let results = try await APIService.shared.getPopularAnime()
            popularAnimes = filterNSFWContent(results)
        } catch let error as APIError {
            // Only show error if it's not a 404
            if case .serverError(404, _) = error {
                popularAnimes = []
            } else {
                errorMessage = error.message
            }
        } catch {
            errorMessage = "Failed to load popular anime: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
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
        
        isLoading = true
        errorMessage = nil
        
        do {
            let results = try await APIService.shared.searchAnime(query: query)
            guard !Task.isCancelled else { return }
            searchResults = filterNSFWContent(results)
        } catch let error as APIError {
            guard !Task.isCancelled else { return }
            
            // Only show error for non-404 errors and when query is too short
            switch error {
            case .searchQueryTooShort:
                errorMessage = error.message
            case .serverError(404, _):
                // For 404, just show empty results
                searchResults = []
            default:
                // For other errors, only show if the query is valid length
                if query.count >= 3 {
                    errorMessage = error.message
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            // Only show general errors if query is valid length
            if query.count >= 3 {
                errorMessage = "Failed to search: \(error.localizedDescription)"
            }
        }
        
        guard !Task.isCancelled else { return }
        isLoading = false
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