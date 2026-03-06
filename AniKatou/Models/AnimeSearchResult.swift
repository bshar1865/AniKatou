import Foundation

// Search Results
struct AnimeSearchResult: Codable {
    let status: Int
    let data: AnimeSearchData
}

struct AnimeSearchData: Codable {
    let animes: [AnimeItem]
}

struct AnimeItem: Codable, Identifiable {
    let id: String
    let name: String
    let jname: String?
    let poster: String
    let duration: String?
    let type: String?
    let rating: String?
    let episodes: EpisodeCount?
    let isNSFW: Bool?
    let genres: [String]?
    let anilistId: Int?

    var title: String { name }
    var image: String { poster }

    var containsNSFWContent: Bool {
        if let isNSFW, isNSFW {
            return true
        }

        let nsfwGenres = ["Hentai", "Adult"]
        if let genres {
            if genres.contains(where: { genre in
                nsfwGenres.contains { blocked in
                    genre.lowercased().contains(blocked.lowercased())
                }
            }) {
                return true
            }
        }

        let nsfwKeywords = ["hentai", "adult", "nsfw", "xxx"]
        let titleLowercased = name.lowercased()
        return nsfwKeywords.contains { keyword in
            titleLowercased.contains(keyword)
        }
    }
}

struct EpisodeCount: Codable {
    let sub: Int?
    let dub: Int?
}

enum SearchSortOption: String, CaseIterable, Identifiable {
    case relevance = "default"
    case recentlyAdded = "recently-added"
    case recentlyUpdated = "recently-updated"
    case score = "score"
    case nameAZ = "name-az"
    case releasedDate = "released-date"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relevance: return "Relevance"
        case .recentlyAdded: return "Recently Added"
        case .recentlyUpdated: return "Recently Updated"
        case .score: return "Score"
        case .nameAZ: return "A-Z"
        case .releasedDate: return "Release Date"
        }
    }
}

struct SearchSuggestionResult: Codable {
    let status: Int
    let data: SearchSuggestionData
}

struct SearchSuggestionData: Codable {
    let suggestions: [SearchSuggestionItem]
}

struct SearchSuggestionItem: Codable, Identifiable {
    let id: String
    let name: String
    let poster: String?
    let jname: String?
    let moreInfo: [String]?
}

// Anime Details
struct AnimeDetailsResult: Codable {
    let status: Int
    let data: AnimeDetailsData
}

struct AnimeDetailsData: Codable {
    let anime: AnimeDetailsInfo
}

struct AnimeDetailsInfo: Codable {
    let info: AnimeDetails
}

struct AnimeDetails: Codable {
    let id: String
    let name: String
    let poster: String
    let description: String?
    let stats: AnimeStats?
    let moreInfo: AnimeMoreInfo?
    let anilistId: Int?

    var title: String { name }
    var image: String { poster }
    var type: String? { stats?.type }
    var status: String? { moreInfo?.status }
    var releaseDate: String? { moreInfo?.aired }
    var genres: [String]? { moreInfo?.genres }
    var rating: String? { stats?.rating }

    var containsNSFWContent: Bool {
        let genreNames = genres ?? []
        let blockedGenres = ["hentai", "adult"]
        if genreNames.contains(where: { genre in
            blockedGenres.contains { blocked in
                genre.lowercased().contains(blocked)
            }
        }) {
            return true
        }

        let titleText = name.lowercased()
        let descriptionText = (description ?? "").lowercased()
        let blockedKeywords = ["hentai", "adult", "xxx"]
        return blockedKeywords.contains { keyword in
            titleText.contains(keyword) || descriptionText.contains(keyword)
        }
    }
}

struct AnimeStats: Codable {
    let rating: String?
    let quality: String?
    let type: String?
    let duration: String?
    let episodes: EpisodeCount?
}

struct AnimeMoreInfo: Codable {
    let japanese: String?
    let aired: String?
    let premiered: String?
    let duration: String?
    let status: String?
    let malscore: String?
    let genres: [String]?
    let studios: [String]?
    let producers: [String]?
}

struct AnimeQtipResult: Codable {
    let status: Int
    let data: AnimeQtipData
}

struct AnimeQtipData: Codable {
    let anime: AnimeQtipInfo
}

struct AnimeQtipInfo: Codable {
    let id: String
    let name: String
    let malscore: String?
    let quality: String?
    let episodes: EpisodeCount?
    let type: String?
    let description: String?
    let jname: String?
    let synonyms: String?
    let aired: String?
    let status: String?
    let genres: [String]?

    var containsNSFWContent: Bool {
        let blockedGenres = ["hentai", "adult"]
        if let genres, genres.contains(where: { genre in
            blockedGenres.contains { blocked in
                genre.lowercased().contains(blocked)
            }
        }) {
            return true
        }

        let blockedKeywords = ["hentai", "adult", "xxx"]
        let haystack = [name, description ?? "", synonyms ?? ""].joined(separator: " ").lowercased()
        return blockedKeywords.contains { haystack.contains($0) }
    }
}

struct NextEpisodeScheduleResult: Codable {
    let status: Int
    let data: NextEpisodeSchedule
}

struct NextEpisodeSchedule: Codable {
    let airingISOTimestamp: String?
    let airingTimestamp: Int?
    let secondsUntilAiring: Int?
}

// Episodes Response
struct EpisodesResponse: Codable {
    let status: Int
    let data: EpisodesData
}

struct EpisodesData: Codable {
    let totalEpisodes: Int
    let episodes: [EpisodeInfo]
}

struct EpisodeInfo: Codable, Identifiable {
    let title: String?
    let episodeId: String
    let number: Int
    let isFiller: Bool?

    var id: String { episodeId }
}

// Streaming
struct StreamingResult: Codable, Equatable {
    let status: Int
    let data: StreamingData
}

struct StreamingData: Codable, Equatable {
    let headers: [String: String]?
    let sources: [StreamSource]
    let tracks: [SubtitleTrack]?
    let intro: IntroOutro?
    let outro: IntroOutro?
    let anilistID: Int?
    let malID: Int?
}

struct StreamSource: Codable, Equatable {
    let url: String
    let quality: String?
    let isM3U8: Bool?
    let type: String?
}

struct SubtitleTrack: Codable, Equatable {
    let url: String
    let lang: String
}

struct IntroOutro: Codable, Equatable {
    let start: Int
    let end: Int
}