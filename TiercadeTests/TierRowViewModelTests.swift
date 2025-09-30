#if os(tvOS)
import XCTest
@testable import Tiercade
import TiercadeCore

final class TierRowViewModelTests: XCTestCase {
    func testAccessibilityLabelUsesDisplayNameAndPosition() {
        let item = Item(id: "mario", name: "Mario", imageUrl: "https://example.com/mario.png")
        let viewModel = TierRowViewModel(item: item, index: 0, totalCount: 3, tierName: "S")

        XCTAssertEqual(viewModel.displayName, "Mario")
        XCTAssertEqual(viewModel.accessibilityIdentifier, "Card_S_0")
        XCTAssertEqual(viewModel.accessibilityLabel, "Mario, position 1 of 3 in S tier")
        XCTAssertEqual(viewModel.imageURL, URL(string: "https://example.com/mario.png"))
    }

    func testFallsBackToIDWhenNameMissing() {
        let item = Item(id: "luigi", name: nil, imageUrl: nil)
        let viewModel = TierRowViewModel(item: item, index: 1, totalCount: 2, tierName: "A")

        XCTAssertEqual(viewModel.displayName, "luigi")
        XCTAssertNil(viewModel.imageURL)
        XCTAssertEqual(viewModel.accessibilityIdentifier, "Card_A_1")
        XCTAssertEqual(viewModel.accessibilityLabel, "luigi, position 2 of 2 in A tier")
    }
}
#endif
