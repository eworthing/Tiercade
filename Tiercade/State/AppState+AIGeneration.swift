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
    // MARK: - State Properties

    /// Whether the AI item generator overlay is visible
    internal var showAIItemGenerator: Bool {
        get { _showAIItemGenerator }
        set { _showAIItemGenerator = newValue }
    }

    /// Current generation request (preserves parameters for regeneration)
    internal var aiGenerationRequest: AIGenerationRequest? {
        get { _aiGenerationRequest }
        set { _aiGenerationRequest = newValue }
    }

    /// Generated item candidates awaiting review
    internal var aiGeneratedCandidates: [AIGeneratedItemCandidate] {
        get { _aiGeneratedCandidates }
        set { _aiGeneratedCandidates = newValue }
    }

    /// Whether generation is in progress
    internal var aiGenerationInProgress: Bool {
        get { _aiGenerationInProgress }
        set { _aiGenerationInProgress = newValue }
    }

    // MARK: - Overlay Management

    /// Present the AI item generator overlay.
    ///
    /// Resets any previous generation state and shows the overlay.
    /// On tvOS, this does nothing as AI generation is only available on macOS/iOS.
    internal func presentAIItemGenerator() {
        #if os(macOS) || os(iOS)
        showAIItemGenerator = true
        aiGenerationRequest = nil
        aiGeneratedCandidates = []
        #else
        // tvOS: Show informative message via toast
        showToast(
            type: .info,
            title: "Unavailable",
            message: "AI generation requires macOS or iOS"
        )
        #endif
    }

    /// Dismiss the AI item generator overlay.
    ///
    /// Clears all generation state and hides the overlay.
    internal func dismissAIItemGenerator() {
        showAIItemGenerator = false
        aiGenerationRequest = nil
        aiGeneratedCandidates = []
        aiGenerationInProgress = false
    }

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
    internal func generateItems(description: String, count: Int) async {
        let request = AIGenerationRequest(
            description: description,
            itemCount: count,
            timestamp: Date()
        )

        guard request.isValid else {
            showToast(type: .error, title: "Invalid Request", message: "Please enter a description")
            return
        }

        aiGenerationRequest = request
        aiGenerationInProgress = true

        await withLoadingIndicator(message: "Generating \(count) items...") {
            do {
                #if canImport(FoundationModels)
                // Create a fresh session locally to avoid cross-file #if and access-level coupling
                // Use strong anti-duplicate instructions like the chat service
                let instructions = Instructions("""
                You are a helpful assistant. Answer questions clearly and concisely.

                CRITICAL RULES FOR LISTS:
                - NEVER repeat any item in a list
                - ALWAYS check if an item was already mentioned before adding it
                - If asked for N items, provide EXACTLY N UNIQUE items
                - Stop immediately after reaching the requested number
                - Do NOT continue generating after the list is complete
                """)
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

                let items = try await coordinator.uniqueList(query: description, targetCount: count, seed: nil)

                // Convert to candidates (all selected by default)
                aiGeneratedCandidates = items.map {
                    AIGeneratedItemCandidate(name: $0, isSelected: true)
                }

                print("✅ [AIGeneration] Generated \(items.count) items for wizard: \(items.prefix(5))...")
                showToast(
                    type: .success,
                    title: "Success",
                    message: "Generated \(items.count) items"
                )
                #else
                throw NSError(
                    domain: "AIGeneration",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "AI generation not available on this platform"]
                )
                #endif
            } catch {
                print("❌ [AIGeneration] AI generation failed: \(error.localizedDescription)")
                showToast(
                    type: .error,
                    title: "Generation Failed",
                    message: error.localizedDescription
                )
                aiGeneratedCandidates = []
            }
        }

        aiGenerationInProgress = false
    }

    // MARK: - Candidate Management

    /// Toggle selection state for a candidate.
    ///
    /// - Parameter candidate: The candidate to toggle
    internal func toggleCandidateSelection(_ candidate: AIGeneratedItemCandidate) {
        guard let index = aiGeneratedCandidates.firstIndex(where: { $0.id == candidate.id }) else {
            return
        }
        aiGeneratedCandidates[index].isSelected.toggle()
    }

    /// Remove a candidate completely from the list.
    ///
    /// This deletes the candidate entirely (vs. just deselecting it).
    ///
    /// - Parameter candidate: The candidate to remove
    internal func removeCandidate(_ candidate: AIGeneratedItemCandidate) {
        aiGeneratedCandidates.removeAll { $0.id == candidate.id }
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
    internal func importSelectedCandidates(into draft: TierProjectDraft) {
        let selected = aiGeneratedCandidates.filter { $0.isSelected }

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
        dismissAIItemGenerator()
    }
}

// MARK: - Private Storage

private var _showAIItemGenerator = false
private var _aiGenerationRequest: AIGenerationRequest?
private var _aiGeneratedCandidates: [AIGeneratedItemCandidate] = []
private var _aiGenerationInProgress = false
