import Foundation

internal enum URLValidator {
    /// Allow only HTTPS for media loading to prevent SSRF / local file access.
    nonisolated internal static func isAllowedMediaURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }

    /// Allow external opens for HTTPS only by default. Extend cautiously if needed.
    nonisolated internal static func isAllowedExternalURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }

    /// Convenience for string inputs.
    nonisolated internal static func allowedMediaURL(from string: String) -> URL? {
        guard let url = URL(string: string), isAllowedMediaURL(url) else { return nil }
        return url
    }
}

