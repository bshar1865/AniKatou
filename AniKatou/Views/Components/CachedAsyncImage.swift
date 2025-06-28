import SwiftUI
import Combine

// Improved image cache with better memory management
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, CachedImage>()
    
    private init() {
        cache.countLimit = 200 // Increased limit
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
        cache.evictsObjectsWithDiscardedContent = true
        
        // Listen for memory warnings
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

// Cached image wrapper with timestamp
private class CachedImage {
    let image: UIImage
    let timestamp: Date
    
    init(image: UIImage, timestamp: Date) {
        self.image = image
        self.timestamp = timestamp
    }
}

// Improved CachedAsyncImage with retry logic and better error handling
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
        .onChange(of: url) { oldValue, newValue in
            // Reset state when URL changes
            image = nil
            error = nil
            retryCount = 0
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        
        // Validate URL
        guard url.scheme != nil, url.host != nil else {
            print("Invalid image URL: \(url)")
            return
        }
        
        // Check cache first
        if let cachedImage = ImageCache.shared.get(url) {
            self.image = cachedImage
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
                    self.isLoading = false
                    
                    // Cache the image with estimated cost based on size
                    let cost = Int(image.size.width * image.size.height * 4) / (1024 * 1024) // Rough estimate in MB
                    ImageCache.shared.set(image, for: url, cost: max(1, cost))
                }
                return
            } catch {
                if attempt == retryAttempts - 1 {
                    // Last attempt failed
                    self.error = error
                    self.isLoading = false
                    print("Failed to load image after \(retryAttempts) attempts: \(error.localizedDescription)")
                } else {
                    // Wait before retrying with exponential backoff
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
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            guard httpResponse.statusCode == 200 else {
                print("Image loading failed with status code: \(httpResponse.statusCode) for URL: \(url)")
                throw URLError(.badServerResponse)
            }
            
            guard let image = UIImage(data: data) else {
                print("Failed to decode image data for URL: \(url)")
                throw URLError(.cannotDecodeContentData)
            }
            
            return image
        } catch {
            print("Image loading error for URL \(url): \(error.localizedDescription)")
            throw error
        }
    }
}

// Convenience initializer for simple use cases
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

// MARK: - Previews
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