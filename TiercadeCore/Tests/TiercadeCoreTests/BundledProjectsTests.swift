import Testing
@testable import TiercadeCore

@Suite("Bundled Projects")
struct BundledProjectsTests {
    @Test("Bundled projects validate and contain items")
    func bundledProjectsValidate() throws {
        let projects = BundledProjects.all
        #expect(!projects.isEmpty)

        for project in projects {
            try ProjectValidation.validateOfflineV1(project.project)
            #expect(!project.project.items.isEmpty, "Bundled project \(project.id) should contain items")
            let hasUnranked = project.project.tiers.contains { $0.id == "unranked" }
            #expect(hasUnranked)
        }
    }
}
