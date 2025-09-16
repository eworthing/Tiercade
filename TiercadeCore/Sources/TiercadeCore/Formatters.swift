import Foundation

public enum ExportFormatter {
    /// Generate export text similar to the web app.
    public static func generate(group: String, date: Date, themeName: String, tiers: Items, tierConfig: TierConfig, locale: Locale = .current) -> String {
        let df = DateFormatter()
        df.locale = locale
        df.dateStyle = .medium
        df.timeStyle = .none
    var text = "🗝️ My Tier List - \(group)\n"
        text += "Created: \(df.string(from: date))\n"
        text += "Theme: \(themeName)\n\n"
        let ordered = tiers.filter { $0.key != "unranked" }
        let parts = ordered.compactMap { (tier, items) -> String? in
            guard let cfg = tierConfig[tier], !items.isEmpty else { return nil }
            let names = items.map { $0.name ?? "" }.joined(separator: ", ")
            let desc = cfg.description ?? ""
            return "\(cfg.name) Tier (\(desc)): \(names)"
        }
        text += parts.joined(separator: "\n\n")
        return text
    }
}

public enum AnalysisFormatter {
    public static func generateTierAnalysis(tierName: String, tierInfo: TierConfigEntry, items: [Item]) -> String {
        var s = "\(tierInfo.name) Tier Analysis - \(tierInfo.description ?? "")\n\n"
    s += "You've placed \(items.count) item\(items.count == 1 ? "" : "s") in this tier:\n\n"
        for c in items {
            let season = c.seasonString ?? (c.seasonNumber.map(String.init) ?? "?")
            let status = c.status ?? ""
            s += "• \(c.name ?? c.id) (Season \(season), \(status))\n"
            if let d = c.description, !d.isEmpty { s += "  \(d)\n\n" }
        }
        return s
    }
}
