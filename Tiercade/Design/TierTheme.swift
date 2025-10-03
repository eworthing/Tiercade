import SwiftUI
import SwiftData

struct TierTheme: Identifiable, Hashable, Sendable {
    struct Tier: Identifiable, Hashable, Sendable {
        let id: UUID
        let index: Int
        let name: String
        let colorHex: String
        let isUnranked: Bool

        func matches(identifier: String) -> Bool {
            let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let nameNormalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == nameNormalized { return true }
            if normalized == "unranked" { return isUnranked }
            if let numeric = Int(normalized) { return numeric == index }
            return false
        }
    }

    static let fallbackColor = "#000000"

    let id: UUID
    let slug: String
    let displayName: String
    let shortDescription: String
    let tiers: [Tier]

    init(id: UUID, slug: String, displayName: String, shortDescription: String, tiers: [Tier]) {
        self.id = id
        self.slug = slug
        self.displayName = displayName
        self.shortDescription = shortDescription
        self.tiers = tiers.sorted { lhs, rhs in
            if lhs.isUnranked != rhs.isUnranked { return !lhs.isUnranked }
            return lhs.index < rhs.index
        }
    }

    init(entity: TierThemeEntity) {
        let mappedTiers = entity.tiers.map { tier in
            Tier(
                id: tier.tierID,
                index: tier.index,
                name: tier.name,
                colorHex: tier.colorHex,
                isUnranked: tier.isUnranked
            )
        }
        self.init(
            id: entity.themeID,
            slug: entity.slug,
            displayName: entity.displayName,
            shortDescription: entity.shortDescription,
            tiers: mappedTiers
        )
    }

    var description: String { shortDescription }

    var rankedTiers: [Tier] {
        tiers.filter { !$0.isUnranked }.sorted { $0.index < $1.index }
    }

    var unrankedTier: Tier? {
        tiers.first(where: \Tier.isUnranked)
    }

    var unrankedColorHex: String {
        unrankedTier?.colorHex ?? Self.fallbackColor
    }

    var previewTiers: ArraySlice<Tier> {
        ArraySlice(rankedTiers.prefix(4))
    }

    func colorHex(forRankIndex index: Int) -> String? {
        rankedTiers.first { $0.index == index }?.colorHex
    }

    func colorHex(forIdentifier identifier: String) -> String? {
        tiers.first { $0.matches(identifier: identifier) }?.colorHex
    }

    func colorHex(forRank identifier: String, fallbackIndex: Int? = nil) -> String {
        if identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "unranked" {
            return unrankedColorHex
        }

        if let direct = colorHex(forIdentifier: identifier) {
            return direct
        }

        if let fallbackIndex, let indexed = colorHex(forRankIndex: fallbackIndex) {
            return indexed
        }

        return Self.fallbackColor
    }

    func swiftUIColor(forRank identifier: String, fallbackIndex: Int? = nil) -> Color {
        ColorUtilities.color(hex: colorHex(forRank: identifier, fallbackIndex: fallbackIndex))
    }

    func swiftUIColor(forRankIndex index: Int) -> Color {
        ColorUtilities.color(hex: colorHex(forRankIndex: index) ?? Self.fallbackColor)
    }
}

@MainActor
enum TierThemeCatalog {
    private static let cachedThemes: [TierTheme] = TierThemeSeeds.defaults.map(TierTheme.init(entity:))
    private static let themesByID: [UUID: TierTheme] = Dictionary(
        uniqueKeysWithValues: cachedThemes.map { ($0.id, $0) }
    )
    private static let themesBySlug: [String: TierTheme] = Dictionary(
        uniqueKeysWithValues: cachedThemes.map { ($0.slug.lowercased(), $0) }
    )

    static var allThemes: [TierTheme] {
        cachedThemes
    }

    static var defaultTheme: TierTheme {
        themesBySlug["smashclassic"] ?? cachedThemes.first ?? TierTheme(
            id: UUID(),
            slug: "default",
            displayName: "Default",
            shortDescription: "Default color palette",
            tiers: []
        )
    }

    static func theme(id: UUID) -> TierTheme? {
        themesByID[id]
    }

    static func theme(slug: String) -> TierTheme? {
        themesBySlug[slug.lowercased()]
    }
}
