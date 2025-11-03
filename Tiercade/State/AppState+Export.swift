import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CryptoKit
import TiercadeCore

@MainActor
internal extension AppState {
    // MARK: - Export System

    internal func exportToFormat(
        _ format: ExportFormat,
        group: String = "All",
        themeName: String = "Default"
    ) async throws(ExportError) -> (Data, String) {
        do {
            return try await withLoadingIndicator(message: "Exporting \(format.displayName)...") {
                try await performExport(format: format, group: group, themeName: themeName)
            }
        } catch let error as ExportError {
            throw error
        } catch {
            throw ExportError.renderingFailed("Unexpected error: \(error.localizedDescription)")
        }
    }

    private func performExport(
        format: ExportFormat,
        group: String,
        themeName: String
    ) async throws -> (Data, String) {
        updateProgress(0.2)

        let tierConfig = buildDefaultTierConfig()
        updateProgress(0.4)

        if let binaryResult = try handleBinaryExport(format: format, group: group, themeName: themeName) {
            return binaryResult
        }

        if format == .json {
            return try handleJSONExport(group: group, themeName: themeName)
        }

        return try handleTextExport(format: format, group: group, themeName: themeName, tierConfig: tierConfig)
    }

    private func buildDefaultTierConfig() -> TierConfig {
        [
            "S": TierConfigEntry(name: "S", description: nil),
            "A": TierConfigEntry(name: "A", description: nil),
            "B": TierConfigEntry(name: "B", description: nil),
            "C": TierConfigEntry(name: "C", description: nil),
            "D": TierConfigEntry(name: "D", description: nil),
            "F": TierConfigEntry(name: "F", description: nil)
        ]
    }

    private func handleBinaryExport(
        format: ExportFormat,
        group: String,
        themeName: String
    ) throws -> (Data, String)? {
        switch exportBinaryFormat(format, group: group, themeName: themeName) {
        case .success(let data, let fileName):
            updateProgress(1.0)
            let message = fileName.hasSuffix(".pdf")
                ? "Exported PDF {export}"
                : "Exported PNG image {export}"
            showSuccessToast("Export Complete", message: message)
            return (data, fileName)
        case .failure:
            throw ExportError.renderingFailed("Binary export failed")
        case .notApplicable:
            return nil
        }
    }

    private func handleJSONExport(group: String, themeName: String) throws -> (Data, String) {
        let (data, fileName) = try exportCanonicalProjectJSON(group: group, themeName: themeName)
        updateProgress(1.0)
        showSuccessToast("Export Complete", message: "Exported canonical JSON {export}")
        return (data, fileName)
    }

    private func handleTextExport(
        format: ExportFormat,
        group: String,
        themeName: String,
        tierConfig: TierConfig
    ) throws -> (Data, String) {
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
        showSuccessToast("Export Complete", message: "Exported as \(format.displayName) {export}")
        return (data, fileName)
    }

    internal func exportText(group: String = "All", themeName: String = "Default") -> String {
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

    internal func exportToFormat(_ format: ExportFormat) async throws(ExportError) -> (Data, String) {
        try await exportToFormat(format, group: "All", themeName: "Default")
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
        func sanitizeCSVCell(_ value: String) -> String {
            if value.hasPrefix("=") || value.hasPrefix("+") || value.hasPrefix("-") || value.hasPrefix("@") {
                return "'" + value
            }
            return value
        }

        var csv = "Name,Season,Tier\n"

        for tierName in tierOrder {
            guard let items = tiers[tierName] else { continue }
            for item in items {
                let rawName = (item.name ?? item.id).replacingOccurrences(of: ",", with: ";")
                let name = sanitizeCSVCell(rawName)
                let season = sanitizeCSVCell(item.seasonString ?? "?")
                csv += "\"\(name)\",\"\(season)\",\"\(tierName)\"\n"
            }
        }

        if let unranked = tiers["unranked"] {
            for item in unranked {
                let rawName = (item.name ?? item.id).replacingOccurrences(of: ",", with: ";")
                let name = sanitizeCSVCell(rawName)
                let season = sanitizeCSVCell(item.seasonString ?? "?")
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
                showErrorToast("Export Failed", message: "Could not render PNG {warning}")
                return .failure
            }
            return .success(data, "tier_list.png")
        case .pdf:
            #if os(tvOS)
            showErrorToast("Unsupported", message: "PDF export is not available on tvOS {warning}")
            return .failure
            #else
            guard let data = ExportRenderer.renderPDF(context: context) else {
                showErrorToast("Export Failed", message: "Could not render PDF {warning}")
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
        case .markdown:
            return (
                exportToMarkdown(group: group, themeName: themeName, tierConfig: tierConfig),
                "tier_list.md"
            )
        case .csv:
            return (exportToCSV(group: group, themeName: themeName), "tier_list.csv")
        default:
            showErrorToast("Export Failed", message: "Unsupported export format {warning}")
            return nil
        }
    }

    private func exportCanonicalProjectJSON(group: String, themeName: String) throws -> (Data, String) {
        let artifacts = try buildProjectExportArtifacts(group: group, themeName: themeName)
        let data = try encodeProjectForExport(artifacts.project)
        let preferredName = artifacts.project.title?.isEmpty == false
            ? artifacts.project.title!
            : artifacts.project.projectId
        let fileName = makeExportFileName(from: preferredName, fileExtension: "json")
        return (data, fileName)
    }

    private func encodeProjectForExport(_ project: Project) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(project)
    }

    internal func buildProjectExportArtifacts(group: String, themeName: String) throws -> ProjectExportArtifacts {
        let now = Date()
        let projectId = exportProjectIdentifier()
        let orderedTiers = exportTierOrderIncludingUnranked()

        let (itemsDictionary, exportFiles) = try buildItemsAndFiles(orderedTiers: orderedTiers)
        let projectTiers = buildProjectTiers(orderedTiers: orderedTiers)
        let settings = buildProjectSettings()
        let additional = buildProjectAdditional(group: group, themeName: themeName)
        let audit = buildProjectAudit(timestamp: now)

        let project = Project(
            schemaVersion: 1,
            projectId: projectId,
            title: activeTierDisplayName,
            description: nil,
            tiers: projectTiers,
            items: itemsDictionary,
            overrides: nil,
            links: nil,
            storage: Project.Storage(mode: "local"),
            settings: settings,
            collab: nil,
            audit: audit,
            additional: additional.isEmpty ? nil : additional
        )

        return ProjectExportArtifacts(project: project, files: exportFiles)
    }

    private func buildItemsAndFiles(
        orderedTiers: [String]
    ) throws -> ([String: Project.Item], [ProjectExportArtifacts.ProjectExportFile]) {
        var itemsDictionary: [String: Project.Item] = [:]
        var exportFiles: [ProjectExportArtifacts.ProjectExportFile] = []

        for tierName in orderedTiers {
            guard let tierItems = tiers[tierName] else { continue }
            for item in tierItems {
                if itemsDictionary[item.id] != nil { continue }
                let projectItem = try makeProjectItem(from: item, collecting: &exportFiles)
                itemsDictionary[item.id] = projectItem
            }
        }

        return (itemsDictionary, exportFiles)
    }

    private func buildProjectTiers(orderedTiers: [String]) -> [Project.Tier] {
        orderedTiers.enumerated().map { index, tierName in
            Project.Tier(
                id: tierName,
                label: tierLabels[tierName] ?? tierName,
                color: tierColors[tierName],
                order: tierName == "unranked" ? orderedTiers.count : index,
                locked: lockedTiers.contains(tierName),
                collapsed: nil,
                rules: nil,
                itemIds: tiers[tierName]?.map(\.id) ?? [],
                additional: nil
            )
        }
    }

    private func buildProjectSettings() -> Project.Settings {
        var settingsAdditional: [String: JSONValue] = [
            "cardDensityPreference": .string(cardDensityPreference.rawValue)
        ]
        if let activeGroup = activeTierList?.displayName {
            settingsAdditional["activeList"] = .string(activeGroup)
        }

        return Project.Settings(
            theme: selectedTheme.slug,
            tierSortOrder: nil,
            gridSnap: nil,
            showUnranked: true,
            accessibility: nil,
            additional: settingsAdditional
        )
    }

    private func buildProjectAdditional(group: String, themeName: String) -> [String: JSONValue] {
        var additional: [String: JSONValue] = [:]
        if !group.isEmpty {
            additional["exportGroup"] = .string(group)
        }
        if !themeName.isEmpty {
            additional["exportThemeName"] = .string(themeName)
        }
        if let customThemesPayload = makeCustomThemesPayload() {
            additional["customThemes"] = customThemesPayload
        }
        return additional
    }

    private func buildProjectAudit(timestamp: Date) -> Project.Audit {
        Project.Audit(
            createdAt: lastSavedTime ?? timestamp,
            updatedAt: timestamp,
            createdBy: "local-user",
            updatedBy: "local-user"
        )
    }

    private func makeProjectItem(
        from item: Item,
        collecting exportFiles: inout [ProjectExportArtifacts.ProjectExportFile]
    ) throws -> Project.Item {
        var attributes: [String: JSONValue] = [:]
        if let season = item.seasonString, !season.isEmpty {
            attributes["season"] = .string(season)
        }
        if let seasonNumber = item.seasonNumber {
            attributes["seasonNumber"] = .number(Double(seasonNumber))
        }
        if let status = item.status, !status.isEmpty {
            attributes["status"] = .string(status)
        }
        if let description = item.description, !description.isEmpty {
            attributes["description"] = .string(description)
        }

        let mediaEntries = try makeMediaEntries(from: item, collecting: &exportFiles)
        if let media = mediaEntries?.first, let thumb = media.thumbUri {
            attributes["thumbUri"] = .string(thumb)
        }

        return Project.Item(
            id: item.id,
            title: item.name ?? item.id,
            subtitle: item.seasonString,
            summary: item.description,
            slug: nil,
            media: mediaEntries,
            attributes: attributes.isEmpty ? nil : attributes,
            tags: nil,
            rating: nil,
            sources: nil,
            locale: nil,
            meta: nil,
            additional: nil
        )
    }

    private func makeMediaEntries(
        from item: Item,
        collecting exportFiles: inout [ProjectExportArtifacts.ProjectExportFile]
    ) throws -> [Project.Media]? {
        guard
            let imagePath = item.imageUrl,
            let url = URL(string: imagePath),
            url.isFileURL,
            FileManager.default.fileExists(atPath: url.path)
        else {
            return nil
        }

        let export = try makeMediaExport(from: url, altText: item.name ?? item.id)
        exportFiles.append(contentsOf: export.files)
        return [export.media]
    }

    private func makeMediaExport(from url: URL, altText: String?) throws -> MediaExportResult {
        let resolvedURL = url.standardizedFileURL
        let data = try Data(contentsOf: resolvedURL)
        let hash = sha256Hex(for: data)
        let fileExtension = resolvedURL.pathExtension.lowercased()
        let mediaFileName = fileExtension.isEmpty ? hash : "\(hash).\(fileExtension)"
        let mediaRelativePath = "Media/\(mediaFileName)"

        let (kind, mime) = determineMediaType(fileExtension: fileExtension)
        let files = buildMediaFiles(
            resolvedURL: resolvedURL,
            mediaRelativePath: mediaRelativePath,
            hash: hash,
            fileExtension: fileExtension,
            kind: kind
        )
        let thumbURI = buildThumbURI(hash: hash, fileExtension: fileExtension, kind: kind)

        let media = Project.Media(
            id: hash,
            kind: kind,
            uri: "file://\(mediaRelativePath)",
            mime: mime,
            w: nil,
            h: nil,
            durationMs: nil,
            posterUri: nil,
            thumbUri: thumbURI,
            alt: altText,
            attribution: nil,
            additional: nil
        )

        return MediaExportResult(media: media, files: files)
    }

    private func determineMediaType(fileExtension: String) -> (ProjectMediaKind, String) {
        let type = UTType(filenameExtension: fileExtension) ?? .data
        let mime = type.preferredMIMEType ?? "application/octet-stream"
        let kind: ProjectMediaKind

        if type.conforms(to: .gif) {
            kind = .gif
        } else if type.conforms(to: .image) {
            kind = .image
        } else if type.conforms(to: .audiovisualContent) && type.conforms(to: .audio) {
            kind = .audio
        } else if type.conforms(to: .audiovisualContent) {
            kind = .video
        } else {
            kind = .image
        }

        return (kind, mime)
    }

    private func buildMediaFiles(
        resolvedURL: URL,
        mediaRelativePath: String,
        hash: String,
        fileExtension: String,
        kind: ProjectMediaKind
    ) -> [ProjectExportArtifacts.ProjectExportFile] {
        var files: [ProjectExportArtifacts.ProjectExportFile] = [
            ProjectExportArtifacts.ProjectExportFile(sourceURL: resolvedURL, relativePath: mediaRelativePath)
        ]

        if kind == .image {
            let thumbExtension = fileExtension.isEmpty ? "bin" : fileExtension
            let thumbFileName = "\(hash)_256.\(thumbExtension)"
            let thumbRelativePath = "Thumbs/\(thumbFileName)"
            files.append(
                ProjectExportArtifacts.ProjectExportFile(
                    sourceURL: resolvedURL,
                    relativePath: thumbRelativePath
                )
            )
        }

        return files
    }

    private func buildThumbURI(hash: String, fileExtension: String, kind: ProjectMediaKind) -> String? {
        guard kind == .image else { return nil }
        let thumbExtension = fileExtension.isEmpty ? "bin" : fileExtension
        let thumbFileName = "\(hash)_256.\(thumbExtension)"
        let thumbRelativePath = "Thumbs/\(thumbFileName)"
        return "file://\(thumbRelativePath)"
    }

    private func sha256Hex(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func makeCustomThemesPayload() -> JSONValue? {
        guard !customThemes.isEmpty else { return nil }

        let themeValues: [JSONValue] = customThemes.map { theme in
            let tierValues: [JSONValue] = theme.tiers.map { tier in
                .object([
                    "id": .string(tier.id.uuidString),
                    "index": .number(Double(tier.index)),
                    "name": .string(tier.name),
                    "colorHex": .string(tier.colorHex),
                    "isUnranked": .bool(tier.isUnranked)
                ])
            }

            return .object([
                "id": .string(theme.id.uuidString),
                "slug": .string(theme.slug),
                "displayName": .string(theme.displayName),
                "shortDescription": .string(theme.shortDescription),
                "tiers": .array(tierValues)
            ])
        }

        return .array(themeValues)
    }

    private func exportProjectIdentifier() -> String {
        if let handle = activeTierList {
            return handle.identifier
        }
        if let currentFileName {
            return currentFileName
        }
        return "tiercade-\(UUID().uuidString)"
    }

    private func exportTierOrderIncludingUnranked() -> [String] {
        var ordered = tierOrder
        if !ordered.contains("unranked") {
            ordered.append("unranked")
        }
        return ordered
    }

    private func makeExportFileName(from preferredName: String, fileExtension ext: String) -> String {
        let sanitized = preferredName
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9-_]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = sanitized.isEmpty ? "tiercade-project" : sanitized
        return "\(base).\(ext)"
    }
}

internal struct ProjectExportArtifacts {
    struct ProjectExportFile {
        let sourceURL: URL
        let relativePath: String
    }

    let project: Project
    let files: [ProjectExportFile]
}

private struct MediaExportResult {
    let media: Project.Media
    let files: [ProjectExportArtifacts.ProjectExportFile]
}
