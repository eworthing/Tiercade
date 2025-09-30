#if os(tvOS)
import Testing
@testable import Tiercade
import TiercadeCore

@Suite("TierRowViewModel Tests", .tags(.tvOS))
struct TierRowViewModelTests {

    @Test("Accessibility label uses display name and position")
    func accessibilityLabelUsesDisplayNameAndPosition() {
        let item = Item(id: "mario", name: "Mario", imageUrl: "https://example.com/mario.png")
        let viewModel = TierRowViewModel(item: item, index: 0, totalCount: 3, tierName: "S")

        #expect(viewModel.displayName == "Mario")
        #expect(viewModel.accessibilityIdentifier == "Card_S_0")
        #expect(viewModel.accessibilityLabel == "Mario, position 1 of 3 in S tier")
        #expect(viewModel.imageURL == URL(string: "https://example.com/mario.png"))
    }

    @Test("Falls back to ID when name is missing")
    func fallsBackToIDWhenNameMissing() {
        let item = Item(id: "luigi", name: nil, imageUrl: nil)
        let viewModel = TierRowViewModel(item: item, index: 1, totalCount: 2, tierName: "A")

        #expect(viewModel.displayName == "luigi")
        #expect(viewModel.imageURL == nil)
        #expect(viewModel.accessibilityIdentifier == "Card_A_1")
        #expect(viewModel.accessibilityLabel == "luigi, position 2 of 2 in A tier")
    }
}
#endif
