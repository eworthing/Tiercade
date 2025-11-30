import Foundation
import os
import SwiftData
import SwiftUI
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Validation & Export

    func validateTierListDraft() -> [TierListDraftValidationIssue] {
        guard let draft = tierListCreatorDraft else {
            return []
        }
        var issues: [TierListDraftValidationIssue] = []

        issues += validateProjectInfo(draft)
        issues += validateTiers(draft)
        issues += validateItems(draft)
        issues += validateMedia(draft)

        tierListCreatorIssues = issues
        return issues
    }

    private func validateProjectInfo(_ draft: TierProjectDraft) -> [TierListDraftValidationIssue] {
        var issues: [TierListDraftValidationIssue] = []
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(category: .project, message: "Project title is required."))
        }
        return issues
    }

    private func validateTiers(_ draft: TierProjectDraft) -> [TierListDraftValidationIssue] {
        var issues: [TierListDraftValidationIssue] = []

        if draft.tiers.isEmpty {
            issues.append(.init(category: .tier, message: "Add at least one tier before saving."))
        }

        let tierIds = draft.tiers.map { $0.tierId.lowercased() }
        if Set(tierIds).count != tierIds.count {
            issues.append(.init(category: .tier, message: "Tier identifiers must be unique."))
        }

        let colorRegex = try? NSRegularExpression(pattern: "^#?[0-9A-Fa-f]{6}$")
        for tier in draft.tiers {
            let range = NSRange(location: 0, length: tier.colorHex.count)
            if colorRegex?.firstMatch(in: tier.colorHex, options: [], range: range) == nil {
                issues.append(
                    .init(
                        category: .tier,
                        message: "Tier \(tier.label) has an invalid color hex value.",
                        contextIdentifier: tier.identifier.uuidString,
                    ),
                )
            }
        }

        return issues
    }

    private func validateItems(_ draft: TierProjectDraft) -> [TierListDraftValidationIssue] {
        var issues: [TierListDraftValidationIssue] = []

        for item in draft.items {
            if item.itemId.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(
                    .init(
                        category: .item,
                        message: "Every item must have a stable identifier.",
                        contextIdentifier: item.identifier.uuidString,
                    ),
                )
            }
            if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(
                    .init(
                        category: .item,
                        message: "Item identifiers \(item.itemId) require a display title.",
                        contextIdentifier: item.identifier.uuidString,
                    ),
                )
            }
        }

        return issues
    }

    private func validateMedia(_ draft: TierProjectDraft) -> [TierListDraftValidationIssue] {
        var issues: [TierListDraftValidationIssue] = []

        for media in draft.mediaLibrary where media.uri.isEmpty || media.mime.isEmpty {
            issues.append(
                .init(
                    category: .media,
                    message: "Media assets require both a URI and MIME type.",
                    contextIdentifier: media.identifier.uuidString,
                ),
            )
        }

        return issues
    }

    func exportTierListDraftPayload() -> String? {
        guard let draft = tierListCreatorDraft else {
            return nil
        }
        do {
            let project = try buildProject(from: draft)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(project)
            return String(data: data, encoding: .utf8)
        } catch {
            Logger.appState.error("Draft export failed: \(error.localizedDescription)")
            showToast(type: .error, title: "Export Failed", message: error.localizedDescription)
            return nil
        }
    }

    func saveTierListDraft(action: TierListDraftCommitAction) async {
        guard let draft = tierListCreatorDraft else {
            return
        }
        let context = tierListWizardContext
        let issues = validateTierListDraft()
        guard issues.isEmpty else {
            showToast(
                type: .warning,
                title: "Needs Attention",
                message: issues.first?.message ?? "Resolve validation issues before saving.",
            )
            return
        }

        await withLoadingIndicator(message: action == .publish ? "Publishing Project..." : "Saving Project...") {
            do {
                let entity = try persistProjectDraft(draft)
                try modelContext.save()
                tierListCreatorDraft = nil
                let feedback = successFeedback(for: context, action: action, entityTitle: entity.title)
                dismissTierListCreator(resetDraft: true)
                let handle = TierListHandle(entity: entity)
                registerTierListSelection(handle)
                showToast(type: .success, title: feedback.title, message: feedback.message)
            } catch {
                Logger.appState.error("Failed to persist draft: \(error.localizedDescription)")
                showToast(type: .error, title: "Save Failed", message: error.localizedDescription)
            }
        }
    }

    private func successFeedback(
        for context: TierListWizardContext,
        action: TierListDraftCommitAction,
        entityTitle: String,
    )
    -> (title: String, message: String) {
        switch (context, action) {
        case (.edit, .save):
            ("Project Updated", "\(entityTitle) changes are saved.")
        case (.edit, .publish):
            ("Project Republished", "\(entityTitle) is ready to rank.")
        case (.create, .publish):
            ("Project Published", "\(entityTitle) is ready to rank.")
        case (.create, .save):
            ("Draft Saved", "\(entityTitle) draft stored for later.")
        }
    }
}
