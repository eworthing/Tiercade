import Foundation

// Minimal resolver utilities to load a tierlist project JSON (matching referencedocs schema)
// and produce resolved tiers for consumers (apply overrides to items).

public struct ResolvedItem: Identifiable {
    public let id: String
    public var title: String
    public var subtitle: String?
    public var description: String?
    public var thumbUri: String?
    // Generic attributes bag for consumers that expect attributes-style items
    public var attributes: [String: String]?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        description: String? = nil,
        thumbUri: String? = nil,
        attributes: [String: String]? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.thumbUri = thumbUri
        self.attributes = attributes
    }
}

public struct ResolvedTier {
    public let id: String
    public let label: String
    public var items: [ResolvedItem]

    public init(id: String, label: String, items: [ResolvedItem]) {
        self.id = id
        self.label = label
        self.items = items
    }
}

public enum ModelResolver {
    // Synchronous API (maintained for compatibility)
    public static func loadProject(from url: URL) throws -> Project {
        let data = try Data(contentsOf: url)
        return try decodeProject(from: data)
    }

    public static func decodeProject(from data: Data) throws -> Project {
        let decoder = jsonDecoder()
        let project = try decoder.decode(Project.self, from: data)
        try ProjectValidation.validateOfflineV1(project)
        return project
    }

    // Swift 6 (Swift 6.2 toolchain) @concurrent pattern: async API for background file I/O and decoding
    @concurrent
    public static func loadProjectAsync(from url: URL) async throws -> Project {
        let data = try Data(contentsOf: url)
        return try await decodeProjectAsync(from: data)
    }

    @concurrent
    public static func decodeProjectAsync(from data: Data) async throws -> Project {
        let decoder = jsonDecoder()
        let project = try decoder.decode(Project.self, from: data)
        try ProjectValidation.validateOfflineV1(project)
        return project
    }

    public static func resolveTiers(from project: Project) -> [ResolvedTier] {
        let overrides = project.overrides ?? [:]

        return project.tiers.map { tier in
            let items = tier.itemIds.compactMap { itemId -> ResolvedItem? in
                guard let item = project.items[itemId] else { return nil }
                let override = overrides[itemId]
                return makeResolvedItem(id: itemId, item: item, override: override)
            }
            return ResolvedTier(id: tier.id, label: tier.label, items: items)
        }
    }
}

private extension ModelResolver {
    static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func makeResolvedItem(id: String, item: Project.Item, override: Project.ItemOverride?) -> ResolvedItem {
        let title = resolvedTitle(id: id, item: item, override: override)
        let subtitle = item.subtitle
        let description = resolvedDescription(item: item, override: override)
        let thumbUri = resolvedThumbUri(item: item, override: override)
        let attributes = buildAttributes(item: item, override: override, thumbUri: thumbUri)

        return ResolvedItem(
            id: id,
            title: title,
            subtitle: subtitle,
            description: description,
            thumbUri: thumbUri,
            attributes: attributes
        )
    }

    static func resolvedTitle(id: String, item: Project.Item, override: Project.ItemOverride?) -> String {
        if let overrideTitle = override?.displayTitle, !overrideTitle.isEmpty {
            return overrideTitle
        }
        if !item.title.isEmpty {
            return item.title
        }
        return id
    }

    static func resolvedDescription(item: Project.Item, override: Project.ItemOverride?) -> String? {
        if let notes = override?.notes, !notes.isEmpty {
            return notes
        }
        if let summary = item.summary, !summary.isEmpty {
            return summary
        }
        return nil
    }

    static func resolvedThumbUri(item: Project.Item, override: Project.ItemOverride?) -> String? {
        if let thumb = mediaPrimaryThumbnail(from: override?.media) {
            return thumb
        }
        if let thumb = mediaPrimaryThumbnail(from: item.media) {
            return thumb
        }
        return nil
    }

    static func mediaPrimaryThumbnail(from media: [Project.Media]?) -> String? {
        guard let media, let first = media.first else { return nil }
        if let thumb = first.thumbUri, !thumb.isEmpty {
            return thumb
        }
        if let poster = first.posterUri, !poster.isEmpty {
            return poster
        }
        return nil
    }

    static func buildAttributes(
        item: Project.Item,
        override: Project.ItemOverride?,
        thumbUri: String?
    ) -> [String: String]? {
        var attributes: [String: String] = [:]

        if let overrideTitle = override?.displayTitle, !overrideTitle.isEmpty {
            attributes["name"] = overrideTitle
        } else if !item.title.isEmpty {
            attributes["name"] = item.title
        }

        if let season = override?.additional?["season"]?.stringValue ?? item.attributes?["season"]?.stringValue {
            attributes["season"] = season
        }

        if let thumbUri {
            attributes["thumbUri"] = thumbUri
        }

        if let rating = override?.rating ?? item.rating {
            attributes["rating"] = String(rating)
        }

        return attributes.isEmpty ? nil : attributes
    }
}

private extension JSONValue {
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let number):
            if floor(number) == number {
                return String(Int(number))
            }
            return String(number)
        case .bool(let bool):
            return String(bool)
        case .array, .object, .null:
            return nil
        }
    }
}
