//
//  BookmarkCard.swift
//  AniKatou
//

import SwiftUI

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100 // Maximum number of images to cache
    }
    
    func set(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func get(_ key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
}

struct CachedAsyncImage: View {
    let url: URL?
    let content: (Image) -> AnyView
    let placeholder: AnyView
    @State private var image: UIImage?
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> some View,
        @ViewBuilder placeholder: @escaping () -> some View
    ) {
        self.url = url
        self.content = { AnyView(content($0)) }
        self.placeholder = AnyView(placeholder())
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = url else { return }
        
        // Check cache first
        if let cachedImage = ImageCache.shared.get(url.absoluteString) {
            image = cachedImage
            return
        }
        
        // If not in cache, load from network
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                ImageCache.shared.set(downloadedImage, for: url.absoluteString)
                image = downloadedImage
            }
        } catch {
            print("Error loading image: \(error)")
        }
    }
}

struct BookmarkCard: View {
    let anime: AnimeItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(
                url: URL(string: anime.image)
            ) { image in
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
            episodes: nil,
            isNSFW: false,
            genres: ["Action", "Adventure"]
        ))
        .frame(width: 200)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif 