import Testing
import Foundation
@testable import Tiercade

/// Security tests for CSV injection and parsing vulnerabilities
@Suite("CSV Injection Security Tests")
internal struct CSVInjectionTests {

    // MARK: - Formula Injection Prevention

    @Test("Sanitizes CSV cells starting with =")
    internal func sanitizeEqualsFormula() {
        internal let dangerous = "=SUM(A1:A10)"
        internal let sanitized = AppState.sanitizeCSVCell(dangerous)
        #expect(sanitized.hasPrefix("'"))
        #expect(sanitized == "'=SUM(A1:A10)")
    }

    @Test("Sanitizes CSV cells starting with +")
    internal func sanitizePlusFormula() {
        internal let dangerous = "+1+1"
        internal let sanitized = AppState.sanitizeCSVCell(dangerous)
        #expect(sanitized.hasPrefix("'"))
        #expect(sanitized == "'+1+1")
    }

    @Test("Sanitizes CSV cells starting with -")
    internal func sanitizeMinusFormula() {
        internal let dangerous = "-AVERAGE(A1:A10)"
        internal let sanitized = AppState.sanitizeCSVCell(dangerous)
        #expect(sanitized.hasPrefix("'"))
        #expect(sanitized == "'-AVERAGE(A1:A10)")
    }

    @Test("Sanitizes CSV cells starting with @")
    internal func sanitizeAtFormula() {
        internal let dangerous = "@SUM(A1:A10)"
        internal let sanitized = AppState.sanitizeCSVCell(dangerous)
        #expect(sanitized.hasPrefix("'"))
        #expect(sanitized == "'@SUM(A1:A10)")
    }

    @Test("Does not modify safe content")
    internal func leaveSafeContentUnchanged() {
        internal let safe = "Normal Item Name"
        internal let sanitized = AppState.sanitizeCSVCell(safe)
        #expect(sanitized == safe)
    }

    @Test("Sanitizes dangerous Excel commands")
    internal func sanitizeDangerousCommands() {
        internal let dangerous = "=SYSTEM(\"rm -rf /\")"
        internal let sanitized = AppState.sanitizeCSVCell(dangerous)
        #expect(sanitized.hasPrefix("'"))
        #expect(!sanitized.contains("SYSTEM"))  // Still contains but prefixed
    }

    // MARK: - CSV Parsing (Quote Escaping)

    @Test("Parses escaped quotes correctly")
    internal func parseEscapedQuotes() {
        internal let input = "Name,\"Description with \"\"quotes\"\"\""
        internal let parsed = AppState.parseCSVLine(input)
        #expect(parsed.count == 2)
        #expect(parsed[0] == "Name")
        #expect(parsed[1] == "Description with \"quotes\"")
    }

    @Test("Handles empty fields")
    internal func parseEmptyFields() {
        internal let input = "Field1,,Field3"
        internal let parsed = AppState.parseCSVLine(input)
        #expect(parsed.count == 3)
        #expect(parsed[0] == "Field1")
        #expect(parsed[1] == "")
        #expect(parsed[2] == "Field3")
    }

    @Test("Handles quoted fields with commas")
    internal func parseQuotedFieldsWithCommas() {
        internal let input = "Name,\"Last, First\",Age"
        internal let parsed = AppState.parseCSVLine(input)
        #expect(parsed.count == 3)
        #expect(parsed[0] == "Name")
        #expect(parsed[1] == "Last, First")
        #expect(parsed[2] == "Age")
    }

    @Test("Handles complex quoted content")
    internal func parseComplexQuotes() {
        internal let input = "\"Field with \"\"nested\"\" quotes and, comma\""
        internal let parsed = AppState.parseCSVLine(input)
        #expect(parsed.count == 1)
        #expect(parsed[0] == "Field with \"nested\" quotes and, comma")
    }

    // MARK: - Duplicate ID Prevention

    @Test("Generates unique IDs for duplicate items", .enabled(if: false))
    internal func generateUniqueIDsForDuplicates() async throws {
        // This test requires actual CSV import implementation
        // Placeholder for when import logic is testable

        internal let csv = """
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
    internal func handleMalformedCSV() async throws {
        // Test that malformed CSV doesn't crash or cause data corruption

        internal let malformed = """
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
