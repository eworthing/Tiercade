#if os(tvOS)
import SwiftUI
import Observation
import Charts

internal struct AnalyticsSidebarView: View {
    @Environment(AppState.self) private var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FocusState private var focusedElement: FocusElement?

    private enum FocusElement: Hashable {
        case close
        case insight(Int)
    }

    internal var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * 0.65
            ZStack(alignment: .trailing) {
                // Background dimming (non-focusable; tap to dismiss)
                Palette.bg.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { app.closeAnalyticsSidebar() }
                    .accessibilityHidden(true)

                ZStack(alignment: .topTrailing) {
                    sidebarContent
                        .frame(width: width, height: proxy.size.height, alignment: .top)

                    closeButton
                        .padding(60)
                }
                .frame(width: width, height: proxy.size.height, alignment: .top)
                .background(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 24, x: -8, y: 0)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Analytics Sidebar")
                .accessibilityHint("View tier distribution statistics and balance score")
                .accessibilityAddTraits(.isModal)
                #if os(tvOS)
                .focusSection()
                .defaultFocus($focusedElement, .close)
                .onAppear { focusedElement = .close }
                .onDisappear { focusedElement = nil }
                .onExitCommand { app.closeAnalyticsSidebar() }
                #endif
            }
            .transition(
                .move(edge: .trailing)
                    .combined(with: .opacity)
            )
            .animation(
                reduceMotion ? nil : Animation.easeInOut(duration: 0.35),
                value: app.overlays.showAnalyticsSidebar
            )
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
        if let analysis = app.analysisData {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    headerSection(totalItems: analysis.totalItems)
                    balanceScoreSection(score: analysis.balanceScore)
                    tierDistributionSection(distribution: analysis.tierDistribution)
                    insightsSection(insights: analysis.insights)
                }
                .padding(.horizontal, 60)
                .padding(.top, 60)
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)
        } else {
            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(2.0)
                Text("Calculating statistics...")
                    .font(TypeScale.analyticsBody)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var closeButton: some View {
        Button("Close", role: .close) {
            app.closeAnalyticsSidebar()
        }
        .buttonStyle(.borderedProminent)
        .focused($focusedElement, equals: .close)
        .accessibilityIdentifier("Analytics_Close")
    }

    private func headerSection(totalItems: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analytics")
                .font(TypeScale.analyticsTitle)
            Text("\(totalItems) items")
                .font(TypeScale.analyticsBody)
                .foregroundStyle(.secondary)
        }
    }

    private func balanceScoreSection(score: Double) -> some View {
        let interpretation = balanceInterpretation(for: score)
        return VStack(alignment: .leading, spacing: 16) {
            Text("Balance Score")
                .font(TypeScale.analyticsSection)

            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Text(balanceScoreText(score))
                    .font(TypeScale.analyticsHero)
                    .foregroundColor(balanceColor(for: score))
                Text("/100")
                    .font(TypeScale.analyticsSubtitle)
                    .foregroundStyle(.secondary)
            }

            Text(interpretation)
                .font(TypeScale.analyticsCaption)
                .foregroundStyle(.secondary)
        }
    }

    private func tierDistributionSection(distribution: [TierDistributionData]) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Tier Distribution")
                .font(TypeScale.analyticsSection)

            Chart(distribution) { tier in
                BarMark(
                    x: .value("Items", tier.count),
                    y: .value("Tier", tier.tier)
                )
                .foregroundStyle(Palette.tierColor(tier.tierId, from: app.tierColors))
                .annotation(position: .trailing) {
                    Text(percentageText(for: tier.percentage))
                        .font(TypeScale.analyticsBadge)
                        .foregroundStyle(Palette.text)
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartLegend(.hidden)
            .frame(height: max(220, CGFloat(distribution.count) * 56))
            .padding(.trailing, 24)
            .accessibilityIdentifier("Analytics_DistributionChart")
        }
    }

    private func insightsSection(insights: [String]) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Insights")
                .font(TypeScale.analyticsSection)

            if insights.isEmpty {
                Text("Your tier list looks balanced!")
                    .font(TypeScale.analyticsCaption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                        insightCard(text: insight, index: index)
                    }
                }
            }
        }
    }

    private func insightCard(text: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "lightbulb.fill")
                .font(TypeScale.analyticsCaption)
                .foregroundColor(.yellow)
                .padding(.top, 4)
                .accessibilityHidden(true)

            Text(text)
                .font(TypeScale.analyticsCaption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfHi)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        #if os(tvOS)
        .focused($focusedElement, equals: .insight(index))
        #endif
    }

    private func balanceColor(for score: Double) -> Color {
        switch score {
        case 80...100:
            return .green
        case 60..<80:
            return .yellow
        default:
            return .red
        }
    }

    private func balanceInterpretation(for score: Double) -> String {
        switch score {
        case 80...100:
            return "Well balanced"
        case 60..<80:
            return "Moderately balanced"
        case 40..<60:
            return "Somewhat unbalanced"
        default:
            return "Needs rebalancing"
        }
    }

    private func balanceScoreText(_ score: Double) -> String {
        String(format: "%.0f", max(0, min(score, 100)))
    }

    private func percentageText(for percentage: Double) -> String {
        String(format: "%.1f%%", percentage)
    }
}

#endif
