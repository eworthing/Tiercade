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
    @Environment(AppState.self) private var app: AppState
    @State private var aiService = AppleIntelligenceService()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showImagePreview = false
    @State private var generatedImage: Image?
    @State private var isGeneratingImage = false

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

    private func runAcceptanceTests() {
        #if DEBUG && canImport(FoundationModels)
        print("🧪 [AcceptanceTest] Checkmark button clicked!")

        if #available(iOS 26.0, macOS 26.0, *) {
            aiService.messages.append(AIChatMessage(
                content: "🧪 Starting acceptance test suite...",
                isUser: false
            ))

            Task {
                do {
                    let report = try await AcceptanceTestSuite.runAll { message in
                        print("🧪 \(message)")
                    }

                    // Post summary to chat
                    let summary = """
                ✅ Test Results: \(report.passed)/\(report.totalTests) passed \
                (\(String(format: "%.1f", report.passRate * 100))%)

                Environment:
                • OS: \(report.environment.osVersion)
                • Top-P: \(report.environment.hasTopP ? "Available" : "Not available")

                Failed tests:
                \(report.results.filter { !$0.passed }.map { "• \($0.testName): \($0.message)" }.joined(separator: "\n"))
                """

                    aiService.messages.append(AIChatMessage(content: summary, isUser: false))

                    // Save report to file
                    let reportPath = "/tmp/tiercade_acceptance_test_report.json"
                    do {
                        try AcceptanceTestSuite.saveReport(report, to: reportPath)
                        aiService.messages.append(AIChatMessage(
                            content: "📄 Detailed report saved to: \(reportPath)",
                            isUser: false
                        ))
                    } catch {
                        print("❌ Failed to save report: \(error)")
                    }

                    if report.passRate == 1.0 {
                        app.showSuccessToast("All Tests Passed!", message: "\(report.totalTests)/\(report.totalTests)")
                    } else {
                        app.showInfoToast("Tests Complete", message: "\(report.passed)/\(report.totalTests) passed")
                    }
                } catch {
                    aiService.messages.append(AIChatMessage(
                        content: "❌ Test suite error: \(error.localizedDescription)",
                        isUser: false
                    ))
                }
            }
        } else {
            aiService.messages.append(AIChatMessage(
                content: "⚠️ Acceptance tests require iOS 26.0+ or macOS 26.0+",
                isUser: false
            ))
        }
        #endif
    }

    private func runPilotTests() {
        #if DEBUG && canImport(FoundationModels)
        print("🧪 [PilotTest] Chart button clicked!")

        if #available(iOS 26.0, macOS 26.0, *) {
            aiService.messages.append(AIChatMessage(
                content: "🧪 Starting pilot test grid (this will take several minutes)...",
                isUser: false
            ))

            Task {
                let runner = PilotTestRunner { progressMessage in
                    print("🧪 \(progressMessage)")
                }

                let report = await runner.runPilot()

                // Post summary to chat
                // Format pass by size breakdown
                let passBySize = report.summary.passBySize
                    .sorted { Int($0.key) ?? 0 < Int($1.key) ?? 0 }
                    .map { "• N=\($0.key): \(String(format: "%.0f%%", $0.value * 100))" }
                    .joined(separator: "\n")

                let topPerformers = report.summary.topPerformers
                    .map { "• \($0)" }
                    .joined(separator: "\n")

                let passRate = String(format: "%.1f%%", report.summary.overallPassRate * 100)
                let meanDup = String(format: "%.1f", report.summary.meanDupRate * 100)
                let stdevDup = String(format: "%.1f", report.summary.stdevDupRate * 100)
                let throughput = String(format: "%.1f", report.summary.meanItemsPerSecond)

                let summary = """
                ✅ Pilot Test Complete

                Overall Metrics:
                • Pass@N rate: \(passRate)
                • Mean dup rate: \(meanDup)±\(stdevDup)%%
                • Throughput: \(throughput) items/sec

                Pass by Size:
                \(passBySize)

                Top Performers:
                \(topPerformers)
                """

                aiService.messages.append(AIChatMessage(content: summary, isUser: false))

                // Save detailed reports
                let jsonPath = "/tmp/tiercade_pilot_test_report.json"
                let txtPath = "/tmp/tiercade_pilot_test_report.txt"

                do {
                    try runner.saveReport(report, to: jsonPath)
                    let textReport = runner.generateTextReport(report)
                    try textReport.write(toFile: txtPath, atomically: true, encoding: .utf8)

                    aiService.messages.append(AIChatMessage(
                        content: "📄 Reports saved:\n• \(jsonPath)\n• \(txtPath)",
                        isUser: false
                    ))
                } catch {
                    print("❌ Failed to save reports: \(error)")
                }

                app.showSuccessToast("Pilot Tests Complete", message: "\(report.completedRuns) runs")
            }
        } else {
            aiService.messages.append(AIChatMessage(
                content: "⚠️ Pilot tests require iOS 26.0+ or macOS 26.0+",
                isUser: false
            ))
        }
        #endif
    }

    private func runPromptTests() {
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

    @available(iOS 18.4, macOS 15.4, *)
    private func performImageGeneration(prompt: String) async {
        #if canImport(ImagePlayground)
        do {
            let currentLocale = Locale.current
            print("🎨 [Image] Starting generation for: \(prompt)")
            print("🎨 [Image] Current locale: \(currentLocale.identifier)")
            print("🎨 [Image] Language: \(currentLocale.language.languageCode?.identifier ?? "unknown")")
            print("🎨 [Image] Region: \(currentLocale.region?.identifier ?? "unknown")")

            let creator = try await ImageCreator()

            // Get the first available style
            guard let style = creator.availableStyles.first else {
                app.showErrorToast("No Styles", message: "No image generation styles available")
                return
            }

            let concepts = [ImagePlaygroundConcept.text(prompt)]

            // Generate first image
            var imageGenerated = false
            for try await createdImage in creator.images(for: concepts, style: style, limit: 1) {
                print("🎨 [Image] Image generated successfully")
                let cgImage = createdImage.cgImage

                #if os(macOS) && !targetEnvironment(macCatalyst)
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                generatedImage = Image(nsImage: nsImage)
                imageGenerated = true
                #elseif os(iOS) || targetEnvironment(macCatalyst)
                let uiImage = UIImage(cgImage: cgImage)
                generatedImage = Image(uiImage: uiImage)
                imageGenerated = true
                #endif
                break // Only take first image
            }

            if imageGenerated {
                showImagePreview = true
            } else {
                app.showErrorToast("Generation Failed", message: "No image was generated")
            }
        } catch let error as ImageCreator.Error {
            print("🎨 [Image] Error: \(error)")
            let message: String
            switch error {
            case .notSupported:
                message = "Image generation is not supported on this device"
            case .unavailable:
                message = "Image generation is currently unavailable"
            case .unsupportedLanguage:
                let locale = Locale.current
                let languageCode = locale.language.languageCode?.identifier ?? "unknown"
                let regionCode = locale.region?.identifier ?? "unknown"
                let localeInfo = "\(languageCode)-\(regionCode)"
                message = """
                Unsupported locale: \(localeInfo)

                ImagePlayground requires English (US, UK, CA, AU, NZ, IE, or ZA).
                Check System Settings > General > Language & Region.
                """
            case .creationFailed:
                message = "Image generation failed. Try a different prompt."
            case .backgroundCreationForbidden:
                message = "App must be in foreground to generate images"
            default:
                message = "Image generation failed: \(error.localizedDescription)"
            }
            app.showErrorToast("Generation Failed", message: message)
        } catch {
            print("🎨 [Image] Unexpected error: \(error)")
            app.showErrorToast("Error", message: "Unexpected error: \(error.localizedDescription)")
        }
        #endif
    }
}

// MARK: - Image Preview Sheet

struct ImagePreviewSheet: View {
    let image: Image
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Generated Image")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    onDismiss()
                }
            }
            .padding()

            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()

            HStack(spacing: 12) {
                Spacer()

                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(maxWidth: 600, maxHeight: 700)
    }
}

// Preview intentionally omitted to keep compile times fast
