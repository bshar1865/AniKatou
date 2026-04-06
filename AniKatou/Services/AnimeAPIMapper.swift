import Foundation

enum AnimeAPIMapper {
    static func mapHome(_ data: AnimeAPIHomeData) -> HomePageData {
        let featured = mapList(data.featured)
        let trending = mapList(data.trending)
        let latestSub = mapList(data.latestSub)
        let latestDub = mapList(data.latestDub)
        let latestChina = mapList(data.latestChina)

        let combinedLatest = latestSub + latestDub + latestChina
        let top10 = Array((trending.isEmpty ? featured : trending).prefix(10))

        return HomePageData(
            spotlightAnimes: featured,
            trendingAnimes: trending,
            latestEpisodeAnimes: combinedLatest,
            topUpcomingAnimes: [],
            topAiringAnimes: latestSub,
            mostPopularAnimes: featured.isEmpty ? trending : featured,
            latestCompletedAnimes: latestDub,
            genres: [],
            top10Animes: Top10Animes(today: top10, week: [], month: [])
        )
    }

    static func mapSearch(_ data: AnimeAPISearchData) -> [AnimeItem] {
        mapList(data.results)
    }

    static func mapDetails(_ data: AnimeAPIDetails) throws -> AnimeDetailsResult {
        guard let title = data.title, !title.isEmpty else {
            throw APIError.invalidResponse
        }

        let id = data.id ?? slugify(title)
        let poster = data.poster ?? data.image ?? AnimeArtworkCache.shared.image(for: id) ?? ""

        let detailsInfo = data.details
        let genres = detailsInfo?.genres?.map(\.name)
        let studios = detailsInfo?.studios?.map(\.name)
        let producers = detailsInfo?.producers?.map(\.name)
        let aired = detailsInfo?.aired ?? detailsInfo?.dateAired

        let stats = AnimeStats(
            rating: data.rating,
            quality: nil,
            type: data.type,
            duration: detailsInfo?.duration,
            episodes: EpisodeCount(sub: data.sub?.intValue, dub: data.dub?.intValue)
        )

        let moreInfo = AnimeMoreInfo(
            japanese: data.jpTitle ?? detailsInfo?.japanese,
            aired: aired,
            premiered: detailsInfo?.premiered,
            duration: detailsInfo?.duration,
            status: detailsInfo?.status,
            malscore: detailsInfo?.malScore ?? data.rating,
            genres: genres,
            studios: studios,
            producers: producers
        )

        let details = AnimeDetails(
            id: id,
            name: title,
            poster: poster,
            description: data.desc,
            stats: stats,
            moreInfo: moreInfo,
            anilistId: Int(data.alId ?? "")
        )

        return AnimeDetailsResult(
            status: nil,
            success: true,
            data: AnimeDetailsData(anime: AnimeDetailsInfo(info: details))
        )
    }

    static func mapQtip(_ data: AnimeAPIDetails) throws -> AnimeQtipResult {
        guard let title = data.title, !title.isEmpty else {
            throw APIError.invalidResponse
        }

        let info = AnimeQtipInfo(
            id: data.id ?? slugify(title),
            name: title,
            malscore: data.details?.malScore,
            quality: nil,
            episodes: EpisodeCount(sub: data.sub?.intValue, dub: data.dub?.intValue),
            type: data.type,
            description: data.desc,
            jname: data.jpTitle,
            synonyms: data.altTitle,
            aired: data.details?.aired ?? data.details?.dateAired,
            status: data.details?.status,
            genres: data.details?.genres?.map(\.name)
        )

        return AnimeQtipResult(
            status: nil,
            success: true,
            data: AnimeQtipData(anime: info)
        )
    }

    static func mapEpisodes(_ items: [AnimeAPIEpisode]) -> [EpisodeInfo] {
        items.map { item in
            let number = item.num.intValue ?? Int(item.num.stringValue ?? "") ?? 0
            return EpisodeInfo(
                title: item.title,
                episodeId: item.token,
                number: number,
                isFiller: item.isFiller
            )
        }
    }

    static func mapStream(_ data: AnimeAPIStreamData) -> StreamingResult {
        let sources = data.sources.map {
            StreamSource(url: $0.file, quality: nil, isM3U8: $0.file.contains(".m3u8"), type: nil)
        }
        let tracks = data.tracks?.map {
            SubtitleTrack(url: $0.file, lang: $0.kind ?? "sub")
        }

        let streamingData = StreamingData(
            headers: nil,
            sources: sources,
            tracks: tracks?.isEmpty == true ? nil : tracks,
            intro: nil,
            outro: nil,
            anilistID: nil,
            malID: nil
        )

        return StreamingResult(status: nil, success: true, data: streamingData)
    }

    static func mapList(_ items: [AnimeAPIListItem]) -> [AnimeItem] {
        items.compactMap(mapListItem)
    }

    static func mapListItem(_ item: AnimeAPIListItem) -> AnimeItem? {
        guard let title = item.title, !title.isEmpty else { return nil }
        let id = item.id ?? item.link.map(extractId) ?? slugify(title)
        if let image = item.image {
            AnimeArtworkCache.shared.store(id: id, image: image)
        }
        let genres = item.genres?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let episodes = EpisodeCount(sub: item.sub?.intValue, dub: item.dub?.intValue)

        return AnimeItem(
            id: id,
            name: title,
            jname: item.jpTitle,
            poster: item.image ?? "",
            duration: nil,
            type: item.type,
            rating: item.rating,
            episodes: episodes,
            isNSFW: nil,
            genres: genres?.isEmpty == true ? nil : genres,
            anilistId: nil
        )
    }

    static func extractId(from link: String) -> String {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.split(separator: "#", maxSplits: 1).first.map(String.init) ?? trimmed
        let noQuery = base.split(separator: "?", maxSplits: 1).first.map(String.init) ?? base

        if let range = noQuery.range(of: "/watch/") {
            return String(noQuery[range.upperBound...])
        }
        if let range = noQuery.range(of: "/details/") {
            return String(noQuery[range.upperBound...])
        }
        if let range = noQuery.range(of: "/anime/") {
            return String(noQuery[range.upperBound...])
        }

        return noQuery.split(separator: "/").last.map(String.init) ?? noQuery
    }

    static func slugify(_ text: String) -> String {
        let lower = text.lowercased()
        let allowed = lower.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            return "-"
        }
        let raw = String(allowed)
        return raw
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
