import SwiftUI
import TiercadeCore

#if os(tvOS)
struct ItemMenuOverlay: View {
    @ObservedObject var app: AppState

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
                        }
                    }
                }
                HStack(spacing: 12) {
                    Button(app.isSelected(item.id) ? "Remove from Selection" : "Add to Selection") {
                        app.toggleSelection(item.id)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("ItemMenu_ToggleSelection")

                    Button("View Details") {
                        app.detailItem = item
                        app.dismissItemMenu()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("ItemMenu_ViewDetails")

                    Button("Remove from Tier") {
                        app.removeFromCurrentTier(item.id)
                        app.dismissItemMenu()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("ItemMenu_RemoveFromTier")

                    Spacer()
                    Button("Close", role: .cancel) { app.dismissItemMenu() }
                        .accessibilityIdentifier("ItemMenu_Close")
                }
            }
            .padding(24)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.06)))
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("ItemMenu_Overlay")
        }
    }
}
#endif
