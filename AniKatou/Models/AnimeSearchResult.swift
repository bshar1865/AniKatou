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
    
    // Map the API fields to our model
    var title: String { name }
    var image: String { poster }
    
    // Helper function to check if content is NSFW
    var containsNSFWContent: Bool {
        if let isNSFW = isNSFW, isNSFW {
            return true
        }
        
        // Check for NSFW genres
        let nsfwGenres = ["Hentai", "Ecchi", "Adult", "Mature"]
        if let genres = genres {
            return genres.contains { genre in
                nsfwGenres.contains { nsfwGenre in
                    genre.lowercased().contains(nsfwGenre.lowercased())
                }
            }
        }
        
        // Check for NSFW keywords in title
        let nsfwKeywords = ["hentai", "ecchi", "adult", "nsfw", "xxx"]
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