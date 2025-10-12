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

                // Heavy JSON parsing and conversion on background thread pool
                let importResult = try await parseAndConvertJSON(jsonString)
                updateProgress(0.8)

                // State updates on MainActor
                let snapshot = captureTierSnapshot()
                tiers = importResult.tiers
                tierOrder = importResult.tierOrder
                finalizeChange(action: "Import JSON", undoSnapshot: snapshot)
                updateProgress(1.0)

                showSuccessToast("Import Complete", message: "Successfully imported tier list {import}")
            }
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.parsingFailed("Unexpected error: \(error.localizedDescription)")
        }
    }

    // Swift 6.2 pattern: heavy JSON work runs on background thread pool via Task.detached
    nonisolated
    private struct JSONImportResult: Sendable {
        var tiers: Items
        var tierOrder: [String]
    }

    private func parseAndConvertJSON(_ jsonString: String) async throws(ImportError) -> JSONImportResult {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ImportError.invalidFormat("String is not valid UTF-8")
        }

        let importData: [String: Any]
        do {
            guard let data = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                throw ImportError.parsingFailed("Invalid JSON structure")
            }
            importData = data
        } catch {
            throw ImportError.parsingFailed("JSON parsing failed: \(error.localizedDescription)")
        }

        guard let tierData = importData["tiers"] as? [String: Any] else {
            throw ImportError.missingRequiredField("tiers")
        }

        // Convert tier data (pure transformation)
        var newTiers: Items = [:]
        for (tierName, rawItems) in tierData {
            guard let itemArray = rawItems as? [[String: Any]] else { continue }
            newTiers[tierName] = itemArray.compactMap { data in
                guard let id = data["id"] as? String, id.isEmpty == false else { return nil }

                var attributes: [String: Any] = data["attributes"] as? [String: Any] ?? [:]
                for (key, value) in data where key != "id" && key != "attributes" {
                    attributes[key] = value
                }

                let stringAttributes = attributes.compactMapValues { value -> String? in
                    if let string = value as? String { return string }
                    if let number = value as? NSNumber { return number.stringValue }
                    return nil
                }

                return Item(id: id, attributes: stringAttributes.isEmpty ? nil : stringAttributes)
            }
        }

        let importedOrder = importData["tierOrder"] as? [String]
        let sanitizedOrder = sanitizeTierOrder(importedOrder, tiers: newTiers)

        return JSONImportResult(tiers: normalizeLoadedTiers(newTiers, order: sanitizedOrder), tierOrder: sanitizedOrder)
    }

    func importFromCSV(_ csvString: String) async throws(ImportError) {
        do {
            try await withLoadingIndicator(message: "Importing CSV data...") {
                updateProgress(0.2)

                // Heavy CSV parsing on background thread pool
                let newTiers = try await parseCSVInBackground(csvString)
                updateProgress(0.8)

                // State updates on MainActor
                let snapshot = captureTierSnapshot()
                tiers = newTiers
                finalizeChange(action: "Import CSV", undoSnapshot: snapshot)
                updateProgress(1.0)

                showSuccessToast("Import Complete", message: "Successfully imported CSV data {import}")
            }
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.parsingFailed("Unexpected error: \(error.localizedDescription)")
        }
    }

    // Swift 6.2 pattern: heavy CSV parsing runs on background thread pool via Task.detached
    nonisolated
    private func parseCSVInBackground(_ csvString: String) async throws(ImportError) -> Items {
        let lines = csvString.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            throw ImportError.invalidData("CSV file appears to be empty")
        }

        var newTiers: Items = [
            "S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []
        ]

        for line in lines.dropFirst() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            let components = Self.parseCSVLine(line)
            guard components.count >= 3 else { continue }

            if let item = Self.createItemFromCSVComponents(components) {
                Self.addItemToTier(item, tier: components[2], in: &newTiers)
            }
        }

        return newTiers
    }

    nonisolated private static func createItemFromCSVComponents(_ components: [String]) -> Item? {
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

    nonisolated private static func addItemToTier(_ item: Item, tier: String, in tiers: inout Items) {
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
            // File I/O and parsing on background thread pool
            let state = try await loadProjectFromFile(url)

            // State updates on MainActor
            let snapshot = captureTierSnapshot()
            tierOrder = state.tierOrder
            tiers = state.tiers
            tierLabels = state.tierLabels
            tierColors = state.tierColors
            lockedTiers = state.lockedTiers
            finalizeChange(action: "Import Project", undoSnapshot: snapshot)

            showSuccessToast("Import Complete", message: "Project loaded successfully {import}")
        } catch let error as NSError where error.domain == "Tiercade" {
            throw ImportError.invalidData(error.localizedDescription)
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.invalidData("Could not read JSON file: \(error.localizedDescription)")
        }
    }

    // Swift 6.2 pattern: file I/O and ModelResolver on background via Task.detached
    nonisolated
    private func loadProjectFromFile(_ url: URL) async throws(ImportError) -> TierStateSnapshot {
        do {
            let project = try await ModelResolver.loadProjectAsync(from: url)
            return buildTierState(from: project)
        } catch {
            // Fallback: try loading as plain JSON
            do {
                let data = try Data(contentsOf: url)
                let content = String(data: data, encoding: .utf8) ?? ""
                let result = try await parseAndConvertJSON(content)
                return TierStateSnapshot(
                    tiers: result.tiers,
                    tierOrder: result.tierOrder,
                    tierLabels: [:],
                    tierColors: [:],
                    lockedTiers: []
                )
            } catch {
                throw ImportError.invalidData("Could not load project or JSON: \(error.localizedDescription)")
            }
        }
    }

    nonisolated private func buildTierState(from project: Project) -> TierStateSnapshot {
        let metadata = Dictionary(uniqueKeysWithValues: project.tiers.map { ($0.id, $0) })
        let resolvedTiers = ModelResolver.resolveTiers(from: project)

        var items: Items = [:]
        var order: [String] = []
        var labels: [String: String] = [:]
        var colors: [String: String] = [:]
        var locked: Set<String> = []

        func normalize(_ name: String) -> String {
            name.lowercased() == "unranked" ? "unranked" : name
        }

        func appendIfNeeded(_ tierId: String) {
            guard tierId != "unranked" else { return }
            if !order.contains(tierId) { order.append(tierId) }
        }

        for resolved in resolvedTiers {
            let normalizedLabel = normalize(resolved.label)
            appendIfNeeded(normalizedLabel)
            if let tier = metadata[resolved.id] {
                labels[normalizedLabel] = tier.label
                if let color = tier.color, !color.isEmpty { colors[normalizedLabel] = color }
                if tier.locked == true { locked.insert(normalizedLabel) }
            } else {
                labels[normalizedLabel] = resolved.label
            }

            items[normalizedLabel] = resolved.items.map(convertResolvedItem)
        }

        for tier in project.tiers {
            let normalizedLabel = normalize(tier.label)
            appendIfNeeded(normalizedLabel)
            if labels[normalizedLabel] == nil { labels[normalizedLabel] = tier.label }
            if colors[normalizedLabel] == nil, let color = tier.color, !color.isEmpty {
                colors[normalizedLabel] = color
            }
            if tier.locked == true { locked.insert(normalizedLabel) }
            if items[normalizedLabel] == nil { items[normalizedLabel] = [] }
        }

        if items["unranked"] == nil {
            items["unranked"] = []
        }

        return TierStateSnapshot(
            tiers: items,
            tierOrder: order,
            tierLabels: labels,
            tierColors: colors,
            lockedTiers: locked
        )
    }

    nonisolated private func convertResolvedItem(_ resolved: ResolvedItem) -> Item {
        var item = Item(id: resolved.id, attributes: resolved.attributes)

        if item.name?.isEmpty != false {
            item.name = resolved.title
        }

        if item.description?.isEmpty != false {
            item.description = resolved.description
        }

        if item.imageUrl?.isEmpty != false {
            item.imageUrl = resolved.thumbUri
        }

        return item
    }

    func importFromCSV(url: URL) async throws(ImportError) {
        // File I/O on background thread pool
        let content = try await loadCSVFromFile(url)

        // Reuse existing CSV import logic
        try await importFromCSV(content)
    }

    // Swift 6.2 pattern: file I/O on background via Task.detached
    nonisolated
    private func loadCSVFromFile(_ url: URL) async throws(ImportError) -> String {
        do {
            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw ImportError.invalidFormat("CSV file is not valid UTF-8")
            }
            return content
        } catch {
            throw ImportError.invalidData("Could not read CSV file: \(error.localizedDescription)")
        }
    }

    nonisolated private static func parseCSVLine(_ line: String) -> [String] {
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
