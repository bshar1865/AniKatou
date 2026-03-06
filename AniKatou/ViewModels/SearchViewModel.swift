import Foundation
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [AnimeItem] = []
    @Published var popularAnimes: [AnimeItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchHistory: [String] = []

    private let maxHistoryItems = 10

    init() {
        loadSearchHistory()
    }

    func loadPopularAnime() async {
        guard popularAnimes.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let results = try await APIService.shared.getPopularAnime()
            popularAnimes = filterNSFWContent(results)
        } catch let error as APIError {
            if case .serverError(404, _) = error {
                popularAnimes = []
            } else if case .networkError = error {
                errorMessage = UserMessage.noInternet
            } else {
                errorMessage = error.message
            }
        } catch {
            errorMessage = OfflineManager.shared.isOfflineMode ? UserMessage.noInternet : UserMessage.popularUnavailable
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

        isLoading = true
        errorMessage = nil

        do {
            let results = try await APIService.shared.searchAnime(query: query)
            guard !Task.isCancelled else { return }
            searchResults = filterNSFWContent(results)

            if !searchResults.isEmpty {
                addToSearchHistory(query)
            }
        } catch let error as APIError {
            guard !Task.isCancelled else { return }

            switch error {
            case .searchQueryTooShort:
                errorMessage = error.message
            case .serverError(404, _):
                searchResults = []
            default:
                if query.count >= 3 {
                    errorMessage = error.message
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            if query.count >= 3 {
                errorMessage = OfflineManager.shared.isOfflineMode ? UserMessage.noInternet : UserMessage.searchUnavailable
            }
        }

        guard !Task.isCancelled else { return }
        isLoading = false
    }

    private func loadSearchHistory() {
        if let data = UserDefaults.standard.data(forKey: "searchHistory"),
           let history = try? JSONDecoder().decode([String].self, from: data) {
            searchHistory = history
        }
    }

    private func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: "searchHistory")
        }
    }

    private func addToSearchHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        searchHistory.removeAll { $0.lowercased() == trimmedQuery.lowercased() }
        searchHistory.insert(trimmedQuery, at: 0)

        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }

        saveSearchHistory()
    }

    func removeFromSearchHistory(_ query: String) {
        searchHistory.removeAll { $0 == query }
        saveSearchHistory()
    }

    func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }

    func cleanupSearch() async {
        isLoading = false
    }

    func clearResults() async {
        isLoading = false
        searchResults = []
        errorMessage = nil
    }
}

