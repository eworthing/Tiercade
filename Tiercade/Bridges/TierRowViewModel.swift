#if os(tvOS)
import Foundation
import TiercadeCore

struct TierRowViewModel: Hashable {
    let id: String
    let displayName: String
    let imageURL: URL?
    let accessibilityIdentifier: String
    let accessibilityLabel: String

    init(item: Item, index: Int, totalCount: Int, tierName: String) {
        id = item.id
        displayName = item.name ?? item.id
        if let source = item.imageUrl ?? item.videoUrl, let url = URL(string: source) {
            imageURL = url
        } else {
            imageURL = nil
        }
        accessibilityIdentifier = "Card_\(tierName)_\(index)"
        let position = index + 1
        accessibilityLabel = "\(displayName), position \(position) of \(totalCount) in \(tierName) tier"
    }
}
#endif
