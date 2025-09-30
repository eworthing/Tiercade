import SwiftUI
import TiercadeCore

#if os(tvOS)
struct TVActionBar: View {
    @Bindable var app: AppState

    var body: some View {
        HStack(spacing: 20) {
            Button {
                app.isMultiSelect.toggle()
                if !app.isMultiSelect { app.clearSelection() }
            } label: {
                HStack(spacing: 12) {
                    Text("Multi-Select")
                    if app.isMultiSelect {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 2, height: 24)
                        Text("\(app.selection.count)")
                            .font(.callout.weight(.semibold))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.tvRemote(.secondary))
            .accessibilityIdentifier("ActionBar_MultiSelect")

            Divider().frame(height: 28)

            ForEach(app.tierOrder.prefix(4), id: \.self) { t in
                Button("Move to \(t)") {
                    app.batchMove(Array(app.selection), to: t)
                }
                .buttonStyle(.tvRemote(.primary))
                .disabled(app.selection.isEmpty)
                .accessibilityIdentifier("ActionBar_Move_\(t)")
            }

            Spacer()

            if app.selection.count > 0 {
                Button("Clear Selection") { app.clearSelection() }
                    .buttonStyle(.tvRemote(.secondary))
                    .accessibilityIdentifier("ActionBar_ClearSelection")
            }
        }
        .lineLimit(1)
        .padding(.horizontal, TVMetrics.barHorizontalPadding)
        .padding(.vertical, TVMetrics.barVerticalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: TVMetrics.bottomBarHeight)
        .focusSection()
        .accessibilityIdentifier("ActionBar")
    }
}
#endif
