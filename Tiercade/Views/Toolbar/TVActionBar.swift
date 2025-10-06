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
        ZStack {
            // Explicit background for UI test visibility
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            HStack(spacing: 20) {
                Button {
                    withAnimation(.snappy(duration: 0.18, extraBounce: 0.04)) {
                        editMode?.wrappedValue = isMultiSelectActive ? .inactive : .active
                        if !isMultiSelectActive { app.clearSelection() }
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: isMultiSelectActive ? "checkmark.circle.fill" : "circle")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(isMultiSelectActive ? Palette.brand : Palette.textDim)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Multi-Select")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text("Enabled")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.brand)
                                .opacity(isMultiSelectActive ? 1 : 0)
                                .accessibilityHidden(!isMultiSelectActive)
                        }

                        Spacer()

                        if isMultiSelectActive {
                            Capsule()
                                .fill(Palette.brand.opacity(0.28))
                                .overlay(
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.stack.3d.up.fill")
                                            .font(.callout.weight(.semibold))
                                        Text("Active · \(app.selection.count)")
                                            .font(.callout.weight(.semibold))
                                    }
                                        .foregroundStyle(Color.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                )
                                .accessibilityIdentifier("ActionBar_SelectionCount")
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(multiSelectBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(.tvRemote(.secondary))
                .animation(.easeOut(duration: 0.18), value: isMultiSelectActive)
                .accessibilityIdentifier("ActionBar_MultiSelect")
                .accessibilityLabel(isMultiSelectActive ? "Exit Selection Mode" : "Enter Selection Mode")
                .accessibilityValue(
                    isMultiSelectActive
                        ? "\(app.selection.count) items selected"
                        : "Selection mode inactive"
                )
                .accessibilityHint(
                    isMultiSelectActive
                        ? "Press to exit selection mode and clear selection"
                        : "Press to enable item selection"
                )

                Divider().frame(height: 28)

                ForEach(app.tierOrder.prefix(4), id: \.self) { t in
                    Button("Move to \(t)") {
                        app.batchMove(Array(app.selection), to: t)
                        // Exit selection mode after batch operation (Photos.app style)
                        editMode?.wrappedValue = .inactive
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
            }  // Close HStack
            .lineLimit(1)
            .padding(.horizontal, TVMetrics.barHorizontalPadding)
            .padding(.vertical, TVMetrics.barVerticalPadding)
        }  // Close ZStack
        .frame(maxWidth: .infinity)
        .frame(height: TVMetrics.bottomBarHeight)
        .background(.thinMaterial)  // Add background to ensure visibility
        .overlay(Divider().opacity(0.15), alignment: .top)
        // Note: .focusSection() can hide elements from accessibility until focused
        // For UI testing, we need elements to be accessible even when not focused
        // NOTE: Don't set accessibilityIdentifier on the container - it overrides children!
        .accessibilityElement(children: .contain)
    }

    private var multiSelectBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(isMultiSelectActive ? Palette.brand.opacity(0.22) : Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        isMultiSelectActive ? Palette.brand : Color.white.opacity(0.12),
                        lineWidth: isMultiSelectActive ? 2 : 1
                    )
            )
    }
}
#endif
