import Foundation

struct AnimeSearchResult: Codable, APIResultEnvelope {
    let status: Int?
    let success: Bool?
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
        ContentSafety.containsAdultContent(
            title: name,
            genres: genres,
            rating: rating,
            isNSFW: isNSFW
        )
    }
}

struct EpisodeCount: Codable {
    let sub: Int?
    let dub: Int?
}

struct AnimeDetailsResult: Codable, APIResultEnvelope {
    let status: Int?
    let success: Bool?
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
        ContentSafety.containsAdultContent(
            title: name,
            description: description,
            genres: genres,
            rating: rating
        )
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

struct AnimeQtipResult: Codable, APIResultEnvelope {
    let status: Int?
    let success: Bool?
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
        ContentSafety.containsAdultContent(
            title: name,
            description: description,
            synonyms: synonyms,
            genres: genres
        )
    }
}

struct NextEpisodeScheduleResult: Codable, APIResultEnvelope {
    let status: Int?
    let success: Bool?
    let data: NextEpisodeSchedule
}

struct NextEpisodeSchedule: Codable {
    let airingISOTimestamp: String?
    let airingTimestamp: Int?
    let secondsUntilAiring: Int?
}

struct EpisodeServersResult: Codable, APIResultEnvelope {
    let status: Int?
    let success: Bool?
    let data: EpisodeServersData
}

struct EpisodeServersData: Codable {
    let episodeId: String
    let episodeNo: Int?
    let sub: [EpisodeServer]?
    let dub: [EpisodeServer]?
    let raw: [EpisodeServer]?
}

struct EpisodeServer: Codable, Identifiable, Hashable {
    let serverId: Int?
    let serverName: String

    var id: String { serverName }
}

struct ResolvedStreamingSource {
    let result: StreamingResult
    let server: String
    let didFallback: Bool
}

struct EpisodesResponse: Codable, APIResultEnvelope {
    let status: Int?
    let success: Bool?
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

struct StreamingResult: Codable, Equatable, APIResultEnvelope {
    let status: Int?
    let success: Bool?
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

    enum CodingKeys: String, CodingKey {
        case headers
        case sources
        case tracks
        case subtitles
        case intro
        case outro
        case anilistID
        case malID
    }
    init(
        headers: [String: String]?,
        sources: [StreamSource],
        tracks: [SubtitleTrack]?,
        intro: IntroOutro?,
        outro: IntroOutro?,
        anilistID: Int?,
        malID: Int?
    ) {
        self.headers = headers
        self.sources = sources
        self.tracks = tracks
        self.intro = intro
        self.outro = outro
        self.anilistID = anilistID
        self.malID = malID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
        sources = try container.decode([StreamSource].self, forKey: .sources)
        tracks =
            try container.decodeIfPresent([SubtitleTrack].self, forKey: .tracks)
            ?? container.decodeIfPresent([SubtitleTrack].self, forKey: .subtitles)
        intro = try container.decodeIfPresent(IntroOutro.self, forKey: .intro)
        outro = try container.decodeIfPresent(IntroOutro.self, forKey: .outro)
        anilistID = try container.decodeIfPresent(Int.self, forKey: .anilistID)
        malID = try container.decodeIfPresent(Int.self, forKey: .malID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(headers, forKey: .headers)
        try container.encode(sources, forKey: .sources)
        try container.encodeIfPresent(tracks, forKey: .tracks)
        try container.encodeIfPresent(intro, forKey: .intro)
        try container.encodeIfPresent(outro, forKey: .outro)
        try container.encodeIfPresent(anilistID, forKey: .anilistID)
        try container.encodeIfPresent(malID, forKey: .malID)
    }
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
