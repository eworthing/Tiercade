import SwiftUI
import TiercadeCore

#if os(tvOS)
struct QuickMoveOverlay: View {
    @Bindable var app: AppState

    @FocusState private var focused: FocusField?

    private enum FocusField: Hashable { case s, a, b, c, u, more, cancel }

    var body: some View {
        if let item = app.quickMoveTarget {
            ZStack {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .onTapGesture { app.cancelQuickMove() }
                    .accessibilityHidden(true)

                VStack(spacing: 16) {
                    Text("Move \(item.name ?? item.id)")
                        .font(.title3)
                        .foregroundStyle(.primary)
                    ZStack {
                        // Radial plate
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 420, height: 420)
                            .overlay(Circle().strokeBorder(.white.opacity(0.08)))

                        // Five targets (S, A, B, C, Unranked)
                        VStack {
                            MoveCircleButton(
                                label: "S",
                                color: .red,
                                a11y: "Move to S tier"
                            ) {
                                app.commitQuickMove(to: "S")
                            }
                            .focused($focused, equals: .s)
                            Spacer(minLength: 0)
                            MoveCircleButton(
                                label: "B",
                                color: .green,
                                a11y: "Move to B tier"
                            ) {
                                app.commitQuickMove(to: "B")
                            }
                            .focused($focused, equals: .b)
                        }
                        .frame(height: 360)

                        HStack {
                            MoveCircleButton(
                                label: "A",
                                color: .orange,
                                a11y: "Move to A tier"
                            ) {
                                app.commitQuickMove(to: "A")
                            }
                            .focused($focused, equals: .a)
                            Spacer(minLength: 0)
                            MoveCircleButton(
                                label: "C",
                                color: .cyan,
                                a11y: "Move to C tier"
                            ) {
                                app.commitQuickMove(to: "C")
                            }
                            .focused($focused, equals: .c)
                        }
                        .frame(width: 360)

                        // Unranked target at center-bottom
                        VStack {
                            Spacer()
                            MoveCircleButton(
                                label: "U",
                                color: Palette.tierColor("unranked"),
                                a11y: "Move to Unranked"
                            ) {
                                app.commitQuickMove(to: "unranked")
                            }
                            .focused($focused, equals: .u)
                        }
                        .frame(height: 420)
                    }
                    .frame(width: 440, height: 440)

                    HStack(spacing: 24) {
                        Button("More…") {
                            app.presentItemMenu(item)
                            app.cancelQuickMove()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.secondary)
                        .accessibilityIdentifier("QuickMove_More")
                        .focused($focused, equals: .more)
                        Button("Cancel", role: .cancel) {
                            app.cancelQuickMove()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("QuickMove_Cancel")
                        .focused($focused, equals: .cancel)
                    }
                }
                .padding(24)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.06)))
                .shadow(radius: 24)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .accessibilityIdentifier("QuickMove_Overlay")
                .focusSection()
                .defaultFocus($focused, .s)
                .onAppear { focused = .s }
                .onDisappear { focused = nil }
            }
            .transition(.opacity.combined(with: .scale))
        }
    }

    // Focus-aware circle button used in the radial layout above
    private struct MoveCircleButton: View {
        let label: String
        let color: Color
        let a11y: String
        let action: () -> Void
        @Environment(\.isFocused) private var isFocused: Bool

        var body: some View {
            Button(action: action, label: {
                Text(label)
                    .font(.system(size: 48, weight: .bold))
                    .frame(width: 140, height: 140)
                    .background(
                        Circle()
                            .fill(color.opacity(0.25))
                    )
                    .overlay(
                        Circle()
                            .stroke(color.opacity(isFocused ? 1.0 : 0.8), lineWidth: isFocused ? 4 : 2)
                            .shadow(color: color.opacity(isFocused ? 0.7 : 0.0), radius: isFocused ? 22 : 0)
                    )
                    .scaleEffect(isFocused ? 1.08 : 1.0)
                    .animation(
                        .spring(response: 0.25, dampingFraction: 0.75, blendDuration: 0.08),
                        value: isFocused
                    )
            })
            .buttonStyle(.plain)
            .contentShape(Circle())
            .focusable(true)
            .accessibilityLabel(a11y)
            .accessibilityIdentifier("QuickMove_\(label)")
        }
    }
}
#endif
