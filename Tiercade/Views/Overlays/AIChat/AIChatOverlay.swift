import SwiftUI

#if canImport(ImagePlayground)
import ImagePlayground
#endif

#if os(macOS) || targetEnvironment(macCatalyst)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

@MainActor
struct AIChatOverlay: View {
    @Environment(AppState.self) var app: AppState
    @State var aiService = AppleIntelligenceService()
    @State var inputText = ""
    @FocusState var isInputFocused: Bool
    @State var showImagePreview = false
    @State var generatedImage: Image?
    @State var isGeneratingImage = false

    var body: some View {
        VStack(spacing: 0) {
            header
            messagesSection
            inputBar
        }
        .frame(maxWidth: 700, maxHeight: 720)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Color.purple.opacity(0.25), lineWidth: 1) }
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

            Button(action: aiService.clearHistory) {
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
        let current = aiService.estimatedTokenCount
        let max = AppleIntelligenceService.maxContextTokens
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
            .onChange(of: aiService.messages.count) { _, _ in
                guard let last = aiService.messages.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private var messagesContent: some View {
        if aiService.messages.isEmpty {
            emptyState
        } else {
            ForEach(aiService.messages) { message in
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

            if aiService.isProcessing {
                thinkingRow
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 56))
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
                .background(Color.white.opacity(0.1))
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
        .background(Color.black.opacity(0.6))
        .overlay(alignment: .top) { Divider().opacity(0.15) }
    }

    private var isSendDisabled: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isProcessing
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
        Task { await aiService.sendMessage(trimmed) }
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS) && !targetEnvironment(macCatalyst)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS) || targetEnvironment(macCatalyst)
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

    func runAcceptanceTests() {
        #if DEBUG && canImport(FoundationModels)
        print("🧪 [AcceptanceTest] Checkmark button clicked!")

        if #available(iOS 26.0, macOS 26.0, *) {
            startAcceptanceTests()
        } else {
            showAcceptanceTestsUnavailable()
        }
        #endif
    }

    func showAcceptanceTestsUnavailable() {
        aiService.messages.append(AIChatMessage(
            content: "⚠️ Acceptance tests require iOS 26.0+ or macOS 26.0+",
            isUser: false
        ))
    }

    func runPilotTests() {
        #if DEBUG && canImport(FoundationModels)
        print("🧪 [PilotTest] Chart button clicked!")

        if #available(iOS 26.0, macOS 26.0, *) {
            startPilotTests()
        } else {
            showPilotTestsUnavailable()
        }
        #endif
    }

    func showPilotTestsUnavailable() {
        aiService.messages.append(AIChatMessage(
            content: "⚠️ Pilot tests require iOS 26.0+ or macOS 26.0+",
            isUser: false
        ))
    }

    func runPromptTests() {
        #if DEBUG
        print("🧪 [Test] Flask button clicked!")

        #if canImport(FoundationModels)
        // Add initial message to chat
        aiService.messages.append(AIChatMessage(content: "🧪 Starting automated prompt tests...", isUser: false))

        Task {
            let results = await SystemPromptTester.testPrompts { progressMessage in
                // Post each progress update to the chat
                aiService.messages.append(AIChatMessage(content: progressMessage, isUser: false))
            }

            // Find the best prompt
            let successful = results.filter { !$0.hasDuplicates }

            if let best = successful.first {
                aiService.messages.append(AIChatMessage(
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
                aiService.messages.append(AIChatMessage(
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
        aiService.messages.append(AIChatMessage(
            content: "⚠️ FoundationModels framework not available at compile time on this platform.",
            isUser: false
        ))
        print("🧪 [Test] FoundationModels not available at compile time")
        #endif
        #endif
    }
}

// Preview intentionally omitted to keep compile times fast
