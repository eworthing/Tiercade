import Foundation
import SwiftUI

@MainActor
extension AppState {
    func setCardDensityPreference(_ preference: CardDensityPreference, quietly: Bool = false) {
        guard cardDensityPreference != preference else { return }
        cardDensityPreference = preference
        if quietly { return }
        markAsChanged()
        logEvent("cardDensityPreference updated to \(preference.rawValue)")
        showInfoToast("Card Size Updated", message: preference.detailDescription)
        announce(preference.toastMessage)
    }

    func cycleCardDensityPreference() {
        let nextPreference = cardDensityPreference.next()
        setCardDensityPreference(nextPreference)
    }

    func restoreCardDensityPreference(rawValue: String?) {
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
