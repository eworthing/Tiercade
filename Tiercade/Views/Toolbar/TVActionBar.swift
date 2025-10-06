import SwiftUI
import TiercadeCore

#if os(tvOS)
struct TVActionBar: View {
    @Bindable var app: AppState
    @Environment(\.editMode) private var editMode

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
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Palette.brand.opacity(0.22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Palette.brand, lineWidth: 2)
                            )
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
            }
            .frame(maxWidth: .infinity)
            .frame(height: TVMetrics.bottomBarHeight)
            .background(.thinMaterial)
            .overlay(Divider().opacity(0.15), alignment: .top)
            .accessibilityElement(children: .contain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
#endif
