import Foundation
import Testing
@testable import Tiercade

/// Security tests for CSV injection and parsing vulnerabilities
@Suite("CSV Injection Security Tests")
struct CSVInjectionTests {

    // MARK: - Formula Injection Prevention

    @Test("Sanitizes CSV cells starting with =")
    func sanitizeEqualsFormula() {
        let dangerous = "=SUM(A1:A10)"
        let sanitized = AppState.sanitizeCSVCell(dangerous)
        #expect(sanitized.hasPrefix("'"))
        #expect(sanitized == "'=SUM(A1:A10)")
    }

    @Test("Sanitizes CSV cells starting with +")
    func sanitizePlusFormula() {
        let dangerous = "+1+1"
        let sanitized = AppState.sanitizeCSVCell(dangerous)
        #expect(sanitized.hasPrefix("'"))
        #expect(sanitized == "'+1+1")
    }

    @Test("Sanitizes CSV cells starting with -")
    func sanitizeMinusFormula() {
        let dangerous = "-AVERAGE(A1:A10)"
        let sanitized = AppState.sanitizeCSVCell(dangerous)
        #expect(sanitized.hasPrefix("'"))
        #expect(sanitized == "'-AVERAGE(A1:A10)")
    }

    @Test("Sanitizes CSV cells starting with @")
    func sanitizeAtFormula() {
        let dangerous = "@SUM(A1:A10)"
        let sanitized = AppState.sanitizeCSVCell(dangerous)
        #expect(sanitized.hasPrefix("'"))
        #expect(sanitized == "'@SUM(A1:A10)")
    }

    @Test("Does not modify safe content")
    func leaveSafeContentUnchanged() {
        let safe = "Normal Item Name"
        let sanitized = AppState.sanitizeCSVCell(safe)
        #expect(sanitized == safe)
    }

    @Test("Sanitizes dangerous Excel commands")
    func sanitizeDangerousCommands() {
        let dangerous = "=SYSTEM(\"rm -rf /\")"
        let sanitized = AppState.sanitizeCSVCell(dangerous)
        #expect(sanitized.hasPrefix("'"))
        #expect(!sanitized.contains("SYSTEM")) // Still contains but prefixed
    }

    // MARK: - CSV Parsing (Quote Escaping)

    @Test("Parses escaped quotes correctly")
    func parseEscapedQuotes() {
        let input = "Name,\"Description with \"\"quotes\"\"\""
        let parsed = AppState.parseCSVLine(input)
        #expect(parsed.count == 2)
        #expect(parsed[0] == "Name")
        #expect(parsed[1] == "Description with \"quotes\"")
    }

    @Test("Handles empty fields")
    func parseEmptyFields() {
        let input = "Field1,,Field3"
        let parsed = AppState.parseCSVLine(input)
        #expect(parsed.count == 3)
        #expect(parsed[0] == "Field1")
        #expect(parsed[1] == "")
        #expect(parsed[2] == "Field3")
    }

    @Test("Handles quoted fields with commas")
    func parseQuotedFieldsWithCommas() {
        let input = "Name,\"Last, First\",Age"
        let parsed = AppState.parseCSVLine(input)
        #expect(parsed.count == 3)
        #expect(parsed[0] == "Name")
        #expect(parsed[1] == "Last, First")
        #expect(parsed[2] == "Age")
    }

    @Test("Handles complex quoted content")
    func parseComplexQuotes() {
        let input = "\"Field with \"\"nested\"\" quotes and, comma\""
        let parsed = AppState.parseCSVLine(input)
        #expect(parsed.count == 1)
        #expect(parsed[0] == "Field with \"nested\" quotes and, comma")
    }

    // MARK: - Duplicate ID Prevention

    @Test("Generates unique IDs for duplicate items", .enabled(if: false))
    func generateUniqueIDsForDuplicates() async throws {
        // This test requires actual CSV import implementation
        // Placeholder for when import logic is testable

        let csv = """
        Name,Tier
        Duplicate Item,S
        Duplicate Item,A
        Duplicate Item,B
        """

        // Expected behavior: IDs should be unique
        // e.g., "duplicate_item", "duplicate_item_2", "duplicate_item_3"

        // let result = try await importCSV(csv)
        // #expect(result.items.count == 3)
        // let ids = result.items.map(\.id)
        // #expect(Set(ids).count == ids.count) // All unique
    }

    @Test("Handles malformed CSV gracefully", .enabled(if: false))
    func handleMalformedCSV() async throws {
        // Test that malformed CSV doesn't crash or cause data corruption

        let malformed = """
        Name,Tier
        "Unclosed quote,S
        Normal Item,A
        """

        // Should either throw validation error or skip malformed row
        // #expect(throws: ImportError.self) {
        //     try await importCSV(malformed)
        // }
    }
}
