import Foundation
import SwiftUI

internal struct ThemeTierDraft: Identifiable, Hashable, Sendable {
    internal let id: UUID
    internal let index: Int
    internal let name: String
    internal var colorHex: String
    internal let isUnranked: Bool
}

internal struct ThemeDraft: Identifiable, Hashable, Sendable {
    internal var id: UUID = UUID()
    internal var displayName: String
    internal var slug: String
    internal var shortDescription: String
    internal var tiers: [ThemeTierDraft]
    internal var activeTierID: UUID
    internal var baseThemeID: UUID?

    internal init(baseTheme: TierTheme, tierOrder: [String]) {
        displayName = "\(baseTheme.displayName) Variant"
        slug = ThemeDraft.slugify(displayName)
        shortDescription = "Inspired by \(baseTheme.displayName)"
        baseThemeID = baseTheme.id
        tiers = ThemeDraft.buildTierDrafts(baseTheme: baseTheme, tierOrder: tierOrder)
        activeTierID = tiers.first?.id ?? UUID()
    }

    internal var activeTier: ThemeTierDraft? {
        tiers.first { $0.id == activeTierID }
    }

    mutating func setName(_ newName: String) {
        internal let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = trimmed
        if !trimmed.isEmpty {
            slug = ThemeDraft.slugify(trimmed)
        }
    }

    mutating func setDescription(_ description: String) {
        shortDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func selectTier(_ tierID: UUID) {
        guard tiers.contains(where: { $0.id == tierID }) else { return }
        activeTierID = tierID
    }

    mutating func assignColor(_ hex: String, to tierID: UUID) {
        tiers = tiers.map { tier in
            guard tier.id == tierID else { return tier }
            internal var updated = tier
            updated.colorHex = ThemeDraft.normalizeHex(hex)
            return updated
        }
    }

    mutating func applyColorToActiveTier(_ hex: String) {
        assignColor(hex, to: activeTierID)
    }

    internal func buildTheme(withSlug slugOverride: String? = nil) -> TierTheme {
        internal let finalSlug = slugOverride ?? slug
        internal let tierModels = tiers.map { tier in
            TierTheme.Tier(
                id: UUID(),
                index: tier.index,
                name: tier.name,
                colorHex: ThemeDraft.normalizeHex(tier.colorHex),
                isUnranked: tier.isUnranked
            )
        }
        return TierTheme(
            id: UUID(),
            slug: finalSlug,
            displayName: displayName.isEmpty ? "Untitled Theme" : displayName,
            shortDescription: shortDescription.isEmpty ? "Custom theme" : shortDescription,
            tiers: tierModels
        )
    }

    internal static func buildTierDrafts(baseTheme: TierTheme, tierOrder: [String]) -> [ThemeTierDraft] {
        internal var drafts: [ThemeTierDraft] = []

        for (index, tierName) in tierOrder.enumerated() {
            internal let hex = ThemeDraft.normalizeHex(
                baseTheme.colorHex(forRank: tierName, fallbackIndex: index)
            )

            if let matched = baseTheme.tiers.first(where: { $0.matches(identifier: tierName) }) {
                drafts.append(
                    ThemeTierDraft(
                        id: UUID(),
                        index: matched.index,
                        name: matched.name,
                        colorHex: ThemeDraft.normalizeHex(matched.colorHex),
                        isUnranked: matched.isUnranked
                    )
                )
            } else {
                drafts.append(
                    ThemeTierDraft(
                        id: UUID(),
                        index: index,
                        name: tierName,
                        colorHex: hex,
                        isUnranked: false
                    )
                )
            }
        }

        if let unranked = baseTheme.tiers.first(where: { $0.isUnranked }) {
            drafts.append(
                ThemeTierDraft(
                    id: UUID(),
                    index: max(tierOrder.count, unranked.index),
                    name: unranked.name,
                    colorHex: ThemeDraft.normalizeHex(unranked.colorHex),
                    isUnranked: true
                )
            )
        } else {
            drafts.append(
                ThemeTierDraft(
                    id: UUID(),
                    index: tierOrder.count,
                    name: "Unranked",
                    colorHex: ThemeDraft.normalizeHex(baseTheme.unrankedColorHex),
                    isUnranked: true
                )
            )
        }

        return drafts
    }

    internal static func slugify(_ value: String) -> String {
        internal let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "custom-theme" }
        internal let lowercase = trimmed.lowercased()
        internal let allowed = lowercase.compactMap { character -> Character? in
            if character.isLetter || character.isNumber { return character }
            if character == " " || character == "-" || character == "_" { return "-" }
            return nil
        }
        internal let collapsed = String(allowed)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return collapsed.isEmpty ? "custom-theme" : collapsed
    }

    internal static func normalizeHex(_ value: String) -> String {
        internal let sanitized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") { return sanitized.uppercased() }
        return "#" + sanitized.uppercased()
    }
}

// MARK: - Theme Creation Workflow

internal extension AppState {
    internal var availableThemes: [TierTheme] {
        internal let bundled = TierThemeCatalog.allThemes
        guard !theme.customThemes.isEmpty else { return bundled }
        internal let bundledIDs = Set(bundled.map(\TierTheme.id))
        internal let uniqueCustom = theme.customThemes.filter { !bundledIDs.contains($0.id) }
        return bundled + uniqueCustom.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    internal func isCustomTheme(_ theme: TierTheme) -> Bool {
        self.theme.customThemeIDs.contains(theme.id)
    }

    internal func theme(with id: UUID) -> TierTheme? {
        if let bundled = TierThemeCatalog.theme(id: id) { return bundled }
        return self.theme.customThemes.first { $0.id == id }
    }

    internal func beginThemeCreation(baseTheme: TierTheme? = nil) {
        internal let source = baseTheme ?? theme.selectedTheme
        theme.themeDraft = ThemeDraft(baseTheme: source, tierOrder: tierOrder)
        overlays.showThemePicker = false
        overlays.presentThemeCreator()
    }

    internal func updateThemeDraftName(_ newName: String) {
        guard var draft = theme.themeDraft else { return }
        draft.setName(newName)
        theme.themeDraft = draft
    }

    internal func updateThemeDraftDescription(_ newDescription: String) {
        guard var draft = theme.themeDraft else { return }
        draft.setDescription(newDescription)
        theme.themeDraft = draft
    }

    internal func selectThemeDraftTier(_ tierID: UUID) {
        guard var draft = theme.themeDraft else { return }
        draft.selectTier(tierID)
        theme.themeDraft = draft
    }

    internal func assignColorToActiveTier(_ hex: String) {
        guard var draft = theme.themeDraft else { return }
        draft.applyColorToActiveTier(hex)
        theme.themeDraft = draft
        markAsChanged()
    }

    internal func cancelThemeCreation(returnToThemePicker: Bool) {
        overlays.dismissThemeCreator()
        theme.themeDraft = nil
        if !returnToThemePicker {
            overlays.dismissThemePicker()
        }
    }

    internal func completeThemeCreation() {
        guard var draft = theme.themeDraft else { return }

        internal let cleanedName = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else {
            showErrorToast("Add a name", message: "Give your theme a descriptive name before saving")
            return
        }

        draft.setName(cleanedName)

        internal let desiredSlug = draft.slug
        internal let uniqueSlug = makeUniqueSlug(from: desiredSlug)
        internal let newTheme = draft.buildTheme(withSlug: uniqueSlug)

        internal let duplicateNameExists = availableThemes.contains {
            $0.displayName.caseInsensitiveCompare(newTheme.displayName) == .orderedSame
        }

        guard !duplicateNameExists else {
            showErrorToast("Name already used", message: "Pick a different name to avoid confusion")
            return
        }

        theme.customThemes.append(newTheme)
        theme.customThemes.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        theme.customThemeIDs.insert(newTheme.id)

        applyTheme(newTheme)

        showSuccessToast("Theme saved", message: "\(newTheme.displayName) is ready to use")
        markAsChanged()

        overlays.dismissThemeCreator()
        theme.themeDraft = nil
        overlays.presentThemePicker()
    }

    private func makeUniqueSlug(from base: String) -> String {
        internal let normalizedBase = base.isEmpty ? "custom-theme" : base
        internal var candidate = normalizedBase
        internal var index = 1
        internal let existing = Set(availableThemes.map(\TierTheme.slug))
        while existing.contains(candidate) {
            index += 1
            candidate = "\(normalizedBase)-\(index)"
        }
        return candidate
    }
}
