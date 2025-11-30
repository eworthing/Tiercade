import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

@MainActor
extension AppState {
    /// Run the enhanced prompt testing framework
    func runEnhancedPromptTests() {
        Task {
            do {
                logEvent("🧪 Starting Enhanced Prompt Tests (Pilot)")

                let results = await EnhancedPromptTester.testPrompts { progress in
                    self.logEvent(progress)
                    print(progress)
                }

                logEvent("✅ Pilot test completed! \(results.count) aggregate results")
                logEvent("📝 Check logs in ~/Library/Containers/eworthing.Tiercade/Data/Documents/")

                showToast(
                    type: .info,
                    title: "Tests Complete",
                    message: "\(results.count) prompts tested. Check Documents folder for detailed logs.",
                )
            }
        }
    }
}
#endif
