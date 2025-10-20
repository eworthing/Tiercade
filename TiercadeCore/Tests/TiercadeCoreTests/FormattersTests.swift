import Foundation
import Testing
@testable import TiercadeCore

@Suite("Formatters")
struct FormattersTests {
    @Test("Export formatter applies tier metadata and locale-sensitive date")
    func exportFormatterGeneratesOverview() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let locale = Locale(identifier: "en_US_POSIX")
        let items: Items = [
            "S": [Item(id: "alpha", name: "Alpha"), Item(id: "beta", name: "Beta")],
            "A": [Item(id: "gamma", name: "Gamma")],
            "unranked": [Item(id: "delta", name: "Delta")]
        ]
        let config: TierConfig = [
            "S": TierConfigEntry(name: "S", colorHex: "#FF0000", description: "Elite"),
            "A": TierConfigEntry(name: "A", colorHex: "#00FF00", description: "Great")
        ]

        let expectedDate = mediumDateString(for: date, locale: locale)
        let export = ExportFormatter.generate(
            group: "Test Group",
            date: date,
            themeName: "Neon",
            tiers: items,
            tierConfig: config,
            locale: locale
        )

        #expect(export.contains("🗝️ My Tier List - Test Group"))
        #expect(export.contains("Created: \(expectedDate)"))
        #expect(export.contains("Theme: Neon"))
        #expect(export.contains("S Tier (Elite): Alpha, Beta"))
        #expect(export.contains("A Tier (Great): Gamma"))
        #expect(export.contains("unranked") == false)
    }

    @Test("Analysis formatter summarizes items with fallbacks")
    func analysisFormatterSummarizesTier() {
        let items = [
            Item(
                id: "alpha",
                name: "Alpha",
                seasonString: "1",
                status: "Active",
                description: "Leading contender"
            ),
            Item(
                id: "beta",
                name: "Beta",
                seasonNumber: 2,
                status: "Retired",
                description: nil
            )
        ]
        let entry = TierConfigEntry(name: "S", colorHex: "#FF0000", description: "Elite status")
        let summary = AnalysisFormatter.generateTierAnalysis(
            tierName: "S",
            tierInfo: entry,
            items: items
        )

        #expect(summary.contains("S Tier Analysis - Elite status"))
        #expect(summary.contains("You've placed 2 items in this tier"))
        #expect(summary.contains("Alpha (Season 1, Active)"))
        #expect(summary.contains("Leading contender"))
        #expect(summary.contains("Beta (Season 2, Retired)"))
    }
}

private func mediumDateString(for date: Date, locale: Locale) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
}
