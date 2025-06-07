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
    
    func loadHomeData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await APIService.shared.getHomePage()
            trendingAnimes = data.trendingAnimes
            latestEpisodeAnimes = data.latestEpisodeAnimes
            topUpcomingAnimes = data.topUpcomingAnimes
            topAiringAnimes = data.topAiringAnimes
            mostPopularAnimes = data.mostPopularAnimes
            mostFavoriteAnimes = data.mostFavoriteAnimes
            latestCompletedAnimes = data.latestCompletedAnimes
            top10Today = data.top10Animes.today
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = "Failed to load home data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
} 