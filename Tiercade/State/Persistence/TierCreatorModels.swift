import Foundation
import SwiftData

// MARK: - Helper Types

enum TierCreatorAttributeValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case stringArray([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([String].self) {
            self = .stringArray(array)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .stringArray(let value):
            try container.encode(value)
        }
    }
}

typealias TierCreatorAttributes = [String: TierCreatorAttributeValue]

enum TierCreatorSourceType: String, CaseIterable, Codable, Sendable {
    case manual
    case bundled
    case importFile

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .bundled: return "Bundled"
        case .importFile: return "Import"
        }
    }
}

enum TierCreatorStage: String, CaseIterable, Codable, Sendable {
    case setup
    case items
    case structure

    var displayTitle: String {
        switch self {
        case .setup: return "Project"
        case .items: return "Items"
        case .structure: return "Structure"
        }
    }

    var systemImageName: String {
        switch self {
        case .setup: return "slider.horizontal.3"
        case .items: return "rectangle.stack"
        case .structure: return "square.grid.3x3"
        }
    }
}

// MARK: - Project

@Model
final class TierCreatorProject {
    #Unique<TierCreatorProject>([\.projectId])
    #Index<TierCreatorProject>([\.title])
    var projectId: UUID
    var schemaVersion: Int
    var title: String
    var projectDescription: String?
    var tierSortOrder: String
    var themePreference: String
    var creationNotes: String?
    var sourceTypeRaw: String
    var hasGeneratedBaseTiers: Bool
    var workflowStageRaw: String
    var settingsData: Data?
    var linksData: Data?
    var storageData: Data?
    var collabData: Data?
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String?
    var updatedBy: String?
    @Relationship(deleteRule: .cascade, inverse: \TierCreatorTier.project)
    var tiers: [TierCreatorTier]
    @Relationship(deleteRule: .cascade, inverse: \TierCreatorItem.project)
    var items: [TierCreatorItem]
    @Relationship(deleteRule: .cascade, inverse: \TierCreatorItemOverride.project)
    var overrides: [TierCreatorItemOverride]

    init(
        projectId: UUID = UUID(),
        schemaVersion: Int = 1,
        title: String,
        projectDescription: String? = nil,
        tierSortOrder: String = "S-F",
        themePreference: String = "system",
        creationNotes: String? = nil,
        sourceTypeRaw: String = TierCreatorSourceType.manual.rawValue,
        hasGeneratedBaseTiers: Bool = false,
        workflowStageRaw: String = TierCreatorStage.setup.rawValue,
        settingsData: Data? = nil,
        linksData: Data? = nil,
        storageData: Data? = nil,
        collabData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String? = nil,
        updatedBy: String? = nil,
        tiers: [TierCreatorTier] = [],
        items: [TierCreatorItem] = [],
        overrides: [TierCreatorItemOverride] = []
    ) {
        self.projectId = projectId
        self.schemaVersion = schemaVersion
        self.title = title
        self.projectDescription = projectDescription
        self.tierSortOrder = tierSortOrder
        self.themePreference = themePreference
        self.creationNotes = creationNotes
        self.sourceTypeRaw = sourceTypeRaw
        self.hasGeneratedBaseTiers = hasGeneratedBaseTiers
        self.workflowStageRaw = workflowStageRaw
        self.settingsData = settingsData
        self.linksData = linksData
        self.storageData = storageData
        self.collabData = collabData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.updatedBy = updatedBy
        self.tiers = tiers
        self.items = items
        self.overrides = overrides
    }
}

extension TierCreatorProject {
    var sourceType: TierCreatorSourceType {
        get { TierCreatorSourceType(rawValue: sourceTypeRaw) ?? .manual }
        set { sourceTypeRaw = newValue.rawValue }
    }

    var workflowStage: TierCreatorStage {
        get { TierCreatorStage(rawValue: workflowStageRaw) ?? .setup }
        set { workflowStageRaw = newValue.rawValue }
    }
}

// MARK: - Tiers

@Model
final class TierCreatorTier {
    #Unique<TierCreatorTier>([\.tierId, \.projectId])
    #Index<TierCreatorTier>([\.order])
    var tierId: String
    var label: String
    var colorHex: String?
    var order: Int
    var isLocked: Bool
    var isCollapsed: Bool
    var rulesData: Data?
    var itemIds: [String]
    var projectId: UUID
    @Relationship var project: TierCreatorProject?

    init(
        tierId: String,
        label: String,
        colorHex: String? = nil,
        order: Int,
        isLocked: Bool = false,
        isCollapsed: Bool = false,
        rulesData: Data? = nil,
        itemIds: [String] = [],
        projectId: UUID,
        project: TierCreatorProject? = nil
    ) {
        self.tierId = tierId
        self.label = label
        self.colorHex = colorHex
        self.order = order
        self.isLocked = isLocked
        self.isCollapsed = isCollapsed
        self.rulesData = rulesData
        self.itemIds = itemIds
        self.projectId = projectId
        self.project = project
    }
}

// MARK: - Items

@Model
final class TierCreatorItem {
    #Unique<TierCreatorItem>([\.itemId])
    #Index<TierCreatorItem>([\.title])
    var itemId: String
    var title: String
    var subtitle: String?
    var summary: String?
    var slug: String?
    var rating: Double?
    var tagsData: Data?
    var attributesData: Data?
    var localeData: Data?
    var sourcesData: Data?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \TierCreatorMedia.item)
    var media: [TierCreatorMedia]
    @Relationship var project: TierCreatorProject?
    @Relationship(deleteRule: .cascade, inverse: \TierCreatorItemOverride.item)
    var overrides: [TierCreatorItemOverride]

    init(
        itemId: String,
        title: String,
        subtitle: String? = nil,
        summary: String? = nil,
        slug: String? = nil,
        rating: Double? = nil,
        tagsData: Data? = nil,
        attributesData: Data? = nil,
        localeData: Data? = nil,
        sourcesData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        media: [TierCreatorMedia] = [],
        project: TierCreatorProject? = nil,
        overrides: [TierCreatorItemOverride] = []
    ) {
        self.itemId = itemId
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.slug = slug
        self.rating = rating
        self.tagsData = tagsData
        self.attributesData = attributesData
        self.localeData = localeData
        self.sourcesData = sourcesData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.media = media
        self.project = project
        self.overrides = overrides
    }
}

// MARK: - Media

@Model
final class TierCreatorMedia {
    #Unique<TierCreatorMedia>([\.mediaId])
    var mediaId: String
    var kind: String
    var uri: String
    var mimeType: String
    var width: Double?
    var height: Double?
    var durationMilliseconds: Double?
    var posterUri: String?
    var thumbUri: String?
    var altText: String?
    var attributionData: Data?
    @Relationship var item: TierCreatorItem?
    @Relationship var override: TierCreatorItemOverride?

    init(
        mediaId: String,
        kind: String,
        uri: String,
        mimeType: String,
        width: Double? = nil,
        height: Double? = nil,
        durationMilliseconds: Double? = nil,
        posterUri: String? = nil,
        thumbUri: String? = nil,
        altText: String? = nil,
        attributionData: Data? = nil,
        item: TierCreatorItem? = nil,
        override: TierCreatorItemOverride? = nil
    ) {
        self.mediaId = mediaId
        self.kind = kind
        self.uri = uri
        self.mimeType = mimeType
        self.width = width
        self.height = height
        self.durationMilliseconds = durationMilliseconds
        self.posterUri = posterUri
        self.thumbUri = thumbUri
        self.altText = altText
        self.attributionData = attributionData
        self.item = item
        self.override = override
    }
}

// MARK: - Overrides

@Model
final class TierCreatorItemOverride {
    #Index<TierCreatorItemOverride>([\.displayTitle])
    var displayTitle: String?
    var notes: String?
    var rating: Double?
    var tagsData: Data?
    var isHidden: Bool
    @Relationship var project: TierCreatorProject?
    @Relationship var item: TierCreatorItem?
    @Relationship(deleteRule: .cascade, inverse: \TierCreatorMedia.override)
    var media: [TierCreatorMedia]

    init(
        displayTitle: String? = nil,
        notes: String? = nil,
        rating: Double? = nil,
        tagsData: Data? = nil,
        isHidden: Bool = false,
        project: TierCreatorProject? = nil,
        item: TierCreatorItem? = nil,
        media: [TierCreatorMedia] = []
    ) {
        self.displayTitle = displayTitle
        self.notes = notes
        self.rating = rating
        self.tagsData = tagsData
        self.isHidden = isHidden
        self.project = project
        self.item = item
        self.media = media
    }
}

// MARK: - Codable Convenience

extension TierCreatorProject {
    @MainActor
    var settingsPayload: [String: AnyCodable] {
        get { decode(settingsData) ?? [:] }
        set { settingsData = encode(newValue) }
    }

    @MainActor
    var linksPayload: [String: AnyCodable] {
        get { decode(linksData) ?? [:] }
        set { linksData = encode(newValue) }
    }

    @MainActor
    var storagePayload: [String: AnyCodable] {
        get { decode(storageData) ?? [:] }
        set { storageData = encode(newValue) }
    }

    @MainActor
    var collabPayload: [String: AnyCodable] {
        get { decode(collabData) ?? [:] }
        set { collabData = encode(newValue) }
    }
}

extension TierCreatorItem {
    @MainActor
    var tags: [String] {
        get { decode(tagsData) ?? [] }
        set { tagsData = encode(newValue) }
    }

    @MainActor
    var attributes: TierCreatorAttributes {
        get { decode(attributesData) ?? [:] }
        set { attributesData = encode(newValue) }
    }

    @MainActor
    var locales: [String: [String: String]] {
        get { decode(localeData) ?? [:] }
        set { localeData = encode(newValue) }
    }

    @MainActor
    var sources: [TierCreatorSource] {
        get { decode(sourcesData) ?? [] }
        set { sourcesData = encode(newValue) }
    }
}

extension TierCreatorItemOverride {
    @MainActor
    var tags: [String] {
        get { decode(tagsData) ?? [] }
        set { tagsData = encode(newValue) }
    }
}

extension TierCreatorMedia {
    @MainActor
    var attribution: TierCreatorAttribution? {
        get { decode(attributionData) }
        set { attributionData = encode(newValue) }
    }
}

// MARK: - Codable DTOs

struct TierCreatorSource: Codable, Sendable {
    var rel: String?
    var href: String
    var title: String?
}

struct TierCreatorAttribution: Codable, Sendable {
    var creator: String?
    var license: String?
    var source: String?
}

// MARK: - Generic Encoding Helpers

private func encode<T: Encodable>(_ value: T?) -> Data? {
    guard let value else { return nil }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try? encoder.encode(value)
}

private func decode<T: Decodable>(_ data: Data?) -> T? {
    guard let data else { return nil }
    let decoder = JSONDecoder()
    return try? decoder.decode(T.self, from: data)
}

// Type erased helper to support simple dictionary payloads
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode([String].self) {
            self.value = value
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self.value = value
        } else {
            self.value = try container.decode(String.self)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let number as Double:
            try container.encode(number)
        case let int as Int:
            try container.encode(Double(int))
        case let bool as Bool:
            try container.encode(bool)
        case let array as [String]:
            try container.encode(array)
        case let dict as [String: AnyCodable]:
            try container.encode(dict)
        default:
            try container.encodeNil()
        }
    }
}
