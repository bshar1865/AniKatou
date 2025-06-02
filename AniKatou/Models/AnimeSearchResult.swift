import Foundation

// Search Results
struct AnimeSearchResult: Codable {
    let success: Bool
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
    
    // Map the API fields to our model
    var title: String { name }
    var image: String { poster }
}

struct EpisodeCount: Codable {
    let sub: Int?
    let dub: Int?
}

// Anime Details
struct AnimeDetailsResult: Codable {
    let success: Bool
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
    
    // Map the API fields to our model
    var title: String { name }
    var image: String { poster }
    var type: String? { stats?.type }
    var status: String? { moreInfo?.status }
    var releaseDate: String? { moreInfo?.aired }
    var genres: [String]? { moreInfo?.genres }
    var rating: String? { stats?.rating }
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

// Episodes Response
struct EpisodesResponse: Codable {
    let success: Bool
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
struct StreamingResult: Codable {
    let success: Bool
    let data: StreamingData
}

struct StreamingData: Codable {
    let headers: [String: String]?
    let sources: [StreamSource]
    let subtitles: [SubtitleTrack]?
    let download: String?
}

struct StreamSource: Codable {
    let url: String
    let quality: String?
    let isM3U8: Bool?
    
    enum CodingKeys: String, CodingKey {
        case url
        case quality
        case isM3U8 = "isM3U8"
    }
}

struct SubtitleTrack: Codable {
    let url: String
    let lang: String
    let language: String?
} 