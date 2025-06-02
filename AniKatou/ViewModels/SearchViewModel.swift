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
    
    func search(query: String) async {
        // Cancel any existing search task
        searchTask?.cancel()
        
        // Clear results if query is empty
        guard !query.isEmpty else {
            searchResults = []
            isLoading = false
            return
        }
        
        // Don't search if query is too short
        guard query.count >= 3 else {
            return
        }
        
        // Create a new search task with debounce
        searchTask = Task {
            do {
                isLoading = true
                errorMessage = nil
                
                // Debounce for 0.8 seconds
                try await Task.sleep(nanoseconds: 800_000_000)
                
                // Check if task was cancelled during sleep
                if Task.isCancelled { return }
                
                let results = try await APIService.shared.searchAnime(query: query)
                
                // Check if task was cancelled after API call
                if Task.isCancelled { return }
                
                searchResults = results
            } catch let error as APIError {
                if !Task.isCancelled {
                    errorMessage = error.message
                    print("API Error: \(error.message)")
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = "Failed to search: \(error.localizedDescription)"
                    print("Search error: \(error)")
                }
            }
            
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }
    
    func loadNextPage(query: String) async {
        guard hasNextPage else { return }
        await search(query: query)
    }
    
    deinit {
        searchTask?.cancel()
    }
} 