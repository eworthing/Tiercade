import Foundation
import Foundation
import SwiftUI

// Minimal resolver utilities to load a tierlist project JSON (matching referencedocs schema)
// and produce resolved tiers for the UI (apply overrides to items).

public struct ResolvedItem: Identifiable {
    public let id: String
    public var title: String
    public var subtitle: String?
    public var description: String?
    public var thumbUri: String?
    // Generic attributes bag for consumers that expect attributes-style items
    public var attributes: [String: String]?
}

public struct ResolvedTier {
    public let id: String
    public let label: String
    public var items: [ResolvedItem]
}

public enum ModelResolver {
    // Load JSON file from URL into a Dictionary representation
    public static func loadProject(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any] else { throw NSError(domain: "ModelResolver", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid project JSON"]) }
        return dict
    }

    // Resolve items map + overrides into ResolvedTiers using the project's tiers array
    public static func resolveTiers(from project: [String: Any]) -> [ResolvedTier] {
        guard let tiers = project["tiers"] as? [[String: Any]] else { return [] }
        let itemsMap = project["items"] as? [String: Any] ?? [:]
        let overrides = project["overrides"] as? [String: Any] ?? [:]

        func buildResolvedItem(_ itemId: String) -> ResolvedItem? {
            guard let item = itemsMap[itemId] as? [String: Any] else { return nil }
            let override = overrides[itemId] as? [String: Any]

            let title = (override?["displayTitle"] as? String) ?? (item["title"] as? String) ?? itemId
            let subtitle = (override?["subtitle"] as? String) ?? (item["subtitle"] as? String)
            let description = (override?["description"] as? String) ?? (item["description"] as? String) ?? (item["summary"] as? String)

            // pick thumbUri from override.media[0].thumbUri or item.media[0].thumbUri or posterUri
            var thumb: String? = nil
            if let o = override, let oMedia = o["media"] as? [[String: Any]], let first = oMedia.first {
                thumb = (first["thumbUri"] as? String) ?? (first["posterUri"] as? String)
            }
            if thumb == nil, let itemMedia = item["media"] as? [[String: Any]], let first = itemMedia.first {
                thumb = (first["thumbUri"] as? String) ?? (first["posterUri"] as? String)
            }

            // Build attributes bag mapping common fields into the generic schema
            var attrs: [String: String] = [:]
            // Prefer override values when present
            if let o = override {
                if let dt = o["displayTitle"] as? String { attrs["name"] = dt }
                if let s = o["season"] as? String { attrs["season"] = s }
                if let media = o["media"] as? [[String: Any]], let first = media.first {
                    if let t = (first["thumbUri"] as? String) ?? (first["posterUri"] as? String) { attrs["thumbUri"] = t }
                }
            }
            // Fallback to item fields
            if attrs["name"] == nil, let it = item["title"] as? String { attrs["name"] = it }
            if attrs["season"] == nil {
                if let s = item["season"] as? String { attrs["season"] = s }
                else if let n = item["season"] as? Int { attrs["season"] = String(n) }
            }
            if attrs["thumbUri"] == nil {
                if let media = item["media"] as? [[String: Any]], let first = media.first {
                    if let t = (first["thumbUri"] as? String) ?? (first["posterUri"] as? String) { attrs["thumbUri"] = t }
                }
                if attrs["thumbUri"] == nil, let poster = item["posterUri"] as? String { attrs["thumbUri"] = poster }
            }

            let attributes = attrs.isEmpty ? nil : attrs

            return ResolvedItem(id: itemId, title: title, subtitle: subtitle, description: description, thumbUri: thumb, attributes: attributes)
        }

        var resolved: [ResolvedTier] = []
        for t in tiers {
            let id = t["id"] as? String ?? UUID().uuidString
            let label = t["label"] as? String ?? ""
            let itemIds = t["itemIds"] as? [String] ?? []
            var items: [ResolvedItem] = []
            for iid in itemIds {
                if let ri = buildResolvedItem(iid) { items.append(ri) }
            }
            resolved.append(ResolvedTier(id: id, label: label, items: items))
        }
        return resolved
    }
}