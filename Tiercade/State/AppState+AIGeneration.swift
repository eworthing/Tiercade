import Foundation
import SwiftUI
import Observation
import TiercadeCore

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AI Item Generation State

@MainActor
internal extension AppState {
    // MARK: - Generation

    /// Generate items using Apple Intelligence.
    ///
    /// Orchestrates the full generation flow:
    /// 1. Validates input parameters
    /// 2. Calls `generateUniqueListForWizard` with progress tracking
    /// 3. Converts results to `AIGeneratedItemCandidate` instances
    /// 4. Shows success/error feedback via toast
    ///
    /// - Parameters:
    ///   - description: Natural language description of items (e.g., "Best sci-fi movies")
    ///   - count: Target number of items (valid range: 5-100)
    ///
    /// - Note: Uses existing `withLoadingIndicator` for progress UI
    /// - Note: Only available on macOS/iOS 26+
    @available(iOS 26.0, macOS 26.0, *)
    func generateItems(description: String, count: Int) async {
        let request = AIGenerationRequest(
            description: description,
            itemCount: count,
            timestamp: Date()
        )

        guard request.isValid else {
            showToast(type: .error, title: "Invalid Request", message: "Please enter a description")
            return
        }

        aiGeneration.aiGenerationRequest = request
        aiGeneration.aiGenerationInProgress = true

        await withLoadingIndicator(message: "Generating \(count) items...") {
            do {
                #if canImport(FoundationModels)
                // Create a fresh session locally to avoid cross-file #if and access-level coupling
                // Use shared anti-duplicate instructions
                let instructions = makeAntiDuplicateInstructions()
                let session = LanguageModelSession(model: .default, tools: [], instructions: instructions)
                let fm = FMClient(session: session, logger: { _ in })
                let coordinator = UniqueListCoordinator(
                    fm: fm,
                    logger: { _ in },
                    useGuidedBackfill: true,
                    hybridSwitchEnabled: false,
                    guidedBudgetBumpFirst: false,
                    promptStyle: .strict
                )

                let items: [String]
                do {
                    items = try await coordinator.uniqueList(query: description, targetCount: count, seed: nil)
                } catch {
                    throw AIGenerationError.generationFailed(underlyingError: error)
                }

                // Convert to candidates (all selected by default)
                aiGeneration.aiGeneratedCandidates = items.map {
                    AIGeneratedItemCandidate(name: $0, isSelected: true)
                }

                print("✅ [AIGeneration] Generated \(items.count) items for wizard: \(items.prefix(5))...")
                showToast(
                    type: .success,
                    title: "Success",
                    message: "Generated \(items.count) items"
                )
                #else
                throw AIGenerationError.platformNotSupported
                #endif
            } catch let error as AIGenerationError {
                print("❌ [AIGeneration] AI generation failed: \(error.userMessage)")
                showToast(
                    type: .error,
                    title: "Generation Failed",
                    message: error.userMessage
                )
                aiGeneration.aiGeneratedCandidates = []
            } catch {
                // Fallback for unexpected errors
                print("❌ [AIGeneration] Unexpected error: \(error)")
                showToast(
                    type: .error,
                    title: "Generation Failed",
                    message: "An unexpected error occurred. Please try again."
                )
                aiGeneration.aiGeneratedCandidates = []
            }
        }

        aiGeneration.aiGenerationInProgress = false
    }

    // MARK: - Candidate Management

    /// Toggle selection state for a candidate.
    ///
    /// - Parameter candidate: The candidate to toggle
    func toggleCandidateSelection(_ candidate: AIGeneratedItemCandidate) {
        guard let index = aiGeneration.aiGeneratedCandidates.firstIndex(where: { $0.id == candidate.id }) else {
            return
        }
        aiGeneration.aiGeneratedCandidates[index].isSelected.toggle()
    }

    /// Remove a candidate completely from the list.
    ///
    /// This deletes the candidate entirely (vs. just deselecting it).
    ///
    /// - Parameter candidate: The candidate to remove
    func removeCandidate(_ candidate: AIGeneratedItemCandidate) {
        aiGeneration.aiGeneratedCandidates.removeAll { $0.id == candidate.id }
    }

    // MARK: - Import

    /// Import selected candidates into tier list draft.
    ///
    /// Creates `TierDraftItem` instances from selected candidates and adds them
    /// to the draft's items array. Automatically deduplicates against existing
    /// draft items (case-insensitive name matching).
    ///
    /// - Parameter draft: The tier list draft to import into
    ///
    /// - Note: Shows toast with import count and duplicate count
    /// - Note: Automatically dismisses overlay after successful import
    func importSelectedCandidates(into draft: TierProjectDraft) {
        let selected = aiGeneration.aiGeneratedCandidates.filter { $0.isSelected }

        guard !selected.isEmpty else {
            showToast(type: .warning, title: "No Selection", message: "Please select items to import")
            return
        }

        // Deduplication: Check against existing draft items (case-insensitive)
        let existingTitles = Set(draft.items.map { $0.title.lowercased() })
        let uniqueCandidates = selected.filter {
            !existingTitles.contains($0.name.lowercased())
        }

        let skippedCount = selected.count - uniqueCandidates.count

        // Create TierDraftItems from unique candidates
        for candidate in uniqueCandidates {
            let item = TierDraftItem(
                itemId: "item-\(UUID().uuidString)",
                title: candidate.name,
                subtitle: "",
                summary: "",
                slug: "item-\(UUID().uuidString)",
                ordinal: draft.items.count
            )
            item.project = draft
            draft.items.append(item)
        }

        markDraftEdited(draft)

        // Show appropriate feedback
        if skippedCount > 0 {
            showToast(
                type: .success,
                title: "Imported",
                message: "Added \(uniqueCandidates.count) items (\(skippedCount) duplicates skipped)"
            )
            print("⚠️ [AIGeneration] Skipped \(skippedCount) duplicate items during import")
        } else {
            showToast(
                type: .success,
                title: "Success",
                message: "Imported \(uniqueCandidates.count) items"
            )
        }

        print("✅ [AIGeneration] Imported \(uniqueCandidates.count) items to draft '\(draft.title)'")
        // Clear state after successful import
        aiGeneration.aiGenerationRequest = nil
        aiGeneration.aiGeneratedCandidates = []
        aiGeneration.aiGenerationInProgress = false
    }
}
