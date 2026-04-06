import Foundation

struct AnimeAPIResponse<T: Decodable>: Decodable {
    let success: Bool?
    let data: T?
    let error: String?
}

struct StringOrInt: Codable {
    let stringValue: String?
    let intValue: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self.intValue = intValue
            self.stringValue = String(intValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self.stringValue = stringValue
            self.intValue = Int(stringValue)
            return
        }
        self.stringValue = nil
        self.intValue = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue {
            try container.encode(intValue)
        } else if let stringValue {
            try container.encode(stringValue)
        } else {
            try container.encodeNil()
        }
    }
}

struct AnimeAPIHomeData: Decodable {
    let featured: [AnimeAPIListItem]
    let trending: [AnimeAPIListItem]
    let latestSub: [AnimeAPIListItem]
    let latestDub: [AnimeAPIListItem]
    let latestChina: [AnimeAPIListItem]

    enum CodingKeys: String, CodingKey {
        case featured
        case trending
        case latestSub
        case latestDub
        case latestChina
        case latestSubAlt = "latest_sub"
        case latestDubAlt = "latest_dub"
        case latestChinaAlt = "latest_china"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        featured = try container.decodeIfPresent([AnimeAPIListItem].self, forKey: .featured) ?? []
        trending = try container.decodeIfPresent([AnimeAPIListItem].self, forKey: .trending) ?? []
        latestSub =
            try container.decodeIfPresent([AnimeAPIListItem].self, forKey: .latestSub)
            ?? container.decodeIfPresent([AnimeAPIListItem].self, forKey: .latestSubAlt)
            ?? []
        latestDub =
            try container.decodeIfPresent([AnimeAPIListItem].self, forKey: .latestDub)
            ?? container.decodeIfPresent([AnimeAPIListItem].self, forKey: .latestDubAlt)
            ?? []
        latestChina =
            try container.decodeIfPresent([AnimeAPIListItem].self, forKey: .latestChina)
            ?? container.decodeIfPresent([AnimeAPIListItem].self, forKey: .latestChinaAlt)
            ?? []
    }
}

struct AnimeAPISearchData: Decodable {
    let results: [AnimeAPIListItem]
    let pagination: AnimeAPIPagination?

    enum CodingKeys: String, CodingKey {
        case results
        case pagination
    }

    init(from decoder: Decoder) throws {
        if var arrayContainer = try? decoder.unkeyedContainer() {
            var items: [AnimeAPIListItem] = []
            while !arrayContainer.isAtEnd {
                if let item = try? arrayContainer.decode(AnimeAPIListItem.self) {
                    items.append(item)
                } else {
                    _ = try? arrayContainer.decode(EmptyDecodable.self)
                }
            }
            results = items
            pagination = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent([AnimeAPIListItem].self, forKey: .results) ?? []
        pagination = try container.decodeIfPresent(AnimeAPIPagination.self, forKey: .pagination)
    }
}

struct AnimeAPIPagination: Codable {
    let currentPage: Int?
    let hasNextPage: Bool?
    let totalPages: Int?
}

struct AnimeAPIListItem: Codable {
    let id: String?
    let title: String?
    let jpTitle: String?
    let link: String?
    let image: String?
    let tooltipId: String?
    let sub: StringOrInt?
    let dub: StringOrInt?
    let episodes: StringOrInt?
    let type: String?
    let rank: Int?
    let desc: String?
    let genres: String?
    let rating: String?
    let release: String?
    let quality: String?
}

struct AnimeAPIDetails: Codable {
    let id: String?
    let title: String?
    let jpTitle: String?
    let altTitle: String?
    let aniId: String?
    let malId: String?
    let alId: String?
    let rating: String?
    let sub: StringOrInt?
    let dub: StringOrInt?
    let type: String?
    let desc: String?
    let details: AnimeAPIDetailsInfo?
    let score: Double?
    let reviews: Int?
    let relations: [AnimeAPIListItem]?
    let recommended: [AnimeAPIListItem]?
    let image: String?
    let poster: String?
}

struct AnimeAPIDetailsInfo: Codable {
    let japanese: String?
    let synonyms: String?
    let aired: String?
    let dateAired: String?
    let premiered: String?
    let duration: String?
    let status: String?
    let malScore: String?
    let genres: [AnimeAPINameUrl]?
    let studios: [AnimeAPINameUrl]?
    let producers: [AnimeAPINameUrl]?
    let episodes: String?

    enum CodingKeys: String, CodingKey {
        case japanese
        case synonyms
        case aired
        case dateAired = "date_aired"
        case premiered
        case duration
        case status
        case malScore = "mal_score"
        case genres
        case studios
        case producers
        case episodes
    }
}

struct AnimeAPINameUrl: Codable {
    let name: String
    let url: String?
}

struct AnimeAPIEpisode: Codable {
    let num: StringOrInt
    let token: String
    let title: String?
    let jpTitle: String?
    let isFiller: Bool?
    let sub: Bool?
    let dub: Bool?
}

struct AnimeAPIStreamData: Codable {
    let sources: [AnimeAPIStreamSource]
    let tracks: [AnimeAPIStreamTrack]?
    let download: String?
}

struct AnimeAPIStreamSource: Codable {
    let file: String
}

struct AnimeAPIStreamTrack: Codable {
    let file: String
    let kind: String?
}

final class AnimeArtworkCache {
    static let shared = AnimeArtworkCache()
    private var cache: [String: String] = [:]

    private init() {}

    func store(id: String, image: String?) {
        guard !id.isEmpty, let image, !image.isEmpty else { return }
        cache[id] = image
    }

    func image(for id: String) -> String? {
        cache[id]
    }
}

private struct EmptyDecodable: Decodable {}

