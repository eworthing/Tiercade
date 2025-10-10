import Observation
import SwiftUI

@MainActor
struct TierCreatorStructureStageView: View {
    @Bindable var appState: AppState
    let project: TierCreatorProject

    private var tiers: [TierCreatorTier] {
        project.tiers.sorted { $0.order < $1.order }
    }

    private var selectedTier: TierCreatorTier? {
        tiers.first { $0.tierId == appState.tierCreatorSelectedTierId }
    }

    private var itemLookup: [String: TierCreatorItem] {
        Dictionary(uniqueKeysWithValues: project.items.map { ($0.itemId, $0) })
    }

    private var assignedItemIds: Set<String> {
        Set(project.tiers.flatMap { $0.itemIds })
    }

    private var unassignedItems: [TierCreatorItem] {
        project.items.filter { !assignedItemIds.contains($0.itemId) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.grid * 2) {
            TierCreatorStageCard(title: "Arrange tiers", subtitle: "Organize order and settings") {
                TierCreatorTierRail(
                    appState: appState,
                    project: project,
                    tiers: tiers,
                    selectedTier: selectedTier,
                    addTier: handleAddTier
                )
            }
            .frame(maxWidth: Metrics.paneLeft)
            #if os(tvOS)
            .focusSection()
            #endif

            TierCreatorStageCard(title: "Live preview", subtitle: "Review items in their tiers") {
                TierCreatorCanvasPreview(
                    appState: appState,
                    project: project,
                    tiers: tiers,
                    itemLookup: itemLookup,
                    unassignedItems: unassignedItems
                )
            }
            #if os(tvOS)
            .focusSection()
            #endif
        }
    }

    private func handleAddTier() {
        let existingIds = Set(project.tiers.map(\.tierId))
        let base = "Tier \(project.tiers.count + 1)"
        var candidate = base
        var index = 1
        while existingIds.contains(candidate) {
            index += 1
            candidate = "\(base) \(index)"
        }

        let newTier = appState.addTier(
            to: project,
            tierId: candidate.replacingOccurrences(of: " ", with: "-"),
            label: candidate
        )
        appState.selectTierCreatorTier(newTier)
    }
}

@MainActor
struct TierCreatorTierRail: View {
    @Bindable var appState: AppState
    let project: TierCreatorProject
    let tiers: [TierCreatorTier]
    let selectedTier: TierCreatorTier?
    let addTier: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 2) {
            Text("Tiers")
                .font(TypeScale.h3)
                .foregroundStyle(Palette.text)
                .padding(.horizontal, Metrics.grid)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.grid) {
                    ForEach(tiers, id: \.tierId) { tier in
                        TierRailRow(
                            appState: appState,
                            project: project,
                            tier: tier,
                            isSelected: tier.tierId == selectedTier?.tierId
                        )
                    }
                }
                .padding(.horizontal, Metrics.grid)
                .padding(.vertical, Metrics.grid)
            }
            .tvGlassRounded(24)

            Button(action: addTier) {
                Label("Add Tier", systemImage: "text.line.first.and.arrowtriangle.forward")
                    .padding(.horizontal, Metrics.grid * 2)
                    .padding(.vertical, Metrics.grid * 1.5)
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_AddTier")

            TierCreatorTierInspector(
                appState: appState,
                tier: selectedTier,
                issues: selectedTier.map { issues(for: $0) } ?? []
            )
        }
    }

    private func issues(for tier: TierCreatorTier) -> [TierCreatorValidationIssue] {
        appState.tierCreatorValidationIssues.filter { issue in
            if case let .tier(projectId: projectId, tierId: tierId) = issue.scope {
                return projectId == project.projectId && tierId == tier.tierId
            }
            return false
        }
    }
}

@MainActor
struct TierRailRow: View {
    @Bindable var appState: AppState
    let project: TierCreatorProject
    let tier: TierCreatorTier
    let isSelected: Bool

    private var issueCount: Int {
        appState.tierCreatorValidationIssues.filter { issue in
            if case let .tier(projectId: projectId, tierId: tierId) = issue.scope {
                return projectId == project.projectId && tierId == tier.tierId
            }
            return false
        }.count
    }

    var body: some View {
        Button {
            appState.selectTierCreatorTier(tier)
        } label: {
            HStack(alignment: .center, spacing: Metrics.grid * 1.5) {
                Text(tier.label.isEmpty ? tier.tierId : tier.label)
                    .font(TypeScale.body)
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)

                Spacer()

                if issueCount > 0 {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.orange)
                }

                Text("\(tier.itemIds.count)")
                    .font(TypeScale.label)
                    .foregroundStyle(Palette.textDim)
            }
            .padding(.vertical, Metrics.grid)
            .padding(.horizontal, Metrics.grid * 1.5)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("TierCreator_Tier_\(tier.tierId)")
    }
}

@MainActor
struct TierCreatorCanvasPreview: View {
    @Bindable var appState: AppState
    let project: TierCreatorProject
    let tiers: [TierCreatorTier]
    let itemLookup: [String: TierCreatorItem]
    let unassignedItems: [TierCreatorItem]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.grid * 1.5) {
                ForEach(tiers, id: \.tierId) { tier in
                    TierPreviewCard(
                        appState: appState,
                        project: project,
                        tier: tier,
                        items: items(for: tier)
                    )
                }

                if !unassignedItems.isEmpty {
                    TierPreviewCard(
                        appState: appState,
                        project: project,
                        tier: TierCreatorTier(
                            tierId: "unassigned",
                            label: "Unassigned",
                            order: Int.max,
                            projectId: project.projectId
                        ),
                        items: unassignedItems
                    )
                }
            }
            .padding(.horizontal, Metrics.grid * 2)
            .padding(.vertical, Metrics.grid * 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Palette.surface)
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 12)
        )
    }

    private func items(for tier: TierCreatorTier) -> [TierCreatorItem] {
        tier.itemIds.compactMap { itemLookup[$0] }
    }
}

@MainActor
struct TierPreviewCard: View {
    @Bindable var appState: AppState
    let project: TierCreatorProject
    let tier: TierCreatorTier
    let items: [TierCreatorItem]

    private var issueCount: Int {
        appState.tierCreatorValidationIssues.filter { issue in
            if case let .tier(projectId: projectId, tierId: tierId) = issue.scope {
                return projectId == project.projectId && tierId == tier.tierId
            }
            return false
        }.count
    }

    private var isSelected: Bool {
        tier.tierId == appState.tierCreatorSelectedTierId
    }

    private var tint: Color {
        if let hex = tier.colorHex, !hex.isEmpty {
            return ColorUtilities.color(hex: hex)
        }
        return Palette.tierColor(tier.tierId)
    }

    private var headerTextColor: Color {
        if let hex = tier.colorHex, !hex.isEmpty {
            return ColorUtilities.accessibleTextColor(onBackground: hex)
        }
        return Palette.text
    }

    var body: some View {
        Button {
            appState.selectTierCreatorTier(tier)
        } label: {
            VStack(alignment: .leading, spacing: Metrics.grid * 1.5) {
                HStack(alignment: .center, spacing: Metrics.grid) {
                    Text(tier.label.isEmpty ? tier.tierId : tier.label)
                        .font(TypeScale.body.weight(.semibold))
                        .foregroundStyle(headerTextColor)
                        .lineLimit(1)

                    Spacer()

                    if issueCount > 0 {
                        Label("\(issueCount)", systemImage: "exclamationmark.triangle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(TypeScale.label)
                            .foregroundStyle(Color.orange)
                    }

                    Text("\(items.count)")
                        .font(TypeScale.label)
                        .foregroundStyle(headerTextColor.opacity(0.8))
                }

                if items.isEmpty {
                    Text("No items yet")
                        .font(TypeScale.label)
                        .foregroundStyle(Palette.textDim)
                } else {
                    VStack(alignment: .leading, spacing: Metrics.grid * 0.75) {
                        ForEach(items.prefix(6), id: \.itemId) { item in
                            HStack {
                                Text(item.title.isEmpty ? "Untitled" : item.title)
                                    .font(TypeScale.label)
                                    .foregroundStyle(Palette.text)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, Metrics.grid * 1.25)
                            .padding(.vertical, Metrics.grid * 0.75)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Palette.surfHi)
                            )
                        }

                        if items.count > 6 {
                            Text("+\(items.count - 6) more")
                                .font(TypeScale.label)
                                .foregroundStyle(Palette.textDim)
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.grid * 2)
            .padding(.vertical, Metrics.grid * 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(tint.opacity(isSelected ? 0.32 : 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(isSelected ? Palette.brand : tint.opacity(0.4), lineWidth: isSelected ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
        .focusable(true)
        .accessibilityIdentifier("TierCreator_PreviewTier_\(tier.tierId)")
    }
}
