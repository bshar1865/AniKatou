import SwiftUI
import Combine

class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, CachedImage>()
    
    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024
        cache.evictsObjectsWithDiscardedContent = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCacheOnMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    func set(_ image: UIImage, for url: URL, cost: Int = 1) {
        let cachedImage = CachedImage(image: image, timestamp: Date())
        cache.setObject(cachedImage, forKey: url.absoluteString as NSString, cost: cost)
    }
    
    func get(_ url: URL?) -> UIImage? {
        guard let url = url else { return nil }
        return cache.object(forKey: url.absoluteString as NSString)?.image
    }
    
    func remove(_ url: URL) {
        cache.removeObject(forKey: url.absoluteString as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    @objc private func clearCacheOnMemoryWarning() {
        cache.removeAllObjects()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

private class CachedImage {
    let image: UIImage
    let timestamp: Date
    
    init(image: UIImage, timestamp: Date) {
        self.image = image
        self.timestamp = timestamp
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    private let retryAttempts: Int
    private let timeoutInterval: TimeInterval
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var retryCount = 0
    
    init(
        url: URL?,
        scale: CGFloat = 1.0,
        retryAttempts: Int = 3,
        timeoutInterval: TimeInterval = 15.0,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.retryAttempts = retryAttempts
        self.timeoutInterval = timeoutInterval
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onChange(of: url) { _, _ in
            image = nil
            error = nil
            retryCount = 0
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        guard url.scheme != nil, url.host != nil else { return }
        
        if let cachedImage = ImageCache.shared.get(url) {
            image = cachedImage
            return
        }
        
        isLoading = true
        error = nil
        
        Task {
            await loadImageWithRetry(url: url)
        }
    }
    
    @MainActor
    private func loadImageWithRetry(url: URL) async {
        for attempt in 0..<retryAttempts {
            do {
                let image = try await loadImageFromURL(url)
                if !Task.isCancelled {
                    self.image = image
                    isLoading = false
                    let cost = Int(image.size.width * image.size.height * 4) / (1024 * 1024)
                    ImageCache.shared.set(image, for: url, cost: max(1, cost))
                }
                return
            } catch {
                if attempt == retryAttempts - 1 {
                    self.error = error
                    isLoading = false
                } else {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }
            }
        }
    }
    
    private func loadImageFromURL(_ url: URL) async throws -> UIImage {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval
        config.requestCachePolicy = .returnCacheDataElseLoad
        
        let session = URLSession(configuration: config)
            let (data, response) = try await session.data(from: url)
            
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            guard let image = UIImage(data: data) else {
                throw URLError(.cannotDecodeContentData)
            }
            
            return image
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(url: URL?, scale: CGFloat = 1.0) {
        self.init(
            url: url,
            scale: scale,
            content: { $0 },
            placeholder: { Color.gray }
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
                .overlay(ProgressView())
        }
        
        CachedAsyncImage(url: URL(string: "https://invalid-url.com/image.jpg")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 300)
        } placeholder: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 200, height: 300)
                .overlay(ProgressView())
        }
    }
    .padding()
} 