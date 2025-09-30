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
    // Load JSON file from URL into a Dictionary representation
    public static func loadProject(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any] else {
            throw NSError(
                domain: "ModelResolver",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid project JSON"]
            )
        }
        return dict
    }

    // Resolve items map + overrides into ResolvedTiers using the project's tiers array
    public static func resolveTiers(from project: [String: Any]) -> [ResolvedTier] {
        guard let tiers = project["tiers"] as? [[String: Any]] else { return [] }
        let itemsMap = project["items"] as? [String: Any] ?? [:]
        let overrides = project["overrides"] as? [String: Any] ?? [:]

        let resolveItem = makeItemResolver(items: itemsMap, overrides: overrides)

        return tiers.map { tier -> ResolvedTier in
            let identifier = tierIdentifier(from: tier)
            let label = tierLabel(from: tier)
            let itemIds = tier["itemIds"] as? [String] ?? []
            let items = itemIds.compactMap(resolveItem)
            return ResolvedTier(id: identifier, label: label, items: items)
        }
    }
}

private extension ModelResolver {
    static func makeItemResolver(items: [String: Any], overrides: [String: Any]) -> (String) -> ResolvedItem? {
        { itemId in
            guard let item = items[itemId] as? [String: Any] else { return nil }
            let override = overrides[itemId] as? [String: Any]

            let title = resolveTitle(for: itemId, item: item, override: override)
            let subtitle = resolveSubtitle(item: item, override: override)
            let description = resolveDescription(item: item, override: override)
            let thumbUri = resolveThumbUri(item: item, override: override)
            let attributes = buildAttributes(item: item, override: override, thumbUri: thumbUri)

            return ResolvedItem(
                id: itemId,
                title: title,
                subtitle: subtitle,
                description: description,
                thumbUri: thumbUri,
                attributes: attributes
            )
        }
    }

    static func tierIdentifier(from tier: [String: Any]) -> String {
        tier["id"] as? String ?? UUID().uuidString
    }

    static func tierLabel(from tier: [String: Any]) -> String {
        tier["label"] as? String ?? ""
    }

    static func resolveTitle(for itemId: String, item: [String: Any], override: [String: Any]?) -> String {
        if let overrideTitle = override?["displayTitle"] as? String { return overrideTitle }
        if let title = item["title"] as? String { return title }
        return itemId
    }

    static func resolveSubtitle(item: [String: Any], override: [String: Any]?) -> String? {
        override?["subtitle"] as? String ?? item["subtitle"] as? String
    }

    static func resolveDescription(item: [String: Any], override: [String: Any]?) -> String? {
        override?["description"] as? String
            ?? item["description"] as? String
            ?? item["summary"] as? String
    }

    static func resolveThumbUri(item: [String: Any], override: [String: Any]?) -> String? {
        mediaThumb(in: override)
            ?? mediaThumb(in: item)
            ?? item["posterUri"] as? String
    }

    static func mediaThumb(in source: [String: Any]?) -> String? {
        guard
            let media = source?["media"] as? [[String: Any]],
            let first = media.first
        else { return nil }

        return (first["thumbUri"] as? String) ?? (first["posterUri"] as? String)
    }

    static func buildAttributes(item: [String: Any], override: [String: Any]?, thumbUri: String?) -> [String: String]? {
        var attributes: [String: String] = [:]

        if let overrideName = override?["displayTitle"] as? String {
            attributes["name"] = overrideName
        } else if let itemName = item["title"] as? String {
            attributes["name"] = itemName
        }

        if let overrideSeason = override?["season"] as? String {
            attributes["season"] = overrideSeason
        } else if let itemSeason = seasonString(from: item["season"]) {
            attributes["season"] = itemSeason
        }

        if let thumbUri = thumbUri {
            attributes["thumbUri"] = thumbUri
        }

        return attributes.isEmpty ? nil : attributes
    }

    static func seasonString(from value: Any?) -> String? {
        if let string = value as? String { return string }
        if let number = value as? Int { return String(number) }
        return nil
    }
}
