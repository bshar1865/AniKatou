import SwiftUI
import UIKit
import ImageIO

private enum CachedImageLoader {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
        return URLSession(configuration: config)
    }()
}

final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 160
        cache.totalCostLimit = 80 * 1024 * 1024
        cache.evictsObjectsWithDiscardedContent = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCacheOnMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    func set(_ image: UIImage, for url: URL, cost: Int) {
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: max(1, cost))
    }
    
    func get(_ url: URL?) -> UIImage? {
        guard let url else { return nil }
        return cache.object(forKey: url.absoluteString as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    @objc private func clearCacheOnMemoryWarning() {
        clearCache()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    private let retryAttempts: Int
    private let maxPixelSize: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        scale: CGFloat = 1.0,
        retryAttempts: Int = 3,
        timeoutInterval: TimeInterval = 15.0,
        maxPixelSize: CGFloat = 1200,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.retryAttempts = retryAttempts
        self.maxPixelSize = maxPixelSize
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .overlay {
                        if isLoading {
                            ProgressView()
                        }
                    }
            }
        }
        .task(id: url?.absoluteString) {
            await loadImage()
        }
    }
    
    @MainActor
    private func loadImage() async {
        guard let url, url.scheme != nil, url.host != nil else {
            image = nil
            isLoading = false
            return
        }
        
        if let cachedImage = ImageCache.shared.get(url) {
            image = cachedImage
            isLoading = false
            return
        }

        if let diskImage = OfflineManager.shared.getCachedImage(for: url.absoluteString) {
            image = diskImage
            let cost = Int(diskImage.size.width * diskImage.size.height * diskImage.scale * diskImage.scale * 4)
            ImageCache.shared.set(diskImage, for: url, cost: cost)
            isLoading = false
            return
        }
        
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        for attempt in 0..<retryAttempts {
            do {
                let loadedImage = try await loadImageFromURL(url)
                guard !Task.isCancelled else { return }

                image = loadedImage
                let cost = Int(loadedImage.size.width * loadedImage.size.height * loadedImage.scale * loadedImage.scale * 4)
                ImageCache.shared.set(loadedImage, for: url, cost: cost)
                return
            } catch {
                if let diskImage = OfflineManager.shared.getCachedImage(for: url.absoluteString) {
                    image = diskImage
                    let cost = Int(diskImage.size.width * diskImage.size.height * diskImage.scale * diskImage.scale * 4)
                    ImageCache.shared.set(diskImage, for: url, cost: cost)
                    return
                }

                guard attempt < retryAttempts - 1 else { break }
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 300_000_000))
            }
        }
    }
    
    private func loadImageFromURL(_ url: URL) async throws -> UIImage {
        let (data, response) = try await CachedImageLoader.session.data(from: url)
            
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
        OfflineManager.shared.cacheImageData(data, for: url.absoluteString)

        guard let image = downsampledImage(from: data) else {
                throw URLError(.cannotDecodeContentData)
            }
            
            return image
    }

    private func downsampledImage(from data: Data) -> UIImage? {
        let options: CFDictionary = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return UIImage(data: data)
        }

        let downsampleOptions: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize))
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage)
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(url: URL?, scale: CGFloat = 1.0) {
        self.init(
            url: url,
            scale: scale,
            content: { $0 },
            placeholder: { Color.gray.opacity(0.25) }
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        CachedAsyncImage(url: URL(string: "https://picsum.photos/200/300")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 300)
        } placeholder: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 200, height: 300)
        }
    }
    .padding()
} 