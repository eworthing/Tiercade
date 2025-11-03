import Testing
import Foundation
@testable import Tiercade

/// Security tests for URL validation to prevent SSRF and file disclosure attacks
@Suite("URL Validation Security Tests")
struct URLValidationTests {

    // MARK: - Media URL Validation (HTTPS-only)

    @Test("Rejects file:// URLs for media loading")
    func rejectFileURLs() {
        let fileURL = URL(string: "file:///etc/passwd")!
        #expect(!URLValidator.isAllowedMediaURL(fileURL))
    }

    @Test("Rejects ftp:// URLs for media loading")
    func rejectFTPURLs() {
        let ftpURL = URL(string: "ftp://example.com/image.jpg")!
        #expect(!URLValidator.isAllowedMediaURL(ftpURL))
    }

    @Test("Rejects http:// URLs for media loading (requires HTTPS)")
    func rejectHTTPURLs() {
        let httpURL = URL(string: "http://example.com/image.jpg")!
        #expect(!URLValidator.isAllowedMediaURL(httpURL))
    }

    @Test("Accepts https:// URLs for media loading")
    func acceptHTTPSURLs() {
        let httpsURL = URL(string: "https://example.com/image.jpg")!
        #expect(URLValidator.isAllowedMediaURL(httpsURL))
    }

    @Test("Rejects javascript: URLs")
    func rejectJavaScriptURLs() {
        let jsURL = URL(string: "javascript:alert(1)")!
        #expect(!URLValidator.isAllowedMediaURL(jsURL))
    }

    @Test("Rejects data: URLs")
    func rejectDataURLs() {
        let dataURL = URL(string: "data:text/html,<script>alert('XSS')</script>")!
        #expect(!URLValidator.isAllowedMediaURL(dataURL))
    }

    @Test("Rejects custom scheme URLs")
    func rejectCustomSchemes() {
        let customURL = URL(string: "myapp://internal/resource")!
        #expect(!URLValidator.isAllowedMediaURL(customURL))
    }

    // MARK: - External URL Validation (HTTPS-only for links)

    @Test("Rejects file:// URLs for external opens")
    func externalRejectFileURLs() {
        let fileURL = URL(string: "file:///Applications")!
        #expect(!URLValidator.isAllowedExternalURL(fileURL))
    }

    @Test("Accepts https:// URLs for external opens")
    func externalAcceptHTTPSURLs() {
        let httpsURL = URL(string: "https://example.com")!
        #expect(URLValidator.isAllowedExternalURL(httpsURL))
    }

    // MARK: - Edge Cases

    @Test("Handles URLs with unusual casing")
    func handlesCasing() {
        let mixedURL = URL(string: "HTTPS://example.com/IMAGE.JPG")!
        #expect(URLValidator.isAllowedMediaURL(mixedURL))

        let fileURLCaps = URL(string: "FILE:///etc/passwd")!
        #expect(!URLValidator.isAllowedMediaURL(fileURLCaps))
    }

    @Test("Handles nil scheme URLs")
    func handlesNilScheme() {
        // Relative URL has nil scheme
        let relativeURL = URL(string: "relative/path")!
        #expect(!URLValidator.isAllowedMediaURL(relativeURL))
    }

    @Test("Convenience method returns nil for invalid URLs")
    func convenienceMethodRejectsInvalid() {
        #expect(URLValidator.allowedMediaURL(from: "file:///etc/passwd") == nil)
        #expect(URLValidator.allowedMediaURL(from: "http://example.com") == nil)
    }

    @Test("Convenience method returns URL for valid HTTPS")
    func convenienceMethodAcceptsValid() {
        let result = URLValidator.allowedMediaURL(from: "https://example.com/image.jpg")
        #expect(result != nil)
        #expect(result?.absoluteString == "https://example.com/image.jpg")
    }
}
