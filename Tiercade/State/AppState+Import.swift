import Foundation
import SwiftUI
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Import System (JSON/CSV)

    func importFromJSON(_ jsonString: String) async -> Bool {
        await withLoadingIndicator(message: "Importing JSON data...") {
            updateProgress(0.2)

            do {
                guard let jsonData = jsonString.data(using: .utf8) else {
                    showErrorToast("Import Failed", message: "Invalid JSON format")
                    return false
                }
                updateProgress(0.4)

                let importData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                guard let tierData = importData?["tiers"] as? [String: [[String: String]]] else {
                    showErrorToast("Import Failed", message: "Invalid tier data format")
                    return false
                }
                updateProgress(0.6)

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
                updateProgress(0.8)

                await MainActor.run {
                    tiers = newTiers
                    history = HistoryLogic.initHistory(tiers, limit: history.limit)
                    markAsChanged()
                }
                updateProgress(1.0)

                showSuccessToast("Import Complete", message: "Successfully imported tier list")
                return true
            } catch {
                showErrorToast("Import Failed", message: "Could not parse JSON data")
                return false
            }
        }
    }

    func importFromCSV(_ csvString: String) async -> Bool {
        await withLoadingIndicator(message: "Importing CSV data...") {
            updateProgress(0.2)

            let lines = csvString.components(separatedBy: .newlines)
            guard lines.count > 1 else {
                showErrorToast("Import Failed", message: "CSV file appears to be empty")
                return false
            }
            updateProgress(0.4)

            var newTiers: Items = [
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

                let components = parseCSVLine(line)
                guard components.count >= 3 else { continue }

                let name = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let season = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let tier = components[2].trimmingCharacters(in: .whitespacesAndNewlines)

                guard !name.isEmpty else { continue }

                let id = name.lowercased().replacingOccurrences(of: " ", with: "_")
                var attributes: [String: String] = ["name": name]
                if !season.isEmpty { attributes["season"] = season }
                let item = Item(id: id, attributes: attributes.isEmpty ? nil : attributes)

                let tierKey = tier.lowercased() == "unranked" ? "unranked" : tier.uppercased()
                if newTiers[tierKey] != nil {
                    newTiers[tierKey]?.append(item)
                } else {
                    newTiers["unranked"]?.append(item)
                }
            }
            updateProgress(0.8)

            await MainActor.run {
                tiers = newTiers
                history = HistoryLogic.initHistory(tiers, limit: history.limit)
                markAsChanged()
            }
            updateProgress(1.0)

            showSuccessToast("Import Complete", message: "Successfully imported CSV data")
            return true
        }
    }

    func importFromJSON(url: URL) async -> Bool {
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
            return true
        } catch {
            do {
                let data = try Data(contentsOf: url)
                let content = String(data: data, encoding: .utf8) ?? ""
                return await importFromJSON(content)
            } catch {
                showErrorToast(
                    "Import Failed",
                    message: "Could not read JSON file: \(error.localizedDescription)"
                )
                return false
            }
        }
    }

    func importFromCSV(url: URL) async -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let content = String(data: data, encoding: .utf8) ?? ""
            return await importFromCSV(content)
        } catch {
            showErrorToast(
                "Import Failed",
                message: "Could not read CSV file: \(error.localizedDescription)"
            )
            return false
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
