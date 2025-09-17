import SwiftUI
import TiercadeCore

#if os(tvOS)
struct TVActionBar: View {
    @ObservedObject var app: AppState

    var body: some View {
        HStack(spacing: 20) {
            Toggle(isOn: Binding(get: { app.isMultiSelect }, set: { v in app.isMultiSelect = v; if !v { app.clearSelection() } })) {
                Text(app.isMultiSelect ? "Multi-Select: \(app.selection.count)" : "Multi-Select")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("ActionBar_MultiSelect")

            Divider().frame(height: 28)

            ForEach(app.tierOrder.prefix(4), id: \.self) { t in
                Button("Move to \(t)") {
                    app.batchMove(Array(app.selection), to: t)
                }
                .buttonStyle(.borderedProminent)
                .disabled(app.selection.isEmpty)
                .accessibilityIdentifier("ActionBar_Move_\(t)")
            }

            Spacer()

            if app.selection.count > 0 {
                Button("Clear Selection") { app.clearSelection() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("ActionBar_ClearSelection")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .focusSection()
        .accessibilityIdentifier("ActionBar")
    }
}
#endif
