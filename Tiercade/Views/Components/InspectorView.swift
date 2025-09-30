import SwiftUI

struct InspectorView: View {
    @EnvironmentObject var app: AppState
    @State private var locked = false
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid) {
            HStack { Text("Inspector").font(TypeScale.h3); Spacer() }

            VStack(alignment: .leading, spacing: Metrics.grid) {
                Text("Details").font(TypeScale.label).foregroundColor(Palette.textDim)
                Text("Select an item to see details")
                    .font(TypeScale.body)
                    .foregroundColor(Palette.textDim)
            }

            Divider()

            Text("Colors").font(TypeScale.label).foregroundColor(Palette.textDim).textCase(.uppercase)
            HStack(spacing: Metrics.grid) {
                ColorSwatch(color: Palette.tierColor("S"), action: {})
                ColorSwatch(color: Palette.tierColor("A"), action: {})
                ColorSwatch(color: Palette.tierColor("B"), action: {})
                ColorSwatch(color: Palette.tierColor("C"), action: {})
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Tier colors")

            Toggle(isOn: $locked) {
                Text("Lock Tier")
            }

            Spacer()
        }
        .panel()
        .frame(minWidth: Metrics.paneRight)
        .padding(.horizontal, Metrics.grid)
    }
}
