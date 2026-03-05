import SwiftUI

struct AnimeCard: View {
    let anime: AnimeItem
    let width: CGFloat?
    
    init(anime: AnimeItem, width: CGFloat? = nil) {
        self.anime = anime
        self.width = width
    }
    
    private var imageHeight: CGFloat {
        (width ?? 140) * 1.5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            .frame(height: imageHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(anime.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .foregroundColor(.primary)
                .frame(height: 36, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let type = anime.type, !type.isEmpty {
                Text(type)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(height: 14, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Color.clear
                    .frame(height: 14)
            }
        }
        .frame(width: width, alignment: .topLeading)
    }
} 
