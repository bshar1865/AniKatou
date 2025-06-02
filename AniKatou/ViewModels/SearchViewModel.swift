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
    
    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            errorMessage = nil
            isLoading = false
            return
        }
        
        // Cancel any existing search
        searchTask?.cancel()
        
        searchTask = Task {
            do {
                isLoading = true
                errorMessage = nil
                
                // Debounce search
                try await Task.sleep(nanoseconds: debounceInterval)
                
                // Check if task was cancelled during sleep
                if Task.isCancelled { return }
                
                let results = try await APIService.shared.searchAnime(query: query)
                
                // Check if task was cancelled after API call
                if Task.isCancelled { return }
                
                searchResults = results
                hasNextPage = !results.isEmpty
            } catch let error as APIError {
                if !Task.isCancelled {
                    errorMessage = error.message
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = "Failed to search: \(error.localizedDescription)"
                }
            }
            
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }
    
    func loadNextPage(query: String) async {
        guard hasNextPage, !isLoading else { return }
        await search(query: query)
    }
    
    deinit {
        searchTask?.cancel()
    }
} 