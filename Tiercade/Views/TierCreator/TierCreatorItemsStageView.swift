import Observation
import SwiftUI

@MainActor
struct TierCreatorItemsStageView: View {
    @Bindable var appState: AppState
    let project: TierCreatorProject
    let focusNamespace: Namespace.ID

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 280, maximum: 320), spacing: Metrics.grid * 1.5)]
    }

    private var selectedItem: TierCreatorItem? {
        project.items.first { $0.itemId == appState.tierCreatorSelectedItemId }
    }

    private var filteredItems: [TierCreatorItem] {
        let query = appState.tierCreatorSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = project.items.sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.title.localizedCaseInsensitiveContains(query) ||
            (item.summary?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.grid * 2) {
            library
                .focusSection()
                .frame(maxWidth: .infinity, alignment: .leading)

            inspector
                .frame(maxWidth: Metrics.paneRight)
                .focusSection()
        }
    }

    private var library: some View {
        TierCreatorStageCard(title: "Author items", subtitle: "Create entries and manage drafts") {
            VStack(alignment: .leading, spacing: Metrics.grid * 1.5) {
                TierCreatorSearchField(text: binding(for: \.tierCreatorSearchQuery))
                    .prefersDefaultFocus(in: focusNamespace)

                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: Metrics.grid * 1.5) {
                        ForEach(filteredItems, id: \.itemId) { item in
                            TierCreatorItemCard(
                                item: item,
                                isSelected: item.itemId == appState.tierCreatorSelectedItemId,
                                issueCount: issueCount(for: item)
                            ) {
                                appState.selectTierCreatorItem(item)
                            }
                        }
                    }
                    .padding(.vertical, Metrics.grid)
                }
                .frame(maxHeight: 480)
                .tvGlassRounded(24)

                ItemsStageToolbar(appState: appState, project: project)
            }
        }
    }

    private var inspector: some View {
        TierCreatorStageCard(title: "Item inspector") {
            TierCreatorItemInspector(
                appState: appState,
                item: selectedItem,
                issues: issues(for: selectedItem)
            )
        }
    }

    private func binding<T>(for keyPath: ReferenceWritableKeyPath<AppState, T>) -> Binding<T> {
        Binding(
            get: { appState[keyPath: keyPath] },
            set: { appState[keyPath: keyPath] = $0 }
        )
    }

    private func issueCount(for item: TierCreatorItem) -> Int {
        issues(for: item).count
    }

    private func issues(for item: TierCreatorItem?) -> [TierCreatorValidationIssue] {
        guard let item else { return [] }
        return appState.tierCreatorValidationIssues.filter { issue in
            if case let .item(projectId, itemId) = issue.scope {
                return projectId == project.projectId && itemId == item.itemId
            }
            return false
        }
    }
}

@MainActor
struct ItemsStageToolbar: View {
    @Bindable var appState: AppState
    let project: TierCreatorProject

    var body: some View {
        HStack(spacing: Metrics.grid * 1.5) {
            Button {
                let nextName = "Item \(project.items.count + 1)"
                let item = appState.addItem(to: project, title: nextName)
                appState.selectTierCreatorItem(item)
            } label: {
                Label("Add item", systemImage: "plus.rectangle.on.rectangle")
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_AddItem")

            Button {
                appState.showInfoToast("Bulk import", message: "Import from CSV coming soon")
            } label: {
                Label("Bulk import", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_BulkImport")

            Button {
                appState.showInfoToast("Template", message: "Sample items coming soon")
            } label: {
                Label("Generate sample", systemImage: "sparkles")
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_GenerateSample")

            Spacer()
        }
    }
}

@MainActor
struct TierCreatorItemCard: View {
    let item: TierCreatorItem
    let isSelected: Bool
    let issueCount: Int
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Metrics.grid) {
                HStack(alignment: .firstTextBaseline, spacing: Metrics.grid) {
                    Text(item.title.isEmpty ? "Untitled" : item.title)
                        .font(TypeScale.body.weight(.semibold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    if issueCount > 0 {
                        Label("\(issueCount)", systemImage: "exclamationmark.triangle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(Color.orange)
                    }
                }

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(TypeScale.label)
                        .foregroundStyle(Palette.textDim)
                }

                Text(item.summary?.isEmpty == false ? item.summary! : "No summary yet")
                    .font(TypeScale.label)
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(2)
            }
            .padding(.horizontal, Metrics.grid * 1.5)
            .padding(.vertical, Metrics.grid * 1.25)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.tvGlass)
        .focusable(true)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isSelected ? Palette.brand.opacity(0.22) : Palette.surface.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? Palette.brand : Color.clear, lineWidth: isSelected ? 2 : 0)
        )
        .accessibilityIdentifier("TierCreator_ItemCard_\(item.itemId)")
    }
}
