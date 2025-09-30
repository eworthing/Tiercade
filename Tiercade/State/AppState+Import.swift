import Foundation
import SwiftUI
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Import System (JSON/CSV)

    func importFromJSON(_ jsonString: String) async throws(ImportError) {
        do {
            try await withLoadingIndicator(message: "Importing JSON data...") {
                updateProgress(0.2)

                let importData = try parseJSONData(jsonString)
                updateProgress(0.4)

                guard let tierData = importData["tiers"] as? [String: [[String: String]]] else {
                    throw ImportError.missingRequiredField("tiers")
                }
                updateProgress(0.6)

                let newTiers = convertTierData(tierData)
                updateProgress(0.8)

                await MainActor.run {
                    tiers = newTiers
                    history = HistoryLogic.initHistory(tiers, limit: history.limit)
                    markAsChanged()
                }
                updateProgress(1.0)

                showSuccessToast("Import Complete", message: "Successfully imported tier list")
            }
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.parsingFailed("Unexpected error: \(error.localizedDescription)")
        }
    }

    private func parseJSONData(_ jsonString: String) throws(ImportError) -> [String: Any] {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ImportError.invalidFormat("String is not valid UTF-8")
        }

        do {
            guard let data = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                throw ImportError.parsingFailed("Invalid JSON structure")
            }
            return data
        } catch {
            throw ImportError.parsingFailed("JSON parsing failed: \(error.localizedDescription)")
        }
    }

    private func convertTierData(_ tierData: [String: [[String: String]]]) -> Items {
        var newTiers: Items = [:]

        for (tierName, itemData) in tierData {
            newTiers[tierName] = itemData.compactMap { data in
                guard let id = data["id"], !id.isEmpty else { return nil }
                var attributes: [String: String] = [:]
                for (key, value) in data where key != "id" {
                    attributes[key] = value
                }
                return Item(id: id, attributes: attributes.isEmpty ? nil : attributes)
            }
        }

        return newTiers
    }

    func importFromCSV(_ csvString: String) async throws(ImportError) {
        do {
            try await withLoadingIndicator(message: "Importing CSV data...") {
                updateProgress(0.2)

                let lines = csvString.components(separatedBy: .newlines)
                guard lines.count > 1 else {
                    throw ImportError.invalidData("CSV file appears to be empty")
                }
                updateProgress(0.4)

                let newTiers = parseCSVLines(lines)
                updateProgress(0.8)

                await MainActor.run {
                    tiers = newTiers
                    history = HistoryLogic.initHistory(tiers, limit: history.limit)
                    markAsChanged()
                }
                updateProgress(1.0)

                showSuccessToast("Import Complete", message: "Successfully imported CSV data")
            }
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.parsingFailed("Unexpected error: \(error.localizedDescription)")
        }
    }

    private func parseCSVLines(_ lines: [String]) -> Items {
        var newTiers: Items = [
            "S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []
        ]

        for line in lines.dropFirst() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            let components = parseCSVLine(line)
            guard components.count >= 3 else { continue }

            if let item = createItemFromCSVComponents(components) {
                addItemToTier(item, tier: components[2], in: &newTiers)
            }
        }

        return newTiers
    }

    private func createItemFromCSVComponents(_ components: [String]) -> Item? {
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

    private func addItemToTier(_ item: Item, tier: String, in tiers: inout Items) {
        let tierKey = tier.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKey = tierKey.lowercased() == "unranked" ? "unranked" : tierKey.uppercased()

        if tiers[normalizedKey] != nil {
            tiers[normalizedKey]?.append(item)
        } else {
            tiers["unranked"]?.append(item)
        }
    }

    func importFromJSON(url: URL) async throws(ImportError) {
        do {
            let project = try ModelResolver.loadProject(from: url)
            let resolvedTiers = ModelResolver.resolveTiers(from: project)
            var newTiers: Items = [:]
            var newOrder: [String] = []
            for resolved in resolvedTiers {
                newOrder.append(resolved.label)
                newTiers[resolved.label] = resolved.items.map { item in
                    Item(id: item.id, name: item.title, imageUrl: item.thumbUri)
                }
            }
            await MainActor.run {
                tierOrder = newOrder
                tiers = newTiers
                history = HistoryLogic.initHistory(tiers, limit: history.limit)
                markAsChanged()
            }
            showSuccessToast("Import Complete", message: "Project loaded successfully")
        } catch {
            do {
                let data = try Data(contentsOf: url)
                let content = String(data: data, encoding: .utf8) ?? ""
                try await importFromJSON(content)
            } catch {
                throw ImportError.invalidData("Could not read JSON file: \(error.localizedDescription)")
            }
        }
    }

    func importFromCSV(url: URL) async throws(ImportError) {
        do {
            let data = try Data(contentsOf: url)
            let content = String(data: data, encoding: .utf8) ?? ""
            try await importFromCSV(content)
        } catch {
            throw ImportError.invalidData("Could not read CSV file: \(error.localizedDescription)")
        }
    }

    private func parseCSVLine(_ line: String) -> [String] {
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
}
