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
    
    private func filterNSFWContent(_ animes: [AnimeItem]) -> [AnimeItem] {
        animes.filter { !$0.containsNSFWContent }
    }
    
    func loadHomeData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await APIService.shared.getHomePage()
            trendingAnimes = filterNSFWContent(data.trendingAnimes)
            latestEpisodeAnimes = filterNSFWContent(data.latestEpisodeAnimes)
            topUpcomingAnimes = filterNSFWContent(data.topUpcomingAnimes)
            topAiringAnimes = filterNSFWContent(data.topAiringAnimes)
            mostPopularAnimes = filterNSFWContent(data.mostPopularAnimes)
            mostFavoriteAnimes = filterNSFWContent(data.mostFavoriteAnimes)
            latestCompletedAnimes = filterNSFWContent(data.latestCompletedAnimes)
            top10Today = filterNSFWContent(data.top10Animes.today)
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = "Failed to load home data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
} 