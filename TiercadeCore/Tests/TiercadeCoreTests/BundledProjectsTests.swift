import Foundation
import Testing
@testable import TiercadeCore

@Suite("BundledProjects")
struct BundledProjectsTests {
    @Test("Bundled catalog exposes known descriptors")
    func bundledProjectsCatalog() throws {
        let all = BundledProjects.all
        #expect(all.count >= 3)

        let survivor = try #require(BundledProjects.project(withId: "survivor-legends"))
        #expect(survivor.title.contains("Survivor"))
        #expect(survivor.itemCount == survivor.project.items.count)
        #expect(survivor.project.tiers.first?.color == "#FF6B6B")
    }
}
