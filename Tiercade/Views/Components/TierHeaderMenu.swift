import SwiftUI

#if os(tvOS)
struct TierHeaderView: View {
    @Environment(AppState.self) private var app: AppState
    let tierId: String
    var titleColor: Color?
    @State private var showMenu = false
    @State private var newLabel: String = ""
    @State private var newColorHex: String = ""

    var body: some View {
        HStack {
            Button(action: { showMenu = true }, label: {
                Text(app.displayLabel(for: tierId))
                    .font(TypeScale.h3)
                    .foregroundColor(titleColor ?? Palette.text)
            })
            .buttonStyle(GhostButtonStyle())

            Spacer()
            Button(action: { app.toggleTierLocked(tierId) }, label: {
                Image(systemName: app.isTierLocked(tierId) ? "lock.fill" : "lock.open.fill")
            })
            .buttonStyle(.bordered)
            .accessibilityLabel(app.isTierLocked(tierId) ? "Unlock Tier" : "Lock Tier")
            .focusTooltip(app.isTierLocked(tierId) ? "Unlock" : "Lock")

            Button(action: { showMenu = true }, label: {
                Image(systemName: "ellipsis.circle")
            })
            .buttonStyle(.bordered)
            .accessibilityLabel("Tier Menu")
            .focusTooltip("Menu")
        }
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.6).onEnded { _ in showMenu = true })
        .sheet(isPresented: $showMenu, content: {
            TierLabelEditor(app: app, tierId: tierId, showMenu: $showMenu)
        })
    }
}

private struct TierLabelEditor: View {
    @Bindable var app: AppState
    let tierId: String
    @Binding var showMenu: Bool
    @State private var label: String = ""
    @State private var colorHex: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Tier \(tierId)").font(.title2)
            HStack(spacing: 12) {
                TextField("Rename", text: $label)
                    .textFieldStyle(.plain)
                    .frame(width: 360)
                Button("Apply") {
                    app.setDisplayLabel(label, for: tierId)
                    app.showInfoToast("Renamed", message: "Tier \(tierId) → \(label)")
                }
            }
            HStack(spacing: 12) {
                TextField("Hex Color (e.g., #E11D48)", text: $colorHex)
                    .textFieldStyle(.plain)
                    .frame(width: 360)
                Button("Set Color") {
                    app.setDisplayColorHex(colorHex, for: tierId)
                    app.showInfoToast("Recolored", message: colorHex)
                }
            }
            HStack(spacing: 12) {
                Button(app.isTierLocked(tierId) ? "Unlock" : "Lock") {
                    app.toggleTierLocked(tierId)
                }
                .buttonStyle(.borderedProminent)
                Button("Clear Tier") {
                    app.clearTier(tierId)
                }
                .buttonStyle(.bordered)
                Button("Close", role: .cancel) { showMenu = false }
            }
        }
        .padding(24)
    }
}
#endif
