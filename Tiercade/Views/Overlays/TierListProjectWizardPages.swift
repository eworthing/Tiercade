import SwiftUI
import TiercadeCore
import os

// MARK: - Wizard Page Protocol

internal protocol WizardPage {
    var pageTitle: String { get }
    var pageDescription: String { get }
}

#if os(tvOS)
internal extension View {
    internal func wizardFieldDecoration() -> some View {
        self
            .padding(.vertical, Metrics.grid * 1.5)
            .padding(.horizontal, Metrics.grid * 2)
            .background(
                RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                    .fill(Palette.surface.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                            .stroke(Palette.stroke, lineWidth: 1)
                    )
            )
    }

    internal func wizardTogglePadding() -> some View {
        self.padding(.vertical, Metrics.grid)
    }
}
#endif
