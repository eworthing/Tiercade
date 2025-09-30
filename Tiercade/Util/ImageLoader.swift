#if os(tvOS)
import Foundation
import UIKit

/// Lightweight async image loader with in-memory caching.
final actor ImageLoader {
    nonisolated static let shared = ImageLoader()

    private enum LoaderError: Error {
        case decodingFailed
    }

    private let cache = NSCache<NSString, UIImage>()

    func cachedImage(for url: URL) async -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: url.absoluteString as NSString) {
            return cached
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw LoaderError.decodingFailed
        }
        cache.setObject(image, forKey: url.absoluteString as NSString)
        return image
    }

    func prefetch(_ url: URL) async {
        if cache.object(forKey: url.absoluteString as NSString) != nil {
            return
        }
        _ = try? await image(for: url)
    }
}
#endif
