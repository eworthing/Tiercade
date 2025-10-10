import Foundation
import SwiftData
import os

@MainActor
extension AppState {
    // MARK: - Fetching

    func fetchTierCreatorProjects(limit: Int? = nil) -> [TierCreatorProject] {
        var descriptor = FetchDescriptor<TierCreatorProject>(
            sortBy: [SortDescriptor(\TierCreatorProject.updatedAt, order: .reverse)]
        )
        if let limit {
            descriptor.fetchLimit = limit
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func loadTierCreatorProject(id: UUID) -> TierCreatorProject? {
        let predicate = #Predicate<TierCreatorProject> { $0.projectId == id }
        let descriptor = FetchDescriptor<TierCreatorProject>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        if let results = try? modelContext.fetch(descriptor) {
            return results.first
        }
        return nil
    }

    // MARK: - Creation

    @discardableResult
    func createTierCreatorProject(
        title: String,
        description: String? = nil,
        schemaVersion: Int = 1,
        tierKeys: [String] = ["S", "A", "B", "C", "D", "F", "unranked"]
    ) -> TierCreatorProject {
        let project = TierCreatorProject(
            schemaVersion: schemaVersion,
            title: title,
            projectDescription: description,
            tierSortOrder: "S-F",
            themePreference: "system"
        )

        project.sourceType = .manual
        project.workflowStage = .setup
        project.hasGeneratedBaseTiers = false
        modelContext.insert(project)

        for (index, key) in tierKeys.enumerated() {
            let tier = TierCreatorTier(
                tierId: key,
                label: key,
                colorHex: nil,
                order: index,
                isLocked: key == "unranked",
                isCollapsed: false,
                projectId: project.projectId,
                project: project
            )
            project.tiers.append(tier)
        }

        project.updatedAt = Date()
        markAsChanged()
        return project
    }

    // MARK: - Tier Editing

    @discardableResult
    func addTier(
        to project: TierCreatorProject,
        tierId: String,
        label: String,
        colorHex: String? = nil,
        order: Int? = nil,
        isLocked: Bool = false,
        isCollapsed: Bool = false
    ) -> TierCreatorTier {
        let resolvedOrder: Int
        if let order {
            resolvedOrder = order
        } else {
            resolvedOrder = (project.tiers.map(\.order).max() ?? -1) + 1
        }

        let tier = TierCreatorTier(
            tierId: tierId,
            label: label,
            colorHex: colorHex,
            order: resolvedOrder,
            isLocked: isLocked,
            isCollapsed: isCollapsed,
            projectId: project.projectId,
            project: project
        )
        project.tiers.append(tier)
        modelContext.insert(tier)
        normalizeTierOrders(for: project)
        touch(project)
        return tier
    }

    func updateTier(
        _ tier: TierCreatorTier,
        label: String? = nil,
        colorHex: String? = nil,
        isLocked: Bool? = nil,
        isCollapsed: Bool? = nil,
        rulesData: Data? = nil
    ) {
        if let label {
            tier.label = label
        }
        if let colorHex {
            tier.colorHex = colorHex
        }
        if let isLocked {
            tier.isLocked = isLocked
        }
        if let isCollapsed {
            tier.isCollapsed = isCollapsed
        }
        if let rulesData {
            tier.rulesData = rulesData
        }
        if let project = tier.project {
            tier.projectId = project.projectId
            touch(project)
        }
    }

    func removeTier(_ tier: TierCreatorTier) {
        guard let project = tier.project else { return }
        if let index = project.tiers.firstIndex(where: { $0 === tier }) {
            project.tiers.remove(at: index)
            modelContext.delete(tier)
            normalizeTierOrders(for: project)
            touch(project)
        }
    }

    private func normalizeTierOrders(for project: TierCreatorProject) {
        let sorted = project.tiers.sorted { $0.order < $1.order }
        for (index, tier) in sorted.enumerated() {
            tier.order = index
        }
    }

    // MARK: - Item Editing

    @discardableResult
    func addItem(
        to project: TierCreatorProject,
        title: String,
        itemId: String = UUID().uuidString
    ) -> TierCreatorItem {
        let item = TierCreatorItem(
            itemId: itemId,
            title: title,
            project: project
        )
        project.items.append(item)
        modelContext.insert(item)
        touch(project)
        return item
    }

    func updateItem(
        _ item: TierCreatorItem,
        title: String? = nil,
        subtitle: String? = nil,
        summary: String? = nil,
        slug: String? = nil,
        rating: Double? = nil
    ) {
        if let title {
            item.title = title
        }
        if let subtitle {
            item.subtitle = subtitle
        }
        if let summary {
            item.summary = summary
        }
        if let slug {
            item.slug = slug
        }
        if let rating {
            item.rating = rating
        }
        item.updatedAt = Date()
        if let project = item.project {
            touch(project)
        }
    }

    func removeItem(_ item: TierCreatorItem) {
        guard let project = item.project else { return }
        if let index = project.items.firstIndex(where: { $0 === item }) {
            project.items.remove(at: index)
        }
        modelContext.delete(item)
        touch(project)
    }

    // MARK: - Override Editing

    @discardableResult
    func ensureOverride(for item: TierCreatorItem, in project: TierCreatorProject) -> TierCreatorItemOverride {
        if let existing = item.overrides.first(where: { $0.project === project }) {
            return existing
        }
        let override = TierCreatorItemOverride(project: project, item: item)
        override.project = project
        override.item = item
        item.overrides.append(override)
        project.overrides.append(override)
        modelContext.insert(override)
        touch(project)
        return override
    }

    func removeOverride(_ override: TierCreatorItemOverride) {
        if let project = override.project,
           let index = project.overrides.firstIndex(where: { $0 === override }) {
            project.overrides.remove(at: index)
            touch(project)
        }
        if let item = override.item,
           let index = item.overrides.firstIndex(where: { $0 === override }) {
            item.overrides.remove(at: index)
        }
        modelContext.delete(override)
    }

    // MARK: - Media Editing

    @discardableResult
    func addMedia(
        to item: TierCreatorItem,
        mediaId: String = UUID().uuidString,
        kind: String,
        uri: String,
        mimeType: String
    ) -> TierCreatorMedia {
        let media = TierCreatorMedia(
            mediaId: mediaId,
            kind: kind,
            uri: uri,
            mimeType: mimeType,
            item: item
        )
        item.media.append(media)
        modelContext.insert(media)
        if let project = item.project {
            touch(project)
        }
        return media
    }

    @discardableResult
    func addMedia(
        to override: TierCreatorItemOverride,
        mediaId: String = UUID().uuidString,
        kind: String,
        uri: String,
        mimeType: String
    ) -> TierCreatorMedia {
        let media = TierCreatorMedia(
            mediaId: mediaId,
            kind: kind,
            uri: uri,
            mimeType: mimeType,
            override: override
        )
        override.media.append(media)
        modelContext.insert(media)
        if let project = override.project {
            touch(project)
        }
        return media
    }

    func removeMedia(_ media: TierCreatorMedia) {
        if let item = media.item,
           let index = item.media.firstIndex(where: { $0 === media }) {
            item.media.remove(at: index)
        }
        if let override = media.override,
           let index = override.media.firstIndex(where: { $0 === media }) {
            override.media.remove(at: index)
        }
        modelContext.delete(media)
        if let project = media.item?.project ?? media.override?.project {
            touch(project)
        }
    }

    // MARK: - Persist Helpers

    @discardableResult
    func saveTierCreatorChanges() -> Bool {
        saveTierCreatorChanges(for: tierCreatorActiveProject)
    }

    @discardableResult
    func openTierCreator(with project: TierCreatorProject?) -> TierCreatorProject {
        let resolvedProject: TierCreatorProject

        if let project {
            resolvedProject = project
        } else if let existing = fetchTierCreatorProjects(limit: 1).first {
            resolvedProject = existing
        } else {
            resolvedProject = createTierCreatorProject(title: "Untitled Project")
        }

        tierCreatorActiveProject = resolvedProject
        showingTierCreator = true
        tierCreatorStage = resolvedProject.workflowStage
        tierCreatorValidationIssues = stageValidationIssues(for: tierCreatorStage, project: resolvedProject)
        tierCreatorSelectedTierId = resolvedProject.tiers.sorted(by: { $0.order < $1.order }).first?.tierId
        tierCreatorSelectedItemId = resolvedProject.items.first?.itemId
        return resolvedProject
    }

    func closeTierCreator() {
        showingTierCreator = false
        tierCreatorActiveProject = nil
        tierCreatorStage = .setup
        tierCreatorSelectedTierId = nil
        tierCreatorSelectedItemId = nil
        tierCreatorValidationIssues = []
        tierCreatorSearchQuery = ""
    }

    func selectTierCreatorTier(_ tier: TierCreatorTier?) {
        tierCreatorSelectedTierId = tier?.tierId
        if let tier, tier.project != tierCreatorActiveProject {
            tierCreatorActiveProject = tier.project
        }
    }

    func selectTierCreatorItem(_ item: TierCreatorItem?) {
        tierCreatorSelectedItemId = item?.itemId
        if let project = item?.project, tierCreatorActiveProject !== project {
            tierCreatorActiveProject = project
        }
    }

    func setTierCreatorStage(_ stage: TierCreatorStage) {
        guard let project = tierCreatorActiveProject else {
            tierCreatorStage = stage
            return
        }
        tierCreatorStage = stage
        project.workflowStage = stage
        touch(project)
        tierCreatorValidationIssues = stageValidationIssues(for: stage, project: project)
    }

    func advanceTierCreatorStage() {
        guard let project = tierCreatorActiveProject else { return }
        let issues = stageValidationIssues(for: tierCreatorStage, project: project)
        tierCreatorValidationIssues = issues
        guard issues.isEmpty else {
            if let issue = issues.first {
                showWarningToast("Needs attention", message: issue.message)
            }
            return
        }

        switch tierCreatorStage {
        case .setup:
            setTierCreatorStage(.items)
            showSuccessToast("Project setup complete", message: "Start authoring items")
        case .items:
            setTierCreatorStage(.structure)
            showSuccessToast("Items ready", message: "Arrange tiers and publish")
        case .structure:
            publishTierCreatorProject()
        }
    }

    func retreatTierCreatorStage() {
        switch tierCreatorStage {
        case .setup:
            break
        case .items:
            setTierCreatorStage(.setup)
        case .structure:
            setTierCreatorStage(.items)
        }
    }

    func publishTierCreatorProject() {
        guard let project = tierCreatorActiveProject else { return }
        if saveTierCreatorChanges(for: project) {
            showSuccessToast("Project published", message: project.title)
        } else if let issue = tierCreatorValidationIssues.first {
            showErrorToast("Fix validation issues", message: issue.message)
        }
    }

    private func touch(_ project: TierCreatorProject) {
        project.updatedAt = Date()
        markAsChanged()
    }
}
