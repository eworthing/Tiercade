import XCTest
@testable import TiercadeCore

final class ProjectValidationTests: XCTestCase {
    func testValidateOfflineV1_allowsFileURIs() throws {
        let project = makeProject()
        XCTAssertNoThrow(try ProjectValidation.validateOfflineV1(project))
    }

    func testValidateOfflineV1_rejectsCloudMode() throws {
        let project = makeProject(storageMode: "cloud")
        XCTAssertThrowsError(try ProjectValidation.validateOfflineV1(project)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "Tiercade")
            XCTAssertEqual(nsError.code, 1001)
        }
    }

    func testValidateOfflineV1_rejectsNonFileMediaURI() throws {
        let project = makeProject(mediaUri: "http://example.com/item.jpg")
        XCTAssertThrowsError(try ProjectValidation.validateOfflineV1(project)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "Tiercade")
            XCTAssertEqual(nsError.code, 1002)
        }
    }

    func testMemberRoleIsRequiredDuringDecoding() throws {
        let jsonData = Data("""
        {
            "schemaVersion": 1,
            "projectId": "00000000-0000-0000-0000-000000000000",
            "tiers": [],
            "items": {},
            "audit": {
                "createdAt": "2024-01-01T00:00:00Z",
                "updatedAt": "2024-01-01T00:00:00Z"
            },
            "collab": {
                "members": [
                    { "userId": "user-1" }
                ]
            }
        }
        """.utf8)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

    XCTAssertThrowsError(try decoder.decode(Project.self, from: jsonData))
    }
}

private extension ProjectValidationTests {
    func makeProject(storageMode: String? = nil, mediaUri: String = "file:///tmp/item.jpg") -> Project {
        let audit = Project.Audit(
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        let media = Project.Media(
            id: "media-1",
            kind: .image,
            uri: mediaUri,
            mime: "image/jpeg",
            posterUri: mediaUri,
            thumbUri: mediaUri
        )

        let item = Project.Item(
            id: "item-1",
            title: "Sample",
            media: [media]
        )

        let tier = Project.Tier(id: "tier-1", label: "Tier", order: 0, itemIds: [item.id])

        let storage = storageMode.map { mode in
            Project.Storage(mode: mode)
        }

        return Project(
            schemaVersion: 1,
            projectId: "00000000-0000-0000-0000-000000000000",
            tiers: [tier],
            items: [item.id: item],
            overrides: nil,
            links: nil,
            storage: storage,
            settings: nil,
            collab: nil,
            audit: audit
        )
    }
}
