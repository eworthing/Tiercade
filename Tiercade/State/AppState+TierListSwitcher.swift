import Foundation
import SwiftUI
import SwiftData
import os
import TiercadeCore

@MainActor
extension AppState {
    enum TierListSource: String, Codable, Sendable {
        case bundled
        case file
    }

    struct TierListHandle: Identifiable, Codable, Hashable, Sendable {
        var source: TierListSource
        var identifier: String
        var displayName: String
        var subtitle: String?
        var iconSystemName: String?
        var entityID: UUID?

        var id: String {
            if let entityID {
                return "\(source.rawValue)::\(identifier)::\(entityID.uuidString)"
            }
            return "\(source.rawValue)::\(identifier)"
        }
    }

    var activeTierDisplayName: String {
        activeTierList?.displayName ?? "Untitled Tier List"
    }

    var quickPickTierLists: [TierListHandle] {
        var picks: [TierListHandle] = []
        if let activeTierList {
            picks.append(activeTierList)
        }

        let recent = recentTierLists.filter { $0 != activeTierList }
        picks.append(contentsOf: recent.prefix(max(0, quickPickMenuLimit - picks.count)))

        if picks.count < quickPickMenuLimit {
            let additionalBundled = bundledProjects
                .map(TierListHandle.init(bundled:))
                .filter { !picks.contains($0) }
                .prefix(max(0, quickPickMenuLimit - picks.count))
            picks.append(contentsOf: additionalBundled)
        }

        if picks.isEmpty, let defaultBundled = bundledProjects.first.map(TierListHandle.init(bundled:)) {
            picks.append(defaultBundled)
        }

        return picks
    }

    func selectTierList(_ handle: TierListHandle) async {
        switch handle.source {
        case .bundled:
            guard let project = bundledProjects.first(where: { $0.id == handle.identifier }) else { return }
            await withLoadingIndicator(message: "Loading \(project.title)...") {
                if let entity = (try? fetchEntity(for: handle)) ?? nil {
                    applyPersistedTierList(entity)
                } else {
                    applyBundledProject(project)
                }
                registerTierListSelection(handle)
            }
        case .file:
            await withLoadingIndicator(message: "Loading \(handle.displayName)...") {
                if loadFromFile(named: handle.identifier) {
                    registerTierListSelection(handle)
                }
            }
        }
    }

    func registerTierListSelection(_ handle: TierListHandle) {
        activeTierList = handle
        do {
            try deactivateOtherLists(except: handle.entityID)
            let entity = try ensureEntity(for: handle)
            entity.isActive = true
            entity.lastOpenedAt = Date()
            entity.title = handle.displayName
            entity.subtitle = handle.subtitle
            entity.iconSystemName = handle.iconSystemName
            entity.externalIdentifier = handle.identifier
            entity.sourceRaw = handle.source.rawValue
            activeTierList = TierListHandle(entity: entity)
            activeTierListEntity = entity
            try modelContext.save()
        } catch {
            Logger.persistence.error("registerTierListSelection failed: \(error.localizedDescription)")
        }
        refreshRecentTierListsFromStore()
    }

    func presentTierListBrowser() {
        logEvent("presentTierListBrowser called")
        showingTierListBrowser = true
        logEvent("showingTierListBrowser set to \(showingTierListBrowser)")
    }

    func dismissTierListBrowser() {
        logEvent("dismissTierListBrowser called")
        showingTierListBrowser = false
    }

    func tierListHandle(forFileNamed fileName: String) -> TierListHandle {
        TierListHandle(
            source: .file,
            identifier: fileName,
            displayName: fileName,
            subtitle: "Saved Locally",
            iconSystemName: "externaldrive",
            entityID: nil
        )
    }

    func restoreTierListState() {
        do {
            if let entity = try fetchActiveTierListEntity() {
                activeTierListEntity = entity
                activeTierList = TierListHandle(entity: entity)
            }
            refreshRecentTierListsFromStore()
        } catch {
            Logger.persistence.error("restoreTierListState failed: \(error.localizedDescription)")
        }
    }

    func loadActiveTierListIfNeeded() {
        guard let handle = activeTierList else { return }

        switch handle.source {
        case .bundled:
            guard let project = bundledProjects.first(where: { $0.id == handle.identifier }) else { return }
            applyBundledProject(project)
            logEvent("loadActiveTierListIfNeeded: loaded bundled project \(project.id)")
        case .file:
            _ = loadFromFile(named: handle.identifier)
            logEvent("loadActiveTierListIfNeeded: loaded file \(handle.identifier)")
        }
    }

    private func refreshRecentTierListsFromStore() {
        do {
            let descriptor = FetchDescriptor<TierListEntity>(
                sortBy: [SortDescriptor(\TierListEntity.lastOpenedAt, order: .reverse)]
            )
            let entities = try modelContext.fetch(descriptor)
            recentTierLists = entities
                .filter { !$0.isDeleted }
                .prefix(maxRecentTierLists)
                .map(TierListHandle.init)
        } catch {
            Logger.persistence.error("refreshRecentTierListsFromStore failed: \(error.localizedDescription)")
        }
    }

    private func deactivateOtherLists(except activeID: UUID?) throws {
        let descriptor = FetchDescriptor<TierListEntity>(
            predicate: #Predicate { $0.isActive == true }
        )
        let activeLists = try modelContext.fetch(descriptor)
        for entity in activeLists where entity.identifier != activeID {
            entity.isActive = false
        }
    }

    private func ensureEntity(for handle: TierListHandle) throws -> TierListEntity {
        if let entity = try fetchEntity(for: handle) {
            return entity
        }

        let newEntity = TierListEntity(
            title: handle.displayName,
            fileName: handle.source == .file ? handle.identifier : nil,
            isActive: true,
            cardDensityRaw: cardDensityPreference.rawValue,
            selectedThemeID: selectedThemeID,
            customThemesData: encodedCustomThemesData(),
            sourceRaw: handle.source.rawValue,
            externalIdentifier: handle.identifier,
            subtitle: handle.subtitle,
            iconSystemName: handle.iconSystemName,
            lastOpenedAt: Date()
        )
        modelContext.insert(newEntity)
        return newEntity
    }

    private func fetchEntity(for handle: TierListHandle) throws -> TierListEntity? {
        if let entityID = handle.entityID {
            let descriptor = FetchDescriptor<TierListEntity>(
                predicate: #Predicate { $0.identifier == entityID }
            )
            if let entity = try modelContext.fetch(descriptor).first {
                return entity
            }
        }
        let sourceRaw = handle.source.rawValue
        let descriptor = FetchDescriptor<TierListEntity>(
            predicate: #Predicate { $0.sourceRaw == sourceRaw }
        )
        let candidates = try modelContext.fetch(descriptor)
        return candidates.first { $0.externalIdentifier == handle.identifier }
    }
}

extension AppState.TierListHandle {
    init(bundled project: BundledProject) {
        self.init(
            source: .bundled,
            identifier: project.id,
            displayName: project.title,
            subtitle: project.subtitle,
            iconSystemName: "square.grid.2x2",
            entityID: nil
        )
    }

    init(entity: TierListEntity) {
        self.init(
            source: AppState.TierListSource(rawValue: entity.sourceRaw) ?? .bundled,
            identifier: entity.externalIdentifier ?? entity.identifier.uuidString,
            displayName: entity.title,
            subtitle: entity.subtitle,
            iconSystemName: entity.iconSystemName,
            entityID: entity.identifier
        )
    }
}
