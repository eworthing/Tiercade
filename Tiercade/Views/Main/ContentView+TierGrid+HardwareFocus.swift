import SwiftUI
import Foundation
import TiercadeCore

#if !os(tvOS)
internal extension TierGridView {
    internal struct TierSnapshot {
        internal let tier: String
        internal let items: [Item]
        internal let layout: PlatformCardLayout
    }

    internal var navigationTierSequence: [String] {
        internal var sequence = tierOrder
        sequence.append("unranked")
        return sequence
    }

    internal func seedHardwareFocus() {
        internal let snapshot = currentSnapshot()
        guard !snapshot.isEmpty else {
            hardwareFocus = nil
            lastHardwareFocus = nil
            return
        }
        if let existing = hardwareFocus,
           snapshot.contains(where: {
            $0.tier == existing.tier && $0.items.contains(where: { $0.id == existing.itemID })
           }) {
            lastHardwareFocus = existing
            return
        }
        if let fallback = defaultHardwareFocus(for: snapshot) {
            hardwareFocus = fallback
            lastHardwareFocus = fallback
        }
    }

    internal func ensureHardwareFocusValid() {
        internal let snapshot = currentSnapshot()
        guard !snapshot.isEmpty else {
            hardwareFocus = nil
            lastHardwareFocus = nil
            return
        }
        if let focus = hardwareFocus,
           snapshot.contains(where: { $0.tier == focus.tier && $0.items.contains(where: { $0.id == focus.itemID }) }) {
            lastHardwareFocus = focus
            return
        }
        if let fallback = defaultHardwareFocus(for: snapshot) {
            hardwareFocus = fallback
            lastHardwareFocus = fallback
        }
    }

    internal func handleDirectionalInput(_ move: DirectionalMove) {
        gridHasFocus = true
        internal let snapshot = currentSnapshot()
        guard !snapshot.isEmpty else {
            hardwareFocus = nil
            lastHardwareFocus = nil
            return
        }

        internal let activeFocus = hardwareFocus ?? defaultHardwareFocus(for: snapshot)
        guard let focus = activeFocus else { return }

        guard let next = focusAfter(focus, move: move, snapshot: snapshot) else { return }
        hardwareFocus = next
        lastHardwareFocus = next
    }

    internal func currentSnapshot() -> [TierSnapshot] {
        navigationTierSequence.compactMap { tier in
            internal let items = app.filteredItems(for: tier)
            guard !items.isEmpty else { return nil }
            internal let layout = PlatformCardLayoutProvider.layout(
                for: items.count,
                preference: app.cardDensityPreference,
                horizontalSizeClass: horizontalSizeClass
            )
            return TierSnapshot(tier: tier, items: items, layout: layout)
        }
    }

    internal func defaultHardwareFocus(for snapshot: [TierSnapshot]) -> CardFocus? {
        if let cached = lastHardwareFocus,
           snapshot.contains(where: {
            $0.tier == cached.tier && $0.items.contains(where: { $0.id == cached.itemID })
           }) {
            return cached
        }
        guard let firstTier = snapshot.first, let firstItem = firstTier.items.first else { return nil }
        return CardFocus(tier: firstTier.tier, itemID: firstItem.id)
    }

    internal func focusAfter(
        _ current: CardFocus,
        move: DirectionalMove,
        snapshot: [TierSnapshot]
    ) -> CardFocus? {
        guard let tierIndex = snapshot.firstIndex(where: { $0.tier == current.tier }) else {
            return defaultHardwareFocus(for: snapshot)
        }
        internal let tierData = snapshot[tierIndex]
        guard let currentIndex = tierData.items.firstIndex(where: { $0.id == current.itemID }) else {
            return defaultHardwareFocus(for: snapshot)
        }

        switch move {
        case .left:
            return focusLeft(
                from: currentIndex,
                tier: current.tier,
                tierIndex: tierIndex,
                tierData: tierData,
                snapshot: snapshot
            )
        case .right:
            return focusRight(
                from: currentIndex,
                tier: current.tier,
                tierIndex: tierIndex,
                tierData: tierData,
                snapshot: snapshot
            )
        case .up:
            return focusUp(
                from: currentIndex,
                tierIndex: tierIndex,
                tierData: tierData,
                snapshot: snapshot
            )
        case .down:
            return focusDown(
                from: currentIndex,
                tierIndex: tierIndex,
                tierData: tierData,
                snapshot: snapshot
            )
        @unknown default:
            return current
        }
    }

    private func focusLeft(
        from currentIndex: Int,
        tier: String,
        tierIndex: Int,
        tierData: TierSnapshot,
        snapshot: [TierSnapshot]
    ) -> CardFocus {
        if currentIndex > 0 {
            return CardFocus(tier: tier, itemID: tierData.items[currentIndex - 1].id)
        } else if tierIndex > 0 {
            internal let previous = snapshot[tierIndex - 1]
            guard let target = previous.items.last else {
                return CardFocus(tier: tier, itemID: tierData.items[currentIndex].id)
            }
            return CardFocus(tier: previous.tier, itemID: target.id)
        }
        return CardFocus(tier: tier, itemID: tierData.items[currentIndex].id)
    }

    private func focusRight(
        from currentIndex: Int,
        tier: String,
        tierIndex: Int,
        tierData: TierSnapshot,
        snapshot: [TierSnapshot]
    ) -> CardFocus {
        if currentIndex + 1 < tierData.items.count {
            return CardFocus(tier: tier, itemID: tierData.items[currentIndex + 1].id)
        } else if tierIndex + 1 < snapshot.count {
            internal let next = snapshot[tierIndex + 1]
            guard let target = next.items.first else {
                return CardFocus(tier: tier, itemID: tierData.items[currentIndex].id)
            }
            return CardFocus(tier: next.tier, itemID: target.id)
        }
        return CardFocus(tier: tier, itemID: tierData.items[currentIndex].id)
    }

    private func focusUp(
        from currentIndex: Int,
        tierIndex: Int,
        tierData: TierSnapshot,
        snapshot: [TierSnapshot]
    ) -> CardFocus {
        internal let columns = max(1, tierData.layout.gridColumns.count)
        internal let targetIndex = currentIndex - columns

        if targetIndex >= 0 {
            return CardFocus(tier: tierData.tier, itemID: tierData.items[targetIndex].id)
        } else if tierIndex > 0 {
            internal let previous = snapshot[tierIndex - 1]
            internal let prevColumns = max(1, previous.layout.gridColumns.count)
            internal let targetColumn = min(currentIndex % columns, prevColumns - 1)
            internal let lastRowStart = max(previous.items.count - prevColumns, 0)
            internal let index = min(previous.items.count - 1, lastRowStart + targetColumn)
            return CardFocus(tier: previous.tier, itemID: previous.items[index].id)
        }
        return CardFocus(tier: tierData.tier, itemID: tierData.items[currentIndex].id)
    }

    private func focusDown(
        from currentIndex: Int,
        tierIndex: Int,
        tierData: TierSnapshot,
        snapshot: [TierSnapshot]
    ) -> CardFocus {
        internal let columns = max(1, tierData.layout.gridColumns.count)
        internal let targetIndex = currentIndex + columns

        if targetIndex < tierData.items.count {
            return CardFocus(tier: tierData.tier, itemID: tierData.items[targetIndex].id)
        } else if tierIndex + 1 < snapshot.count {
            internal let next = snapshot[tierIndex + 1]
            internal let nextColumns = max(1, next.layout.gridColumns.count)
            internal let targetColumn = min(currentIndex % columns, nextColumns - 1)
            internal let index = min(next.items.count - 1, targetColumn)
            return CardFocus(tier: next.tier, itemID: next.items[index].id)
        }
        return CardFocus(tier: tierData.tier, itemID: tierData.items[currentIndex].id)
    }

    internal func item(for focus: CardFocus, in snapshot: [TierSnapshot]) -> Item? {
        guard let tierData = snapshot.first(where: { $0.tier == focus.tier }) else { return nil }
        return tierData.items.first(where: { $0.id == focus.itemID })
    }
}
#endif
