import Foundation
import SwiftUI
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

        var id: String {
            "\(source.rawValue)::\(identifier)"
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
                applyBundledProject(project)
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
        var updated = recentTierLists.filter { $0 != handle }
        updated.insert(handle, at: 0)
        recentTierLists = Array(updated.prefix(maxRecentTierLists))
        persistTierListState()
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
            iconSystemName: "externaldrive"
        )
    }

    func restoreTierListState() {
        let defaults = UserDefaults.standard

        if let activeData = defaults.data(forKey: tierListStateKey) {
            if let handle = try? JSONDecoder().decode(TierListHandle.self, from: activeData) {
                activeTierList = handle
            }
        }

        if let recentsData = defaults.data(forKey: tierListRecentsKey) {
            if let handles = try? JSONDecoder().decode([TierListHandle].self, from: recentsData) {
                recentTierLists = handles
            }
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

    private func persistTierListState() {
        let defaults = UserDefaults.standard
        if let activeTierList {
            let data = try? JSONEncoder().encode(activeTierList)
            defaults.set(data, forKey: tierListStateKey)
        } else {
            defaults.removeObject(forKey: tierListStateKey)
        }

        let recentsData = try? JSONEncoder().encode(recentTierLists)
        defaults.set(recentsData, forKey: tierListRecentsKey)
    }
}

extension AppState.TierListHandle {
    init(bundled project: BundledProject) {
        self.init(
            source: .bundled,
            identifier: project.id,
            displayName: project.title,
            subtitle: project.subtitle,
            iconSystemName: "square.grid.2x2"
        )
    }
}
