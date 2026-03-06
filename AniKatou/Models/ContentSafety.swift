import Foundation

enum ContentSafety {
    private static let blockedGenres = ["hentai", "adult"]
    private static let blockedKeywords = ["hentai", "adult", "nsfw", "xxx"]
    private static let blockedRatingPrefixes = ["r+", "rx"]

    static func containsAdultContent(
        title: String,
        description: String? = nil,
        synonyms: String? = nil,
        genres: [String]? = nil,
        rating: String? = nil,
        isNSFW: Bool? = nil
    ) -> Bool {
        if isNSFW == true {
            return true
        }

        if let genres, genres.contains(where: matchesBlockedGenre) {
            return true
        }

        if let rating, matchesBlockedRating(rating) {
            return true
        }

        let haystack = [title, description ?? "", synonyms ?? ""]
            .joined(separator: " ")
            .lowercased()
        return blockedKeywords.contains { haystack.contains($0) }
    }

    private static func matchesBlockedGenre(_ genre: String) -> Bool {
        let lowered = genre.lowercased()
        return blockedGenres.contains { lowered.contains($0) }
    }

    private static func matchesBlockedRating(_ rating: String) -> Bool {
        let normalized = rating
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return blockedRatingPrefixes.contains { normalized.hasPrefix($0) }
    }
}
