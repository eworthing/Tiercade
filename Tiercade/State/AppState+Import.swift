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

                let project = try await decodeProject(fromJSON: jsonString)
                updateProgress(0.7)
                let snapshot = captureTierSnapshot()
                applyImportedProject(project, action: "Import JSON", fileName: nil, undoSnapshot: snapshot)
                updateProgress(1.0)

                showSuccessToast("Import Complete", message: "Successfully imported tier list {import}")
            }
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.parsingFailed("Unexpected error: \(error.localizedDescription)")
        }
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

    // Swift 6 (Swift 6.2 toolchain) pattern: heavy CSV parsing runs on background thread pool via Task.detached
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
            let project = try await loadProjectFromFile(url)
            let snapshot = captureTierSnapshot()
            applyImportedProject(
                project,
                action: "Import Project",
                fileName: url.deletingPathExtension().lastPathComponent,
                undoSnapshot: snapshot
            )
            showSuccessToast("Import Complete", message: "Project loaded successfully {import}")
        } catch let error as NSError where error.domain == "Tiercade" {
            throw ImportError.invalidData(error.localizedDescription)
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.invalidData("Could not read JSON file: \(error.localizedDescription)")
        }
    }

    // Swift 6 (Swift 6.2 toolchain) pattern: file I/O and ModelResolver on background via Task.detached
    nonisolated
    private func loadProjectFromFile(_ url: URL) async throws(ImportError) -> Project {
        do {
            return try await ModelResolver.loadProjectAsync(from: url)
        } catch {
            do {
                let data = try Data(contentsOf: url)
                return try await decodeProject(fromData: data)
            } catch let error as ImportError {
                throw error
            } catch {
                throw ImportError.invalidData("Could not load project: \(error.localizedDescription)")
            }
        }
    }

    func importFromCSV(url: URL) async throws(ImportError) {
        // File I/O on background thread pool
        let content = try await loadCSVFromFile(url)

        // Reuse existing CSV import logic
        try await importFromCSV(content)
    }

    // Swift 6 (Swift 6.2 toolchain) pattern: file I/O on background via Task.detached
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

    // MARK: - Canonical project helpers

    func applyImportedProject(
        _ project: Project,
        action: String,
        fileName: String?,
        undoSnapshot: TierStateSnapshot
    ) {
        let state = resolvedTierState(from: project)
        tierOrder = state.order
        tiers = state.items
        tierLabels = state.labels
        tierColors = state.colors
        lockedTiers = state.locked

        applyProjectMetadata(from: project)

        if let fileName {
            currentFileName = fileName
        }

        finalizeChange(action: action, undoSnapshot: undoSnapshot)
    }

    private func applyProjectMetadata(from project: Project) {
        restoreCustomThemes(from: project)

        if let settings = project.settings {
            if let themeSlug = settings.theme {
                applyTheme(slug: themeSlug)
            }

            if let densityValue = settings.additional?["cardDensityPreference"]?.stringValue,
               let preference = CardDensityPreference(rawValue: densityValue) {
                cardDensityPreference = preference
            }
        }
    }

    private func restoreCustomThemes(from project: Project) {
        guard
            let value = project.additional?["customThemes"],
            case let .array(themeValues) = value
        else {
            customThemes = []
            customThemeIDs = []
            return
        }

        var restored: [TierTheme] = []
        restored.reserveCapacity(themeValues.count)

        for entry in themeValues {
            if let theme = decodeTheme(from: entry) {
                restored.append(theme)
            }
        }

        customThemes = restored
        customThemeIDs = Set(restored.map(\.id))
    }

    private func decodeTheme(from value: JSONValue) -> TierTheme? {
        guard
            case let .object(themeDict) = value,
            let idString = themeDict["id"]?.stringValue,
            let id = UUID(uuidString: idString),
            let slug = themeDict["slug"]?.stringValue,
            let displayName = themeDict["displayName"]?.stringValue,
            let shortDescription = themeDict["shortDescription"]?.stringValue,
            let tiersValue = themeDict["tiers"],
            case let .array(tierValues) = tiersValue
        else {
            return nil
        }

        var tiers: [TierTheme.Tier] = []
        tiers.reserveCapacity(tierValues.count)

        for tierEntry in tierValues {
            guard
                case let .object(tierDict) = tierEntry,
                let tierIdString = tierDict["id"]?.stringValue,
                let tierId = UUID(uuidString: tierIdString),
                let indexValue = tierDict["index"]?.numberValue,
                let name = tierDict["name"]?.stringValue,
                let colorHex = tierDict["colorHex"]?.stringValue,
                let isUnranked = tierDict["isUnranked"]?.boolValue
            else {
                continue
            }

            tiers.append(
                TierTheme.Tier(
                    id: tierId,
                    index: Int(indexValue),
                    name: name,
                    colorHex: colorHex,
                    isUnranked: isUnranked
                )
            )
        }

        guard !tiers.isEmpty else { return nil }

        return TierTheme(
            id: id,
            slug: slug,
            displayName: displayName,
            shortDescription: shortDescription,
            tiers: tiers
        )
    }

    private func applyTheme(slug: String) {
        if let builtIn = TierThemeCatalog.theme(slug: slug) {
            setSelectedTheme(builtIn)
            return
        }

        if let custom = customThemes.first(where: { $0.slug.caseInsensitiveCompare(slug) == .orderedSame }) {
            setSelectedTheme(custom)
        }
    }

    private func setSelectedTheme(_ theme: TierTheme) {
        selectedTheme = theme
        selectedThemeID = theme.id
    }

    // MARK: - Decoding helpers

    nonisolated
    private func decodeProject(fromJSON jsonString: String) async throws(ImportError) -> Project {
        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.invalidFormat("String is not valid UTF-8")
        }
        return try await decodeProject(fromData: data)
    }

    nonisolated
    private func decodeProject(fromData data: Data) async throws(ImportError) -> Project {
        do {
            return try await Task.detached(priority: .userInitiated) {
                try ModelResolver.decodeProject(from: data)
            }.value
        } catch let error as NSError where error.domain == "Tiercade" {
            throw ImportError.invalidData(error.localizedDescription)
        } catch {
            throw ImportError.parsingFailed("JSON parsing failed: \(error.localizedDescription)")
        }
    }
}

private extension JSONValue {
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let number):
            return String(number)
        case .bool(let bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
    }

    var numberValue: Double? {
        switch self {
        case .number(let value):
            return value
        case .string(let string):
            return Double(string)
        default:
            return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value):
            return value
        case .string(let string):
            return (string as NSString).boolValue
        default:
            return nil
        }
    }
}
