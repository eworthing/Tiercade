import SwiftUI

// MARK: - Focus Routing for ThemeCreatorOverlay

extension ThemeCreatorOverlay {
    #if os(tvOS)
    func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard let move = DirectionalMove(moveCommand: direction) else {
            return
        }
        handleDirectionalMove(move)
    }
    #endif

    func handleDirectionalMove(_ move: DirectionalMove) {
        #if !os(tvOS)
        setOverlayHasFocus(true)
        #endif
        guard let focus = currentFocusedElement else {
            return
        }
        switch focus {
        case .name:
            handleNameMove(move)
        case .description:
            handleDescriptionMove(move)
        case let .tier(id):
            handleTierMove(move, tierID: id)
        case let .palette(index):
            handlePaletteMove(move, index: index)
        case .advancedPicker:
            handleAdvancedPickerMove(move)
        case .save:
            handleSaveMove(move)
        case .cancel:
            handleCancelMove(move)
        }
    }

    func handlePrimaryAction() {
        guard let focus = currentFocusedElement else {
            return
        }
        switch focus {
        case .description,
             .name:
            // Let system handle text field activation
            break
        case let .tier(id):
            setActiveTier(id)
        case let .palette(index):
            updatePaletteFocusIndex(index)
            if index < Self.paletteHexes.count {
                let hex = Self.paletteHexes[index]
                appState.assignColorToActiveTier(hex)
            }
            setFocusField(.palette(index))
        case .advancedPicker:
            presentAdvancedPicker()
        case .save:
            appState.completeThemeCreation()
        case .cancel:
            dismiss(returnToPicker: true)
        }
    }

    func handleNameMove(_ move: DirectionalMove) {
        switch move {
        case .down:
            setFocusField(.description)
        case .right:
            setFocusField(.tier(draft.activeTierID))
        default:
            setFocusField(.name)
        }
    }

    func handleDescriptionMove(_ move: DirectionalMove) {
        switch move {
        case .up:
            setFocusField(.name)
        case .down,
             .right:
            setFocusField(.tier(draft.activeTierID))
        default:
            setFocusField(.description)
        }
    }

    func handleTierMove(_ move: DirectionalMove, tierID: UUID) {
        guard let currentIndex = tierIndex(for: tierID) else {
            return
        }
        switch move {
        case .up:
            if currentIndex == 0 {
                setFocusField(.description)
            } else {
                focusTier(at: currentIndex - 1)
            }
        case .down:
            if currentIndex >= draft.tiers.count - 1 {
                setFocusField(.save)
            } else {
                focusTier(at: currentIndex + 1)
            }
        case .right:
            let paletteIdx = paletteIndex(for: draft.tiers[currentIndex].colorHex)
            updatePaletteFocusIndex(paletteIdx)
            setFocusField(.palette(paletteIdx))
        case .left:
            setFocusField(.cancel)
        }
    }

    func handlePaletteMove(_ move: DirectionalMove, index: Int) {
        switch move {
        case .left:
            setFocusField(.tier(draft.activeTierID))
        case .up:
            if index < paletteColumns {
                setFocusField(.advancedPicker)
            } else {
                let target = max(index - paletteColumns, 0)
                updatePaletteFocusIndex(target)
                setFocusField(.palette(target))
            }
        case .down:
            let target = index + paletteColumns
            if target < Self.paletteHexes.count {
                updatePaletteFocusIndex(target)
                setFocusField(.palette(target))
            } else {
                setFocusField(.save)
            }
        case .right:
            let target = min(index + 1, Self.paletteHexes.count - 1)
            updatePaletteFocusIndex(target)
            setFocusField(.palette(target))
        }
    }

    func handleAdvancedPickerMove(_ move: DirectionalMove) {
        switch move {
        case .down:
            setFocusField(.palette(currentPaletteFocusIndex))
        case .left:
            setFocusField(.tier(draft.activeTierID))
        default:
            setFocusField(.advancedPicker)
        }
    }

    func handleSaveMove(_ move: DirectionalMove) {
        switch move {
        case .up:
            setFocusField(.palette(currentPaletteFocusIndex))
        case .left:
            setFocusField(.cancel)
        default:
            setFocusField(.save)
        }
    }

    func handleCancelMove(_ move: DirectionalMove) {
        switch move {
        case .up:
            setFocusField(.tier(draft.activeTierID))
        case .down,
             .right:
            setFocusField(.save)
        case .left:
            setFocusField(.name)
        }
    }

    func focusTier(at index: Int) {
        let tier = draft.tiers[index]
        let paletteIdx = paletteIndex(for: tier.colorHex)
        updatePaletteFocusIndex(paletteIdx)
        setActiveTier(tier.id)
    }

    func tierIndex(for id: UUID) -> Int? {
        draft.tiers.firstIndex { $0.id == id }
    }

    func paletteIndex(for hex: String?) -> Int {
        guard let hex else {
            return 0
        }
        let normalized = ThemeDraft.normalizeHex(hex)
        return Self.paletteHexes.firstIndex { ThemeDraft.normalizeHex($0) == normalized } ?? 0
    }
}
