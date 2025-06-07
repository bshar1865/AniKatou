import Foundation

struct EpisodeGroup: Identifiable {
    let id: String
    let startEpisode: Int
    let endEpisode: Int
    let episodes: [EpisodeInfo]
    
    var title: String {
        "Episodes \(startEpisode)-\(endEpisode)"
    }
    
    static func createGroups(from episodes: [EpisodeInfo], groupSize: Int = 100) -> [EpisodeGroup] {
        guard !episodes.isEmpty else { return [] }
        
        let sortedEpisodes = episodes.sorted { $0.number < $1.number }
        var groups: [EpisodeGroup] = []
        var currentGroup: [EpisodeInfo] = []
        var currentStartEpisode = sortedEpisodes[0].number
        
        for episode in sortedEpisodes {
            if episode.number >= currentStartEpisode + groupSize {
                // Create a new group
                groups.append(EpisodeGroup(
                    id: "\(currentStartEpisode)-\(currentStartEpisode + groupSize - 1)",
                    startEpisode: currentStartEpisode,
                    endEpisode: currentStartEpisode + groupSize - 1,
                    episodes: currentGroup
                ))
                
                currentGroup = []
                currentStartEpisode = episode.number
            }
            
            currentGroup.append(episode)
        }
        
        // Add the last group
        if !currentGroup.isEmpty {
            groups.append(EpisodeGroup(
                id: "\(currentStartEpisode)-\(sortedEpisodes.last!.number)",
                startEpisode: currentStartEpisode,
                endEpisode: sortedEpisodes.last!.number,
                episodes: currentGroup
            ))
        }
        
        return groups
    }
} 