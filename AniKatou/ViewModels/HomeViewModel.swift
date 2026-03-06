import Foundation
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    @Published var trendingAnimes: [AnimeItem] = []
    @Published var latestEpisodeAnimes: [AnimeItem] = []
    @Published var topUpcomingAnimes: [AnimeItem] = []
    @Published var topAiringAnimes: [AnimeItem] = []
    @Published var mostPopularAnimes: [AnimeItem] = []
    @Published var latestCompletedAnimes: [AnimeItem] = []
    @Published var top10Today: [AnimeItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private func filterNSFWContent(_ animes: [AnimeItem]) -> [AnimeItem] {
        animes.filter { !$0.containsNSFWContent }
    }

    private var hasContent: Bool {
        !trendingAnimes.isEmpty ||
        !latestEpisodeAnimes.isEmpty ||
        !topUpcomingAnimes.isEmpty ||
        !topAiringAnimes.isEmpty ||
        !mostPopularAnimes.isEmpty ||
        !latestCompletedAnimes.isEmpty ||
        !top10Today.isEmpty
    }

    func loadHomeData() async {
        let hadContent = hasContent
        if !hadContent {
            isLoading = true
        }
        errorMessage = nil

        do {
            let data = try await APIService.shared.getHomePage()
            trendingAnimes = filterNSFWContent(data.trendingAnimes)
            latestEpisodeAnimes = filterNSFWContent(data.latestEpisodeAnimes)
            topUpcomingAnimes = filterNSFWContent(data.topUpcomingAnimes)
            topAiringAnimes = filterNSFWContent(data.topAiringAnimes)
            mostPopularAnimes = filterNSFWContent(data.mostPopularAnimes)
            latestCompletedAnimes = filterNSFWContent(data.latestCompletedAnimes)
            top10Today = filterNSFWContent(data.top10Animes.today)
            errorMessage = nil
        } catch let error as APIError {
            if !hadContent, case .networkError = error {
                errorMessage = UserMessage.homeOffline
            }
        } catch {
            if !hadContent, OfflineManager.shared.isOfflineMode {
                errorMessage = UserMessage.homeOffline
            }
        }

        isLoading = false
    }
}
