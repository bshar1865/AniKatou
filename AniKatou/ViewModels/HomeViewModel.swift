import Foundation
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    @Published var trendingAnimes: [AnimeItem] = []
    @Published var latestEpisodeAnimes: [AnimeItem] = []
    @Published var topUpcomingAnimes: [AnimeItem] = []
    @Published var topAiringAnimes: [AnimeItem] = []
    @Published var mostPopularAnimes: [AnimeItem] = []
    @Published var mostFavoriteAnimes: [AnimeItem] = []
    @Published var latestCompletedAnimes: [AnimeItem] = []
    @Published var top10Today: [AnimeItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var loadTask: Task<Void, Never>?
    private let retryLimit = 3
    private var retryCount = 0
    private let retryDelay: UInt64 = 2_000_000_000 // 2 seconds
    
    private func filterNSFWContent(_ animes: [AnimeItem]) -> [AnimeItem] {
        animes.filter { !$0.containsNSFWContent }
    }
    
    func loadHomeData() async {
        // Cancel any existing load task
        loadTask?.cancel()
        
        loadTask = Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let data = try await APIService.shared.getHomePage()
                if !Task.isCancelled {
                    // Reset retry count on successful load
                    retryCount = 0
                    
                    // Update all sections
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask { @MainActor in
                            self.trendingAnimes = self.filterNSFWContent(data.trendingAnimes)
                        }
                        group.addTask { @MainActor in
                            self.latestEpisodeAnimes = self.filterNSFWContent(data.latestEpisodeAnimes)
                        }
                        group.addTask { @MainActor in
                            self.topUpcomingAnimes = self.filterNSFWContent(data.topUpcomingAnimes)
                        }
                        group.addTask { @MainActor in
                            self.topAiringAnimes = self.filterNSFWContent(data.topAiringAnimes)
                        }
                        group.addTask { @MainActor in
                            self.mostPopularAnimes = self.filterNSFWContent(data.mostPopularAnimes)
                        }
                        group.addTask { @MainActor in
                            self.mostFavoriteAnimes = self.filterNSFWContent(data.mostFavoriteAnimes)
                        }
                        group.addTask { @MainActor in
                            self.latestCompletedAnimes = self.filterNSFWContent(data.latestCompletedAnimes)
                        }
                        group.addTask { @MainActor in
                            self.top10Today = self.filterNSFWContent(data.top10Animes.today)
                        }
                    }
                }
            } catch let error as APIError {
                if !Task.isCancelled {
                    // Handle API-specific errors
                    switch error {
                    case .serverError(let code, _) where code >= 500:
                        // Server error - attempt retry
                        if retryCount < retryLimit {
                            retryCount += 1
                            try? await Task.sleep(nanoseconds: retryDelay)
                            await loadHomeData()
                            return
                        }
                        errorMessage = "Server error. Please try again later."
                    case .serverError(404, _):
                        errorMessage = "Content not available."
                    case .networkError:
                        errorMessage = "Network error. Please check your connection."
                    default:
                        errorMessage = error.message
                    }
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = "Failed to load content: \(error.localizedDescription)"
                }
            }
            
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }
    
    deinit {
        loadTask?.cancel()
    }
} 