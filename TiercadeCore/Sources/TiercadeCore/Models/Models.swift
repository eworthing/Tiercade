import Foundation

public struct Item: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public var name: String?
    public var seasonString: String?
    public var seasonNumber: Int?
    public var status: String?
    public var description: String?
    public var imageUrl: String?
    public var videoUrl: String?

    public enum CodingKeys: String, CodingKey {
        case id, name, season, status, description, imageUrl, videoUrl
    }

    public init(id: String,
                name: String? = nil,
                seasonString: String? = nil,
                seasonNumber: Int? = nil,
                status: String? = nil,
                description: String? = nil,
                imageUrl: String? = nil,
                videoUrl: String? = nil) {
        self.id = id
        self.name = name
        self.seasonString = seasonString
        self.seasonNumber = seasonNumber
        self.status = status
        self.description = description
        self.imageUrl = imageUrl
        self.videoUrl = videoUrl
    }

    /// Convenience initializer to build an Item from a generic attributes bag.
    /// Recognized keys: "name", "season", "seasonNumber", "imageUrl", "thumbUri", "status", "description", "videoUrl"
    public init(id: String, attributes: [String: String]?) {
        self.id = id
        guard let a = attributes else {
            self.name = nil
            self.seasonString = nil
            self.seasonNumber = nil
            self.status = nil
            self.description = nil
            self.imageUrl = nil
            self.videoUrl = nil
            return
        }
        self.name = a["name"]
        // season may be stored as string or number; prefer explicit seasonNumber key if present
        if let sn = a["seasonNumber"], let n = Int(sn) {
            self.seasonNumber = n
            self.seasonString = String(n)
        } else if let s = a["season"] {
            self.seasonString = s
            self.seasonNumber = Int(s)
        } else {
            self.seasonString = nil
            self.seasonNumber = nil
        }
        // image keys
        if let thumb = a["thumbUri"] ?? a["imageUrl"] {
            self.imageUrl = thumb
        } else {
            self.imageUrl = nil
        }
        self.status = a["status"]
        self.description = a["description"]
        self.videoUrl = a["videoUrl"]
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        videoUrl = try c.decodeIfPresent(String.self, forKey: .videoUrl)
        // season can be String or Number; decode leniently
        if let s = try? c.decode(String.self, forKey: .season) {
            seasonString = s
            seasonNumber = Int(s)
        } else if let n = try? c.decode(Int.self, forKey: .season) {
            seasonNumber = n
            seasonString = String(n)
        } else {
            seasonString = nil
            seasonNumber = nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try c.encodeIfPresent(videoUrl, forKey: .videoUrl)
        // Prefer writing number if available, else string
        if let n = seasonNumber {
            try c.encode(n, forKey: .season)
        } else if let s = seasonString {
            try c.encode(s, forKey: .season)
        }
    }
}

public struct TierConfigEntry: Codable, Sendable, Equatable {
    public var name: String
    public var colorHex: String?
    public var description: String?

    public init(name: String, colorHex: String? = nil, description: String? = nil) {
        self.name = name
        self.colorHex = colorHex
        self.description = description
    }
}

public typealias Items = [String: [Item]]
public typealias TierConfig = [String: TierConfigEntry]

// MARK: - Sorting

/// Defines the type of a sortable attribute discovered at runtime
public enum AttributeType: String, Codable, Sendable, Hashable {
    case string
    case number
    case bool
    case date
}

/// Global sort mode applied across all tiers
public enum GlobalSortMode: Codable, Sendable, Hashable, Equatable {
    case custom  // Manual user-defined order (array index)
    case alphabetical(ascending: Bool)
    case byAttribute(key: String, ascending: Bool, type: AttributeType)

    public var displayName: String {
        switch self {
        case .custom:
            return "Manual Order"
        case .alphabetical(let ascending):
            return ascending ? "A → Z" : "Z → A"
        case .byAttribute(let key, let ascending, _):
            let arrow = ascending ? "↑" : "↓"
            return "\(key.capitalized) \(arrow)"
        }
    }

    public var isCustom: Bool {
        if case .custom = self {
            return true
        }
        return false
    }
}
