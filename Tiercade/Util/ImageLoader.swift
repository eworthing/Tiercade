import Foundation
import CoreGraphics
import ImageIO

/// Lightweight async image loader with in-memory caching using Core Graphics images.
internal final actor ImageLoader {
    internal nonisolated static let shared = ImageLoader()

    private enum LoaderError: Error {
        case decodingFailed
    }

    private final class CGImageBox: NSObject {
        let image: CGImage

        init(image: CGImage) {
            self.image = image
        }
    }

    private let cache = NSCache<NSURL, CGImageBox>()

    internal func cachedImage(for url: URL) async -> CGImage? {
        cache.object(forKey: url as NSURL)?.image
    }

    internal func image(for url: URL) async throws -> CGImage {
        if let cached = cache.object(forKey: url as NSURL)?.image {
            return cached
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let image = try decodeImage(from: data)
        cache.setObject(CGImageBox(image: image), forKey: url as NSURL)
        return image
    }

    internal func prefetch(_ url: URL) async {
        if cache.object(forKey: url as NSURL) != nil {
            return
        }
        _ = try? await image(for: url)
    }

    private func decodeImage(from data: Data) throws -> CGImage {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw LoaderError.decodingFailed
        }
        return image
    }
}
