import SwiftUI
import TiercadeCore

#if os(tvOS)
struct QuickMoveOverlay: View {
    @ObservedObject var app: AppState

    private let primaryTargets = ["S", "A", "B", "C"]

    var body: some View {
        if let item = app.quickMoveTarget {
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

                    // Four targets
                    VStack {
                        moveButton(label: "S", color: .red, a11y: "Move to S tier") { app.commitQuickMove(to: "S") }
                        Spacer(minLength: 0)
                        moveButton(label: "B", color: .green, a11y: "Move to B tier") { app.commitQuickMove(to: "B") }
                    }
                    .frame(height: 360)

                    HStack {
                        moveButton(label: "A", color: .orange, a11y: "Move to A tier") { app.commitQuickMove(to: "A") }
                        Spacer(minLength: 0)
                        moveButton(label: "C", color: .cyan, a11y: "Move to C tier") { app.commitQuickMove(to: "C") }
                    }
                    .frame(width: 360)
                }
                .frame(width: 440, height: 440)
                .focusSection()

                HStack(spacing: 24) {
                    Button("More…") {
                        app.presentItemMenu(item)
                        app.cancelQuickMove()
                    }
                        .buttonStyle(.borderedProminent)
                        .tint(.secondary)
                        .accessibilityIdentifier("QuickMove_More")
                    Button("Cancel", role: .cancel) { app.cancelQuickMove() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("QuickMove_Cancel")
                }
            }
            .padding(24)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.06)))
            .shadow(radius: 24)
            .transition(.opacity.combined(with: .scale))
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("QuickMove_Overlay")
            .onMoveCommand { dir in
                switch dir {
                case .up: app.commitQuickMove(to: "S")
                case .right: app.commitQuickMove(to: "A")
                case .down: app.commitQuickMove(to: "B")
                case .left: app.commitQuickMove(to: "C")
                @unknown default: break
                }
            }
        }
    }

    @ViewBuilder
    private func moveButton(label: String, color: Color, a11y: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 48, weight: .bold))
                .frame(width: 140, height: 140)
                .background(
                    Circle()
                        .fill(color.opacity(0.25))
                )
                .overlay(Circle().stroke(color.opacity(0.8), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .focusable(true)
        .accessibilityLabel(a11y)
        .accessibilityIdentifier("QuickMove_\(label)")
        .scaleEffect(1.0)
    }
}
#endif
