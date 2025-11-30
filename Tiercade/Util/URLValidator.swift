import Foundation

enum URLValidator {
    /// Allow only HTTPS for media loading to prevent SSRF / local file access.
    nonisolated static func isAllowedMediaURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }

    /// Allow external opens for HTTP/HTTPS since the OS (Safari) handles the connection, not our app.
    /// ATS applies to URL Loading System (URLSession), not external app handoff.
    nonisolated static func isAllowedExternalURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }

    /// Convenience for string inputs.
    nonisolated static func allowedMediaURL(from string: String) -> URL? {
        guard let url = URL(string: string), isAllowedMediaURL(url) else {
            return nil
        }
        return url
    }
}
