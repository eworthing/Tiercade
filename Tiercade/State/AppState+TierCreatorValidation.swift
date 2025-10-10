import Foundation
import os

private let hexColorRegex: Regex<Substring> = {
    // Accept full #RRGGBB colors only for deterministic palette handling.
    do {
        return try Regex(#"^#[0-9A-Fa-f]{6}$"#)
    } catch {
        preconditionFailure("Invalid hex color regex: \(error)")
    }
}()

enum TierCreatorValidationScope: Hashable, Sendable {
    case project(UUID)
    case tier(projectId: UUID, tierId: String)
    case item(projectId: UUID, itemId: String)
    case media(projectId: UUID, ownerId: String, mediaId: String)
    case override(projectId: UUID, itemId: String)
}

struct TierCreatorValidationIssue: Identifiable, Hashable, Sendable {
    let id = UUID()
    let scope: TierCreatorValidationScope
    let message: String
}

@MainActor
extension AppState {
    func validateTierCreatorProject(_ project: TierCreatorProject) -> [TierCreatorValidationIssue] {
        stageValidationIssues(for: .structure, project: project)
    }

    func stageValidationIssues(
        for stage: TierCreatorStage,
        project: TierCreatorProject
    ) -> [TierCreatorValidationIssue] {
        var issues: [TierCreatorValidationIssue] = []

        switch stage {
        case .setup:
            issues.append(contentsOf: validateProjectMetadata(project))
        case .items:
            issues.append(contentsOf: validateProjectMetadata(project))
            var observedMediaIds: Set<String> = []
            issues.append(contentsOf: validateItems(
                in: project,
                observedMediaIds: &observedMediaIds
            ))
        case .structure:
            issues.append(contentsOf: validateProjectMetadata(project))
            issues.append(contentsOf: validateTiers(in: project))
            var observedMediaIds: Set<String> = []
            issues.append(contentsOf: validateItems(
                in: project,
                observedMediaIds: &observedMediaIds
            ))
            issues.append(contentsOf: validateOverrides(
                in: project,
                observedMediaIds: &observedMediaIds
            ))
        }

        return issues
    }

    @discardableResult
    func saveTierCreatorChanges(for project: TierCreatorProject? = nil) -> Bool {
        if let project {
            tierCreatorValidationIssues = validateTierCreatorProject(project)
            guard tierCreatorValidationIssues.isEmpty else {
                Logger.persistence.error("TierCreator validation failed; refusing to save")
                return false
            }
        } else {
            tierCreatorValidationIssues = []
        }

        do {
            try modelContext.save()
            hasUnsavedChanges = false
            lastSavedTime = Date()
            return true
        } catch {
            Logger.persistence.error("TierCreator save failed: \(error.localizedDescription)")
            return false
        }
    }

    private func validateProjectMetadata(_ project: TierCreatorProject) -> [TierCreatorValidationIssue] {
        var issues: [TierCreatorValidationIssue] = []
        if project.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(
                scope: .project(project.projectId),
                message: "Project title can't be empty"
            ))
        }
        return issues
    }

    private func validateTiers(in project: TierCreatorProject) -> [TierCreatorValidationIssue] {
        var issues: [TierCreatorValidationIssue] = []
        var observedTierIds: Set<String> = []

        for tier in project.tiers {
            issues.append(contentsOf: validateTierIdentifier(
                tier,
                projectId: project.projectId,
                seen: &observedTierIds
            ))
            issues.append(contentsOf: validateTierColor(tier, projectId: project.projectId))
            if tier.projectId != project.projectId {
                issues.append(.init(
                    scope: .tier(projectId: project.projectId, tierId: tier.tierId),
                    message: "Tier project linkage is inconsistent"
                ))
            }
        }

        return issues
    }

    private func validateTierIdentifier(
        _ tier: TierCreatorTier,
        projectId: UUID,
        seen: inout Set<String>
    ) -> [TierCreatorValidationIssue] {
        var issues: [TierCreatorValidationIssue] = []
        let trimmedId = tier.tierId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedId.isEmpty {
            issues.append(.init(
                scope: .tier(projectId: projectId, tierId: tier.tierId),
                message: "Tier ID can't be blank"
            ))
        } else if !seen.insert(trimmedId).inserted {
            issues.append(.init(
                scope: .tier(projectId: projectId, tierId: tier.tierId),
                message: "Duplicate tier ID \(trimmedId)"
            ))
        }
        return issues
    }

    private func validateTierColor(_ tier: TierCreatorTier, projectId: UUID) -> [TierCreatorValidationIssue] {
        guard let color = tier.colorHex, !color.isEmpty else { return [] }
        if color.wholeMatch(of: hexColorRegex) != nil {
            return []
        }
        return [TierCreatorValidationIssue(
            scope: .tier(projectId: projectId, tierId: tier.tierId),
            message: "Tier color must be a #RRGGBB hex value"
        )]
    }

    private func validateItems(
        in project: TierCreatorProject,
        observedMediaIds: inout Set<String>
    ) -> [TierCreatorValidationIssue] {
        var issues: [TierCreatorValidationIssue] = []
        var observedItemIds: Set<String> = []
        var observedSlugs: Set<String> = []

        for item in project.items {
            issues.append(contentsOf: validateItemBasics(
                item,
                projectId: project.projectId,
                seenIds: &observedItemIds,
                seenSlugs: &observedSlugs
            ))
            issues.append(contentsOf: validateMediaCollection(
                item.media,
                projectId: project.projectId,
                ownerId: item.itemId,
                observedMediaIds: &observedMediaIds
            ))
        }

        return issues
    }

    private func validateItemBasics(
        _ item: TierCreatorItem,
        projectId: UUID,
        seenIds: inout Set<String>,
        seenSlugs: inout Set<String>
    ) -> [TierCreatorValidationIssue] {
        var issues: [TierCreatorValidationIssue] = []

        if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(
                scope: .item(projectId: projectId, itemId: item.itemId),
                message: "Item title can't be empty"
            ))
        }

        if !seenIds.insert(item.itemId).inserted {
            issues.append(.init(
                scope: .item(projectId: projectId, itemId: item.itemId),
                message: "Duplicate item ID \(item.itemId)"
            ))
        }

        if let slug = item.slug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty,
           !seenSlugs.insert(slug).inserted {
            issues.append(.init(
                scope: .item(projectId: projectId, itemId: item.itemId),
                message: "Duplicate item slug \(slug)"
            ))
        }

        return issues
    }

    private func validateOverrides(
        in project: TierCreatorProject,
        observedMediaIds: inout Set<String>
    ) -> [TierCreatorValidationIssue] {
        var issues: [TierCreatorValidationIssue] = []

        for override in project.overrides {
            guard let item = override.item else { continue }
            if override.project?.projectId != project.projectId {
                issues.append(.init(
                    scope: .override(projectId: project.projectId, itemId: item.itemId),
                    message: "Override project linkage is inconsistent"
                ))
            }

            issues.append(contentsOf: validateMediaCollection(
                override.media,
                projectId: project.projectId,
                ownerId: item.itemId,
                observedMediaIds: &observedMediaIds
            ))
        }

        return issues
    }

    private func validateMediaCollection(
        _ media: [TierCreatorMedia],
        projectId: UUID,
        ownerId: String,
        observedMediaIds: inout Set<String>
    ) -> [TierCreatorValidationIssue] {
        var issues: [TierCreatorValidationIssue] = []
        for asset in media {
            issues.append(contentsOf: validateMediaAsset(
                asset,
                projectId: projectId,
                ownerId: ownerId,
                observedMediaIds: &observedMediaIds
            ))
        }
        return issues
    }

    private func validateMediaAsset(
        _ media: TierCreatorMedia,
        projectId: UUID,
        ownerId: String,
        observedMediaIds: inout Set<String>
    ) -> [TierCreatorValidationIssue] {
        var issues: [TierCreatorValidationIssue] = []
        let scope = TierCreatorValidationScope.media(
            projectId: projectId,
            ownerId: ownerId,
            mediaId: media.mediaId
        )

        if !observedMediaIds.insert(media.mediaId).inserted {
            issues.append(.init(scope: scope, message: "Duplicate media ID \(media.mediaId)"))
        }

        if !isValidURI(media.uri) {
            issues.append(.init(scope: scope, message: "Media URI must be a valid absolute URL"))
        }

        if let poster = media.posterUri, !poster.isEmpty, !isValidURI(poster) {
            issues.append(.init(scope: scope, message: "Poster URI must be a valid absolute URL"))
        }

        if let thumb = media.thumbUri, !thumb.isEmpty, !isValidURI(thumb) {
            issues.append(.init(scope: scope, message: "Thumbnail URI must be a valid absolute URL"))
        }

        return issues
    }

    private func isValidURI(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme, !scheme.isEmpty else {
            return false
        }
        return url.host != nil || scheme == "file"
    }
}
