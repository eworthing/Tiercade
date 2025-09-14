import Foundation

public struct Contestant: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public var name: String?
    public var seasonString: String?
    public var seasonNumber: Int?
    public var status: String?
    public var description: String?
    public var imageUrl: String?
    public var videoUrl: String?

    enum CodingKeys: String, CodingKey {
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
}

public typealias Tiers = [String: [Contestant]]
public typealias TierConfig = [String: TierConfigEntry]

public struct History<T: Sendable>: Sendable {
    public var stack: [T]
    public var index: Int
    public var limit: Int
    public init(stack: [T], index: Int, limit: Int) {
        self.stack = stack
        self.index = index
        self.limit = max(1, limit)
    }
}
