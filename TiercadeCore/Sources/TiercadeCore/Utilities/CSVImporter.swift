import Foundation

public enum CSVImporter {
    public enum CSVImportError: Error, Equatable {
        case emptyFile
    }

    public static func parse(_ csvString: String) throws -> Items {
        let lines = csvString.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            throw CSVImportError.emptyFile
        }

        var tiers: Items = [
            "S": [],
            "A": [],
            "B": [],
            "C": [],
            "D": [],
            "F": [],
            "unranked": []
        ]

        for line in lines.dropFirst() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            let components = parseLine(line)
            guard components.count >= 3 else { continue }

            if let item = makeItem(from: components) {
                addItem(item, toTier: components[2], in: &tiers)
            }
        }

        return tiers
    }

    public static func parseInBackground(_ csvString: String) async throws -> Items {
        try await Task.detached(priority: .userInitiated) {
            try parse(csvString)
        }.value
    }

    static func parseLine(_ line: String) -> [String] {
        var components: [String] = []
        var currentComponent = ""
        var insideQuotes = false

        for character in line {
            if character == "\"" {
                insideQuotes.toggle()
            } else if character == "," && !insideQuotes {
                components.append(currentComponent)
                currentComponent = ""
            } else {
                currentComponent.append(character)
            }
        }
        components.append(currentComponent)

        return components.map { component in
            component
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
        }
    }

    static func makeItem(from components: [String]) -> Item? {
        let name = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let season = components[1].trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else { return nil }

        let id = name.lowercased().replacingOccurrences(of: " ", with: "_")
        var attributes: [String: String] = ["name": name]
        if !season.isEmpty {
            attributes["season"] = season
        }

        return Item(id: id, attributes: attributes.isEmpty ? nil : attributes)
    }

    static func addItem(_ item: Item, toTier tier: String, in tiers: inout Items) {
        let trimmedTier = tier.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKey = trimmedTier.lowercased() == "unranked" ? "unranked" : trimmedTier.uppercased()

        if tiers[normalizedKey] != nil {
            tiers[normalizedKey]?.append(item)
        } else {
            tiers["unranked"]?.append(item)
        }
    }
}
