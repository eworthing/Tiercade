import SwiftUI
import TiercadeCore

#if os(tvOS)
struct TVActionBar: View {
    @Bindable var app: AppState
    @Environment(\.editMode) private var editMode
    var glassNamespace: Namespace.ID

    private var isMultiSelectActive: Bool {
        editMode?.wrappedValue == .active
    }

    var body: some View {
        if isMultiSelectActive {
            ZStack {
                // Explicit background for UI test visibility
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                HStack(spacing: 20) {
                    // Selection count indicator
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Palette.brand)

                        Text("\(app.selection.count) Selected")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .tvGlassRounded(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Palette.brand.opacity(0.9), lineWidth: 2)
                    )
                    .accessibilityIdentifier("ActionBar_SelectionCount")
                    .accessibilityLabel("\(app.selection.count) items selected")

                    Spacer()

                    // Move to Tier button (only show if items selected)
                    if app.selection.count > 0 {
                        let selectionHint = "Open tier selection to move \(app.selection.count) item" +
                            (app.selection.count == 1 ? "" : "s")
                        Button("Move to Tier…") {
                            app.presentBatchQuickMove()
                        }
                        .buttonStyle(.tvRemote(.primary))
                        .accessibilityIdentifier("ActionBar_MoveBatch")
                        .accessibilityHint(selectionHint)
                    }

                    // Clear selection button
                    Button("Clear Selection") {
                        app.clearSelection()
                    }
                    .buttonStyle(.tvRemote(.secondary))
                    .accessibilityIdentifier("ActionBar_ClearSelection")
                }
                .lineLimit(1)
                .padding(.horizontal, TVMetrics.barHorizontalPadding)
                .padding(.vertical, TVMetrics.barVerticalPadding)
                .tvGlassRounded(28)
#if swift(>=6.0)
                .glassEffectID("actionBar", in: glassNamespace)
                .glassEffectUnion(id: "tiercade.controls", namespace: glassNamespace)
#endif
            }
            .frame(maxWidth: .infinity)
            .frame(height: TVMetrics.bottomBarHeight)
            .accessibilityElement(children: .contain)
            .overlay(alignment: .top) {
                Divider().opacity(0.12)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
#endif
