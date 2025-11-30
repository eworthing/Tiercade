import Foundation
import os
import SwiftData
import SwiftUI
import TiercadeCore

// MARK: - CodableTheme

private struct CodableTheme: Codable {

    // MARK: Lifecycle

    init(theme: TierTheme) {
        self.id = theme.id
        self.slug = theme.slug
        self.name = theme.displayName
        self.description = theme.shortDescription
        self.tiers = theme.tiers.map { tier in
            CodableTier(
                id: tier.id,
                index: tier.index,
                name: tier.name,
                colorHex: tier.colorHex,
                isUnranked: tier.isUnranked,
            )
        }
    }

    // MARK: Internal

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

    func toTheme() -> TierTheme {
        let tierModels = tiers.map { tier in
            TierTheme.Tier(
                id: tier.id,
                index: tier.index,
                name: tier.name,
                colorHex: tier.colorHex,
                isUnranked: tier.isUnranked,
            )
        }

        return TierTheme(
            id: id,
            slug: slug,
            displayName: name,
            shortDescription: description,
            tiers: tierModels,
        )
    }
}

extension AppState {
    // MARK: - SwiftData-backed persistence

    func save() throws(PersistenceError) {
        do {
            try persistActiveTierList()
            try modelContext.save()
            persistence.hasUnsavedChanges = false
            persistence.lastSavedTime = Date()
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
        guard persistence.hasUnsavedChanges else {
            return
        }
        try save()
    }

    func autoSaveAsync() async {
        guard persistence.hasUnsavedChanges else {
            return
        }
        try? save()
    }

    @discardableResult
    func load() -> Bool {
        do {
            if let entity = try fetchActiveTierListEntity() {
                persistence.activeTierListEntity = entity
                applyLoadedTierList(entity)
                return true
            }
        } catch {
            Logger.persistence.error("SwiftData load failed: \(error.localizedDescription)")
        }
        return false
    }

    func saveToFile(named fileName: String) throws(PersistenceError) {
        let sanitizedName = sanitizeFileName(fileName)
        do {
            let artifacts = try buildProjectExportArtifacts(
                group: "All",
                themeName: theme.selectedTheme.displayName,
            )
            let destination = try fileURLForExport(named: sanitizedName)
            try writeProjectBundle(artifacts, to: destination)
            finalizeSuccessfulFileSave(named: sanitizedName)
        } catch let error as ExportError {
            throw PersistenceError.encodingFailed(error.localizedDescription)
        } catch let error as PersistenceError {
            throw error
        } catch let error as CocoaError where error.code == .fileWriteNoPermission {
            throw PersistenceError.permissionDenied
        } catch {
            throw PersistenceError.fileSystemError("Could not write bundle: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func loadFromFile(named fileName: String) -> Bool {
        let snapshot = captureTierSnapshot()
        do {
            let bundleURL = try fileURLForExport(named: fileName)
            let project = try loadProjectBundle(from: bundleURL)
            applyImportedProject(
                project,
                action: "Load File",
                fileName: fileName,
                undoSnapshot: snapshot,
            )
            showSuccessToast("File Loaded", message: "Loaded \(fileName).tierproj {file}")
            persistCurrentStateToStore()
            return true
        } catch let error as PersistenceError {
            Logger.persistence.error("File load failed: \(error.localizedDescription)")
            showErrorToast("Load Failed", message: error.localizedDescription)
            return false
        } catch let error as ImportError {
            Logger.persistence.error("File load failed: \(error.localizedDescription)")
            showErrorToast("Load Failed", message: error.localizedDescription)
            return false
        } catch {
            Logger.persistence.error("File load failed: \(error.localizedDescription)")
            showErrorToast("Load Failed", message: "Could not load \(fileName).tierproj {warning}")
            return false
        }
    }

    private func persistCurrentStateToStore() {
        do {
            try persistActiveTierList()
            try modelContext.save()
            persistence.hasUnsavedChanges = false
            persistence.lastSavedTime = Date()
        } catch let error as PersistenceError {
            Logger.persistence.error("Persist after external load failed: \(error.localizedDescription)")
        } catch {
            Logger.persistence.error("Persist after external load failed: \(error.localizedDescription)")
        }
    }

    private func fileURLForExport(named fileName: String) throws -> URL {
        let projects = try projectsDirectory()
        let sanitized = sanitizeFileName(fileName)
        return projects.appendingPathComponent("\(sanitized).tierproj")
    }

    private func finalizeSuccessfulFileSave(named fileName: String) {
        persistence.currentFileName = fileName
        persistence.hasUnsavedChanges = false
        persistence.lastSavedTime = Date()
        showSuccessToast("File Saved", message: "Saved as \(fileName).tierproj {file}")
    }

    func fetchActiveTierListEntity() throws(PersistenceError) -> TierListEntity? {
        if let cached = persistence.activeTierListEntity {
            return cached
        }

        do {
            let descriptor = FetchDescriptor<TierListEntity>(
                predicate: #Predicate { $0.isActive == true },
                sortBy: [SortDescriptor(\TierListEntity.updatedAt, order: .reverse)],
            )

            if let entity = try modelContext.fetch(descriptor).first {
                persistence.activeTierListEntity = entity
                return entity
            }

            let anyDescriptor = FetchDescriptor<TierListEntity>(
                sortBy: [SortDescriptor(\TierListEntity.updatedAt, order: .reverse)],
            )
            let entity = try modelContext.fetch(anyDescriptor).first
            if let entity {
                persistence.activeTierListEntity = entity
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
            fileName: persistence.currentFileName,
            cardDensityRaw: cardDensityPreference.rawValue,
            selectedThemeID: theme.selectedThemeID,
            customThemesData: encodedCustomThemesData(),
            globalSortModeData: encodedGlobalSortMode(),
        )
        modelContext.insert(newEntity)
        persistence.activeTierListEntity = newEntity
        return newEntity
    }

    private func persistActiveTierList() throws(PersistenceError) {
        let entity = try ensureActiveTierListEntity()
        entity.title = activeTierDisplayName
        entity.fileName = persistence.currentFileName
        entity.cardDensityRaw = cardDensityPreference.rawValue
        entity.selectedThemeID = theme.selectedThemeID
        entity.updatedAt = Date()
        entity.customThemesData = encodedCustomThemesData()
        entity.globalSortModeData = encodedGlobalSortMode()

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
                    isLocked: isLocked,
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
                    tier: tierEntity,
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
        restoreGlobalSortMode(from: entity.globalSortModeData)
        restoreCardDensityPreference(rawValue: entity.cardDensityRaw)
        persistence.currentFileName = entity.fileName
        persistence.hasUnsavedChanges = false
        persistence.lastSavedTime = entity.updatedAt
    }

    private func decodeCustomThemes(from data: Data?) -> [CodableTheme] {
        guard let data else {
            return []
        }
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
            videoUrl: entity.videoUrl,
        )
    }

    // MARK: - Theme & preference restoration

    private func restoreTheme(themeID: UUID?) {
        if
            let themeID,
            let foundTheme = theme.theme(with: themeID)
        {
            theme.selectedThemeID = themeID
            theme.selectedTheme = foundTheme
            return
        }

        let fallback = TierThemeCatalog.defaultTheme
        theme.selectedTheme = fallback
        theme.selectedThemeID = fallback.id
    }

    private func restoreCustomThemes(_ codableThemes: [CodableTheme]) {
        let restored = codableThemes.map { $0.toTheme() }
        theme.customThemes = restored.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        theme.customThemeIDs = Set(restored.map(\TierTheme.id))
    }

    func encodedCustomThemesData() -> Data? {
        try? JSONEncoder().encode(theme.customThemes.map(CodableTheme.init))
    }

    func encodedGlobalSortMode() -> Data? {
        try? JSONEncoder().encode(globalSortMode)
    }

    private func restoreGlobalSortMode(from data: Data?) {
        guard let data else {
            // Default to alphabetical A-Z if no saved sort mode
            globalSortMode = .alphabetical(ascending: true)
            return
        }

        if let decoded = try? JSONDecoder().decode(GlobalSortMode.self, from: data) {
            globalSortMode = decoded
        } else {
            // Fallback to alphabetical A-Z if decoding fails
            globalSortMode = .alphabetical(ascending: true)
        }
    }
}
