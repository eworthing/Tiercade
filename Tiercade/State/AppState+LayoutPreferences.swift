import Foundation
import SwiftUI

@MainActor
internal extension AppState {
    internal func setCardDensityPreference(_ preference: CardDensityPreference, quietly: Bool = false) {
        guard cardDensityPreference != preference else { return }
        let snapshot = captureTierSnapshot()
        cardDensityPreference = preference
        finalizeChange(action: "Card Density", undoSnapshot: snapshot)
        if quietly { return }
        logEvent("cardDensityPreference updated to \(preference.rawValue)")
        showInfoToast("Card Size Updated", message: preference.detailDescription)
        announce(preference.toastMessage)
    }

    internal func cycleCardDensityPreference() {
        let nextPreference = cardDensityPreference.next()
        setCardDensityPreference(nextPreference)
    }

    internal func restoreCardDensityPreference(rawValue: String?) {
        guard
            let rawValue,
            let preference = CardDensityPreference(rawValue: rawValue)
        else {
            cardDensityPreference = .compact
            return
        }
        cardDensityPreference = preference
    }
}
