import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Test Reporting

@available(iOS 26.0, macOS 26.0, *)
@MainActor
extension AcceptanceTestSuite {
static func saveReport(
    _ report: TestReport,
    to path: String,
    logger: @escaping (String) -> Void = { print($0) }
) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    try data.write(to: URL(fileURLWithPath: path))
    logger("📄 Test report saved: \(path)")
}
}
#endif
