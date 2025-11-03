import Foundation

/// Sanitizes user input before embedding in AI prompts to mitigate prompt injection attacks
public struct PromptValidator {

    /// Sanitizes user input for safe inclusion in prompts
    /// - Parameter input: Raw user input string
    /// - Returns: Sanitized string safe for prompt inclusion
    ///
    /// Mitigations:
    /// - Removes control characters that could interfere with prompt parsing
    /// - Limits excessive punctuation patterns often used in injection attacks
    /// - Truncates to reasonable length to prevent context window manipulation
    /// - Normalizes whitespace
    public static func sanitize(_ input: String) -> String {
        var clean = input

        // 1. Remove control characters (except basic whitespace)
        clean = clean.filter { char in
            !char.unicodeScalars.contains(where: { scalar in
                // Keep space, tab, newline
                if scalar == " " || scalar == "\t" || scalar == "\n" {
                    return false
                }
                return CharacterSet.controlCharacters.contains(scalar)
            })
        }

        // 2. Limit excessive punctuation (common injection pattern: "!!!!!!", ".......")
        // Replace 3+ consecutive punctuation with just 2
        let punctuationPattern = "([!?.]){3,}"
        if let regex = try? NSRegularExpression(pattern: punctuationPattern, options: []) {
            let range = NSRange(clean.startIndex..., in: clean)
            clean = regex.stringByReplacingMatches(
                in: clean,
                options: [],
                range: range,
                withTemplate: "$1$1"
            )
        }

        // 3. Normalize whitespace (collapse multiple spaces/newlines)
        clean = clean.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // 4. Truncate to reasonable length (500 chars for topic descriptions)
        let maxLength = 500
        if clean.count > maxLength {
            clean = String(clean.prefix(maxLength))
        }

        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Validates and sanitizes a topic string for list generation
    /// - Parameter topic: User-provided topic description
    /// - Returns: Sanitized topic safe for prompt inclusion
    /// - Throws: `ValidationError` if topic is empty after sanitization
    public static func validateTopic(_ topic: String) throws -> String {
        let sanitized = sanitize(topic)

        guard !sanitized.isEmpty else {
            throw ValidationError.emptyInput
        }

        return sanitized
    }

    /// Validation errors
    public enum ValidationError: Error, LocalizedError {
        case emptyInput

        public var errorDescription: String? {
            switch self {
            case .emptyInput:
                return "Topic cannot be empty"
            }
        }
    }
}
