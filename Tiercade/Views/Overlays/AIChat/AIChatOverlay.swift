import SwiftUI

// swiftlint:disable file_length type_body_length
// Prototype AI chat overlay - comprehensive UI for testing justifies complexity

#if canImport(ImagePlayground)
import ImagePlayground
#endif

#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

@MainActor
internal struct AIChatOverlay: View {
    @Environment(AppState.self) var app: AppState
    @Bindable var ai: AIGenerationState
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    // swiftlint:disable:next private_swiftui_state - Accessed from AIChatOverlay+ImageGeneration.swift
    @State var showImagePreview = false
    // swiftlint:disable:next private_swiftui_state - Accessed from AIChatOverlay+ImageGeneration.swift
    @State var generatedImage: Image?
    @State private var isGeneratingImage = false
    @State private var showTestSuitePicker = false
    #if DEBUG
    @State private var useLeadingToolchain = false
    @State private var showSteps = false
    @State private var useMinimalPrompt = false
    #endif

    internal var body: some View {
        VStack(spacing: 0) {
            header
            messagesSection
            inputBar
        }
        .frame(maxWidth: ScaledDimensions.overlayMaxWidth, maxHeight: ScaledDimensions.overlayMaxHeight)
        .background(Palette.bg.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Palette.brand.opacity(0.25), lineWidth: 1) }
        .shadow(radius: 20)
        .onAppear { isInputFocused = true }
        #if os(tvOS)
        .focusSection()
        .onExitCommand { app.closeAIChat() }
        #endif
        .sheet(isPresented: $showImagePreview) {
            if let generatedImage {
                ImagePreviewSheet(image: generatedImage, onDismiss: { showImagePreview = false })
            }
        }
        #if DEBUG && os(macOS)
        .sheet(isPresented: $showTestSuitePicker) {
            TestSuitePickerSheet(onSelectSuite: { suiteId in
                showTestSuitePicker = false
                runUnifiedTestSuite(suiteId: suiteId)
            }, onDismiss: { showTestSuitePicker = false })
        }
        #endif
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Intelligence")
                    .font(.title2)
                    .foregroundStyle(.primary)
                tokenCounter
            }
            Spacer()

            #if DEBUG
            Button {
                showTestSuitePicker = true
            } label: {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select test suite")
            .accessibilityIdentifier("AIChat_TestSuitePicker")

            Button(action: runUnifiedTests) {
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundStyle(.purple)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Run unified test suite")
            .accessibilityIdentifier("AIChat_UnifiedTests")

            Toggle(isOn: $useMinimalPrompt) {
                Text("A/B Prompt")
                    .font(.caption)
                    .foregroundStyle(useMinimalPrompt ? .green : .secondary)
            }
            #if !os(tvOS)
            .toggleStyle(.switch)
            #endif
            .onChange(of: useMinimalPrompt) { _, newValue in
                ai.promptStyle = newValue ? .minimal : .strict
                let style = newValue ? "🧪 Prompt style: Minimal JSON" : "🧪 Prompt style: Strict JSON"
                ai.messages.append(AIChatMessage(content: style, isUser: false))
            }
            .accessibilityIdentifier("AIChat_PromptABToggle")
            .accessibilityLabel("Toggle A/B prompt style")

            Toggle(isOn: $useLeadingToolchain) {
                Image(systemName: useLeadingToolchain ? "bolt.fill" : "bolt")
                    .foregroundStyle(useLeadingToolchain ? .yellow : .secondary)
            }
            #if !os(tvOS)
            .toggleStyle(.button)
            #endif
            .onChange(of: useLeadingToolchain) { _, newValue in
                ai.useLeadingToolchain = newValue
                if newValue {
                    ai.hybridSwitchEnabled = false
                    ai.guidedBudgetBumpFirst = true
                    let msg = "⚙️ Leading toolchain enabled (guided + budget bump; hybrid off ≤50)"
                    ai.messages.append(AIChatMessage(content: msg, isUser: false))
                } else {
                    let msg = "⚙️ Leading toolchain disabled (standard chat)"
                    ai.messages.append(AIChatMessage(content: msg, isUser: false))
                }
            }
            .accessibilityIdentifier("AIChat_ToolchainToggle")
            .accessibilityLabel("Toggle leading toolchain")

            Toggle(isOn: $showSteps) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(showSteps ? .green : .secondary)
            }
            #if !os(tvOS)
            .toggleStyle(.button)
            #endif
            .onChange(of: showSteps) { _, newValue in
                ai.showStepByStep = newValue
                let stepMsg = newValue ? "🔎 Step‑by‑step logging enabled" : "🔎 Step‑by‑step logging disabled"
                ai.messages.append(AIChatMessage(content: stepMsg, isUser: false))
            }
            .accessibilityIdentifier("AIChat_StepToggle")
            .accessibilityLabel("Toggle step-by-step logging")

            Button(action: runCoordinatorExperiments) {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(.teal)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Run coordinator experiments")
            .accessibilityIdentifier("AIChat_CoordinatorExperiments")

            Button(action: runAcceptanceTests) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Run acceptance tests")

            Button(action: runPilotTests) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.cyan)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Run pilot tests")

            Button(action: runPromptTests) {
                Image(systemName: "flask")
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Test system prompts")
            #endif

            Button(action: ai.clearHistory) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear chat history")

            Button(action: app.closeAIChat) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("AIChat_Close")
            .accessibilityLabel("Close")
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .overlay(alignment: .bottom) { Divider().opacity(0.15) }
    }

    @ViewBuilder
    private var tokenCounter: some View {
        let current = ai.estimatedTokenCount
        let max = AIGenerationState.maxContextTokens
        let percentage = Double(current) / Double(max)
        let color: Color = {
            if percentage < 0.5 { return .green }
            if percentage < 0.75 { return .yellow }
            if percentage < 0.9 { return .orange }
            return .red
        }()

        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.caption2)
            Text("\(current) / \(max)")
                .font(.caption)
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .accessibilityLabel("Token usage: \(current) of \(max)")
    }

    @ViewBuilder
    private var messagesSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    messagesContent
                }
                .padding()
            }
            .onChange(of: ai.messages.count) { _, _ in
                guard let last = ai.messages.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
            #if DEBUG
            .onChange(of: ai.testConsoleMessages.count) { _, _ in
                guard let last = ai.testConsoleMessages.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
            #endif
        }
    }

    @ViewBuilder
    private var messagesContent: some View {
        let allMessages: [AIChatMessage] = {
            #if DEBUG
            return ai.messages + ai.testConsoleMessages
            #else
            return ai.messages
            #endif
        }()

        if allMessages.isEmpty {
            emptyState
        } else {
            ForEach(allMessages) { message in
                HStack {
                    if message.isUser { Spacer(minLength: 0) }
                    HStack(spacing: 8) {
                        Text(message.content)
                            .font(.body)
                            .foregroundStyle(.primary)
                            #if !os(tvOS)
                            .textSelection(.enabled)
                        #endif

                        if !message.isUser {
                            Button {
                                copyToClipboard(message.content)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Copy response")
                        }
                    }
                    .padding(12)
                    .background(
                        message.isUser
                            ? Color.purple.opacity(0.25)
                            : Color.white.opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    if !message.isUser { Spacer(minLength: 0) }
                }
                .id(message.id)
            }

            if ai.isProcessing {
                thinkingRow
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(TypeScale.emptyStateIcon)
                .foregroundStyle(.purple.opacity(0.6))
            Text("Ask me anything")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Try: ‘Tell me the captains on all Star Trek series’.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    @ViewBuilder
    private var thinkingRow: some View {
        HStack(spacing: 8) {
            ProgressView().tint(.purple)
            Text("Thinking…").foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask Apple Intelligence…", text: $inputText)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Palette.surfHi)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($isInputFocused)
                .onSubmit(send)
                .accessibilityIdentifier("AIChat_Input")

            Button(action: generateImage) {
                Image(systemName: "photo.badge.plus")
                    .font(.title3)
                    .foregroundStyle(imageButtonColor)
            }
            .buttonStyle(.plain)
            .disabled(isImageButtonDisabled)
            .accessibilityIdentifier("AIChat_GenerateImage")
            .accessibilityLabel("Generate image from text")

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(sendButtonColor)
            }
            .buttonStyle(.plain)
            .disabled(isSendDisabled)
            .accessibilityIdentifier("AIChat_Send")
            .accessibilityLabel("Send message")
        }
        .padding()
        .background(Palette.bg.opacity(0.6))
        .overlay(alignment: .top) { Divider().opacity(0.15) }
    }

    private var isSendDisabled: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ai.isProcessing
    }

    private var isImageButtonDisabled: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGeneratingImage
    }

    private var sendButtonColor: some ShapeStyle {
        isSendDisabled ? AnyShapeStyle(.secondary) : AnyShapeStyle(.purple)
    }

    private var imageButtonColor: some ShapeStyle {
        isImageButtonDisabled ? AnyShapeStyle(.secondary) : AnyShapeStyle(.cyan)
    }

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        Task { await ai.sendMessage(trimmed) }
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif

        // Show brief feedback
        app.showSuccessToast("Copied", message: "Response copied to clipboard")
    }

    private func generateImage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        #if canImport(ImagePlayground)
        guard #available(iOS 18.4, macOS 15.4, *) else {
            app.showInfoToast("Unavailable", message: "Image generation requires iOS 18.4+ or macOS 15.4+")
            return
        }

        isGeneratingImage = true
        Task {
            await performImageGeneration(prompt: trimmed)
            isGeneratingImage = false
        }
        #else
        app.showInfoToast("Unavailable", message: "Image generation is not available on this platform")
        #endif
    }

    internal func runUnifiedTests() {
        #if DEBUG && canImport(FoundationModels)
        print("🧪 [UnifiedTest] Sparkles button clicked!")

        if #available(iOS 26.0, macOS 26.0, *) {
            // Run comprehensive suite for interactive testing
            // Use enhanced-pilot for good coverage (10-15 min, 192 runs)
            // For quick automation, use CLI: -runUnifiedTests quick-smoke
            runUnifiedTestSuite(suiteId: "enhanced-pilot")
        } else {
            showUnifiedTestsUnavailable()
        }
        #endif
    }

    internal func showUnifiedTestsUnavailable() {
        ai.messages.append(AIChatMessage(
            content: "⚠️ Unified tests require iOS 26.0+ or macOS 26.0+",
            isUser: false
        ))
    }

    internal func runCoordinatorExperiments() {
        #if DEBUG && canImport(FoundationModels)
        print("🔧 [Coordinator] Experiments button clicked!")

        if #available(iOS 26.0, macOS 26.0, *) {
            ai.messages.append(AIChatMessage(
                content: "🔧 Starting Coordinator Experiments (baseline)…",
                isUser: false
            ))

            Task {
                let runner = CoordinatorExperimentRunner { message in
                    Task { @MainActor in
                        ai.messages.append(AIChatMessage(content: message, isUser: false))
                    }
                }
                let report = await runner.runDefaultSuite()
                await MainActor.run {
                    let summary = "📊 Coordinator experiments complete: " +
                        "\(report.successfulRuns)/\(report.totalRuns) passed. Report saved to temp directory."
                    ai.messages.append(AIChatMessage(
                        content: summary,
                        isUser: false
                    ))
                }
            }
        } else {
            ai.messages.append(AIChatMessage(
                content: "⚠️ Coordinator experiments require iOS 26.0+ or macOS 26.0+",
                isUser: false
            ))
        }
        #endif
    }

    internal func runAcceptanceTests() {
        #if DEBUG && canImport(FoundationModels)
        print("🧪 [AcceptanceTest] Checkmark button clicked!")

        if #available(iOS 26.0, macOS 26.0, *) {
            startAcceptanceTests()
        } else {
            showAcceptanceTestsUnavailable()
        }
        #endif
    }

    internal func showAcceptanceTestsUnavailable() {
        ai.messages.append(AIChatMessage(
            content: "⚠️ Acceptance tests require iOS 26.0+ or macOS 26.0+",
            isUser: false
        ))
    }

    internal func runPilotTests() {
        #if DEBUG && canImport(FoundationModels)
        print("🧪 [PilotTest] Chart button clicked!")

        if #available(iOS 26.0, macOS 26.0, *) {
            startPilotTests()
        } else {
            showPilotTestsUnavailable()
        }
        #endif
    }

    internal func showPilotTestsUnavailable() {
        ai.messages.append(AIChatMessage(
            content: "⚠️ Pilot tests require iOS 26.0+ or macOS 26.0+",
            isUser: false
        ))
    }

    internal func runPromptTests() {
        #if DEBUG
        print("🧪 [Test] Flask button clicked!")

        #if canImport(FoundationModels)
        // Add initial message to chat
        ai.messages.append(AIChatMessage(content: "🧪 Starting automated prompt tests...", isUser: false))

        Task {
            let results = await SystemPromptTester.testPrompts { progressMessage in
                // Post each progress update to the chat
                ai.messages.append(AIChatMessage(content: progressMessage, isUser: false))
            }

            // Find the best prompt
            let successful = results.filter { !$0.hasDuplicates }

            if let best = successful.first {
                ai.messages.append(AIChatMessage(
                    content: """
                    🎉 SUCCESS! Prompt #\(best.promptNumber) eliminates duplicates.

                    Prompt text:
                    \(best.promptText)
                    """,
                    isUser: false
                ))
                app.showSuccessToast(
                    "Found Solution!",
                    message: "Prompt #\(best.promptNumber) works!"
                )
                print("\n✅ BEST PROMPT:")
                print(best.promptText)
            } else {
                ai.messages.append(AIChatMessage(
                    content: """
                    😔 All \(results.count) prompts failed - duplicates still occur \
                    with every variation tested.
                    """,
                    isUser: false
                ))
                app.showErrorToast(
                    "No Solution",
                    message: "All prompts still produce duplicates"
                )
            }
        }
        #else
        ai.messages.append(AIChatMessage(
            content: "⚠️ FoundationModels framework not available at compile time on this platform.",
            isUser: false
        ))
        print("🧪 [Test] FoundationModels not available at compile time")
        #endif
        #endif
    }
}
// swiftlint:enable type_body_length

// MARK: - Test Suite Picker Sheet

#if DEBUG && os(macOS)
@MainActor
private struct TestSuitePickerSheet: View {
    struct TestSuiteInfo {
        let id: String
        let name: String
        let description: String
        let duration: Int
        let runs: Int
    }

    let onSelectSuite: (String) -> Void
    let onDismiss: () -> Void

    private let testSuites: [TestSuiteInfo] = [
        TestSuiteInfo(id: "quick-smoke", name: "Quick Smoke Test",
                      description: "Fast validation (1-2 min)", duration: 60, runs: 4),
        TestSuiteInfo(id: "n50-validation", name: "N=50 Validation",
                      description: "Validate N=50 generation (2 min)", duration: 120, runs: 8),
        TestSuiteInfo(id: "n50-focused", name: "N=50 Focused",
                      description: "Unified N=50 (24 runs)", duration: 180, runs: 24),
        TestSuiteInfo(id: "standard-prompt-test", name: "Standard Prompt Test",
                      description: "Baseline prompt testing (8 min)", duration: 480, runs: 8),
        TestSuiteInfo(id: "hybrid-switch-eval", name: "Hybrid Switch Evaluation",
                      description: "Guided vs. unguided at N=50/150", duration: 900, runs: 48),
        TestSuiteInfo(id: "temperature-ramp-study", name: "Temperature Ramp Study",
                      description: "Diversity vs. JSON validity", duration: 600, runs: 32),
        TestSuiteInfo(id: "lenient-parse-stress", name: "Lenient Parse Stress Test",
                      description: "Unguided parsing at large N", duration: 480, runs: 8),
        TestSuiteInfo(id: "seed-rotation-study", name: "Seed Rotation Study",
                      description: "Variance across seed set", duration: 720, runs: 40),
        TestSuiteInfo(id: "diversity-comparison", name: "Diversity Comparison",
                      description: "Compare diversity strategies (10 min)", duration: 600, runs: 72),
        TestSuiteInfo(id: "enhanced-pilot", name: "Enhanced Pilot Test",
                      description: "Multi-dimensional testing (15 min)", duration: 900, runs: 192),
        TestSuiteInfo(id: "full-acceptance", name: "Full Acceptance Test",
                      description: "Comprehensive suite (30 min)", duration: 1800, runs: 432)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Test Suite")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            // Test suite list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(testSuites, id: \.id) { suite in
                        Button {
                            onSelectSuite(suite.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suite.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text(suite.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 12) {
                                        Label("\(suite.runs) runs", systemImage: "number")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Label(formatDuration(suite.duration), systemImage: "clock")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
    }
}
#endif

// MARK: - Previews

@MainActor
private struct AIChatOverlayPreview: View {
    private let appState = PreviewHelpers.makeAppState { app in
        app.aiGeneration.showAIChat = true
    }

    var body: some View {
        AIChatOverlay(ai: appState.aiGeneration)
            .environment(appState)
    }
}

#Preview("AI Chat Overlay") {
    AIChatOverlayPreview()
}
