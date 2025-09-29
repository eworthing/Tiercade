import SwiftUI
import TiercadeCore

#if os(tvOS)
struct ItemMenuOverlay: View {
    @ObservedObject var app: AppState
    @FocusState private var focused: FocusField?
    private enum FocusField: Hashable { case firstMove, toggle, details, remove, close }

    var body: some View {
        if let item = app.itemMenuTarget {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.name ?? item.id).font(.title3)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Move to:").font(.headline)
                    HStack {
                        ForEach(app.tierOrder, id: \.self) { t in
                            Button(t) { app.move(item.id, to: t); app.dismissItemMenu() }
                                .buttonStyle(.borderedProminent)
                                .accessibilityLabel("Move to \(t) tier")
                                .accessibilityIdentifier("ItemMenu_Move_\(t)")
                                .focused($focused, equals: t == app.tierOrder.first ? .firstMove : nil)
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

                    Button("Remove from Tier") {
                        app.removeFromCurrentTier(item.id)
                        app.dismissItemMenu()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("ItemMenu_RemoveFromTier")
                    .focused($focused, equals: .remove)

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
            .defaultFocus($focused, .firstMove)
            .focusSection()
        }
    }
}
#endif
