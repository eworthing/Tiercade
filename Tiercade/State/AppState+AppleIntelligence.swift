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

// MARK: - Shared Instructions Factory

#if canImport(FoundationModels)
/// Create instructions with strong anti-duplicate rules for list generation.
///
/// These instructions are used across all AI generation contexts (wizard, chat)
/// to ensure consistent duplicate prevention behavior.
@available(iOS 26.0, macOS 26.0, *)
internal func makeAntiDuplicateInstructions() -> Instructions {
    Instructions("""
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
}
#endif

// MARK: - Apple Intelligence Chat State
@MainActor
internal extension AppState {
    /// Toggle AI chat overlay visibility
    internal func toggleAIChat() {
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
    internal func closeAIChat() {
        showAIChat = false
        logEvent("🤖 Apple Intelligence chat closed")
    }

    #if DEBUG
    /// Add a test console message (for streaming test progress)
    internal func appendTestMessage(_ content: String) {
        testConsoleMessages.append(AIChatMessage(content: content, isUser: false))
    }

    /// Clear test console messages
    internal func clearTestMessages() {
        testConsoleMessages.removeAll()
    }
    #endif
}// MARK: - Chat Message Model
internal struct AIChatMessage: Identifiable, Sendable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date

    internal init(content: String, isUser: Bool) {
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

    // DEBUG/runtime toggles for advanced list generation (coordinator-based)
    var useLeadingToolchain: Bool = false
    var hybridSwitchEnabled: Bool = false
    var guidedBudgetBumpFirst: Bool = true
    var showStepByStep: Bool = false
    // Prompt A/B style for UniqueListCoordinator
    enum PromptAB: String { case strict, minimal }
    var promptStyle: PromptAB = .strict

    // Last-run context for rating/export
    var lastGeneratedItems: [String]? = nil
    var lastRunDiagnosticsJSON: String? = nil
    var lastUserQuery: String? = nil

    internal static let maxContextTokens = 4096
    internal static let instructionsTokenEstimate = 100 // Estimated tokens for our strong anti-duplicate instructions

    internal static var isSupportedOnCurrentPlatform: Bool {
        // Show button on platforms where Apple Intelligence is available
        #if os(iOS) || os(iPadOS) || os(macOS) || os(visionOS)
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
            let instructions = makeAntiDuplicateInstructions()
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
    internal func sendMessage(_ text: String) async {
        lastUserQuery = text
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

        // Standard response path (re-ensure session in case advanced path reset it)
        _ = ensureSessionAvailable()
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
            var detection = detectListRequest(text)
            // If user toggled leading toolchain, default to N=50 when no explicit count
            if useLeadingToolchain, detection.count == nil {
                detection = (isListRequest: true, count: 50)
            }
            if (useLeadingToolchain || detection.isListRequest), let count = detection.count {
                print("🤖 [AI] 🧪 POC: Detected list request for \(count) items")
                print("🤖 [AI] 🧪 POC: Using advanced UniqueListCoordinator")

                do {
                    // Start a fresh session to avoid transcript bloat/hangs between runs
                    resetSessionWithSummary()
                    // Recreate session immediately after reset so advanced path has an active session
                    ensureSession()
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
    internal func clearHistory() {
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
            if self.showStepByStep {
                self.messages.append(AIChatMessage(content: message, isUser: false))
            } else if UniqueListGenerationFlags.verboseLogging {
                print("🤖 [UniqueList] \(message)")
            }
        }

        // Choose coordinator options based on desired count and runtime toggles
        var enableHybrid = hybridSwitchEnabled
        var bumpFirst = guidedBudgetBumpFirst
        if count <= 50 {
            // For medium-N, prefer guided + budget bump, hybrid off by default
            enableHybrid = false
            bumpFirst = true
        } else if count > 50 {
            // For large-N, allow hybrid switch with budget bump
            enableHybrid = true
            bumpFirst = true
        }

        let coordinator = UniqueListCoordinator(
            fm: fm,
            logger: { message in
                if self.showStepByStep {
                    self.messages.append(AIChatMessage(content: message, isUser: false))
                } else if UniqueListGenerationFlags.verboseLogging {
                    print(message)
                }
            },
            useGuidedBackfill: true,
            hybridSwitchEnabled: enableHybrid,
            guidedBudgetBumpFirst: bumpFirst,
            promptStyle: (self.promptStyle == .minimal ? .minimal : .strict)
        )

        let items = try await coordinator.uniqueList(query: query, targetCount: count, seed: nil)
        // Capture last-run context for rating/export
        self.lastGeneratedItems = items
        let d = coordinator.getDiagnostics()
        let diagDict: [String: Any?] = [
            "totalGenerated": d.totalGenerated,
            "dupCount": d.dupCount,
            "dupRate": d.dupRate,
            "backfillRounds": d.backfillRounds,
            "circuitBreakerTriggered": d.circuitBreakerTriggered,
            "passCount": d.passCount,
            "failureReason": d.failureReason,
            "topDuplicates": d.topDuplicates
        ]
        if let data = try? JSONSerialization.data(withJSONObject: diagDict.compactMapValues { $0 }, options: []),
           let s = String(data: data, encoding: .utf8) {
            self.lastRunDiagnosticsJSON = s
        }

        // Format as numbered list for chat display
        let formatted = items.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        return formatted
    }

    // MARK: - Ratings
    internal func rateLastRun(upvote: Bool) {
        guard let items = lastGeneratedItems, let query = lastUserQuery else {
            messages.append(AIChatMessage(content: "⚠️ No recent run to rate.", isUser: false))
            return
        }
        let payload: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "upvote": upvote,
            "query": query,
            "items": items,
            "promptStyle": promptStyle.rawValue,
            "diagnostics": lastRunDiagnosticsJSON ?? "{}"
        ]
        do {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ai_quality_ratings.jsonl")
            let data = try JSONSerialization.data(withJSONObject: payload)
            if let fh = try? FileHandle(forWritingTo: url) {
                try fh.seekToEnd()
                try fh.write(data)
                try fh.write(Data("\n".utf8))
                try fh.close()
            } else {
                try (data + Data("\n".utf8)).write(to: url)
            }
            messages.append(AIChatMessage(content: upvote ? "👍 Rated this run as GOOD" : "👎 Rated this run as NEEDS WORK", isUser: false))
        } catch {
            messages.append(AIChatMessage(content: "⚠️ Failed to save rating: \(error.localizedDescription)", isUser: false))
        }
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

    // MARK: - Wizard List Generation

    /// Reuse existing UniqueListCoordinator for tier list wizard item generation.
    ///
    /// This wrapper instantiates the coordinator with the existing session and calls
    /// `uniqueList(query:targetCount:)` to generate unique items. Progress updates
    /// are handled by the caller via `withLoadingIndicator`.
    ///
    /// - Parameters:
    ///   - query: Natural language description of items to generate
    ///   - count: Target number of items (5-100)
    /// - Returns: Array of unique item names
    /// - Throws: Error if generation fails or platform is unsupported
    ///
    /// - Note: Only available on macOS/iOS 26+ with FoundationModels framework
    @available(iOS 26.0, macOS 26.0, *)
    internal func generateUniqueListForWizard(query: String, count: Int) async throws -> [String] {
        if #available(iOS 26.0, macOS 26.0, *) {
            ensureSession()
            guard let session else {
                throw NSError(
                    domain: "AIGeneration",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No active AI session"]
                )
            }

            let fm = FMClient(session: session, logger: { _ in })
            let coordinator = UniqueListCoordinator(
                fm: fm,
                logger: { _ in },
                useGuidedBackfill: true,
                hybridSwitchEnabled: false,
                guidedBudgetBumpFirst: false,
                promptStyle: .strict
            )

            return try await coordinator.uniqueList(query: query, targetCount: count, seed: nil)
        } else {
            throw NSError(
                domain: "AIGeneration",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "AI generation requires macOS or iOS 26+"]
            )
        }
    }
    #endif
}
