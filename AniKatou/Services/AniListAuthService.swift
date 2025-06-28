import Foundation

class AniListAuthService {
    static let shared = AniListAuthService()
    private let endpoint = "https://graphql.anilist.co"
    private let userDefaults = UserDefaults.standard
    private let accessTokenKey = "AniListAccessToken"
    private let refreshTokenKey = "AniListRefreshToken"
    private let tokenExpiryKey = "AniListTokenExpiry"
    
    private init() {}
    
    // MARK: - Authentication Properties
    
    var isAuthenticated: Bool {
        guard let accessToken = userDefaults.string(forKey: accessTokenKey),
              let expiryDate = userDefaults.object(forKey: tokenExpiryKey) as? Date else {
            return false
        }
        return !accessToken.isEmpty && expiryDate > Date()
    }
    
    var accessToken: String? {
        return userDefaults.string(forKey: accessTokenKey)
    }
    
    // MARK: - Authentication Methods
    
    func authenticate(code: String) async throws -> Bool {
        let query = """
        mutation ($code: String!) {
            authenticate(code: $code) {
                access_token
                refresh_token
                expires_in
            }
        }
        """
        
        let variables: [String: Any] = ["code": code]
        
        do {
            let data = try await sendGraphQLRequest(query: query, variables: variables)
            guard let authDict = data["authenticate"] as? [String: Any],
                  let accessToken = authDict["access_token"] as? String,
                  let refreshToken = authDict["refresh_token"] as? String,
                  let expiresIn = authDict["expires_in"] as? Int else {
                throw AniListError.authenticationFailed
            }
            
            // Save tokens
            userDefaults.set(accessToken, forKey: accessTokenKey)
            userDefaults.set(refreshToken, forKey: refreshTokenKey)
            userDefaults.set(Date().addingTimeInterval(TimeInterval(expiresIn)), forKey: tokenExpiryKey)
            
            return true
        } catch {
            throw AniListError.authenticationFailed
        }
    }
    
    func storeAccessToken(_ accessToken: String) async throws -> Bool {
        // For Implicit Grant flow, we receive the access token directly
        // AniList tokens are long-lived (1 year), so we set expiry to 1 year from now
        let expiryDate = Date().addingTimeInterval(365 * 24 * 60 * 60) // 1 year
        
        userDefaults.set(accessToken, forKey: accessTokenKey)
        userDefaults.set(expiryDate, forKey: tokenExpiryKey)
        
        // No refresh token in Implicit Grant flow
        userDefaults.removeObject(forKey: refreshTokenKey)
        
        return true
    }
    
    func logout() {
        userDefaults.removeObject(forKey: accessTokenKey)
        userDefaults.removeObject(forKey: refreshTokenKey)
        userDefaults.removeObject(forKey: tokenExpiryKey)
    }
    
    func refreshToken() async throws -> Bool {
        guard let refreshToken = userDefaults.string(forKey: refreshTokenKey) else {
            throw AniListError.noRefreshToken
        }
        
        let query = """
        mutation ($refreshToken: String!) {
            refreshToken(refreshToken: $refreshToken) {
                access_token
                refresh_token
                expires_in
            }
        }
        """
        
        let variables: [String: Any] = ["refreshToken": refreshToken]
        
        do {
            let data = try await sendGraphQLRequest(query: query, variables: variables)
            guard let authDict = data["refreshToken"] as? [String: Any],
                  let accessToken = authDict["access_token"] as? String,
                  let newRefreshToken = authDict["refresh_token"] as? String,
                  let expiresIn = authDict["expires_in"] as? Int else {
                throw AniListError.tokenRefreshFailed
            }
            
            // Save new tokens
            userDefaults.set(accessToken, forKey: accessTokenKey)
            userDefaults.set(newRefreshToken, forKey: refreshTokenKey)
            userDefaults.set(Date().addingTimeInterval(TimeInterval(expiresIn)), forKey: tokenExpiryKey)
            
            return true
        } catch {
            throw AniListError.tokenRefreshFailed
        }
    }
    
    // MARK: - User Library Methods
    
    func getUserLibrary(status: AniListStatus? = nil) async throws -> [AniListLibraryItem] {
        guard isAuthenticated else {
            throw AniListError.notAuthenticated
        }
        
        // First get the user profile to get the user ID
        let userProfile = try await getUserProfile()
        
        // Use different queries based on whether status is provided
        let query: String
        let variables: [String: Any]
        
        if let status = status {
            query = """
            query ($userId: Int!, $status: MediaListStatus!) {
              MediaListCollection(userId: $userId, type: ANIME, status: $status) {
                lists {
                  entries {
                    id
                    mediaId
                    status
                    score
                    progress
                    media {
                      id
                      title {
                        romaji
                        english
                        native
                      }
                      coverImage {
                        large
                        medium
                      }
                      episodes
                      status
                      format
                    }
                  }
                }
              }
            }
            """
            variables = ["userId": userProfile.id, "status": status.rawValue]
        } else {
            query = """
            query ($userId: Int!) {
              MediaListCollection(userId: $userId, type: ANIME) {
                lists {
                  entries {
                    id
                    mediaId
                    status
                    score
                    progress
                    media {
                      id
                      title {
                        romaji
                        english
                        native
                      }
                      coverImage {
                        large
                        medium
                      }
                      episodes
                      status
                      format
                    }
                  }
                }
              }
            }
            """
            variables = ["userId": userProfile.id]
        }
        
        do {
            let data = try await sendGraphQLRequest(query: query, variables: variables, requiresAuth: true)
            print("AniList response data: \(data)") // Debug logging
            return try parseLibraryResponse(data)
        } catch {
            print("AniList library fetch error: \(error)") // Debug logging
            throw AniListError.failedToFetchLibrary
        }
    }
    
    func getUserProfile() async throws -> AniListUserProfile {
        guard isAuthenticated else {
            throw AniListError.notAuthenticated
        }
        
        let query = """
        query {
          Viewer {
            id
            name
            avatar {
              large
              medium
            }
            statistics {
              anime {
                count
                episodesWatched
                meanScore
              }
            }
          }
        }
        """
        
        do {
            let data = try await sendGraphQLRequest(query: query, variables: [:], requiresAuth: true)
            return try parseUserProfile(data)
        } catch {
            throw AniListError.failedToFetchProfile
        }
    }
    
    private func parseLibraryResponse(_ data: [String: Any]) throws -> [AniListLibraryItem] {
        guard let collection = data["MediaListCollection"] as? [String: Any],
              let lists = collection["lists"] as? [[String: Any]] else {
            throw AniListError.invalidResponse
        }
        
        var items: [AniListLibraryItem] = []
        
        for list in lists {
            guard let entries = list["entries"] as? [[String: Any]] else {
                continue
            }
            
            for entry in entries {
                guard let media = entry["media"] as? [String: Any],
                      let mediaId = media["id"] as? Int,
                      let title = media["title"] as? [String: Any],
                      let romajiTitle = title["romaji"] as? String,
                      let status = entry["status"] as? String,
                      let listStatus = AniListStatus(rawValue: status) else {
                    continue
                }
                
                let englishTitle = title["english"] as? String
                let nativeTitle = title["native"] as? String
                let coverImage = media["coverImage"] as? [String: Any]
                let imageURL = coverImage?["large"] as? String
                let episodes = media["episodes"] as? Int
                let progress = entry["progress"] as? Int ?? 0
                let score = entry["score"] as? Double
                
                let item = AniListLibraryItem(
                    id: entry["id"] as? Int ?? 0,
                    mediaId: mediaId,
                    title: englishTitle ?? romajiTitle,
                    romajiTitle: romajiTitle,
                    nativeTitle: nativeTitle,
                    imageURL: imageURL,
                    status: listStatus,
                    progress: progress,
                    totalEpisodes: episodes,
                    score: score
                )
                
                items.append(item)
            }
        }
        
        return items
    }
    
    private func parseUserProfile(_ data: [String: Any]) throws -> AniListUserProfile {
        guard let viewer = data["Viewer"] as? [String: Any],
              let id = viewer["id"] as? Int,
              let name = viewer["name"] as? String else {
            throw AniListError.invalidResponse
        }
        
        let avatar = viewer["avatar"] as? [String: Any]
        let avatarURL = avatar?["large"] as? String
        
        let statistics = viewer["statistics"] as? [String: Any]
        let animeStats = statistics?["anime"] as? [String: Any]
        let animeCount = animeStats?["count"] as? Int ?? 0
        let episodesWatched = animeStats?["episodesWatched"] as? Int ?? 0
        let meanScore = animeStats?["meanScore"] as? Double
        
        return AniListUserProfile(
            id: id,
            name: name,
            avatarURL: avatarURL,
            animeCount: animeCount,
            episodesWatched: episodesWatched,
            meanScore: meanScore
        )
    }
    
    // MARK: - GraphQL Request Helper
    
    private func sendGraphQLRequest(query: String, variables: [String: Any] = [:], requiresAuth: Bool = false) async throws -> [String: Any] {
        let url = URL(string: "https://graphql.anilist.co")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if requiresAuth, let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AniListError.invalidResponse
        }
        
        print("AniList HTTP Status: \(httpResponse.statusCode)")
        print("AniList Response Headers: \(httpResponse.allHeaderFields)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("AniList Raw Response: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AniListError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AniListError.invalidResponse
        }
        
        // Check for GraphQL errors
        if let errors = json["errors"] as? [[String: Any]] {
            print("AniList GraphQL Errors: \(errors)")
            let errorMessages = errors.compactMap { $0["message"] as? String }.joined(separator: "; ")
            throw NSError(domain: "AniListAuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "GraphQL errors: \(errorMessages)"])
        }
        
        guard let data = json["data"] as? [String: Any] else {
            print("AniList No data in response: \(json)")
            throw AniListError.invalidResponse
        }
        
        return data
    }
}
