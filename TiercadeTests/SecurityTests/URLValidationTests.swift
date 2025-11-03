import Testing
import Foundation
@testable import Tiercade

/// Security tests for URL validation to prevent SSRF and file disclosure attacks
@Suite("URL Validation Security Tests")
internal struct URLValidationTests {

    // MARK: - Media URL Validation (HTTPS-only)

    @Test("Rejects file:// URLs for media loading")
    internal func rejectFileURLs() {
        internal let fileURL = URL(string: "file:///etc/passwd")!
        #expect(!URLValidator.isAllowedMediaURL(fileURL))
    }

    @Test("Rejects ftp:// URLs for media loading")
    internal func rejectFTPURLs() {
        internal let ftpURL = URL(string: "ftp://example.com/image.jpg")!
        #expect(!URLValidator.isAllowedMediaURL(ftpURL))
    }

    @Test("Rejects http:// URLs for media loading (requires HTTPS)")
    internal func rejectHTTPURLs() {
        internal let httpURL = URL(string: "http://example.com/image.jpg")!
        #expect(!URLValidator.isAllowedMediaURL(httpURL))
    }

    @Test("Accepts https:// URLs for media loading")
    internal func acceptHTTPSURLs() {
        internal let httpsURL = URL(string: "https://example.com/image.jpg")!
        #expect(URLValidator.isAllowedMediaURL(httpsURL))
    }

    @Test("Rejects javascript: URLs")
    internal func rejectJavaScriptURLs() {
        internal let jsURL = URL(string: "javascript:alert(1)")!
        #expect(!URLValidator.isAllowedMediaURL(jsURL))
    }

    @Test("Rejects data: URLs")
    internal func rejectDataURLs() {
        internal let dataURL = URL(string: "data:text/html,<script>alert('XSS')</script>")!
        #expect(!URLValidator.isAllowedMediaURL(dataURL))
    }

    @Test("Rejects custom scheme URLs")
    internal func rejectCustomSchemes() {
        internal let customURL = URL(string: "myapp://internal/resource")!
        #expect(!URLValidator.isAllowedMediaURL(customURL))
    }

    // MARK: - External URL Validation (HTTP/HTTPS for browser handoff)

    @Test("Rejects file:// URLs for external opens")
    internal func externalRejectFileURLs() {
        internal let fileURL = URL(string: "file:///Applications")!
        #expect(!URLValidator.isAllowedExternalURL(fileURL))
    }

    @Test("Accepts https:// URLs for external opens")
    internal func externalAcceptHTTPSURLs() {
        internal let httpsURL = URL(string: "https://example.com")!
        #expect(URLValidator.isAllowedExternalURL(httpsURL))
    }

    @Test("Accepts http:// URLs for external opens (Safari handles connection)")
    internal func externalAcceptHTTPURLs() {
        internal let httpURL = URL(string: "http://example.com")!
        #expect(URLValidator.isAllowedExternalURL(httpURL))
    }

    // MARK: - Edge Cases

    @Test("Handles URLs with unusual casing")
    internal func handlesCasing() {
        internal let mixedURL = URL(string: "HTTPS://example.com/IMAGE.JPG")!
        #expect(URLValidator.isAllowedMediaURL(mixedURL))

        internal let fileURLCaps = URL(string: "FILE:///etc/passwd")!
        #expect(!URLValidator.isAllowedMediaURL(fileURLCaps))
    }

    @Test("Handles nil scheme URLs")
    internal func handlesNilScheme() {
        // Relative URL has nil scheme
        internal let relativeURL = URL(string: "relative/path")!
        #expect(!URLValidator.isAllowedMediaURL(relativeURL))
    }

    @Test("Convenience method returns nil for invalid URLs")
    internal func convenienceMethodRejectsInvalid() {
        #expect(URLValidator.allowedMediaURL(from: "file:///etc/passwd") == nil)
        #expect(URLValidator.allowedMediaURL(from: "http://example.com") == nil)
    }

    @Test("Convenience method returns URL for valid HTTPS")
    internal func convenienceMethodAcceptsValid() {
        internal let result = URLValidator.allowedMediaURL(from: "https://example.com/image.jpg")
        #expect(result != nil)
        #expect(result?.absoluteString == "https://example.com/image.jpg")
    }
}
