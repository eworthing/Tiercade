import Foundation

public enum CSVImportRowBuilder {
    /// Builds a TiercadeCore `Item` from a CSV row.
    /// - Parameters:
    ///   - components: The parsed CSV row components. Expected order: name, season, tier, identifier (optional).
    ///   - usedIdentifiers: A running set of identifiers that have already been emitted during this import session.
    /// - Returns: A configured `Item` or `nil` when the row is missing a usable name.
    public static func makeItem(
        from components: [String],
        usedIdentifiers: inout Set<String>
    ) -> Item? {
        guard let rawName = components.first else { return nil }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let season = components.indices.contains(1)
            ? components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        let identifierColumn = components.indices.contains(3)
            ? components[3].trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        let baseIdentifier: String
        if !identifierColumn.isEmpty {
            baseIdentifier = identifierColumn
        } else {
            baseIdentifier = UUID().uuidString
        }

        let identifier = nextUniqueIdentifier(from: baseIdentifier, usedIdentifiers: &usedIdentifiers)

        var attributes: [String: String] = ["name": name]
        if !season.isEmpty {
            attributes["season"] = season
        }

        return Item(id: identifier, attributes: attributes.isEmpty ? nil : attributes)
    }
}

private extension CSVImportRowBuilder {
    static func nextUniqueIdentifier(from base: String, usedIdentifiers: inout Set<String>) -> String {
        var candidate = base
        var suffix = 1
        while usedIdentifiers.contains(candidate) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }
        usedIdentifiers.insert(candidate)
        return candidate
    }
}
