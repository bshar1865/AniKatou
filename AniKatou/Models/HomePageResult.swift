import Foundation

struct HomePageResult: Codable {
    let success: Bool
    let data: HomePageData
}

struct HomePageData: Codable {
    let spotlightAnimes: [AnimeItem]
    let trendingAnimes: [AnimeItem]
    let latestEpisodeAnimes: [AnimeItem]
    let topUpcomingAnimes: [AnimeItem]
    let topAiringAnimes: [AnimeItem]
    let mostPopularAnimes: [AnimeItem]
    let mostFavoriteAnimes: [AnimeItem]
    let latestCompletedAnimes: [AnimeItem]
    let genres: [String]
    let top10Animes: Top10Animes
}

struct Top10Animes: Codable {
    let today: [AnimeItem]
    let week: [AnimeItem]
    let month: [AnimeItem]
} 