import Foundation
import SwiftData
import TiercadeCore

extension TierProjectDraft {
    static func makeDefault(now: Date = Date()) -> TierProjectDraft {
        let audit = TierDraftAudit(createdAt: now, updatedAt: now)
        let draft = TierProjectDraft(
            projectId: UUID(),
            schemaVersion: 1,
            title: "Untitled Project",
            summary: "",
            themeToken: "system-default",
            tiers: [],
            items: [],
            overrides: [],
            mediaLibrary: [],
            collaborators: [],
            audit: audit
        )
        audit.project = draft

        let palette = [
            ("tier.s", "S", "#FF3B30"),
            ("tier.a", "A", "#FF9500"),
            ("tier.b", "B", "#FFCC00"),
            ("tier.c", "C", "#34C759"),
            ("tier.d", "D", "#007AFF"),
            ("tier.f", "F", "#5856D6")
        ]

        for (index, entry) in palette.enumerated() {
            let tier = TierDraftTier(
                tierId: entry.0,
                label: entry.1,
                colorHex: entry.2,
                order: index
            )
            tier.project = draft
            draft.tiers.append(tier)
        }

        return draft
    }

    static func make(from project: Project) -> TierProjectDraft {
        let projectUUID = UUID(uuidString: project.projectId) ?? UUID()
        let auditSource = project.audit
        let settings = project.settings

        let draft = TierProjectDraft(
            projectId: projectUUID,
            schemaVersion: project.schemaVersion,
            title: project.title ?? "Untitled Project",
            summary: project.description ?? "",
            themeToken: settings?.theme ?? "system-default",
            tierSortOrder: settings?.tierSortOrder ?? "descending",
            gridSnap: settings?.gridSnap ?? true,
            showUnranked: settings?.showUnranked ?? true,
            accessibilityVoiceOver: settings?.accessibility?["voiceOver"] ?? true,
            accessibilityHighContrast: settings?.accessibility?["highContrast"] ?? false,
            visibility: project.links?.visibility ?? "private",
            createdAt: auditSource.createdAt,
            updatedAt: auditSource.updatedAt,
            createdBy: auditSource.createdBy,
            updatedBy: auditSource.updatedBy
        )

        setupDraftMetadata(draft: draft, project: project, settings: settings)

        func makeMediaDraft(from media: Project.Media) -> TierDraftMedia {
            createMediaDraft(from: media, project: draft)
        }

        let itemDrafts = populateItems(from: project, draft: draft, makeMediaDraft: makeMediaDraft)
        populateOverrides(from: project, draft: draft, itemDrafts: itemDrafts, makeMediaDraft: makeMediaDraft)
        populateTiers(from: project, draft: draft, itemDrafts: itemDrafts)

        draft.updatedAt = auditSource.updatedAt
        return draft
    }

    private static func setupDraftMetadata(
        draft: TierProjectDraft,
        project: Project,
        settings: Project.Settings?
    ) {
        let audit = TierDraftAudit(
            createdAt: project.audit.createdAt,
            updatedAt: project.audit.updatedAt,
            createdBy: project.audit.createdBy,
            updatedBy: project.audit.updatedBy
        )
        audit.project = draft
        draft.audit = audit
        draft.links = project.links
        draft.storage = project.storage
        draft.settings = settings ?? Project.Settings(
            theme: draft.themeToken,
            tierSortOrder: draft.tierSortOrder,
            gridSnap: draft.gridSnap,
            showUnranked: draft.showUnranked,
            accessibility: [
                "voiceOver": draft.accessibilityVoiceOver,
                "highContrast": draft.accessibilityHighContrast
            ]
        )
        draft.collaboration = project.collab
        draft.additional = project.additional
    }

    private static func createMediaDraft(
        from media: Project.Media,
        project: TierProjectDraft
    ) -> TierDraftMedia {
        let mediaDraft = TierDraftMedia(
            mediaId: media.id,
            kindRaw: media.kind.rawValue,
            uri: media.uri,
            mime: media.mime,
            width: media.w,
            height: media.h,
            durationMs: media.durationMs,
            posterUri: media.posterUri,
            thumbUri: media.thumbUri,
            altText: media.alt
        )
        mediaDraft.project = project
        mediaDraft.attribution = media.attribution ?? [:]
        mediaDraft.additional = media.additional ?? [:]
        return mediaDraft
    }

    private static func populateItems(
        from project: Project,
        draft: TierProjectDraft,
        makeMediaDraft: (Project.Media) -> TierDraftMedia
    ) -> [String: TierDraftItem] {
        var itemDrafts: [String: TierDraftItem] = [:]
        for (identifier, item) in project.items {
            let itemDraft = TierDraftItem(
                itemId: identifier,
                title: item.title,
                subtitle: item.subtitle ?? "",
                summary: item.summary ?? "",
                slug: item.slug ?? "",
                rating: item.rating,
                hidden: false
            )
            itemDraft.project = draft
            itemDraft.tags = item.tags ?? []
            itemDraft.attributes = item.attributes ?? [:]
            itemDraft.sources = item.sources ?? []
            itemDraft.locale = item.locale ?? [:]
            itemDraft.additional = item.additional ?? [:]
            itemDraft.meta = item.meta

            if let media = item.media {
                itemDraft.media = media.map { mediaElement in
                    let draftMedia = makeMediaDraft(mediaElement)
                    draftMedia.item = itemDraft
                    return draftMedia
                }
            }

            draft.items.append(itemDraft)
            itemDrafts[identifier] = itemDraft
        }
        return itemDrafts
    }

    private static func populateOverrides(
        from project: Project,
        draft: TierProjectDraft,
        itemDrafts: [String: TierDraftItem],
        makeMediaDraft: (Project.Media) -> TierDraftMedia
    ) {
        guard let overrides = project.overrides else { return }

        for (identifier, override) in overrides {
            let overrideDraft = TierDraftOverride(
                itemId: identifier,
                displayTitle: override.displayTitle ?? "",
                notes: override.notes ?? "",
                tags: override.tags ?? [],
                rating: override.rating,
                hidden: override.hidden ?? false
            )
            overrideDraft.project = draft
            overrideDraft.additional = override.additional ?? [:]

            if let media = override.media {
                overrideDraft.media = media.map { mediaElement in
                    let draftMedia = makeMediaDraft(mediaElement)
                    draftMedia.override = overrideDraft
                    return draftMedia
                }
            }

            if let itemDraft = itemDrafts[identifier] {
                overrideDraft.item = itemDraft
                itemDraft.overrides.append(overrideDraft)
            }

            draft.overrides.append(overrideDraft)
        }
    }

    private static func populateTiers(
        from project: Project,
        draft: TierProjectDraft,
        itemDrafts: [String: TierDraftItem]
    ) {
        let orderedTiers = project.tiers.sorted { $0.order < $1.order }
        for tier in orderedTiers {
            let tierDraft = TierDraftTier(
                tierId: tier.id,
                label: tier.label,
                colorHex: tier.color ?? Self.defaultColor(for: tier.order),
                order: tier.order,
                locked: tier.locked ?? false,
                collapsed: tier.collapsed ?? false
            )
            tierDraft.project = draft
            tierDraft.rules = tier.rules ?? [:]
            tierDraft.additional = tier.additional ?? [:]

            var ordinal = 0
            for itemId in tier.itemIds {
                guard let itemDraft = itemDrafts[itemId] else { continue }
                itemDraft.tier = tierDraft
                itemDraft.ordinal = ordinal
                ordinal += 1
                tierDraft.items.append(itemDraft)
            }

            draft.tiers.append(tierDraft)
        }
    }

    private static func defaultColor(for index: Int) -> String {
        guard index >= 0 else { return fallbackTierColors.first ?? "#FF3B30" }
        return fallbackTierColors[index % fallbackTierColors.count]
    }

    private static let fallbackTierColors: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#AF52DE",
        "#FF2D55", "#5AC8FA", "#FF9F0A", "#FFD60A"
    ]
}
