import Foundation
@testable import Tiercade

/// Mock implementation of UniqueListGenerating for testing
///
/// Allows tests to inject predictable AI generation responses without
/// depending on actual FoundationModels or network calls.
@MainActor
final class MockUniqueListGenerator: UniqueListGenerating {
    // MARK: - Configuration

    /// Whether the generator should report as available
    var isAvailable: Bool = true

    /// Items to return from generateUniqueList
    var itemsToReturn: [AIGeneratedItemCandidate] = []

    /// Error to throw from generateUniqueList
    var errorToThrow: Error?

    /// Tracks all generation calls for verification
    private(set) var generateCalls: [(topic: String, count: Int)] = []

    // MARK: - UniqueListGenerating

    func generateUniqueList(topic: String, count: Int) async throws -> [AIGeneratedItemCandidate] {
        generateCalls.append((topic, count))

        if let error = errorToThrow {
            throw error
        }

        return itemsToReturn
    }

    // MARK: - Test Helpers

    /// Reset the mock to its initial state
    func reset() {
        isAvailable = true
        itemsToReturn = []
        errorToThrow = nil
        generateCalls = []
    }

    /// Configure the mock to return specific items
    func mockGeneration(items: [AIGeneratedItemCandidate]) {
        itemsToReturn = items
    }

    /// Configure the mock to throw an error
    func mockError(_ error: Error) {
        errorToThrow = error
    }
}
