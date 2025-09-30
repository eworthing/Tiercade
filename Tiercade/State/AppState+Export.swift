import Foundation
import SwiftUI
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Export System

    func exportToFormat(
        _ format: ExportFormat,
        group: String = "All",
        themeName: String = "Default"
    ) async throws(ExportError) -> (Data, String) {
        do {
            return try await withLoadingIndicator(message: "Exporting \(format.displayName)...") {
                updateProgress(0.2)

                let tierConfig: TierConfig = [
                    "S": TierConfigEntry(name: "S", description: nil),
                    "A": TierConfigEntry(name: "A", description: nil),
                    "B": TierConfigEntry(name: "B", description: nil),
                    "C": TierConfigEntry(name: "C", description: nil),
                    "D": TierConfigEntry(name: "D", description: nil),
                    "F": TierConfigEntry(name: "F", description: nil)
                ]
                updateProgress(0.4)

                switch exportBinaryFormat(format, group: group, themeName: themeName) {
                case .success(let data, let fileName):
                    updateProgress(1.0)
                    let message = fileName.hasSuffix(".pdf") ? "Exported PDF" : "Exported PNG image"
                    showSuccessToast("Export Complete", message: message)
                    return (data, fileName)
                case .failure:
                    throw ExportError.renderingFailed("Binary export failed")
                case .notApplicable:
                    break
                }

                guard let (content, fileName) = exportTextFormat(
                    format,
                    group: group,
                    themeName: themeName,
                    tierConfig: tierConfig
                ) else {
                    throw ExportError.formatNotSupported(format)
                }

                updateProgress(0.8)

                guard let data = content.data(using: .utf8) else {
                    throw ExportError.dataEncodingFailed("UTF-8 encoding failed")
                }

                updateProgress(1.0)
                showSuccessToast("Export Complete", message: "Exported as \(format.displayName)")
                return (data, fileName)
            }
        } catch let error as ExportError {
            throw error
        } catch {
            throw ExportError.renderingFailed("Unexpected error: \(error.localizedDescription)")
        }
    }

    func exportText(group: String = "All", themeName: String = "Default") -> String {
        let config: TierConfig = [
            "S": TierConfigEntry(name: "S", description: nil),
            "A": TierConfigEntry(name: "A", description: nil),
            "B": TierConfigEntry(name: "B", description: nil),
            "C": TierConfigEntry(name: "C", description: nil),
            "D": TierConfigEntry(name: "D", description: nil),
            "F": TierConfigEntry(name: "F", description: nil)
        ]
        return ExportFormatter.generate(
            group: group,
            date: .now,
            themeName: themeName,
            tiers: tiers,
            tierConfig: config
        )
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
            "tiers": tiers.mapValues { tierItems in
                tierItems.map { item in
                    var dict: [String: Any] = ["id": item.id]
                    var attributes: [String: Any] = [:]
                    if let name = item.name { attributes["name"] = name }
                    if let season = item.seasonString { attributes["season"] = season }
                    if let image = item.imageUrl { attributes["thumbUri"] = image }
                    dict["attributes"] = attributes
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
            guard
                let items = tiers[tierName],
                !items.isEmpty,
                let config = tierConfig[tierName]
            else { continue }

            markdown += "## \(config.name) Tier\n\n"
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

    private enum BinaryExportResult {
        case success(Data, String)
        case failure
        case notApplicable
    }

    private func exportBinaryFormat(
        _ format: ExportFormat,
        group: String,
        themeName: String
    ) -> BinaryExportResult {
        let context = ExportRenderer.Context(
            tiers: tiers,
            order: tierOrder,
            labels: tierLabels,
            colors: tierColors,
            group: group,
            themeName: themeName
        )

        switch format {
        case .png:
            guard let data = ExportRenderer.renderPNG(context: context) else {
                showErrorToast("Export Failed", message: "Could not render PNG")
                return .failure
            }
            return .success(data, "tier_list.png")
        case .pdf:
            #if os(tvOS)
            showErrorToast("Unsupported", message: "PDF export is not available on tvOS")
            return .failure
            #else
            guard let data = ExportRenderer.renderPDF(context: context) else {
                showErrorToast("Export Failed", message: "Could not render PDF")
                return .failure
            }
            return .success(data, "tier_list.pdf")
            #endif
        default:
            return .notApplicable
        }
    }

    private func exportTextFormat(
        _ format: ExportFormat,
        group: String,
        themeName: String,
        tierConfig: TierConfig
    ) -> (String, String)? {
        switch format {
        case .text:
            let content = ExportFormatter.generate(
                group: group,
                date: .now,
                themeName: themeName,
                tiers: tiers,
                tierConfig: tierConfig
            )
            return (content, "tier_list.txt")
        case .json:
            return (exportToJSON(group: group, themeName: themeName), "tier_list.json")
        case .markdown:
            return (
                exportToMarkdown(group: group, themeName: themeName, tierConfig: tierConfig),
                "tier_list.md"
            )
        case .csv:
            return (exportToCSV(group: group, themeName: themeName), "tier_list.csv")
        default:
            showErrorToast("Export Failed", message: "Unsupported export format")
            return nil
        }
    }
}
