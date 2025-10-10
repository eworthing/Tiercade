import SwiftUI
import Observation

@MainActor
struct TierCreatorItemLibrary: View {
    @Bindable var appState: AppState
    let project: TierCreatorProject

    private var selectedItem: TierCreatorItem? {
        project.items.first { $0.itemId == appState.tierCreatorSelectedItemId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 2) {
            Text("Item Library")
                .font(TypeScale.h3)
                .foregroundStyle(Palette.text)
                .padding(.horizontal, Metrics.grid)

            TierCreatorSearchField(text: binding(for: \AppState.tierCreatorSearchQuery))
                .padding(.horizontal, Metrics.grid)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.grid) {
                    ForEach(filteredItems(project.items), id: \TierCreatorItem.itemId) { item in
                        itemRow(for: item)
                    }
                }
                .padding(.horizontal, Metrics.grid)
            }
            .tvGlassRounded(24)

            TierCreatorItemInspector(
                appState: appState,
                item: selectedItem,
                issues: itemIssues(for: selectedItem)
            )
            .focusSection()

            Button(action: handleAddItem) {
                Label("Add Item", systemImage: "plus.rectangle.on.rectangle")
                    .padding(.horizontal, Metrics.grid * 2)
                    .padding(.vertical, Metrics.grid * 1.5)
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_AddItem")
        }
    }

    private func binding<T>(for keyPath: ReferenceWritableKeyPath<AppState, T>) -> Binding<T> {
        Binding(
            get: { appState[keyPath: keyPath] },
            set: { appState[keyPath: keyPath] = $0 }
        )
    }

    private func filteredItems(_ items: [TierCreatorItem]) -> [TierCreatorItem] {
        let query = appState.tierCreatorSearchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.title.localizedCaseInsensitiveContains(query) ||
            (item.summary?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func itemRow(for item: TierCreatorItem) -> some View {
        let isSelected = appState.tierCreatorSelectedItemId == item.itemId
        return Button {
            appState.selectTierCreatorItem(item)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title.isEmpty ? "Untitled" : item.title)
                    .font(TypeScale.body)
                    .foregroundStyle(Palette.text)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(TypeScale.label)
                        .foregroundStyle(Palette.textDim)
                }
            }
            .padding(.vertical, Metrics.grid)
            .padding(.horizontal, Metrics.grid * 1.5)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.tvGlass)
        .accessibilityIdentifier("TierCreator_Item_\(item.itemId)")
        .focusable(true)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Palette.brand.opacity(0.22) : .clear)
        )
    }

    private func handleAddItem() {
        guard let project = appState.tierCreatorActiveProject else { return }
        let nextName = "Item \(project.items.count + 1)"
        let item = appState.addItem(to: project, title: nextName)
        appState.selectTierCreatorItem(item)
    }

    private func itemIssues(for item: TierCreatorItem?) -> [TierCreatorValidationIssue] {
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
struct TierCreatorItemInspector: View {
    @Bindable var appState: AppState
    let item: TierCreatorItem?
    let issues: [TierCreatorValidationIssue]

    @State private var titleDraft: String = ""
    @State private var subtitleDraft: String = ""
    @State private var slugDraft: String = ""
    @State private var summaryDraft: String = ""
    @State private var ratingEnabled: Bool = false
    @State private var ratingDraft: Double = 50

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 1.5) {
            header
            content
        }
        .onAppear(perform: syncDrafts)
        .onChange(of: item?.itemId) { _, _ in syncDrafts() }
        .onChange(of: titleDraft) { _, _ in applyTitleIfNeeded() }
        .onChange(of: subtitleDraft) { _, _ in applySubtitleIfNeeded() }
        .onChange(of: slugDraft) { _, _ in applySlugIfNeeded() }
        .onChange(of: summaryDraft) { _, _ in applySummaryIfNeeded() }
        .onChange(of: ratingEnabled) { _, _ in applyRatingIfNeeded() }
        .onChange(of: ratingDraft) { _, _ in applyRatingIfNeeded() }
    }

    private var header: some View {
        HStack {
            Text("Item Inspector")
                .font(TypeScale.h3)
                .foregroundStyle(Palette.text)
            Spacer()
            if let item {
                Text("Item ID: \(item.itemId)")
                    .font(TypeScale.label)
                    .foregroundStyle(Palette.textDim)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let item {
            VStack(alignment: .leading, spacing: Metrics.grid * 1.5) {
                inspectorField(
                    title: "Title",
                    text: $titleDraft,
                    prompt: "Item title",
                    accessibilityIdentifier: "TierCreator_ItemTitle"
                )

                inspectorField(
                    title: "Subtitle",
                    text: $subtitleDraft,
                    prompt: "Optional subtitle",
                    accessibilityIdentifier: "TierCreator_ItemSubtitle"
                )

                inspectorField(
                    title: "Slug",
                    text: $slugDraft,
                    prompt: "URL-friendly identifier",
                    accessibilityIdentifier: "TierCreator_ItemSlug"
                )
                .textInputAutocapitalization(.none)
                .keyboardType(.alphabet)

                summaryField
                ratingSection(for: item)
                actionRow(for: item)
                validationList
            }
            .padding(.horizontal, Metrics.grid * 2)
            .padding(.vertical, Metrics.grid * 1.5)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Palette.surface)
                    .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
            )
        } else {
            Text("Select an item to edit its properties.")
                .font(TypeScale.body)
                .foregroundStyle(Palette.textDim)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Palette.surface)
                )
        }
    }

    private func inspectorField(
        title: String,
        text: Binding<String>,
        prompt: String,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(TypeScale.label)
                .foregroundStyle(Palette.textDim)
            TextField(prompt, text: text)
                .padding(.horizontal, Metrics.grid * 1.5)
                .padding(.vertical, Metrics.grid)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.surface.opacity(0.72))
                )
                .frame(height: 52)
                .focusable(true)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }

    private var summaryField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Summary")
                .font(TypeScale.label)
                .foregroundStyle(Palette.textDim)
            Group {
                if #available(tvOS 17.0, *) {
                    TextField("Summary", text: $summaryDraft, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    TextField("Summary", text: $summaryDraft)
                        .lineLimit(3)
                }
            }
            .textInputAutocapitalization(.sentences)
            .padding(.horizontal, Metrics.grid * 1.5)
            .padding(.vertical, Metrics.grid)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.surface.opacity(0.72))
            )
            .focusable(true)
            .accessibilityIdentifier("TierCreator_ItemSummary")
        }
    }

    private func ratingSection(for item: TierCreatorItem) -> some View {
        VStack(alignment: .leading, spacing: Metrics.grid) {
            Toggle(isOn: $ratingEnabled) {
                Label("Enable Rating", systemImage: "star.fill")
                    .labelStyle(.titleAndIcon)
            }
            .toggleStyle(.switch)
            .accessibilityIdentifier("TierCreator_ItemRatingToggle")

            if ratingEnabled {
                VStack(alignment: .leading, spacing: Metrics.grid) {
                    ProgressView(value: ratingDraft, total: 100)
                        .tint(Palette.brand)
                        .accessibilityIdentifier("TierCreator_ItemRatingProgress")

                    HStack(spacing: Metrics.grid * 1.5) {
                        Button(action: decrementRating) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32, weight: .bold))
                        }
                        .buttonStyle(.tvGlass)
                        .accessibilityIdentifier("TierCreator_ItemRatingDecrement")

                        VStack(spacing: 4) {
                            Text("\(Int(ratingDraft))")
                                .font(TypeScale.h3.monospacedDigit())
                                .foregroundStyle(Palette.text)
                            Text("out of 100")
                                .font(TypeScale.label)
                                .foregroundStyle(Palette.textDim)
                        }

                        Button(action: incrementRating) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32, weight: .bold))
                        }
                        .buttonStyle(.tvGlass)
                        .accessibilityIdentifier("TierCreator_ItemRatingIncrement")
                    }
                }
            }
        }
    }

    private func actionRow(for item: TierCreatorItem) -> some View {
        HStack(spacing: Metrics.grid * 2) {
            Button(role: .destructive) {
                appState.removeItem(item)
            } label: {
                Label("Delete Item", systemImage: "trash")
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_DeleteItem")

            Spacer()

            Button(action: handleValidate) {
                Label("Validate", systemImage: "checkmark.circle")
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_ItemValidate")
        }
    }

    @ViewBuilder
    private var validationList: some View {
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(issues) { issue in
                    HStack(spacing: Metrics.grid) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.orange)
                        Text(issue.message)
                            .font(TypeScale.label)
                            .foregroundStyle(Palette.textDim)
                    }
                }
            }
            .padding(.horizontal, Metrics.grid * 1.5)
            .padding(.vertical, Metrics.grid)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.orange.opacity(0.12))
            )
            .accessibilityIdentifier("TierCreator_ItemIssues")
        }
    }

    private func syncDrafts() {
        guard let item else {
            titleDraft = ""
            subtitleDraft = ""
            slugDraft = ""
            summaryDraft = ""
            ratingEnabled = false
            ratingDraft = 50
            return
        }
        titleDraft = item.title
        subtitleDraft = item.subtitle ?? ""
        slugDraft = item.slug ?? ""
        summaryDraft = item.summary ?? ""
        if let rating = item.rating {
            ratingDraft = rating
            ratingEnabled = true
        } else {
            ratingDraft = 50
            ratingEnabled = false
        }
    }

    private func incrementRating() {
        ratingDraft = min(100, ratingDraft + 1)
    }

    private func decrementRating() {
        ratingDraft = max(0, ratingDraft - 1)
    }

    private func applyTitleIfNeeded() {
        guard let item, titleDraft != item.title else { return }
        appState.updateItem(item, title: titleDraft)
    }

    private func applySubtitleIfNeeded() {
        guard let item else { return }
        let trimmed = subtitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != (item.subtitle ?? "") {
            appState.updateItem(item, subtitle: trimmed.isEmpty ? nil : trimmed)
        }
    }

    private func applySlugIfNeeded() {
        guard let item else { return }
        let trimmed = slugDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != (item.slug ?? "") {
            appState.updateItem(item, slug: trimmed.isEmpty ? nil : trimmed)
        }
    }

    private func applySummaryIfNeeded() {
        guard let item else { return }
        let trimmed = summaryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != (item.summary ?? "") {
            appState.updateItem(item, summary: trimmed.isEmpty ? nil : trimmed)
        }
    }

    private func applyRatingIfNeeded() {
        guard let item else { return }
        if ratingEnabled {
            if item.rating != ratingDraft {
                appState.updateItem(item, rating: ratingDraft)
            }
        } else if item.rating != nil {
            appState.updateItem(item, rating: nil)
        }
    }

    private func handleValidate() {
        guard let project = appState.tierCreatorActiveProject else { return }
        appState.tierCreatorValidationIssues = appState.stageValidationIssues(
            for: .items,
            project: project
        )
    }
}

@MainActor
struct TierCreatorSearchField: View {
    @Binding var text: String

    var body: some View {
        if #available(tvOS 18.0, *) {
            TextField("Search items", text: $text)
                .padding(.horizontal, Metrics.grid * 1.5)
                .padding(.vertical, Metrics.grid)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.surface.opacity(0.72))
                )
                .submitLabel(.search)
                .frame(height: 48)
                .focusable(true)
        } else {
            Text(text.isEmpty ? "Search unavailable on this tvOS" : text)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.surface.opacity(0.6))
                )
        }
    }
}
