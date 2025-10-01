import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
            return
        }
        if let number = try? container.decode(Double.self) {
            self = .number(number)
            return
        }
        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }
        if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
            return
        }
        if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown JSON value")
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        case .bool(let bool):
            try container.encode(bool)
        case .array(let array):
            try container.encode(array)
        case .object(let object):
            try container.encode(object)
        case .null:
            try container.encodeNil()
        }
    }
}

public enum ProjectMediaKind: String, Codable, Sendable {
    case image
    case gif
    case video
    case audio
}

public struct Project: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var projectId: String
    public var title: String?
    public var description: String?
    public var tiers: [Tier]
    public var items: [String: Item]
    public var overrides: [String: ItemOverride]?
    public var links: Links?
    public var storage: Storage?
    public var settings: Settings?
    public var collab: Collaboration?
    public var audit: Audit
    public var additional: [String: JSONValue]?

    public init(
        schemaVersion: Int,
        projectId: String,
        title: String? = nil,
        description: String? = nil,
        tiers: [Tier],
        items: [String: Item],
        overrides: [String: ItemOverride]? = nil,
        links: Links? = nil,
        storage: Storage? = nil,
        settings: Settings? = nil,
        collab: Collaboration? = nil,
        audit: Audit,
        additional: [String: JSONValue]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.projectId = projectId
        self.title = title
        self.description = description
        self.tiers = tiers
        self.items = items
        self.overrides = overrides
        self.links = links
        self.storage = storage
        self.settings = settings
        self.collab = collab
        self.audit = audit
        self.additional = additional
    }
}

public extension Project {
    struct Audit: Codable, Equatable, Sendable {
        public var createdAt: Date
        public var updatedAt: Date
        public var createdBy: String?
        public var updatedBy: String?

        public init(createdAt: Date, updatedAt: Date, createdBy: String? = nil, updatedBy: String? = nil) {
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.createdBy = createdBy
            self.updatedBy = updatedBy
        }
    }

    struct Media: Codable, Equatable, Identifiable, Sendable {
        public var id: String
        public var kind: ProjectMediaKind
        public var uri: String
        public var mime: String
        public var w: Double?
        public var h: Double?
        public var durationMs: Double?
        public var posterUri: String?
        public var thumbUri: String?
        public var alt: String?
        public var attribution: [String: String]?
        public var additional: [String: JSONValue]?

        public init(
            id: String,
            kind: ProjectMediaKind,
            uri: String,
            mime: String,
            w: Double? = nil,
            h: Double? = nil,
            durationMs: Double? = nil,
            posterUri: String? = nil,
            thumbUri: String? = nil,
            alt: String? = nil,
            attribution: [String: String]? = nil,
            additional: [String: JSONValue]? = nil
        ) {
            self.id = id
            self.kind = kind
            self.uri = uri
            self.mime = mime
            self.w = w
            self.h = h
            self.durationMs = durationMs
            self.posterUri = posterUri
            self.thumbUri = thumbUri
            self.alt = alt
            self.attribution = attribution
            self.additional = additional
        }
    }

    struct Item: Codable, Equatable, Identifiable, Sendable {
        public var id: String
        public var title: String
        public var subtitle: String?
        public var summary: String?
        public var slug: String?
        public var media: [Media]?
        public var attributes: [String: JSONValue]?
        public var tags: [String]?
        public var rating: Double?
        public var sources: [[String: String]]?
        public var locale: [String: [String: String]]?
        public var meta: Audit?
        public var additional: [String: JSONValue]?

        public init(
            id: String,
            title: String,
            subtitle: String? = nil,
            summary: String? = nil,
            slug: String? = nil,
            media: [Media]? = nil,
            attributes: [String: JSONValue]? = nil,
            tags: [String]? = nil,
            rating: Double? = nil,
            sources: [[String: String]]? = nil,
            locale: [String: [String: String]]? = nil,
            meta: Audit? = nil,
            additional: [String: JSONValue]? = nil
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.summary = summary
            self.slug = slug
            self.media = media
            self.attributes = attributes
            self.tags = tags
            self.rating = rating
            self.sources = sources
            self.locale = locale
            self.meta = meta
            self.additional = additional
        }
    }

    struct ItemOverride: Codable, Equatable, Sendable {
        public var displayTitle: String?
        public var notes: String?
        public var tags: [String]?
        public var rating: Double?
        public var media: [Media]?
        public var hidden: Bool?
        public var additional: [String: JSONValue]?

        public init(
            displayTitle: String? = nil,
            notes: String? = nil,
            tags: [String]? = nil,
            rating: Double? = nil,
            media: [Media]? = nil,
            hidden: Bool? = nil,
            additional: [String: JSONValue]? = nil
        ) {
            self.displayTitle = displayTitle
            self.notes = notes
            self.tags = tags
            self.rating = rating
            self.media = media
            self.hidden = hidden
            self.additional = additional
        }
    }

    struct Tier: Codable, Equatable, Identifiable, Sendable {
        public var id: String
        public var label: String
        public var color: String?
        public var order: Int
        public var locked: Bool?
        public var collapsed: Bool?
        public var rules: [String: JSONValue]?
        public var itemIds: [String]
        public var additional: [String: JSONValue]?

        public init(
            id: String,
            label: String,
            color: String? = nil,
            order: Int,
            locked: Bool? = nil,
            collapsed: Bool? = nil,
            rules: [String: JSONValue]? = nil,
            itemIds: [String],
            additional: [String: JSONValue]? = nil
        ) {
            self.id = id
            self.label = label
            self.color = color
            self.order = order
            self.locked = locked
            self.collapsed = collapsed
            self.rules = rules
            self.itemIds = itemIds
            self.additional = additional
        }
    }

    struct Links: Codable, Equatable, Sendable {
        public var visibility: String?
        public var shareUrl: String?
        public var embedHtml: String?
        public var stateUrl: String?
        public var additional: [String: JSONValue]?

        public init(
            visibility: String? = nil,
            shareUrl: String? = nil,
            embedHtml: String? = nil,
            stateUrl: String? = nil,
            additional: [String: JSONValue]? = nil
        ) {
            self.visibility = visibility
            self.shareUrl = shareUrl
            self.embedHtml = embedHtml
            self.stateUrl = stateUrl
            self.additional = additional
        }
    }

    struct Storage: Codable, Equatable, Sendable {
        public var mode: String?
        public var remote: [String: JSONValue]?
        public var additional: [String: JSONValue]?

        public init(mode: String? = nil, remote: [String: JSONValue]? = nil, additional: [String: JSONValue]? = nil) {
            self.mode = mode
            self.remote = remote
            self.additional = additional
        }
    }

    struct Settings: Codable, Equatable, Sendable {
        public var theme: String?
        public var tierSortOrder: String?
        public var gridSnap: Bool?
        public var showUnranked: Bool?
        public var accessibility: [String: Bool]?
        public var additional: [String: JSONValue]?

        public init(
            theme: String? = nil,
            tierSortOrder: String? = nil,
            gridSnap: Bool? = nil,
            showUnranked: Bool? = nil,
            accessibility: [String: Bool]? = nil,
            additional: [String: JSONValue]? = nil
        ) {
            self.theme = theme
            self.tierSortOrder = tierSortOrder
            self.gridSnap = gridSnap
            self.showUnranked = showUnranked
            self.accessibility = accessibility
            self.additional = additional
        }
    }

    struct Member: Codable, Equatable, Sendable {
        public var userId: String
        public var role: String
        public var additional: [String: JSONValue]?

        public init(userId: String, role: String, additional: [String: JSONValue]? = nil) {
            self.userId = userId
            self.role = role
            self.additional = additional
        }
    }

    struct Collaboration: Codable, Equatable, Sendable {
        public var members: [Member]?
        public var additional: [String: JSONValue]?

        public init(members: [Member]? = nil, additional: [String: JSONValue]? = nil) {
            self.members = members
            self.additional = additional
        }
    }
}

public enum ProjectValidation {
    public static func validateOfflineV1(_ project: Project) throws {
        if let mode = project.storage?.mode, mode.lowercased() != "local" {
            throw NSError(
                domain: "Tiercade",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "v1 is offline-only (storage.mode must be 'local' or omitted)."]
            )
        }

        for item in project.items.values {
            try validateMediaCollection(item.media, errorCode: 1002)
        }

        if let overrides = project.overrides {
            for override in overrides.values {
                try validateMediaCollection(override.media, errorCode: 1003)
            }
        }
    }

    private static func validateMediaCollection(_ media: [Project.Media]?, errorCode: Int) throws {
        guard let media else { return }
        for entry in media where !isFileURL(entry.uri) || !isFileURL(entry.thumbUri) || !isFileURL(entry.posterUri) {
            throw NSError(
                domain: "Tiercade",
                code: errorCode,
                userInfo: [NSLocalizedDescriptionKey: "Media URIs must be file:// in offline v1."]
            )
        }
    }

    private static func isFileURL(_ value: String?) -> Bool {
        guard let value else { return true }
        return value.lowercased().hasPrefix("file://")
    }
}
