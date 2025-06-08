import SwiftUI

struct AnimeCard: View {
    let anime: AnimeItem
    let width: CGFloat?
    
    init(anime: AnimeItem, width: CGFloat? = nil) {
        self.anime = anime
        self.width = width
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image with caching
            CachedAsyncImage(url: URL(string: anime.image)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(anime.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            if let type = anime.type {
                Text(type)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: width)
    }
}

#Preview {
    AnimeCard(
        anime: AnimeItem(
            id: "preview",
            name: "Sample Anime",
            jname: nil,
            poster: "https://example.com/image.jpg",
            duration: "24 min",
            type: "TV",
            rating: "PG-13",
            episodes: nil,
            isNSFW: false,
            genres: ["Action", "Adventure"]
        )
    )
    .frame(width: 160)
    .padding()
} 