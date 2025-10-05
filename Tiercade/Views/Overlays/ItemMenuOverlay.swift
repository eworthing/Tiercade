import SwiftUI
import TiercadeCore

#if os(tvOS)
struct ItemMenuOverlay: View {
    @Bindable var app: AppState
    @FocusState private var focused: FocusField?
    private enum FocusField: Hashable {
        case move(String)
        case toggle
        case details
        case remove
        case close
        case backgroundTrap
    }

    var body: some View {
        if let item = app.itemMenuTarget {
            ZStack {
                // Focus-trapping background: Focusable to catch stray focus and redirect back
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .onTapGesture { app.dismissItemMenu() }
                    .focusable()
                    .focused($focused, equals: .backgroundTrap)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 16) {
                    Text(item.name ?? item.id).font(.title3)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Move to:").font(.headline)
                        HStack {
                            ForEach(allMoveTargets, id: \.self) { tierId in
                                let isCurrentTier = app.currentTier(of: item.id) == tierId
                                Button {
                                    if !isCurrentTier {
                                        app.move(item.id, to: tierId)
                                        app.dismissItemMenu()
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(app.displayLabel(for: tierId))
                                        if isCurrentTier {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isCurrentTier)
                                .opacity(isCurrentTier ? 0.5 : 1.0)
                                .accessibilityLabel(isCurrentTier ? "Current tier: \(app.displayLabel(for: tierId))" : "Move to \(app.displayLabel(for: tierId)) tier")
                                .accessibilityIdentifier("ItemMenu_Move_\(tierId)")
                                .focused($focused, equals: .move(tierId))
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        Button(app.isSelected(item.id) ? "Remove from Selection" : "Add to Selection") {
                            app.toggleSelection(item.id)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("ItemMenu_ToggleSelection")
                        .focused($focused, equals: .toggle)

                        Button("View Details") {
                            app.detailItem = item
                            app.dismissItemMenu()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("ItemMenu_ViewDetails")
                        .focused($focused, equals: .details)

                        Spacer()
                        Button("Close", role: .cancel) { app.dismissItemMenu() }
                            .accessibilityIdentifier("ItemMenu_Close")
                            .focused($focused, equals: .close)
                    }
                }
                .padding(24)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.06)))
                .padding()
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .accessibilityIdentifier("ItemMenu_Overlay")
                .focusSection()
                .defaultFocus($focused, defaultFocusField)
                .onAppear { focused = defaultFocusField }
                .onDisappear { focused = nil }
            }
        }
    }
}

private extension ItemMenuOverlay {
    private var allMoveTargets: [String] {
        app.tierOrder + ["unranked"]
    }

    private var defaultFocusField: FocusField {
        guard let item = app.itemMenuTarget else { return .toggle }
        let currentTier = app.currentTier(of: item.id)

        // Find first tier that isn't the current tier
        if let firstAvailable = allMoveTargets.first(where: { $0 != currentTier }) {
            return .move(firstAvailable)
        }

        return .toggle
    }
}
#endif
