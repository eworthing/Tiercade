import SwiftUI
import TiercadeCore

#if os(tvOS)
struct CollectionTierRowContainer: UIViewControllerRepresentable {
    let tierName: String
    let items: [Item]
    var onSelect: ((Item) -> Void)?
    var onPlayPause: ((Item) -> Void)?
    var selectedIds: Set<String> = []
    var isMultiSelect: Bool = false

    func makeUIViewController(context: Context) -> CollectionTierRowController {
        let controller = CollectionTierRowController(tierName: tierName, items: items)
        controller.onSelect = onSelect
        controller.onPlayPause = onPlayPause
        controller.isPrefetchingEnabled = !DeviceCheck.isLowMemoryTV
        controller.selectedIds = selectedIds
        controller.isMultiSelect = isMultiSelect
        return controller
    }

    func updateUIViewController(_ uiViewController: CollectionTierRowController, context: Context) {
        uiViewController.onSelect = onSelect
        uiViewController.onPlayPause = onPlayPause
        uiViewController.apply(items: items)
        uiViewController.isPrefetchingEnabled = !DeviceCheck.isLowMemoryTV
        uiViewController.selectedIds = selectedIds
        uiViewController.isMultiSelect = isMultiSelect
    }
}
#endif
