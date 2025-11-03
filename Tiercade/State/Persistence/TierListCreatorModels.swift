import Foundation
import SwiftData
import TiercadeCore

// MARK: - Encoding Helpers

internal enum TierListCreatorCodec {
    nonisolated static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    nonisolated static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    nonisolated static func encode<T: Encodable>(_ value: T?) -> Data? {
        guard let value else { return nil }
        return try? makeEncoder().encode(value)
    }

    nonisolated static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? makeDecoder().decode(type, from: data)
    }
}

// MARK: - Project Draft Models

@Model
final class TierProjectDraft {
    @Attribute(.unique) var identifier: UUID
    var projectId: UUID
    var schemaVersion: Int
    var title: String
    var summary: String
    var themeToken: String
    var tierSortOrder: String
    var gridSnap: Bool
    var showUnranked: Bool
    var accessibilityVoiceOver: Bool
    var accessibilityHighContrast: Bool
    var visibility: String
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String?
    var updatedBy: String?
    var additionalData: Data?
    var linksData: Data?
    var storageData: Data?
    var settingsData: Data?
    var collaborationData: Data?
    @Relationship(deleteRule: .cascade, inverse: \TierDraftTier.project) var tiers: [TierDraftTier]
    @Relationship(deleteRule: .cascade, inverse: \TierDraftItem.project) var items: [TierDraftItem]
    @Relationship(deleteRule: .cascade, inverse: \TierDraftOverride.project) var overrides: [TierDraftOverride]
    @Relationship(deleteRule: .cascade, inverse: \TierDraftMedia.project) var mediaLibrary: [TierDraftMedia]
    @Relationship(
        deleteRule: .cascade,
        inverse: \TierDraftCollabMember.project
    ) var collaborators: [TierDraftCollabMember]
    @Relationship(deleteRule: .cascade, inverse: \TierDraftAudit.project) var audit: TierDraftAudit?

    internal init(
        identifier: UUID = UUID(),
        projectId: UUID = UUID(),
        schemaVersion: Int = 1,
        title: String = "Untitled Project",
        summary: String = "",
        themeToken: String = "system-default",
        tierSortOrder: String = "descending",
        gridSnap: Bool = true,
        showUnranked: Bool = true,
        accessibilityVoiceOver: Bool = true,
        accessibilityHighContrast: Bool = false,
        visibility: String = "private",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String? = nil,
        updatedBy: String? = nil,
        tiers: [TierDraftTier] = [],
        items: [TierDraftItem] = [],
        overrides: [TierDraftOverride] = [],
        mediaLibrary: [TierDraftMedia] = [],
        collaborators: [TierDraftCollabMember] = [],
        audit: TierDraftAudit? = nil
    ) {
        self.identifier = identifier
        self.projectId = projectId
        self.schemaVersion = schemaVersion
        self.title = title
        self.summary = summary
        self.themeToken = themeToken
        self.tierSortOrder = tierSortOrder
        self.gridSnap = gridSnap
        self.showUnranked = showUnranked
        self.accessibilityVoiceOver = accessibilityVoiceOver
        self.accessibilityHighContrast = accessibilityHighContrast
        self.visibility = visibility
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.updatedBy = updatedBy
        self.tiers = tiers
        self.items = items
        self.overrides = overrides
        self.mediaLibrary = mediaLibrary
        self.collaborators = collaborators
        self.audit = audit
    }
}

extension TierProjectDraft {
    var links: Project.Links? {
        get { TierListCreatorCodec.decode(Project.Links.self, from: linksData) }
        set { linksData = TierListCreatorCodec.encode(newValue) }
    }

    var storage: Project.Storage? {
        get { TierListCreatorCodec.decode(Project.Storage.self, from: storageData) }
        set { storageData = TierListCreatorCodec.encode(newValue) }
    }

    var settings: Project.Settings {
        get {
            TierListCreatorCodec.decode(Project.Settings.self, from: settingsData)
                ?? Project.Settings(
                    theme: themeToken,
                    tierSortOrder: tierSortOrder,
                    gridSnap: gridSnap,
                    showUnranked: showUnranked,
                    accessibility: [
                        "voiceOver": accessibilityVoiceOver,
                        "highContrast": accessibilityHighContrast
                    ]
                )
        }
        set { settingsData = TierListCreatorCodec.encode(newValue) }
    }

    var additional: [String: JSONValue]? {
        get { TierListCreatorCodec.decode([String: JSONValue].self, from: additionalData) }
        set { additionalData = TierListCreatorCodec.encode(newValue) }
    }

    var collaboration: Project.Collaboration? {
        get { TierListCreatorCodec.decode(Project.Collaboration.self, from: collaborationData) }
        set { collaborationData = TierListCreatorCodec.encode(newValue) }
    }
}

// MARK: - Tier Draft Model

@Model
final class TierDraftTier {
    @Attribute(.unique) var identifier: UUID
    var tierId: String
    var label: String
    var colorHex: String
    var order: Int
    var locked: Bool
    var collapsed: Bool
    var rulesData: Data?
    var additionalData: Data?
    @Relationship(deleteRule: .nullify, inverse: \TierDraftItem.tier) var items: [TierDraftItem]
    @Relationship var project: TierProjectDraft?

    internal init(
        identifier: UUID = UUID(),
        tierId: String,
        label: String,
        colorHex: String,
        order: Int,
        locked: Bool = false,
        collapsed: Bool = false,
        items: [TierDraftItem] = []
    ) {
        self.identifier = identifier
        self.tierId = tierId
        self.label = label
        self.colorHex = colorHex
        self.order = order
        self.locked = locked
        self.collapsed = collapsed
        self.items = items
    }
}

extension TierDraftTier {
    var rules: [String: JSONValue] {
        get { TierListCreatorCodec.decode([String: JSONValue].self, from: rulesData) ?? [:] }
        set { rulesData = TierListCreatorCodec.encode(newValue.isEmpty ? nil : newValue) }
    }

    var additional: [String: JSONValue] {
        get { TierListCreatorCodec.decode([String: JSONValue].self, from: additionalData) ?? [:] }
        set { additionalData = TierListCreatorCodec.encode(newValue.isEmpty ? nil : newValue) }
    }
}

// MARK: - Item Draft Model

@Model
final class TierDraftItem {
    @Attribute(.unique) var identifier: UUID
    var itemId: String
    var title: String
    var subtitle: String
    var summary: String
    var slug: String
    var rating: Double?
    var hidden: Bool
    var ordinal: Int
    var attributesData: Data?
    var tags: [String]
    var sourcesData: Data?
    var localeData: Data?
    var additionalData: Data?
    var metaData: Data?
    @Relationship(deleteRule: .cascade, inverse: \TierDraftMedia.item) var media: [TierDraftMedia]
    @Relationship(deleteRule: .nullify, inverse: \TierDraftOverride.item) var overrides: [TierDraftOverride]
    @Relationship var tier: TierDraftTier?
    @Relationship var project: TierProjectDraft?

    internal init(
        identifier: UUID = UUID(),
        itemId: String,
        title: String,
        subtitle: String = "",
        summary: String = "",
        slug: String = "",
        rating: Double? = nil,
        hidden: Bool = false,
        ordinal: Int = 0,
        tags: [String] = [],
        media: [TierDraftMedia] = [],
        overrides: [TierDraftOverride] = []
    ) {
        self.identifier = identifier
        self.itemId = itemId
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.slug = slug
        self.rating = rating
        self.hidden = hidden
        self.ordinal = ordinal
        self.tags = tags
        self.media = media
        self.overrides = overrides
    }
}

extension TierDraftItem {
    var attributes: [String: JSONValue] {
        get { TierListCreatorCodec.decode([String: JSONValue].self, from: attributesData) ?? [:] }
        set { attributesData = TierListCreatorCodec.encode(newValue.isEmpty ? nil : newValue) }
    }

    var sources: [[String: String]] {
        get { TierListCreatorCodec.decode([[String: String]].self, from: sourcesData) ?? [] }
        set { sourcesData = TierListCreatorCodec.encode(newValue.isEmpty ? nil : newValue) }
    }

    var locale: [String: [String: String]] {
        get { TierListCreatorCodec.decode([String: [String: String]].self, from: localeData) ?? [:] }
        set { localeData = TierListCreatorCodec.encode(newValue.isEmpty ? nil : newValue) }
    }

    var additional: [String: JSONValue] {
        get { TierListCreatorCodec.decode([String: JSONValue].self, from: additionalData) ?? [:] }
        set { additionalData = TierListCreatorCodec.encode(newValue.isEmpty ? nil : newValue) }
    }

    var meta: Project.Audit? {
        get { TierListCreatorCodec.decode(Project.Audit.self, from: metaData) }
        set { metaData = TierListCreatorCodec.encode(newValue) }
    }
}

// MARK: - Overrides

@Model
final class TierDraftOverride {
    @Attribute(.unique) var identifier: UUID
    var itemId: String
    var displayTitle: String
    var notes: String
    var tags: [String]
    var rating: Double?
    var hidden: Bool
    var additionalData: Data?
    @Relationship(deleteRule: .cascade, inverse: \TierDraftMedia.override) var media: [TierDraftMedia]
    @Relationship var item: TierDraftItem?
    @Relationship var project: TierProjectDraft?

    internal init(
        identifier: UUID = UUID(),
        itemId: String,
        displayTitle: String = "",
        notes: String = "",
        tags: [String] = [],
        rating: Double? = nil,
        hidden: Bool = false,
        media: [TierDraftMedia] = []
    ) {
        self.identifier = identifier
        self.itemId = itemId
        self.displayTitle = displayTitle
        self.notes = notes
        self.tags = tags
        self.rating = rating
        self.hidden = hidden
        self.media = media
    }
}

extension TierDraftOverride {
    var additional: [String: JSONValue] {
        get { TierListCreatorCodec.decode([String: JSONValue].self, from: additionalData) ?? [:] }
        set { additionalData = TierListCreatorCodec.encode(newValue.isEmpty ? nil : newValue) }
    }
}

// MARK: - Media Library

@Model
final class TierDraftMedia {
    @Attribute(.unique) var identifier: UUID
    var mediaId: String
    var kindRaw: String
    var uri: String
    var mime: String
    var width: Double?
    var height: Double?
    var durationMs: Double?
    var posterUri: String?
    var thumbUri: String?
    var altText: String?
    var attributionData: Data?
    var additionalData: Data?
    @Relationship var item: TierDraftItem?
    @Relationship var override: TierDraftOverride?
    @Relationship var project: TierProjectDraft?

    internal init(
        identifier: UUID = UUID(),
        mediaId: String,
        kindRaw: String,
        uri: String,
        mime: String,
        width: Double? = nil,
        height: Double? = nil,
        durationMs: Double? = nil,
        posterUri: String? = nil,
        thumbUri: String? = nil,
        altText: String? = nil
    ) {
        self.identifier = identifier
        self.mediaId = mediaId
        self.kindRaw = kindRaw
        self.uri = uri
        self.mime = mime
        self.width = width
        self.height = height
        self.durationMs = durationMs
        self.posterUri = posterUri
        self.thumbUri = thumbUri
        self.altText = altText
    }
}

extension TierDraftMedia {
    var attribution: [String: String] {
        get { TierListCreatorCodec.decode([String: String].self, from: attributionData) ?? [:] }
        set { attributionData = TierListCreatorCodec.encode(newValue.isEmpty ? nil : newValue) }
    }

    var additional: [String: JSONValue] {
        get { TierListCreatorCodec.decode([String: JSONValue].self, from: additionalData) ?? [:] }
        set { additionalData = TierListCreatorCodec.encode(newValue.isEmpty ? nil : newValue) }
    }

    var kind: ProjectMediaKind {
        ProjectMediaKind(rawValue: kindRaw) ?? .image
    }

    internal func toProjectMedia() -> Project.Media {
        Project.Media(
            id: mediaId,
            kind: kind,
            uri: uri,
            mime: mime,
            w: width,
            h: height,
            durationMs: durationMs,
            posterUri: posterUri,
            thumbUri: thumbUri,
            alt: altText,
            attribution: attribution.isEmpty ? nil : attribution,
            additional: additional.isEmpty ? nil : additional
        )
    }
}

// MARK: - Audit & Collaboration

@Model
final class TierDraftAudit {
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String?
    var updatedBy: String?
    @Relationship var project: TierProjectDraft?

    internal init(
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String? = nil,
        updatedBy: String? = nil
    ) {
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.updatedBy = updatedBy
    }
}

extension TierDraftAudit {
    var projectAudit: Project.Audit {
        Project.Audit(
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdBy: createdBy,
            updatedBy: updatedBy
        )
    }
}

@Model
final class TierDraftCollabMember {
    @Attribute(.unique) var identifier: UUID
    var userId: String
    var role: String
    var additionalData: Data?
    @Relationship var project: TierProjectDraft?

    internal init(
        identifier: UUID = UUID(),
        userId: String,
        role: String,
        additionalData: Data? = nil
    ) {
        self.identifier = identifier
        self.userId = userId
        self.role = role
        self.additionalData = additionalData
    }
}

extension TierDraftCollabMember {
    var additional: [String: JSONValue] {
        get { TierListCreatorCodec.decode([String: JSONValue].self, from: additionalData) ?? [:] }
        set { additionalData = TierListCreatorCodec.encode(newValue.isEmpty ? nil : newValue) }
    }

    var member: Project.Member {
        Project.Member(userId: userId, role: role, additional: additional.isEmpty ? nil : additional)
    }
}

// MARK: - Draft Seeding
