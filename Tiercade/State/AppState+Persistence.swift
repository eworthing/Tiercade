import Foundation
import SwiftUI
import TiercadeCore

private struct CodableTheme: Codable {
    struct CodableTier: Codable {
        let id: UUID
        let index: Int
        let name: String
        let colorHex: String
        let isUnranked: Bool
    }

    let id: UUID
    let slug: String
    let name: String
    let description: String
    let tiers: [CodableTier]

    init(theme: TierTheme) {
        id = theme.id
        slug = theme.slug
        name = theme.displayName
        description = theme.shortDescription
        tiers = theme.tiers.map { tier in
            CodableTier(
                id: tier.id,
                index: tier.index,
                name: tier.name,
                colorHex: tier.colorHex,
                isUnranked: tier.isUnranked
            )
        }
    }

    func toTheme() -> TierTheme {
        let tierModels = tiers.map { tier in
            TierTheme.Tier(
                id: tier.id,
                index: tier.index,
                name: tier.name,
                colorHex: tier.colorHex,
                isUnranked: tier.isUnranked
            )
        }

        return TierTheme(
            id: id,
            slug: slug,
            displayName: name,
            shortDescription: description,
            tiers: tierModels
        )
    }
}

private struct PersistenceSnapshot: Sendable {
    let tiers: Items
    let tierLabels: [String: String]
    let tierColors: [String: String]
    let selectedThemeID: UUID
    let customThemes: [CodableTheme]
    let cardDensityPreference: CardDensityPreference
}

@MainActor
extension AppState {
    // MARK: - Enhanced Persistence

    func save() throws(PersistenceError) {
        do {
            // Persist tiers and customizations
            struct SaveData: Codable {
                let tiers: Items
                let tierLabels: [String: String]
                let tierColors: [String: String]
                let selectedThemeID: String?
                let customThemes: [CodableTheme]
                let cardDensityPreference: String
            }
            let saveData = SaveData(
                tiers: tiers,
                tierLabels: tierLabels,
                tierColors: tierColors,
                selectedThemeID: selectedThemeID.uuidString,
                customThemes: customThemes.map(CodableTheme.init),
                cardDensityPreference: cardDensityPreference.rawValue
            )
            let data = try JSONEncoder().encode(saveData)
            UserDefaults.standard.set(data, forKey: storageKey)
            hasUnsavedChanges = false
            lastSavedTime = Date()
            // No toast for autosave - silent like modern apps
        } catch {
            throw PersistenceError.encodingFailed("JSONEncoder failed: \(error.localizedDescription)")
        }
    }

    // Swift 6.2 pattern: async save with background encoding
    func saveAsync() async throws(PersistenceError) {
        // Capture state and convert to Codable on MainActor
        let tiersSnapshot = tiers
        let labelsSnapshot = tierLabels
        let colorsSnapshot = tierColors
        let themeIDSnapshot = selectedThemeID
        let codableThemes = customThemes.map { CodableTheme(theme: $0) }
        let densitySnapshot = cardDensityPreference

        let snapshot = PersistenceSnapshot(
            tiers: tiersSnapshot,
            tierLabels: labelsSnapshot,
            tierColors: colorsSnapshot,
            selectedThemeID: themeIDSnapshot,
            customThemes: codableThemes,
            cardDensityPreference: densitySnapshot
        )

        // Encode on background thread pool
        let data = try await encodeAppState(snapshot: snapshot)

        // Save and update state on MainActor
        UserDefaults.standard.set(data, forKey: storageKey)
        hasUnsavedChanges = false
        lastSavedTime = Date()
    }

    func autoSave() throws(PersistenceError) {
        guard hasUnsavedChanges else { return }
        try save()
    }

    func autoSaveAsync() async {
        guard hasUnsavedChanges else { return }
        try? await saveAsync()
    }

    // Swift 6.2 pattern: heavy JSON encoding on background via Task.detached
    nonisolated
    private func encodeAppState(
        snapshot: PersistenceSnapshot
    ) async throws(PersistenceError) -> Data {
        struct SaveData: Codable {
            let tiers: Items
            let tierLabels: [String: String]
            let tierColors: [String: String]
            let selectedThemeID: String?
            let customThemes: [CodableTheme]
            let cardDensityPreference: String
        }

        let saveData = SaveData(
            tiers: snapshot.tiers,
            tierLabels: snapshot.tierLabels,
            tierColors: snapshot.tierColors,
            selectedThemeID: snapshot.selectedThemeID.uuidString,
            customThemes: snapshot.customThemes,
            cardDensityPreference: snapshot.cardDensityPreference.rawValue
        )

        do {
            return try JSONEncoder().encode(saveData)
        } catch {
            throw PersistenceError.encodingFailed("JSONEncoder failed: \(error.localizedDescription)")
        }
    }

    func saveToFile(named fileName: String) throws(PersistenceError) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            struct AppSaveFile: Codable {
                let tiers: Items
                let tierLabels: [String: String]
                let tierColors: [String: String]
                let selectedThemeID: String?
                let customThemes: [CodableTheme]
                let createdDate: Date
                let appVersion: String
                let cardDensityPreference: String
            }

            let saveData = AppSaveFile(
                tiers: tiers,
                tierLabels: tierLabels,
                tierColors: tierColors,
                selectedThemeID: selectedThemeID.uuidString,
                customThemes: customThemes.map(CodableTheme.init),
                createdDate: Date(),
                appVersion: "1.0",
                cardDensityPreference: cardDensityPreference.rawValue
            )

            let data = try encoder.encode(saveData)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("\(fileName).json")

            try data.write(to: fileURL)

            currentFileName = fileName
            hasUnsavedChanges = false
            lastSavedTime = Date()

            showSuccessToast("File Saved", message: "Saved as \(fileName).json")
        } catch let error as EncodingError {
            throw PersistenceError.encodingFailed("Failed to encode: \(error.localizedDescription)")
        } catch let error as CocoaError where error.code == .fileWriteNoPermission {
            throw PersistenceError.permissionDenied
        } catch {
            throw PersistenceError.fileSystemError("Could not write file: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func load() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return false }

        restoreCustomThemes([])

        if loadModernFormat(from: data) {
            return true
        }

        return loadLegacyFormat(from: data)
    }

    private func loadModernFormat(from data: Data) -> Bool {
        do {
            // Try new format with customizations first
            struct SaveData: Codable {
                let tiers: Items
                let tierLabels: [String: String]
                let tierColors: [String: String]
                let selectedThemeID: String?
                let customThemes: [CodableTheme]?
                let cardDensityPreference: String?
            }
            if let saveData = try? JSONDecoder().decode(SaveData.self, from: data) {
                applyLoadedTiers(saveData.tiers, isLegacy: false)
                tierLabels = saveData.tierLabels
                tierColors = saveData.tierColors
                restoreCustomThemes(saveData.customThemes ?? [])
                restoreTheme(themeIDString: saveData.selectedThemeID)
                restoreCardDensityPreference(rawValue: saveData.cardDensityPreference)
                return true
            }

            // Fallback to old format without customizations
            let decoded = try JSONDecoder().decode(Items.self, from: data)
            applyLoadedTiers(decoded, isLegacy: false)
            return true
        } catch {
            return false
        }
    }

    private func loadLegacyFormat(from data: Data) -> Bool {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tierData = json["tiers"] as? [String: [[String: Any]]] else {
                return false
            }

            let newTiers = parseLegacyTiers(from: tierData)
            applyLoadedTiers(newTiers, isLegacy: true)
            restoreCustomThemes([])
            restoreCardDensityPreference(rawValue: nil)
            return true
        } catch {
            print("Legacy load failed: \(error)")
            showErrorToast("Load Failed", message: "Could not load tier list")
            return false
        }
    }

    private func parseLegacyTiers(from tierData: [String: [[String: Any]]]) -> Items {
        var newTiers: Items = [:]
        for (tierName, itemData) in tierData {
            newTiers[tierName] = itemData.compactMap { parseLegacyItem(from: $0) }
        }
        return newTiers
    }

    private func parseLegacyItem(from dict: [String: Any]) -> Item? {
        guard let id = dict["id"] as? String else { return nil }

        if let attrs = dict["attributes"] as? [String: String] {
            return Item(id: id, attributes: attrs)
        }

        var attrs: [String: String] = [:]
        for (k, v) in dict where k != "id" {
            attrs[k] = String(describing: v)
        }
        return Item(id: id, attributes: attrs.isEmpty ? nil : attrs)
    }

    private func applyLoadedTiers(_ loadedTiers: Items, isLegacy: Bool) {
        tiers = loadedTiers
        history = HistoryLogic.initHistory(tiers, limit: history.limit)
        hasUnsavedChanges = false
        lastSavedTime = UserDefaults.standard.object(forKey: "\(storageKey).timestamp") as? Date
        let message = isLegacy ? "Tier list loaded (legacy) successfully" : "Tier list loaded successfully"
        showSuccessToast("Loaded", message: message)
    }

    private func restoreTheme(themeIDString: String?) {
        if let themeIDString,
           let uuid = UUID(uuidString: themeIDString),
           let theme = theme(with: uuid) {
            selectedThemeID = uuid
            selectedTheme = theme
            return
        }

        let fallback = TierThemeCatalog.defaultTheme
        selectedTheme = fallback
        selectedThemeID = fallback.id
    }

    private func restoreCustomThemes(_ codableThemes: [CodableTheme]) {
        let restored = codableThemes.map { $0.toTheme() }
        customThemes = restored.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        customThemeIDs = Set(restored.map(\TierTheme.id))
    }

    @discardableResult
    func loadFromFile(named fileName: String) -> Bool {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("\(fileName).json")

            let data = try Data(contentsOf: fileURL)
            // Try to decode the modern app save file with customizations, fall back to legacy structures
            struct AppSaveFile: Codable {
                let tiers: Items
                let tierLabels: [String: String]?
                let tierColors: [String: String]?
                let selectedThemeID: String?
                let customThemes: [CodableTheme]?
                let createdDate: Date
                let appVersion: String
                let cardDensityPreference: String?
            }

            if let saveData = try? JSONDecoder().decode(AppSaveFile.self, from: data) {
                applyLoadedFileSync(
                    tiers: saveData.tiers,
                    fileName: fileName,
                    savedDate: saveData.createdDate
                )
                tierLabels = saveData.tierLabels ?? tierLabels
                tierColors = saveData.tierColors ?? tierColors
                restoreCustomThemes(saveData.customThemes ?? [])
                restoreTheme(themeIDString: saveData.selectedThemeID)
                restoreCardDensityPreference(rawValue: saveData.cardDensityPreference)
                showSuccessToast("File Loaded", message: "Loaded \(fileName).json")
                return true
            }

            // Legacy fallback: parse JSON and build Items from attributes
            if let legacyTiers = parseLegacyTiers(from: data) {
                applyLoadedFileSync(
                    tiers: legacyTiers,
                    fileName: fileName,
                    savedDate: Date()
                )
                restoreCardDensityPreference(rawValue: nil)
                showSuccessToast("File Loaded", message: "Loaded \(fileName).json")
                return true
            }
            showErrorToast("Load Failed", message: "Unrecognized format for \(fileName).json")
            return false
        } catch {
            print("File load failed: \(error)")
            showErrorToast("Load Failed", message: "Could not load \(fileName).json")
            return false
        }
    }

    func getAvailableSaveFiles() -> [String] {
        do {
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: nil
            )
            return fileURLs
                .filter { $0.pathExtension == "json" }
                .map { $0.deletingPathExtension().lastPathComponent }
                .sorted()
        } catch {
            print("Error listing save files: \(error)")
            return []
        }
    }

    func deleteSaveFile(named fileName: String) -> Bool {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            print("Error deleting save file: \(error)")
            return false
        }
    }

    // MARK: - Async File Operations with Progress Tracking

    func saveToFileAsync(named fileName: String) async -> Bool {
        // No loading indicator - save is fast, just show result
        do {
            struct AppSaveFile: Codable {
                let tiers: Items
                let tierLabels: [String: String]
                let tierColors: [String: String]
                let createdDate: Date
                let appVersion: String
                let cardDensityPreference: String
            }
            let saveData = AppSaveFile(
                tiers: tiers,
                tierLabels: tierLabels,
                tierColors: tierColors,
                createdDate: Date(),
                appVersion: "1.0",
                cardDensityPreference: cardDensityPreference.rawValue
            )

            let data = try JSONEncoder().encode(saveData)

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("\(fileName).json")

            try data.write(to: fileURL)

            await MainActor.run {
                currentFileName = fileName
                hasUnsavedChanges = false
                lastSavedTime = Date()
            }

            showSuccessToast("File Saved", message: "Saved \(fileName).json")
            return true
        } catch {
            print("File save failed: \(error)")
            showErrorToast("Save Failed", message: "Could not save \(fileName).json")
            return false
        }
    }

    func loadFromFileAsync(named fileName: String) async -> Bool {
        // No loading indicator - load is fast, just show result
        do {
            let fileURL = try getFileURL(for: fileName)

            let data = try Data(contentsOf: fileURL)

            if try await loadModernSaveFormat(from: data, fileName: fileName) {
                return true
            }

            if try await loadLegacySaveFormat(from: data, fileName: fileName) {
                return true
            }

            throw NSError(
                domain: "AppState",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unrecognized save file format"]
            )
        } catch {
            print("File load failed: \(error)")
            showErrorToast("Load Failed", message: "Could not load \(fileName).json")
            return false
        }
    }

    private func getFileURL(for fileName: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("\(fileName).json")
    }

    private func loadModernSaveFormat(from data: Data, fileName: String) async throws -> Bool {
        struct AppSaveFile: Codable {
            let tiers: Items
            let tierLabels: [String: String]?
            let tierColors: [String: String]?
            let createdDate: Date
            let appVersion: String
            let cardDensityPreference: String?
        }

        guard let saveData = try? JSONDecoder().decode(AppSaveFile.self, from: data) else {
            return false
        }

        await applyLoadedFile(
            tiers: saveData.tiers,
            fileName: fileName,
            savedDate: saveData.createdDate
        )

        // Restore tier customizations if present
        if let labels = saveData.tierLabels {
            tierLabels = labels
        }
        if let colors = saveData.tierColors {
            tierColors = colors
        }
        restoreCardDensityPreference(rawValue: saveData.cardDensityPreference)

        showSuccessToast("File Loaded", message: "Loaded \(fileName).json")
        return true
    }

    private func loadLegacySaveFormat(from data: Data, fileName: String) async throws -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tierData = json["tiers"] as? [String: [[String: Any]]] else {
            return false
        }

        let newTiers = parseLegacyTiers(from: tierData)
        updateProgress(0.8)
        await applyLoadedFile(
            tiers: newTiers,
            fileName: fileName,
            savedDate: Date()
        )
        restoreCardDensityPreference(rawValue: nil)
        updateProgress(1.0)
        showSuccessToast("File Loaded", message: "Loaded \(fileName).json")
        return true
    }

    private func applyLoadedFile(tiers newTiers: Items, fileName: String, savedDate: Date) async {
        await MainActor.run {
            applyLoadedFileSync(
                tiers: newTiers,
                fileName: fileName,
                savedDate: savedDate
            )
        }
    }

    private func applyLoadedFileSync(tiers newTiers: Items, fileName: String, savedDate: Date) {
        tiers = newTiers
        history = HistoryLogic.initHistory(tiers, limit: history.limit)
        currentFileName = fileName
        hasUnsavedChanges = false
        lastSavedTime = savedDate
        registerTierListSelection(tierListHandle(forFileNamed: fileName))
    }

    private func parseLegacyTiers(from data: Data) -> Items? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tierData = json["tiers"] as? [String: [[String: Any]]] else {
            return nil
        }

        var newTiers: Items = [:]
        for (tierName, itemData) in tierData {
            newTiers[tierName] = itemData.compactMap { dict in
                guard let id = dict["id"] as? String else { return nil }
                if let attrs = dict["attributes"] as? [String: String] {
                    return Item(id: id, attributes: attrs)
                }
                var attrs: [String: String] = [:]
                for (key, value) in dict where key != "id" {
                    attrs[key] = String(describing: value)
                }
                return Item(id: id, attributes: attrs.isEmpty ? nil : attrs)
            }
        }
        return newTiers
    }
}
