import Foundation
import SwiftUI
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Export & Import System

    func exportToFormat(_ format: ExportFormat, group: String = "All", themeName: String = "Default") async -> (Data, String)? {
        return await withLoadingIndicator(message: "Exporting \(format.displayName)...") {
            updateProgress(0.2)
            
            let cfg: TierConfig = [
                "S": TierConfigEntry(name: "S", description: nil),
                "A": TierConfigEntry(name: "A", description: nil),
                "B": TierConfigEntry(name: "B", description: nil),
                "C": TierConfigEntry(name: "C", description: nil),
                "D": TierConfigEntry(name: "D", description: nil),
                "F": TierConfigEntry(name: "F", description: nil)
            ]
            updateProgress(0.4)
            
            let result: String
            let fileName: String
            switch format {
            case .text:
                result = ExportFormatter.generate(group: group, date: .now, themeName: themeName, tiers: tiers, tierConfig: cfg)
                fileName = "tier_list.txt"
            case .json:
                result = exportToJSON(group: group, themeName: themeName)
                fileName = "tier_list.json"
            case .markdown:
                result = exportToMarkdown(group: group, themeName: themeName, tierConfig: cfg)
                fileName = "tier_list.md"
            case .csv:
                result = exportToCSV(group: group, themeName: themeName)
                fileName = "tier_list.csv"
            }
            updateProgress(0.8)
            
            guard let data = result.data(using: .utf8) else {
                showErrorToast("Export Failed", message: "Could not convert content to data")
                return nil
            }
            
            updateProgress(1.0)
            showSuccessToast("Export Complete", message: "Exported as \(format.displayName)")
            return (data, fileName)
        }
    }

    private func exportToJSON(group: String, themeName: String) -> String {
        let exportData = [
            "metadata": [
                "group": group,
                "theme": themeName,
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "appVersion": "1.0"
            ],
            "tierOrder": tierOrder,
            "tiers": tiers.mapValues { items in
                items.map { i in
                    var dict: [String: Any] = ["id": i.id]
                    var attrs: [String: Any] = [:]
                    if let name = i.name { attrs["name"] = name }
                    if let season = i.seasonString { attrs["season"] = season }
                    if let img = i.imageUrl { attrs["thumbUri"] = img }
                    dict["attributes"] = attrs
                    return dict
                }
            }
        ] as [String: Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }

    private func exportToMarkdown(group: String, themeName: String, tierConfig: TierConfig) -> String {
        var markdown = "# My Tier List - \(group)\n\n"
        markdown += "**Theme:** \(themeName)  \n"
        markdown += "**Date:** \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))\n\n"
        
        for tierName in tierOrder {
            guard let items = tiers[tierName], !items.isEmpty,
                  let cfg = tierConfig[tierName] else { continue }

            markdown += "## \(cfg.name) Tier\n\n"
            for item in items {
                markdown += "- **\(item.name ?? item.id)** (Season \(item.seasonString ?? "?"))\n"
            }
            markdown += "\n"
        }
        
        if let unranked = tiers["unranked"], !unranked.isEmpty {
            markdown += "## Unranked\n\n"
            for item in unranked {
                markdown += "- \(item.name ?? item.id) (Season \(item.seasonString ?? "?"))\n"
            }
        }
        
        return markdown
    }

    private func exportToCSV(group: String, themeName: String) -> String {
        var csv = "Name,Season,Tier\n"
        
        for tierName in tierOrder {
            guard let items = tiers[tierName] else { continue }
            for item in items {
                let name = (item.name ?? item.id).replacingOccurrences(of: ",", with: ";")
                let season = item.seasonString ?? "?"
                csv += "\"\(name)\",\"\(season)\",\"\(tierName)\"\n"
            }
        }
        
        if let unranked = tiers["unranked"] {
            for item in unranked {
                let name = (item.name ?? item.id).replacingOccurrences(of: ",", with: ";")
                let season = item.seasonString ?? "?"
                csv += "\"\(name)\",\"\(season)\",\"Unranked\"\n"
            }
        }
        
        return csv
    }

    func exportText(group: String = "All", themeName: String = "Default") -> String {
        let cfg: TierConfig = [
            "S": TierConfigEntry(name: "S", description: nil),
            "A": TierConfigEntry(name: "A", description: nil),
            "B": TierConfigEntry(name: "B", description: nil),
            "C": TierConfigEntry(name: "C", description: nil),
            "D": TierConfigEntry(name: "D", description: nil),
            "F": TierConfigEntry(name: "F", description: nil)
        ]
        return ExportFormatter.generate(group: group, date: .now, themeName: themeName, tiers: tiers, tierConfig: cfg)
    }

    // MARK: - Import Helpers (JSON/CSV)

    func importFromJSON(_ jsonString: String) async -> Bool {
        return await withLoadingIndicator(message: "Importing JSON data...") {
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
                        // Build attributes bag where possible
                        var attrs: [String: String] = [:]
                        for (k, v) in data { if k != "id" { attrs[k] = v } }
                        return Item(id: id, attributes: attrs.isEmpty ? nil : attrs)
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
        return await withLoadingIndicator(message: "Importing CSV data...") {
            updateProgress(0.2)
            
            let lines = csvString.components(separatedBy: .newlines)
            guard lines.count > 1 else {
                showErrorToast("Import Failed", message: "CSV file appears to be empty")
                return false
            }
            updateProgress(0.4)
            
            var newTiers: Items = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
            
            // Skip header row
            for line in lines.dropFirst() {
                guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                
                let components = parseCSVLine(line)
                guard components.count >= 3 else { continue }
                
                let name = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let season = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let tier = components[2].trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard !name.isEmpty else { continue }
                
                let id = name.lowercased().replacingOccurrences(of: " ", with: "_")
                var attrs: [String: String] = ["name": name]
                if !season.isEmpty { attrs["season"] = season }
                let item = Item(id: id, attributes: attrs.isEmpty ? nil : attrs)

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

    private func parseCSVLine(_ line: String) -> [String] {
        var components: [String] = []
        var currentComponent = ""
        var insideQuotes = false
        
        for char in line {
            if char == Character("\"") {
                insideQuotes.toggle()
            } else if char == Character(",") && !insideQuotes {
                components.append(currentComponent)
                currentComponent = ""
            } else {
                currentComponent.append(char)
            }
        }
        components.append(currentComponent)
        
        return components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "") }
    }

    // URL-based import methods for file handling
    func importFromJSON(url: URL) async -> Bool {
        // Try to load as a full project JSON (new schema) and resolve tiers/items
        do {
            let dict = try ModelResolver.loadProject(from: url)
            let resolved = ModelResolver.resolveTiers(from: dict)
            var newTiers: Items = [:]
            var newOrder: [String] = []
            for rt in resolved {
                newOrder.append(rt.label)
                newTiers[rt.label] = rt.items.map { ri in
                    // Construct Item from ResolvedItem canonical fields (title,
                    // thumbUri). We intentionally avoid depending on the generic
                    // attributes bag here.
                    return Item(id: ri.id, name: ri.title, imageUrl: ri.thumbUri)
                }
            }
            await MainActor.run {
                self.tierOrder = newOrder
                self.tiers = newTiers
                self.history = HistoryLogic.initHistory(self.tiers, limit: self.history.limit)
                self.markAsChanged()
            }
            showSuccessToast("Import Complete", message: "Project loaded successfully")
            return true
        } catch {
            // Fallback to previous simple JSON import
            do {
                let data = try Data(contentsOf: url)
                let content = String(data: data, encoding: .utf8) ?? ""
                return await importFromJSON(content)
            } catch {
                showErrorToast("Import Failed", message: "Could not read JSON file: \(error.localizedDescription)")
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
            showErrorToast("Import Failed", message: "Could not read CSV file: \(error.localizedDescription)")
            return false
        }
    }
}
