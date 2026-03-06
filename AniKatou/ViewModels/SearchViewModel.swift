import Foundation
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [AnimeItem] = []
    @Published var popularAnimes: [AnimeItem] = []
    @Published var availableGenres: [String] = ["All"]
    @Published var selectedGenre: String = "All"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchHistory: [String] = []

    private let maxHistoryItems = 10

    init() {
        loadSearchHistory()
    }

    func loadPopularAnime() async {
        if !popularAnimes.isEmpty && availableGenres.count > 1 {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let popularTask = APIService.shared.getPopularAnime()
            async let homeTask = APIService.shared.getHomePage()
            let popular = try await popularTask
            let home = try await homeTask
            popularAnimes = filterNSFWContent(popular)
            let safeGenres = home.genres.filter { genre in
                let lower = genre.lowercased()
                return !lower.contains("hentai") && !lower.contains("adult")
            }
            availableGenres = ["All"] + safeGenres.sorted()
        } catch let error as APIError {
            if case .serverError(404, _) = error {
                popularAnimes = []
            } else {
                errorMessage = error.message
            }
        } catch {
            errorMessage = OfflineManager.shared.isOfflineMode ? UserMessage.noInternet : UserMessage.popularUnavailable
        }

        if availableGenres.isEmpty {
            availableGenres = ["All"]
        }
        isLoading = false
    }

    private func filterNSFWContent(_ animes: [AnimeItem]) -> [AnimeItem] {
        animes.filter { !$0.containsNSFWContent }
    }

    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await clearResults()
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let results = try await APIService.shared.searchAnime(query: trimmed, genre: selectedGenre)
            guard !Task.isCancelled else { return }
            searchResults = filterNSFWContent(results)

            if !searchResults.isEmpty {
                addToSearchHistory(trimmed)
            }
        } catch let error as APIError {
            guard !Task.isCancelled else { return }

            switch error {
            case .searchQueryTooShort:
                errorMessage = error.message
            case .serverError(404, _):
                searchResults = []
            default:
                if trimmed.count >= 3 {
                    errorMessage = error.message
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            if trimmed.count >= 3 {
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
        guard !query.isEmpty else { return }

        searchHistory.removeAll { $0.lowercased() == query.lowercased() }
        searchHistory.insert(query, at: 0)

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
