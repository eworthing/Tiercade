import Foundation
import Observation
import os
import SwiftUI
import TiercadeCore

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AIGenerationState

/// Consolidated state for Apple Intelligence chat and AI generation
///
/// This state object encapsulates all AI-related functionality including:
/// - Chat overlay visibility and messages
/// - AI item generation for the wizard
/// - LanguageModel session management
/// - Token estimation and context management
@MainActor
@Observable
final class AIGenerationState {

    // MARK: Lifecycle

    // MARK: - Initialization

    init(listGenerator: UniqueListGenerating) {
        self.listGenerator = listGenerator
        Logger.aiGeneration.info("AIGenerationState initialized")
    }

    // MARK: Internal

    // MARK: - Constants

    static let maxContextTokens = 4096
    static let instructionsTokenEstimate = 100

    // MARK: - Platform Availability

    static var isSupportedOnCurrentPlatform: Bool {
        #if os(iOS) || os(iPadOS) || os(macOS) || os(visionOS)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Chat Overlay State

    /// Whether the AI chat overlay is visible
    var showAIChat: Bool = false

    /// Chat messages history
    var messages: [AIChatMessage] = []

    /// Whether the AI is currently processing a request
    var isProcessing: Bool = false

    /// Estimated token count for context management
    var estimatedTokenCount: Int = 0

    // MARK: - Wizard Integration State

    /// Current AI generation request from the wizard
    var aiGenerationRequest: AIGenerationRequest?

    /// AI-generated item candidates awaiting user review
    var aiGeneratedCandidates: [AIGeneratedItemCandidate] = []

    /// Whether AI generation is in progress for the wizard
    var aiGenerationInProgress: Bool = false

    // MARK: - Advanced Generation Settings (DEBUG/POC)

    #if DEBUG
    /// Test console messages for streaming test progress
    var testConsoleMessages: [AIChatMessage] = []

    /// Use leading toolchain for advanced generation
    var useLeadingToolchain: Bool = false

    /// Enable hybrid switch for coordinator experiments
    var hybridSwitchEnabled: Bool = false

    /// Enable guided budget bump first strategy
    var guidedBudgetBumpFirst: Bool = true

    /// Show step-by-step generation progress
    var showStepByStep: Bool = false

    /// Prompt style for UniqueListCoordinator
    enum PromptAB: String { case strict, minimal }
    var promptStyle: PromptAB = .strict

    /// Last generated items for rating/export
    var lastGeneratedItems: [String]?

    /// Last run diagnostics JSON for debugging
    var lastRunDiagnosticsJSON: String?

    /// Last user query for reference
    var lastUserQuery: String?
    #endif

    // MARK: - Chat Overlay Actions

    /// Toggle AI chat overlay visibility
    func toggleAIChat(
        showToast: @escaping (ToastType, String, String) -> Void,
        logEvent: @escaping (String) -> Void,
    ) {
        guard Self.isSupportedOnCurrentPlatform else {
            if showAIChat {
                showAIChat = false
            }
            showToast(.info, "Unavailable", "Apple Intelligence chat isn't supported on this platform.")
            return
        }

        #if !canImport(FoundationModels)
        showToast(.info, "Not Available", "Apple Intelligence requires FoundationModels framework (macOS 26+).")
        return
        #endif

        showAIChat.toggle()
        if showAIChat {
            logEvent("🤖 Apple Intelligence chat opened")
        }
    }

    /// Close AI chat overlay
    func closeAIChat(logEvent: @escaping (String) -> Void) {
        showAIChat = false
        logEvent("🤖 Apple Intelligence chat closed")
    }

    // MARK: - Message Sending

    /// Send a message to Apple Intelligence
    func sendMessage(_ text: String) async {
        // Sanitize user input to mitigate prompt injection attacks
        let sanitizedText = PromptValidator.sanitize(text)

        #if DEBUG
        lastUserQuery = sanitizedText
        #endif

        Logger.aiGeneration.debug("sendMessage START")
        Logger.aiGeneration.debug("Message count: \(self.messages.count)")
        Logger.aiGeneration.debug("Estimated tokens: \(self.estimatedTokenCount)")

        // Append user message immediately (display original for transparency)
        messages.append(AIChatMessage(content: sanitizedText, isUser: true))
        updateTokenEstimate()

        isProcessing = true
        defer {
            isProcessing = false
            Logger.aiGeneration.debug("isProcessing set to false")
        }

        #if canImport(FoundationModels)
        // Stub path: infrastructure is in place; full FoundationModels
        // integration will be implemented in a follow-up.
        // Provide a placeholder response for now.
        try? await Task.sleep(for: .seconds(0.5))
        let stubMsg = "AI generation infrastructure is set up. " +
            "Full FoundationModels integration will be added in a follow-up."
        messages.append(AIChatMessage(content: stubMsg, isUser: false))
        updateTokenEstimate()
        Logger.aiGeneration.debug("sendMessage END")
        #else
        messages.append(AIChatMessage(
            content: "Apple Intelligence requires FoundationModels framework (macOS 26+).",
            isUser: false,
        ))
        updateTokenEstimate()
        #endif
    }

    /// Clear chat history
    func clearHistory() {
        messages.removeAll()
        estimatedTokenCount = 0
        Logger.aiGeneration.info("Cleared chat history")
    }

    #if DEBUG
    /// Add a test console message (for streaming test progress)
    func appendTestMessage(_ content: String) {
        testConsoleMessages.append(AIChatMessage(content: content, isUser: false))
    }

    /// Clear test console messages
    func clearTestMessages() {
        testConsoleMessages.removeAll()
    }
    #endif

    // MARK: Private

    // MARK: - Dependencies

    private let listGenerator: UniqueListGenerating

    // MARK: - FoundationModels Session

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    // MARK: - Token Estimation

    /// Estimate token count from text (roughly 3-4 chars per token for English)
    private func estimateTokens(from text: String) -> Int {
        // Conservative estimate: 3 characters per token
        max(1, text.count / 3)
    }

    /// Update estimated token count based on current messages
    private func updateTokenEstimate() {
        var total = Self.instructionsTokenEstimate // System instructions

        for message in messages {
            total += estimateTokens(from: message.content)
        }

        estimatedTokenCount = total
        Logger.aiGeneration.debug("Estimated tokens: \(self.estimatedTokenCount)/\(Self.maxContextTokens)")
    }

    // MARK: - Session Management

    #if canImport(FoundationModels)
    private func ensureSession() {
        if session == nil {
            let instructions = makeAntiDuplicateInstructions()
            session = LanguageModelSession(model: .default, tools: [], instructions: instructions)
            Logger.aiGeneration.info("Created new LanguageModelSession")
        }
    }
    #endif

}

// MARK: - AIChatMessage

/// Chat message model
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

// Note: makeAntiDuplicateInstructions() is defined in State/AppState+AppleIntelligence.swift
// and is shared across all AI generation contexts
