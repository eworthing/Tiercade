import Foundation
import TiercadeCore

@MainActor
internal extension AppState {
    // MARK: - Analysis
    internal func generateAnalysis() async {
        analysisData = await withLoadingIndicator(message: "Generating analysis...") {
            updateProgress(0.1)
            let result = await buildAnalysis()
            updateProgress(1.0)
            return result
        }
    }

    internal func toggleAnalysis() {
        #if os(tvOS)
        toggleAnalyticsSidebar()
        #else
        if showingAnalysis {
            showingAnalysis = false
            return
        }

        guard canShowAnalysis else {
            showInfoToast("Nothing to Analyze", message: "Add items before opening analysis")
            return
        }

        // Close theme picker when opening analysis
        overlays.showThemePicker = false
        themePickerActive = false

        showingAnalysis = true
        if analysisData == nil {
            Task { await generateAnalysis() }
        }
        #endif
    }

    internal func toggleAnalyticsSidebar() {
        if overlays.showAnalyticsSidebar {
            overlays.showAnalyticsSidebar = false
            return
        }

        guard canShowAnalysis else {
            showInfoToast("Nothing to Analyze", message: "Add items before opening analytics")
            return
        }

        overlays.showAnalyticsSidebar = true
        showingAnalysis = false
        if analysisData == nil {
            Task { await generateSidebarAnalysis() }
        }
    }

    internal func closeAnalyticsSidebar() {
        overlays.showAnalyticsSidebar = false
        showingAnalysis = false
    }

    private func generateSidebarAnalysis() async {
        analysisData = await buildAnalysis()
    }

    private func buildAnalysis() async -> TierAnalysisData {
        let allItems = tiers.values.flatMap { $0 }
        guard allItems.isEmpty == false else { return .empty }

        updateProgress(0.3)
        let distribution = tierDistribution(totalCount: allItems.count)

        updateProgress(0.6)
        let (mostPopulated, leastPopulated) = dominantTiers(from: distribution)

        updateProgress(0.8)
        let insights = analysisInsights(distribution: distribution, totalItems: allItems.count)

        let unrankedCount = tiers["unranked"]?.count ?? 0

        return TierAnalysisData(
            totalItems: allItems.count,
            tierDistribution: distribution,
            mostPopulatedTier: mostPopulated,
            leastPopulatedTier: leastPopulated,
            balanceScore: balanceScore(for: distribution),
            insights: insights,
            unrankedCount: unrankedCount
        )
    }

    private func tierDistribution(totalCount: Int) -> [TierDistributionData] {
        tierOrder.compactMap { tier in
            let count = tiers[tier]?.count ?? 0
            guard totalCount > 0 else { return TierDistributionData(tier: tier, count: 0, percentage: 0) }
            let percentage = Double(count) / Double(totalCount) * 100
            return TierDistributionData(tier: tier, count: count, percentage: percentage)
        }
    }

    private func dominantTiers(from distribution: [TierDistributionData]) -> (String?, String?) {
        let most = distribution.max(by: { $0.count < $1.count })?.tier
        let least = distribution.min(by: { $0.count < $1.count })?.tier
        return (most, least)
    }

    private func balanceScore(for distribution: [TierDistributionData]) -> Double {
        guard distribution.isEmpty == false else { return 0 }
        let ideal = 100.0 / Double(distribution.count)
        let totalDiff = distribution.reduce(0) { partial, tier in
            partial + abs(tier.percentage - ideal)
        }
        let normalized = totalDiff / Double(distribution.count)
        return max(0, 100.0 - normalized)
    }

    private func analysisInsights(distribution: [TierDistributionData], totalItems: Int) -> [String] {
        var insights: [String] = []

        if let topTier = distribution.max(by: { $0.percentage < $1.percentage }), topTier.percentage > 40 {
            let formatted = String(format: "%.1f", topTier.percentage)
            insights.append("Tier \(topTier.tier) contains \(formatted)% of all items")
        }

        let score = balanceScore(for: distribution)
        if score < 50 {
            insights.append("Tiers are unevenly distributed - consider rebalancing")
        } else if score > 80 {
            insights.append("Tiers are well-balanced across all categories")
        }

        let unrankedCount = tiers["unranked"]?.count ?? 0
        if unrankedCount > 0 {
            let denominator = max(1, totalItems + unrankedCount)
            let percentage = Double(unrankedCount) / Double(denominator) * 100
            let formatted = String(format: "%.1f", percentage)
            insights.append("\(formatted)% of items remain unranked")
        }

        return insights
    }
}
