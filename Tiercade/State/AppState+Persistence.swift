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
        let sanitizedName = sanitizeFileName(fileName)
        do {
            let artifacts = try buildProjectExportArtifacts(
                group: "All",
                themeName: selectedTheme.displayName
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
                undoSnapshot: snapshot
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
            hasUnsavedChanges = false
            lastSavedTime = Date()
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
        currentFileName = fileName
        hasUnsavedChanges = false
        lastSavedTime = Date()
        showSuccessToast("File Saved", message: "Saved as \(fileName).tierproj {file}")
    }

    func getAvailableSaveFiles() -> [String] {
        do {
            let projects = try projectsDirectory()
            let fileURLs = try FileManager.default.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil)
            return fileURLs
                .filter { $0.pathExtension == "tierproj" }
                .map { $0.deletingPathExtension().lastPathComponent }
                .sorted()
        } catch {
            Logger.persistence.error("Could not list save files: \(error.localizedDescription)")
            return []
        }
    }

    private func writeProjectBundle(_ artifacts: ProjectExportArtifacts, to destination: URL) throws(PersistenceError) {
        let fileManager = FileManager.default

        do {
            try ensureDirectoryExists(at: destination.deletingLastPathComponent())
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }

            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

            let projectURL = destination.appendingPathComponent("project.json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(artifacts.project)
            try data.write(to: projectURL, options: .atomic)

            for exportFile in artifacts.files {
                let destinationURL = destination.appendingPathComponent(exportFile.relativePath)
                try fileManager.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if fileManager.fileExists(atPath: destinationURL.path) {
                    continue
                }
                guard fileManager.fileExists(atPath: exportFile.sourceURL.path) else {
                    throw PersistenceError.fileSystemError("Missing media asset at \(exportFile.sourceURL.path)")
                }
                try fileManager.copyItem(at: exportFile.sourceURL, to: destinationURL)
            }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.fileSystemError("Failed to assemble bundle: \(error.localizedDescription)")
        }
    }

    private func loadProjectBundle(from url: URL) throws -> Project {
        let fileManager = FileManager.default

        do {
            guard fileManager.fileExists(atPath: url.path) else {
                throw PersistenceError.fileSystemError("Bundle not found at \(url.path)")
            }

            let projectURL = url.appendingPathComponent("project.json")
            guard fileManager.fileExists(atPath: projectURL.path) else {
                throw PersistenceError.fileSystemError("Missing project.json in \(url.path)")
            }

            let data = try Data(contentsOf: projectURL)
            let project = try ModelResolver.decodeProject(from: data)
            return try relocateProject(project, extractedAt: url)
        } catch let error as PersistenceError {
            throw error
        } catch let error as ImportError {
            throw error
        } catch let error as DecodingError {
            throw ImportError.parsingFailed(error.localizedDescription)
        } catch let error as NSError where error.domain == "Tiercade" {
            throw ImportError.invalidData(error.localizedDescription)
        } catch {
            throw PersistenceError.fileSystemError("Failed to read bundle: \(error.localizedDescription)")
        }
    }

    private func relocateProject(_ project: Project, extractedAt tempDirectory: URL) throws -> Project {
        var updatedItems: [String: Project.Item] = [:]
        for (id, item) in project.items {
            var newItem = item
            if let result = try relocateMediaList(item.media, extractedAt: tempDirectory) {
                newItem.media = result.list
                if var attributes = item.attributes {
                    if let thumb = result.primaryThumb {
                        attributes["thumbUri"] = .string(thumb)
                    }
                    newItem.attributes = attributes
                }
            }
            updatedItems[id] = newItem
        }

        var updatedOverrides = project.overrides
        if let overrides = project.overrides {
            var mapped: [String: Project.ItemOverride] = [:]
            for (id, override) in overrides {
                var newOverride = override
                if let result = try relocateMediaList(override.media, extractedAt: tempDirectory) {
                    newOverride.media = result.list
                }
                mapped[id] = newOverride
            }
            updatedOverrides = mapped
        }

        var output = project
        output.items = updatedItems
        output.overrides = updatedOverrides
        return output
    }

    private struct MediaRelocationResult {
        let list: [Project.Media]
        let primaryThumb: String?
    }

    private func relocateMediaList(
        _ mediaList: [Project.Media]?,
        extractedAt tempDirectory: URL
    ) throws -> MediaRelocationResult? {
        guard let mediaList else { return nil }
        var relocated: [Project.Media] = []
        var firstThumb: String?

        for media in mediaList {
            let updated = try relocateMedia(media, extractedAt: tempDirectory)
            if firstThumb == nil, let thumb = updated.thumbUri {
                firstThumb = thumb
            }
            relocated.append(updated)
        }

        return MediaRelocationResult(list: relocated, primaryThumb: firstThumb)
    }

    private func relocateMedia(_ media: Project.Media, extractedAt tempDirectory: URL) throws -> Project.Media {
        var updated = media

        let uri = media.uri
        if let destination = try relocateFile(fromBundleURI: uri, extractedAt: tempDirectory) {
            updated.uri = destination.absoluteString
        }

        if let thumb = media.thumbUri,
           let destination = try relocateFile(fromBundleURI: thumb, extractedAt: tempDirectory) {
            updated.thumbUri = destination.absoluteString
        }

        return updated
    }

    private func relocateFile(fromBundleURI uri: String, extractedAt tempDirectory: URL) throws -> URL? {
        guard let relativePath = bundleRelativePath(from: uri) else { return nil }

        let fileManager = FileManager.default
        let sourceURL = tempDirectory.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw PersistenceError.fileSystemError("Missing asset inside bundle at \(relativePath)")
        }

        let destinationBase: URL
        if relativePath.hasPrefix("Media/") {
            destinationBase = try mediaStoreDirectory()
        } else if relativePath.hasPrefix("Thumbs/") {
            destinationBase = try thumbsStoreDirectory()
        } else {
            destinationBase = try mediaStoreDirectory()
        }

        let fileName = (relativePath as NSString).lastPathComponent
        let destinationURL = destinationBase.appendingPathComponent(fileName)
        try copyReplacingItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func projectsDirectory() throws -> URL {
        let root = try applicationSupportRoot()
        let directory = root.appendingPathComponent("Projects", isDirectory: true)
        try ensureDirectoryExists(at: directory)
        return directory
    }

    private func mediaStoreDirectory() throws -> URL {
        let root = try applicationSupportRoot()
        let directory = root.appendingPathComponent("Media", isDirectory: true)
        try ensureDirectoryExists(at: directory)
        return directory
    }

    private func thumbsStoreDirectory() throws -> URL {
        let root = try applicationSupportRoot()
        let directory = root.appendingPathComponent("Thumbs", isDirectory: true)
        try ensureDirectoryExists(at: directory)
        return directory
    }

    private func applicationSupportRoot() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let root = base.appendingPathComponent("Tiercade", isDirectory: true)
        try ensureDirectoryExists(at: root)
        return root
    }

    private func ensureDirectoryExists(at url: URL) throws {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if exists {
            if !isDirectory.boolValue {
                throw PersistenceError.fileSystemError("Expected directory at \(url.path) but found a file.")
            }
            return
        }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw PersistenceError.fileSystemError("Could not create directory at \(url.path): \(error.localizedDescription)")
        }
    }

    private func copyReplacingItem(at source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        try ensureDirectoryExists(at: destination.deletingLastPathComponent())
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            throw PersistenceError.fileSystemError("Failed to copy asset to \(destination.path): \(error.localizedDescription)")
        }
    }

    private func bundleRelativePath(from uri: String) -> String? {
        guard uri.hasPrefix("file://") else { return nil }
        let trimmed = String(uri.dropFirst("file://".count))
        if trimmed.hasPrefix("/") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private func sanitizeFileName(_ fileName: String) -> String {
        let sanitized = fileName
            .replacingOccurrences(of: "[^A-Za-z0-9-_]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return sanitized.isEmpty ? "tiercade-project" : sanitized
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

    func encodedCustomThemesData() -> Data? {
        try? JSONEncoder().encode(customThemes.map(CodableTheme.init))
    }
}
