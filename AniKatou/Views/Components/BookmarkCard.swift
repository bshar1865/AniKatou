//
//  BookmarkCard.swift
//  AniKatou
//

import SwiftUI

struct BookmarkCard: View {
    let anime: AnimeItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: anime.image)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
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
    }
}

#if DEBUG
struct BookmarkCard_Previews: PreviewProvider {
    static var previews: some View {
        BookmarkCard(anime: AnimeItem(
            id: "preview",
            name: "Sample Anime",
            jname: nil,
            poster: "https://example.com/image.jpg",
            duration: nil,
            type: "TV",
            rating: nil,
            episodes: nil
        ))
        .frame(width: 200)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif 