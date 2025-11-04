import SwiftUI
import TiercadeCore
import os

// MARK: - Tiers Wizard Page

internal struct TiersWizardPage: View, WizardPage {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    @State private var selectedTierID: UUID?
    @State private var showingTierDetailsSheet = false

    internal let pageTitle = "Tier Assignment"
    internal let pageDescription = "Review and manage item assignments to tiers"

    #if os(tvOS)
    @Namespace private var defaultFocusNamespace
    #endif

    internal var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.grid * 3) {
                    assignmentOverviewSection

                    Divider()
                        .padding(.horizontal, Metrics.grid * 6)

                    tierManagementSection
                }
                .padding(.horizontal, Metrics.grid * 6)
                .padding(.vertical, Metrics.grid * 5)
            }

            // Add tier button at bottom
            HStack {
                Spacer()
                Button {
                    let newTier = appState.addTier(to: draft)
                    selectedTierID = newTier.identifier
                    showingTierDetailsSheet = true
                } label: {
                    Label("Add Tier", systemImage: "plus.circle.fill")
                }
                #if os(tvOS)
                .buttonStyle(.glassProminent)
                .prefersDefaultFocus(true, in: defaultFocusNamespace)
                #else
                .buttonStyle(.borderedProminent)
                #endif
                .accessibilityIdentifier("Tiers_AddTier")
            }
            .padding(.horizontal, Metrics.grid * 6)
            .padding(.vertical, Metrics.grid * 3)
            .background(
                Rectangle()
                    .fill(Palette.cardBackground.opacity(0.9))
                    .overlay(Rectangle().stroke(Palette.stroke, lineWidth: 1))
            )
        }
        #if os(tvOS)
        // Scope default focus for tvOS so prefersDefaultFocus is reliable
        .focusScope(defaultFocusNamespace)
        #endif
        .sheet(isPresented: $showingTierDetailsSheet) {
            if let tier = currentTier {
                TierDetailsSheet(appState: appState, draft: draft, tier: tier)
            }
        }
    }

    private var assignmentOverviewSection: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 2) {
            Text("Assignment Overview")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.text)

            let assignedCount = draft.items.filter { $0.tier != nil }.count
            let totalCount = draft.items.count
            let percentage = totalCount > 0 ? Double(assignedCount) / Double(totalCount) * 100 : 0

            HStack(spacing: Metrics.grid * 3) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assigned Items")
                        .font(.caption)
                        .foregroundStyle(Palette.textDim)
                    Text("\(assignedCount) / \(totalCount)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Palette.text)
                }

                Divider()
                    .frame(height: 50)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Completion")
                        .font(.caption)
                        .foregroundStyle(Palette.textDim)
                    Text(String(format: "%.0f%%", percentage))
                        .font(.title.weight(.bold))
                        .foregroundStyle(percentage == 100 ? Palette.tierColor("B") : Palette.text)
                }

                Spacer()
            }
            .padding(Metrics.grid * 2.5)
            .background(
                RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                    .fill(Palette.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                            .stroke(Palette.stroke, lineWidth: 1)
                    )
            )
        }
    }

    private var tierManagementSection: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 2) {
            Text("Tier Management")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.text)

            if orderedTiers.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: Metrics.grid * 2) {
                    ForEach(orderedTiers) { tier in
                        tierManagementCard(tier)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(Palette.textDim)
            Text("No tiers defined")
                .font(.title3)
            Text("Use the Add Tier button below to create ranking tiers")
                .font(.body)
                .foregroundStyle(Palette.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                .fill(Palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                )
        )
    }

    private func tierManagementCard(_ tier: TierDraftTier) -> some View {
        let items = appState.orderedItems(for: tier)

        return HStack(spacing: 16) {
            Circle()
                .fill(ColorUtilities.color(hex: tier.colorHex))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Palette.stroke.opacity(0.5), lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(tier.label)
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Text("\(items.count) items")
                    .font(.caption)
                    .foregroundStyle(Palette.textDim)
            }

            Spacer()

            HStack(spacing: 8) {
                tierActionButton("arrow.up") { appState.moveTier(tier, direction: -1, in: draft) }
                tierActionButton("arrow.down") { appState.moveTier(tier, direction: 1, in: draft) }
                tierActionButton("pencil") {
                    selectedTierID = tier.identifier
                    showingTierDetailsSheet = true
                }
                tierActionButton("trash", role: .destructive) { appState.delete(tier, from: draft) }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                .fill(Palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                )
        )
    }

    private func tierActionButton(
        _ icon: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: icon)
        }
        #if os(tvOS)
        .buttonStyle(.glass)
        #else
        .buttonStyle(.bordered)
        #endif
    }

    // MARK: - Helpers

    private var orderedTiers: [TierDraftTier] {
        appState.orderedTiers(for: draft)
    }

    private var currentTier: TierDraftTier? {
        guard let id = selectedTierID else { return nil }
        return draft.tiers.first { $0.identifier == id }
    }
}
