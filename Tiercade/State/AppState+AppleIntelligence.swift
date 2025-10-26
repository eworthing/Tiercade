import Foundation
import SwiftUI
import Observation
import TiercadeCore

#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(AppIntents)
import AppIntents
#endif

// MARK: - Apple Intelligence Chat State
@MainActor
extension AppState {
    /// Toggle AI chat overlay visibility
    func toggleAIChat() {
        guard AppleIntelligenceService.isSupportedOnCurrentPlatform else {
            if showAIChat { showAIChat = false }
            showToast(
                type: .info,
                title: "Unavailable",
                message: "Apple Intelligence chat isn't supported on this platform."
            )
            return
        }

        #if !canImport(FoundationModels)
        // FoundationModels not available at compile time (e.g., Catalyst SDK limitation)
        showToast(
            type: .info,
            title: "Not Available",
            message: "Apple Intelligence requires FoundationModels framework (macOS 26+)."
        )
        return
        #endif

        showAIChat.toggle()
        if showAIChat {
            logEvent("🤖 Apple Intelligence chat opened")
        }
    }

    /// Close AI chat overlay
    func closeAIChat() {
        showAIChat = false
        logEvent("🤖 Apple Intelligence chat closed")
    }
}// MARK: - Chat Message Model
struct AIChatMessage: Identifiable, Sendable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date

    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }
}

// MARK: - Apple Intelligence Service (real integration where available)
@MainActor
@Observable
final class AppleIntelligenceService {
    var messages: [AIChatMessage] = []
    var isProcessing = false
    var estimatedTokenCount: Int = 0

    static let maxContextTokens = 4096
    static let instructionsTokenEstimate = 100 // Estimated tokens for our strong anti-duplicate instructions

    static var isSupportedOnCurrentPlatform: Bool {
        // Show button on platforms where Apple docs indicate FoundationModels should be available
        // even if framework isn't accessible at compile time (e.g., Catalyst SDK limitation)
        #if os(iOS) || os(iPadOS) || os(macOS) || targetEnvironment(macCatalyst) || os(visionOS)
        return true
        #else
        return false
        #endif
    }

    /// Estimate token count from text (roughly 3-4 chars per token for English)
    private func estimateTokens(from text: String) -> Int {
        // Conservative estimate: 3 characters per token
        return max(1, text.count / 3)
    }

    /// Update estimated token count based on current messages
    private func updateTokenEstimate() {
        var total = Self.instructionsTokenEstimate // System instructions

        for message in messages {
            total += estimateTokens(from: message.content)
        }

        estimatedTokenCount = total
        print("🤖 [AI] Estimated tokens: \(estimatedTokenCount)/\(Self.maxContextTokens)")
    }

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?

    private func ensureSession() {
        if session == nil {
            let instructions = Instructions("""
            You are a helpful assistant. Answer questions clearly and concisely.

            CRITICAL RULES FOR LISTS:
            - NEVER repeat any item in a list
            - ALWAYS check if an item was already mentioned before adding it
            - If asked for N items, provide EXACTLY N UNIQUE items
            - Stop immediately after reaching the requested number
            - Do NOT continue generating after the list is complete

            Example of CORRECT list (no repeats):
            1. Item A
            2. Item B
            3. Item C

            Example of INCORRECT list (has repeats - NEVER DO THIS):
            1. Item A
            2. Item B
            3. Item A ← WRONG! Already listed
            """)
            session = LanguageModelSession(model: .default, tools: [], instructions: instructions)
            print("🤖 [AI] Created new LanguageModelSession with STRONG anti-duplicate instructions")
        }
    }
    #endif

    /// Deduplicate numbered list items in response
    private func deduplicateListItems(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var seenItems = Set<String>()
        var result: [String] = []
        var foundDuplicates = false

        for line in lines {
            // Check if this is a numbered list item (e.g., "1. Item" or "1) Item" or "1 Item")
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let range = trimmed.range(of: #"^\d+[\.)]\s*"#, options: .regularExpression) {
                // Extract the content after the number
                let content = String(trimmed[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()

                // Check for duplicate (case-insensitive comparison)
                if seenItems.contains(content) {
                    foundDuplicates = true
                    print("🤖 [AI] Filtered duplicate: \(content)")
                    continue // Skip this duplicate
                } else {
                    seenItems.insert(content)
                    result.append(line)
                }
            } else {
                // Not a list item, keep as-is
                result.append(line)
            }
        }

        if foundDuplicates {
            print("🤖 [AI] Removed \(lines.count - result.count) duplicate list items")
        }

        return result.joined(separator: "\n")
    }

    /// Send a message to Apple Intelligence
    func sendMessage(_ text: String) async {
        logSendMessageStart()

        // Append user message immediately
        messages.append(AIChatMessage(content: text, isUser: true))
        updateTokenEstimate()

        isProcessing = true
        defer {
            isProcessing = false
            print("🤖 [AI] isProcessing set to false")
        }

        #if canImport(FoundationModels)
        // Check model availability and ensure session
        guard validateModelAvailability() else { return }
        guard ensureSessionAvailable() else { return }

        // Try advanced list generation if enabled (POC)
        if await tryAdvancedListGeneration(text: text) { return }

        // Standard response path
        await executeStandardResponse(text: text)
        print("🤖 [AI] ===== sendMessage END =====")
        #else
        handleFoundationModelsUnavailable()
        #endif
    }

    private func logSendMessageStart() {
        print("🤖 [AI] ===== sendMessage START =====")
        print("🤖 [AI] Message count before: \(messages.count)")
        print("🤖 [AI] Estimated tokens before: \(estimatedTokenCount)")
    }

    #if canImport(FoundationModels)
    /// Validate that the Apple Intelligence model is available
    /// - Returns: true if available and can proceed, false if unavailable (error message added)
    private func validateModelAvailability() -> Bool {
        print("🤖 [AI] Checking model availability...")
        // Check system model availability (iOS/iPadOS/macOS/Catalyst/visionOS 26+)
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            print("🤖 [AI] Model is available ✓")
            return true
        case .unavailable(let reason):
            print("🤖 [AI] ❌ Model unavailable: \(reason)")
            messages.append(AIChatMessage(content: availabilityExplanation(for: reason), isUser: false))
            updateTokenEstimate()
            return false
        }
    }

    /// Ensure session is created and available
    /// - Returns: true if session exists, false if creation failed (error message added)
    private func ensureSessionAvailable() -> Bool {
        ensureSession()
        guard session != nil else {
            print("🤖 [AI] ❌ Failed to create session")
            messages.append(AIChatMessage(content: "Apple Intelligence session couldn't be created.", isUser: false))
            updateTokenEstimate()
            return false
        }

        print("🤖 [AI] Session exists ✓")
        print("🤖 [AI] Session.isResponding: \(session!.isResponding)")
        return true
    }

    /// Try advanced list generation if enabled (EXPERIMENTAL POC)
    /// - Returns: true if advanced generation was used and completed, false to fall through to standard path
    private func tryAdvancedListGeneration(text: String) async -> Bool {
        // EXPERIMENTAL: Try advanced list generation if enabled (POC)
        if #available(iOS 26.0, macOS 26.0, *),
           UniqueListGenerationFlags.enableAdvancedGeneration {
            let detection = detectListRequest(text)
            if detection.isListRequest, let count = detection.count {
                print("🤖 [AI] 🧪 POC: Detected list request for \(count) items")
                print("🤖 [AI] 🧪 POC: Using advanced UniqueListCoordinator")

                do {
                    let result = try await generateUniqueList(query: text, count: count)
                    messages.append(AIChatMessage(content: result, isUser: false))
                    updateTokenEstimate()
                    print("🤖 [AI] 🧪 POC: Advanced generation succeeded")
                    print("🤖 [AI] ===== sendMessage END (POC path) =====")
                    return true
                } catch {
                    print("🤖 [AI] ⚠️ POC: Advanced generation failed, falling back to standard: \(error)")
                    // Fall through to standard path
                }
            }
        }
        return false
    }

    /// Execute standard response flow using session.respond()
    private func executeStandardResponse(text: String) async {
        guard let session else { return }

        do {
            let startTime = Date()
            print("🤖 [AI] Calling session.respond() at \(startTime)...")
            print("🤖 [AI] Prompt text: \"\(text)\"")

            let response = try await session.respond(to: Prompt(text))

            logResponseReceived(response: response, startTime: startTime)

            // Apply deduplication filter to remove duplicate list items
            let deduplicated = deduplicateListItems(response.content)
            messages.append(AIChatMessage(content: deduplicated, isUser: false))
            updateTokenEstimate()
            print("🤖 [AI] Message count after: \(messages.count)")
            print("🤖 [AI] Estimated tokens after: \(estimatedTokenCount)")
        } catch let error as LanguageModelSession.GenerationError {
            await handleGenerationError(error, originalText: text)
        } catch {
            handleUnexpectedError(error)
        }
    }

    private func logResponseReceived(response: LanguageModelSession.Response<String>, startTime: Date) {
        let elapsed = Date().timeIntervalSince(startTime)
        print("🤖 [AI] ✓ Received response after \(String(format: "%.2f", elapsed))s")
        print("🤖 [AI] Response content: \"\(response.content)\"")
        print("🤖 [AI] Response length: \(response.content.count) chars")
    }

    /// Handle LanguageModelSession.GenerationError cases
    private func handleGenerationError(_ error: LanguageModelSession.GenerationError, originalText: String) async {
        print("🤖 [AI] ❌ GenerationError caught: \(error)")
        print("🤖 [AI] Error description: \(error.localizedDescription)")
        print("🤖 [AI] Error type: \(type(of: error))")

        // Handle context window overflow by resetting the session
        if case .exceededContextWindowSize = error {
            print("🤖 [AI] Context window exceeded - resetting session")
            // Remove the user message we just added (will be re-added on retry)
            if messages.last?.isUser == true {
                messages.removeLast()
            }
            resetSessionWithSummary()
            messages.append(AIChatMessage(
                content: "Context window limit reached. Continuing with a fresh session...",
                isUser: false
            ))
            updateTokenEstimate()
            // Retry the current message with new session
            print("🤖 [AI] Retrying with new session...")
            await sendMessage(originalText)
            return
        }

        // Check for other specific error types
        print("🤖 [AI] Checking error cases...")
        switch error {
        case .refusal(let refusal, _):
            print("🤖 [AI] Refusal error: \(refusal)")
            messages.append(
                AIChatMessage(content: "Request refused: \(String(describing: refusal))", isUser: false)
            )
        case .rateLimited:
            print("🤖 [AI] Rate limited!")
            messages.append(
                AIChatMessage(content: "Rate limited. Please wait a moment and try again.", isUser: false)
            )
        case .concurrentRequests:
            print("🤖 [AI] Concurrent requests error")
            messages.append(
                AIChatMessage(content: "Please wait for the current request to complete.", isUser: false)
            )
        default:
            print("🤖 [AI] Other generation error")
            messages.append(
                AIChatMessage(content: "Generation failed: \(error.localizedDescription)", isUser: false)
            )
        }
        updateTokenEstimate()
    }

    private func handleUnexpectedError(_ error: Error) {
        print("🤖 [AI] ❌ Unexpected error type: \(type(of: error))")
        print("🤖 [AI] Error: \(error)")
        print("🤖 [AI] Error description: \(error.localizedDescription)")
        messages.append(AIChatMessage(content: "Unexpected error: \(error.localizedDescription)", isUser: false))
        updateTokenEstimate()
    }
    #endif

    private func handleFoundationModelsUnavailable() {
        print("🤖 [AI] FoundationModels not available at compile time")
        // Platform does not provide FoundationModels (e.g., tvOS)
        messages.append(AIChatMessage(
            content: "Apple Intelligence is not available on this platform.",
            isUser: false
        ))
        updateTokenEstimate()
    }

    #if canImport(FoundationModels)
    private func availabilityExplanation(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "Apple Intelligence isn't supported on this device."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is turned off. Enable it in Settings to use chat."
        case .modelNotReady:
            return "The on-device model isn't ready yet (downloading or preparing). Please try again."
        @unknown default:
            return "Apple Intelligence is currently unavailable."
        }
    }
    #endif

    /// Clear all messages
    func clearHistory() {
        messages.removeAll()
        estimatedTokenCount = 0
        resetSession()
    }

    /// Reset the session (for context window management)
    private func resetSession() {
        #if canImport(FoundationModels)
        session = nil
        print("🤖 [AI] Session reset")
        #endif
    }

    /// Reset session while preserving conversation context
    private func resetSessionWithSummary() {
        #if canImport(FoundationModels)
        // Keep only the last few messages to maintain context
        let recentMessageCount = 4 // Keep last 2 exchanges (4 messages)
        if messages.count > recentMessageCount {
            let recentMessages = Array(messages.suffix(recentMessageCount))
            messages = recentMessages
        }
        session = nil
        updateTokenEstimate()
        print("🤖 [AI] Session reset with \(messages.count) recent messages preserved")
        #endif
    }

    // MARK: - Advanced List Generation (POC)

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    /// EXPERIMENTAL: Generate unique list using advanced coordinator
    /// Only called when UniqueListGenerationFlags.enableAdvancedGeneration is true
    private func generateUniqueList(query: String, count: Int) async throws -> String {
        guard let session else {
            throw NSError(domain: "AppleIntelligenceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No active session"])
        }

        let fm = FMClient(session: session) { message in
            if UniqueListGenerationFlags.verboseLogging {
                print("🤖 [UniqueList] \(message)")
            }
        }

        let coordinator = UniqueListCoordinator(fm: fm) { message in
            if UniqueListGenerationFlags.verboseLogging {
                print("🤖 [Coordinator] \(message)")
            }
        }

        let items = try await coordinator.uniqueList(query: query, targetCount: count, seed: nil)

        // Format as numbered list for chat display
        let formatted = items.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        return formatted
    }

    /// Detect if user message is requesting a list and extract count
    private func detectListRequest(_ text: String) -> (isListRequest: Bool, count: Int?) {
        let lower = text.lowercased()

        // Common list request patterns
        let listPatterns = [
            #"(?:give|tell|show|list|name)\s+(?:me\s+)?(\d+)"#,
            #"(\d+)\s+(?:examples?|items?|things?|names?)"#,
            #"top\s+(\d+)"#
        ]

        for pattern in listPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let countRange = Range(match.range(at: 1), in: text),
               let count = Int(text[countRange]) {
                return (true, count)
            }
        }

        return (false, nil)
    }
    #endif
}
