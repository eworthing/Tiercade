import CoreGraphics
import Foundation
import ImageIO

/// Lightweight async image loader with in-memory caching using Core Graphics images.
final actor ImageLoader {

    // MARK: Internal

    nonisolated static let shared = ImageLoader()

    func cachedImage(for url: URL) async -> CGImage? {
        cache.object(forKey: url as NSURL)?.image
    }

    func image(for url: URL) async throws -> CGImage {
        if let cached = cache.object(forKey: url as NSURL)?.image {
            return cached
        }

        guard URLValidator.isAllowedMediaURL(url) else {
            throw LoaderError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let image = try decodeImage(from: data)
        // Compute cost for NSCache limit enforcement: bytes = bytesPerRow × height
        let cost = image.bytesPerRow * image.height
        cache.setObject(CGImageBox(image: image), forKey: url as NSURL, cost: cost)
        return image
    }

    func prefetch(_ url: URL) async {
        if cache.object(forKey: url as NSURL) != nil {
            return
        }
        _ = try? await image(for: url)
    }

    // MARK: Private

    private enum LoaderError: Error {
        case decodingFailed
        case invalidURL
    }

    private final class CGImageBox: NSObject {
        let image: CGImage

        init(image: CGImage) {
            self.image = image
        }
    }

    private let cache: NSCache<NSURL, CGImageBox> = {
        let c = NSCache<NSURL, CGImageBox>()
        c.countLimit = 200
        c.totalCostLimit = 50_000_000 // ~50 MB budget
        return c
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

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
