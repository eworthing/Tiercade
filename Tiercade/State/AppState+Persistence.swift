import Foundation
import SwiftUI
import SwiftData
import os
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

@MainActor
private struct AppSaveFilePayload: Codable {
    let tiers: Items
    let tierLabels: [String: String]?
    let tierColors: [String: String]?
    let selectedThemeID: String?
    let customThemes: [CodableTheme]?
    let createdDate: Date
    let appVersion: String
    let cardDensityPreference: String?
}

extension AppState {
    // MARK: - SwiftData-backed persistence

    func save() throws(PersistenceError) {
        do {
            try persistActiveTierList()
            try modelContext.save()
            hasUnsavedChanges = false
            lastSavedTime = Date()
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.fileSystemError("ModelContext save failed: \(error.localizedDescription)")
        }
    }

    func saveAsync() async throws(PersistenceError) {
        try save()
    }

    func autoSave() throws(PersistenceError) {
        guard hasUnsavedChanges else { return }
        try save()
    }

    func autoSaveAsync() async {
        guard hasUnsavedChanges else { return }
        try? save()
    }

    @discardableResult
    func load() -> Bool {
        do {
            if let entity = try fetchActiveTierListEntity() {
                activeTierListEntity = entity
                applyLoadedTierList(entity)
                return true
            }
        } catch {
            Logger.persistence.error("SwiftData load failed: \(error.localizedDescription)")
        }
        return false
    }

    func saveToFile(named fileName: String) throws(PersistenceError) {
        do {
            let data = try encodeCurrentStateForFileExport()
            let fileURL = fileURLForExport(named: fileName)
            try data.write(to: fileURL)
            finalizeSuccessfulFileSave(named: fileName)
        } catch let error as PersistenceError {
            throw error
        } catch let error as CocoaError where error.code == .fileWriteNoPermission {
            throw PersistenceError.permissionDenied
        } catch {
            throw PersistenceError.fileSystemError("Could not write file: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func loadFromFile(named fileName: String) -> Bool {
        let snapshot = captureTierSnapshot()
        do {
            let data = try dataForFile(named: fileName)

            if applyModernSave(from: data, fileName: fileName, snapshot: snapshot) {
                return true
            }

            if applyLegacySave(from: data, fileName: fileName, snapshot: snapshot) {
                return true
            }

            showErrorToast("Load Failed", message: "Unrecognized format for \(fileName).json {warning}")
            return false
        } catch {
            Logger.persistence.error("File load failed: \(error.localizedDescription)")
            showErrorToast("Load Failed", message: "Could not load \(fileName).json {warning}")
            return false
        }
    }

    private func persistCurrentStateToStore() {
        do {
            try persistActiveTierList()
            try modelContext.save()
            hasUnsavedChanges = false
            lastSavedTime = Date()
        } catch let error as PersistenceError {
            Logger.persistence.error("Persist after external load failed: \(error.localizedDescription)")
        } catch {
            Logger.persistence.error("Persist after external load failed: \(error.localizedDescription)")
        }
    }

    private func encodeCurrentStateForFileExport() throws(PersistenceError) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let payload = AppSaveFilePayload(
            tiers: tiers,
            tierLabels: tierLabels,
            tierColors: tierColors,
            selectedThemeID: selectedThemeID.uuidString,
            customThemes: customThemes.map(CodableTheme.init),
            createdDate: Date(),
            appVersion: "1.0",
            cardDensityPreference: cardDensityPreference.rawValue
        )

        do {
            return try encoder.encode(payload)
        } catch let error as EncodingError {
            throw PersistenceError.encodingFailed("Failed to encode: \(error.localizedDescription)")
        } catch {
            throw PersistenceError.fileSystemError("Could not encode save data: \(error.localizedDescription)")
        }
    }

    private func fileURLForExport(named fileName: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("\(fileName).json")
    }

    private func finalizeSuccessfulFileSave(named fileName: String) {
        currentFileName = fileName
        hasUnsavedChanges = false
        lastSavedTime = Date()
        showSuccessToast("File Saved", message: "Saved as \(fileName).json {file}")
    }

    private func dataForFile(named fileName: String) throws -> Data {
        let fileURL = fileURLForExport(named: fileName)
        return try Data(contentsOf: fileURL)
    }

    private func applyModernSave(from data: Data, fileName: String, snapshot: TierStateSnapshot) -> Bool {
        guard let saveData = try? JSONDecoder().decode(AppSaveFilePayload.self, from: data) else {
            return false
        }

        applyLoadedFileSync(
            tiers: saveData.tiers,
            fileName: fileName,
            savedDate: saveData.createdDate
        )
        tierLabels = saveData.tierLabels ?? tierLabels
        tierColors = saveData.tierColors ?? tierColors
        restoreCustomThemes(saveData.customThemes ?? [])
        restoreTheme(themeID: saveData.selectedThemeID.flatMap(UUID.init))
        restoreCardDensityPreference(rawValue: saveData.cardDensityPreference)
        showSuccessToast("File Loaded", message: "Loaded \(fileName).json {file}")
        finalizeChange(action: "Load File", undoSnapshot: snapshot)
        persistCurrentStateToStore()
        return true
    }

    private func applyLegacySave(from data: Data, fileName: String, snapshot: TierStateSnapshot) -> Bool {
        guard let legacyTiers = parseLegacyTiers(from: data) else {
            return false
        }

        applyLoadedFileSync(
            tiers: legacyTiers,
            fileName: fileName,
            savedDate: Date()
        )
        restoreCardDensityPreference(rawValue: nil)
        showSuccessToast("File Loaded", message: "Loaded \(fileName).json {file}")
        finalizeChange(action: "Load File", undoSnapshot: snapshot)
        persistCurrentStateToStore()
        return true
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
            Logger.persistence.error("Could not list save files: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - SwiftData helpers

    func fetchActiveTierListEntity() throws(PersistenceError) -> TierListEntity? {
        if let cached = activeTierListEntity {
            return cached
        }

        do {
            let descriptor = FetchDescriptor<TierListEntity>(
                predicate: #Predicate { $0.isActive == true },
                sortBy: [SortDescriptor(\TierListEntity.updatedAt, order: .reverse)]
            )

            if let entity = try modelContext.fetch(descriptor).first {
                activeTierListEntity = entity
                return entity
            }

            let anyDescriptor = FetchDescriptor<TierListEntity>(
                sortBy: [SortDescriptor(\TierListEntity.updatedAt, order: .reverse)]
            )
            let entity = try modelContext.fetch(anyDescriptor).first
            if let entity {
                activeTierListEntity = entity
            }
            return entity
        } catch {
            throw PersistenceError.fileSystemError("Model fetch failed: \(error.localizedDescription)")
        }
    }

    private func ensureActiveTierListEntity() throws(PersistenceError) -> TierListEntity {
        if let entity = try fetchActiveTierListEntity() {
            entity.isActive = true
            return entity
        }

        let newEntity = TierListEntity(
            title: activeTierDisplayName,
            fileName: currentFileName,
            cardDensityRaw: cardDensityPreference.rawValue,
            selectedThemeID: selectedThemeID,
            customThemesData: encodedCustomThemesData()
        )
        modelContext.insert(newEntity)
        activeTierListEntity = newEntity
        return newEntity
    }

    private func persistActiveTierList() throws(PersistenceError) {
        let entity = try ensureActiveTierListEntity()
        entity.title = activeTierDisplayName
        entity.fileName = currentFileName
        entity.cardDensityRaw = cardDensityPreference.rawValue
        entity.selectedThemeID = selectedThemeID
        entity.updatedAt = Date()
        entity.customThemesData = encodedCustomThemesData()

        let allTierKeys = tierOrder + ["unranked"]
        var existing = Dictionary(uniqueKeysWithValues: entity.tiers.map { ($0.normalizedKey, $0) })

        for (index, key) in allTierKeys.enumerated() {
            let displayName = tierLabels[key] ?? key
            let colorHex = tierColors[key]
            let isLocked = lockedTiers.contains(key)
            let tierEntity: TierEntity
            if let existingEntity = existing[key] {
                tierEntity = existingEntity
                existingEntity.order = key == "unranked" ? allTierKeys.count : index
                existingEntity.displayName = displayName
                existingEntity.colorHex = colorHex
                existingEntity.isLocked = isLocked
                existingEntity.key = key
            } else {
                tierEntity = TierEntity(
                    key: key,
                    displayName: displayName,
                    colorHex: colorHex,
                    order: key == "unranked" ? allTierKeys.count : index,
                    isLocked: isLocked
                )
                tierEntity.list = entity
                entity.tiers.append(tierEntity)
            }
            existing.removeValue(forKey: key)
            let items = tiers[key] ?? []
            updateItems(for: tierEntity, items: items)
        }

        // Remove tiers that are no longer present
        for obsolete in existing.values {
            if let index = entity.tiers.firstIndex(where: { $0.identifier == obsolete.identifier }) {
                entity.tiers.remove(at: index)
                modelContext.delete(obsolete)
            }
        }
    }

    private func updateItems(for tierEntity: TierEntity, items: [Item]) {
        var existing = Dictionary(uniqueKeysWithValues: tierEntity.items.map { ($0.itemID, $0) })

        for (position, item) in items.enumerated() {
            if let entity = existing[item.id] {
                entity.name = item.name
                entity.seasonString = item.seasonString
                entity.seasonNumber = item.seasonNumber
                entity.status = item.status
                entity.details = item.description
                entity.imageUrl = item.imageUrl
                entity.videoUrl = item.videoUrl
                entity.position = position
                existing.removeValue(forKey: item.id)
            } else {
                let newEntity = TierItemEntity(
                    itemID: item.id,
                    name: item.name,
                    seasonString: item.seasonString,
                    seasonNumber: item.seasonNumber,
                    status: item.status,
                    details: item.description,
                    imageUrl: item.imageUrl,
                    videoUrl: item.videoUrl,
                    position: position,
                    tier: tierEntity
                )
                tierEntity.items.append(newEntity)
            }
        }

        for obsolete in existing.values {
            if let index = tierEntity.items.firstIndex(where: { $0.identifier == obsolete.identifier }) {
                tierEntity.items.remove(at: index)
            }
            modelContext.delete(obsolete)
        }
    }

    func applyPersistedTierList(_ entity: TierListEntity) {
        applyLoadedTierList(entity)
    }

    private func applyLoadedTierList(_ entity: TierListEntity) {
        var newTiers: Items = [:]
        var newLabels: [String: String] = [:]
        var newColors: [String: String] = [:]
        var newLocked: Set<String> = []

        let sortedTiers = entity.tiers.sorted { left, right in
            left.order < right.order
        }

        for tierEntity in sortedTiers {
            let key = tierEntity.normalizedKey
            let items = tierEntity.items
                .sorted { $0.position < $1.position }
                .map(makeItem)
            newTiers[key] = items
            newLabels[key] = tierEntity.displayName
            if let colorHex = tierEntity.colorHex {
                newColors[key] = colorHex
            }
            if tierEntity.isLocked {
                newLocked.insert(key)
            }
        }

        tierOrder = sortedTiers
            .map(\.normalizedKey)
            .filter { $0 != "unranked" }

        tiers = newTiers
        tierLabels = newLabels
        tierColors = newColors
        lockedTiers = newLocked
        restoreTheme(themeID: entity.selectedThemeID)
        restoreCustomThemes(decodeCustomThemes(from: entity.customThemesData))
        restoreCardDensityPreference(rawValue: entity.cardDensityRaw)
        currentFileName = entity.fileName
        hasUnsavedChanges = false
        lastSavedTime = entity.updatedAt
    }

    private func decodeCustomThemes(from data: Data?) -> [CodableTheme] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([CodableTheme].self, from: data)) ?? []
    }

    private func makeItem(from entity: TierItemEntity) -> Item {
        Item(
            id: entity.itemID,
            name: entity.name,
            seasonString: entity.seasonString,
            seasonNumber: entity.seasonNumber,
            status: entity.status,
            description: entity.details,
            imageUrl: entity.imageUrl,
            videoUrl: entity.videoUrl
        )
    }

    // MARK: - Theme & preference restoration

    private func restoreTheme(themeID: UUID?) {
        if let themeID,
           let theme = theme(with: themeID) {
            selectedThemeID = themeID
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

    private func applyLoadedFileSync(
        tiers: Items,
        fileName: String,
        savedDate: Date
    ) {
        self.tiers = tiers
        hasUnsavedChanges = false
        currentFileName = fileName
        lastSavedTime = savedDate
    }

    private func parseLegacyTiers(from data: Data) -> Items? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tierData = json["tiers"] as? [String: [[String: Any]]] else {
            return nil
        }
        return parseLegacyTiers(from: tierData)
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

    func encodedCustomThemesData() -> Data? {
        try? JSONEncoder().encode(customThemes.map(CodableTheme.init))
    }
}
