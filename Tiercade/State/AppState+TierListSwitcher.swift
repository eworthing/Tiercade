import Foundation
import SwiftUI
import SwiftData
import os
import TiercadeCore

// MARK: - Tier List Source & Handle Types

internal enum TierListSource: String, Codable, Sendable {
    internal case bundled
    internal case file
    internal case authored
}

internal struct TierListHandle: Identifiable, Codable, Hashable, Sendable {
    internal var source: TierListSource
    internal var identifier: String
    internal var displayName: String
    internal var subtitle: String?
    internal var iconSystemName: String?
    internal var entityID: UUID?

    internal var id: String {
        if let entityID {
            return "\(source.rawValue)::\(identifier)::\(entityID.uuidString)"
        }
        return "\(source.rawValue)::\(identifier)"
    }
}

// MARK: - AppState Tier List Switcher Extension

@MainActor
internal extension AppState {

    internal var activeTierDisplayName: String {
        persistence.activeTierList?.displayName ?? "Untitled Tier List"
    }

    internal var quickPickTierLists: [TierListHandle] {
        internal var picks: [TierListHandle] = []
        if let activeTierList = persistence.activeTierList {
            picks.append(activeTierList)
        }

        internal let recent = persistence.recentTierLists.filter { $0 != persistence.activeTierList }
        picks.append(contentsOf: recent.prefix(max(0, persistence.quickPickMenuLimit - picks.count)))

        if picks.count < persistence.quickPickMenuLimit {
            internal let additionalBundled = bundledProjects
                .map(TierListHandle.init(bundled:))
                .filter { !picks.contains($0) }
                .prefix(max(0, persistence.quickPickMenuLimit - picks.count))
            picks.append(contentsOf: additionalBundled)
        }

        if picks.isEmpty, let defaultBundled = bundledProjects.first.map(TierListHandle.init(bundled:)) {
            picks.append(defaultBundled)
        }

        return picks
    }

    /// Deduped quick pick list - fixes duplicate entries from different sources
    /// by comparing source+identifier only (ignoring entityID differences)
    internal var quickPickTierListsDeduped: [TierListHandle] {
        internal var seen = Set<String>()
        internal var result: [TierListHandle] = []
        for handle in quickPickTierLists {
            internal let key = "\(handle.source.rawValue)::\(handle.identifier)"
            if seen.insert(key).inserted {
                result.append(handle)
            }
        }
        return result
    }

    internal func selectTierList(_ handle: TierListHandle) async {
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
        case .authored:
            await withLoadingIndicator(message: "Loading \(handle.displayName)...") {
                if let entity = try? ensureEntity(for: handle) {
                    applyPersistedTierList(entity)
                    registerTierListSelection(handle)
                }
            }
        }
    }

    internal func registerTierListSelection(_ handle: TierListHandle) {
        persistence.activeTierList = handle
        do {
            try deactivateOtherLists(except: handle.entityID)
            internal let entity = try ensureEntity(for: handle)
            entity.isActive = true
            entity.lastOpenedAt = Date()
            entity.title = handle.displayName
            entity.subtitle = handle.subtitle
            entity.iconSystemName = handle.iconSystemName
            entity.externalIdentifier = handle.identifier
            entity.sourceRaw = handle.source.rawValue
            persistence.activeTierList = TierListHandle(entity: entity)
            persistence.activeTierListEntity = entity
            try modelContext.save()
        } catch {
            Logger.persistence.error("registerTierListSelection failed: \(error.localizedDescription)")
        }
        refreshRecentTierListsFromStore()
    }

    internal func presentTierListBrowser() {
        logEvent("presentTierListBrowser called")
        overlays.showTierListBrowser = true
        logEvent("overlays.showTierListBrowser set to \(overlays.showTierListBrowser)")
    }

    internal func dismissTierListBrowser() {
        logEvent("dismissTierListBrowser called")
        overlays.showTierListBrowser = false
    }

    internal func tierListHandle(forFileNamed fileName: String) -> TierListHandle {
        TierListHandle(
            source: .file,
            identifier: fileName,
            displayName: fileName,
            subtitle: "Saved Locally",
            iconSystemName: "externaldrive",
            entityID: nil
        )
    }

    internal func restoreTierListState() {
        do {
            if let entity = try fetchActiveTierListEntity() {
                persistence.activeTierListEntity = entity
                persistence.activeTierList = TierListHandle(entity: entity)
            }
            refreshRecentTierListsFromStore()
        } catch {
            Logger.persistence.error("restoreTierListState failed: \(error.localizedDescription)")
        }
    }

    internal func loadActiveTierListIfNeeded() {
        guard let handle = persistence.activeTierList else { return }

        switch handle.source {
        case .bundled:
            guard let project = bundledProjects.first(where: { $0.id == handle.identifier }) else { return }
            applyBundledProject(project)
            logEvent("loadActiveTierListIfNeeded: loaded bundled project \(project.id)")
        case .file:
            _ = loadFromFile(named: handle.identifier)
            logEvent("loadActiveTierListIfNeeded: loaded file \(handle.identifier)")
        case .authored:
            if let entity = try? ensureEntity(for: handle) {
                applyPersistedTierList(entity)
                logEvent("loadActiveTierListIfNeeded: loaded authored project \(handle.identifier)")
            }
        }
    }

    private func refreshRecentTierListsFromStore() {
        do {
            internal let descriptor = FetchDescriptor<TierListEntity>(
                sortBy: [SortDescriptor(\TierListEntity.lastOpenedAt, order: .reverse)]
            )
            internal let entities = try modelContext.fetch(descriptor)
            persistence.recentTierLists = entities
                .filter { !$0.isDeleted }
                .prefix(persistence.maxRecentTierLists)
                .map(TierListHandle.init)
        } catch {
            Logger.persistence.error("refreshRecentTierListsFromStore failed: \(error.localizedDescription)")
        }
    }

    private func deactivateOtherLists(except activeID: UUID?) throws {
        internal let descriptor = FetchDescriptor<TierListEntity>(
            predicate: #Predicate { $0.isActive == true }
        )
        internal let activeLists = try modelContext.fetch(descriptor)
        for entity in activeLists where entity.identifier != activeID {
            entity.isActive = false
        }
    }

    private func ensureEntity(for handle: TierListHandle) throws -> TierListEntity {
        if let entity = try fetchEntity(for: handle) {
            return entity
        }

        internal let newEntity = TierListEntity(
            title: handle.displayName,
            fileName: handle.source == .file ? handle.identifier : nil,
            isActive: true,
            cardDensityRaw: cardDensityPreference.rawValue,
            selectedThemeID: theme.selectedThemeID,
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
            internal let descriptor = FetchDescriptor<TierListEntity>(
                predicate: #Predicate { $0.identifier == entityID }
            )
            if let entity = try modelContext.fetch(descriptor).first {
                return entity
            }
        }
        internal let sourceRaw = handle.source.rawValue
        internal let descriptor = FetchDescriptor<TierListEntity>(
            predicate: #Predicate { $0.sourceRaw == sourceRaw }
        )
        internal let candidates = try modelContext.fetch(descriptor)
        return candidates.first { $0.externalIdentifier == handle.identifier }
    }
}

internal extension TierListHandle {
    internal init(bundled project: BundledProject) {
        self.init(
            source: .bundled,
            identifier: project.id,
            displayName: project.title,
            subtitle: project.subtitle,
            iconSystemName: "square.grid.2x2",
            entityID: nil
        )
    }

    internal init(entity: TierListEntity) {
        self.init(
            source: TierListSource(rawValue: entity.sourceRaw) ?? .bundled,
            identifier: entity.externalIdentifier ?? entity.identifier.uuidString,
            displayName: entity.title,
            subtitle: entity.subtitle,
            iconSystemName: entity.iconSystemName,
            entityID: entity.identifier
        )
    }
}
