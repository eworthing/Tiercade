import SwiftUI
import TiercadeCore

// MARK: - Analysis & Statistics Views

internal struct AnalysisView: View {
    @Bindable var app: AppState
    @Environment(\.dismiss) private var dismiss

    internal var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let analysis = app.analysisData {
                        AnalysisContentView(analysis: analysis)
                    } else if app.isLoading {
                        ProgressView("Generating analysis...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar.fill")
                                .font(TypeScale.h2)
                                .foregroundColor(.secondary)
                                .accessibilityHidden(true)
                            Text("No Analysis Available")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Generate analysis to see tier distribution and insights")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Generate Analysis") {
                                Task {
                                    await app.generateAnalysis()
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            #if !os(tvOS)
                            .controlSize(.large)
                            #endif
                        }
                        .padding(Metrics.grid * 2)
                    }
                }
                .padding(Metrics.grid * 2)
            }
            .navigationTitle("Tier Analysis")
            #if !os(macOS)
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
}

internal struct AnalysisContentView: View {
    internal let analysis: TierAnalysisData

    internal var body: some View {
        VStack(spacing: 24) {
            // Overall Statistics
            OverallStatsView(analysis: analysis)

            // Tier Distribution Chart
            TierDistributionChartView(distribution: analysis.tierDistribution)

            // Balance Score
            BalanceScoreView(score: analysis.balanceScore)

            // Insights
            InsightsView(insights: analysis.insights)
        }
    }
}

internal struct OverallStatsView: View {
    internal let analysis: TierAnalysisData

    internal var body: some View {
        VStack(spacing: 16) {
            Text("Overall Statistics")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCardView(
                    title: "Total Items",
                    value: "\(analysis.totalItems)",
                    icon: "person.3.fill"
                )

                StatCardView(
                    title: "Most Populated",
                    value: analysis.mostPopulatedTier ?? "—",
                    icon: "arrow.up.circle.fill"
                )

                StatCardView(
                    title: "Unranked",
                    value: "\(analysis.unrankedCount)",
                    icon: "questionmark.circle.fill"
                )
            }
        }
        .padding(Metrics.grid * 2)
        .panel()
    }
}

internal struct StatCardView: View {
    internal let title: String
    internal let value: String
    internal let icon: String

    internal var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Palette.text)
                .accessibilityHidden(true)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Metrics.grid)
        .card()
    }
}

internal struct TierDistributionChartView: View {
    internal let distribution: [TierDistributionData]

    internal var body: some View {
        VStack(spacing: 16) {
            Text("Tier Distribution")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                ForEach(distribution) { tier in
                    TierBarView(tierData: tier)
                }
            }
        }
        .padding(Metrics.grid * 2)
        .panel()
    }
}

internal struct TierBarView: View {
    internal let tierData: TierDistributionData
    @Environment(AppState.self) private var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    internal var body: some View {
        VStack(spacing: 4) {
            header
            bar
        }
        .padding(.horizontal, Metrics.grid * 2)
    }

    private var header: some View {
        HStack {
            Text("Tier \(tierData.tier)")
                .font(.headline)
                .frame(width: 80, alignment: .leading)

            Spacer()

            Text("\(tierData.count) items")
                .font(.body)
                .foregroundColor(.secondary)

            Text(percentageText)
                .font(.body)
                .fontWeight(.medium)
        }
    }

    private var bar: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(barColor)
                .frame(width: barWidth(in: geometry.size.width))
                .animation(reduceMotion ? nil : Animation.easeInOut(duration: 0.6), value: tierData.percentage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 8)
    }

    private var barColor: Color {
        Palette.tierColor(tierData.tierId, from: app.tierColors)
    }

    private var percentageText: String {
        String(format: "(%.1f%%)", clampedPercentage)
    }

    private var clampedPercentage: Double {
        min(max(tierData.percentage, 0), 100)
    }

    private func barWidth(in totalWidth: CGFloat) -> CGFloat {
        let scaledWidth = totalWidth * CGFloat(clampedPercentage / 100)
        return max(scaledWidth, 4)
    }
}

internal struct BalanceScoreView: View {
    internal let score: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    internal var body: some View {
        VStack(spacing: 16) {
            Text("Balance Score")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Palette.surfHi, lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: score / 100)
                        .stroke(scoreColor, lineWidth: 8)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : Animation.easeInOut(duration: 1), value: score)

                    VStack {
                        Text("\(score, specifier: "%.0f")")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor)
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(scoreDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Metrics.grid * 2)
        .panel()
    }

    private var scoreColor: Color {
        switch score {
        case 80...:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }

    private var scoreDescription: String {
        switch score {
        case 80...:
            return "Excellent balance across all tiers"
        case 60..<80:
            return "Good distribution with room for improvement"
        default:
            return "Uneven distribution - consider rebalancing"
        }
    }
}

internal struct InsightsView: View {
    internal let insights: [String]

    internal var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights & Recommendations")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: Metrics.grid) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 20)
                            .accessibilityHidden(true)

                        Text(insight)
                            .font(TypeScale.body)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .padding(.horizontal, Metrics.grid)
                    .padding(.vertical, Metrics.grid * 0.5)
                    .card()
                }
            }
        }
        .padding(Metrics.grid * 2)
        .panel()
    }
}
