import SwiftUI
import TiercadeCore

// MARK: - Analysis & Statistics Views

struct AnalysisView: View {
    @ObservedObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
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
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Refresh") {
                            Task {
                                await app.generateAnalysis()
                            }
                        }
                        .disabled(app.isLoading)
                    }
                }
    #endif
        }
    }
}

struct AnalysisContentView: View {
    let analysis: TierAnalysisData

    var body: some View {
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

struct OverallStatsView: View {
    let analysis: TierAnalysisData

    var body: some View {
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

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
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

struct TierDistributionChartView: View {
    let distribution: [TierDistributionData]

    var body: some View {
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

struct TierBarView: View {
    let tierData: TierDistributionData

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Tier \(tierData.tier)")
                    .font(.headline)
                    .frame(width: 80, alignment: .leading)
                
                Spacer()
                
                Text("\(tierData.count) items")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("(\(tierData.percentage, specifier: "%.1f")%)")
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            GeometryReader { geometry in
                HStack {
                    Rectangle()
                        .fill(tierColor(for: tierData.tier))
                        .frame(width: max(geometry.size.width * (tierData.percentage / 100), 4))
                        .animation(.easeInOut(duration: 0.6), value: tierData.percentage)
                    
                    Spacer()
                }
            }
            .frame(height: 8)
    }
    .padding(.horizontal, Metrics.grid * 2)
    }
    
    private func tierColor(for tier: String) -> Color {
        switch tier {
        case "S": return .red
        case "A": return .orange
        case "B": return .yellow
        case "C": return .green
        case "D": return .blue
        case "F": return .purple
        default: return .gray
        }
    }
}

struct BalanceScoreView: View {
    let score: Double

    var body: some View {
        VStack(spacing: 16) {
            Text("Balance Score")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                ZStack {
                    let strokeColor: Color = {
    #if os(tvOS)
                        return Palette.surfHi
    #elseif canImport(UIKit)
                        return Color(UIColor.systemGray4)
    #else
                        return Palette.surfHi
    #endif
                    }()

                    Circle()
                        .stroke(strokeColor, lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: score / 100)
                        .stroke(scoreColor, lineWidth: 8)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1), value: score)
                    
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
        if score >= 80 { return .green }
        else if score >= 60 { return .orange }
        else { return .red }
    }
    
    private var scoreDescription: String {
        if score >= 80 { return "Excellent balance across all tiers" }
        else if score >= 60 { return "Good distribution with room for improvement" }
        else { return "Uneven distribution - consider rebalancing" }
    }
}

struct InsightsView: View {
    let insights: [String]

    var body: some View {
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
