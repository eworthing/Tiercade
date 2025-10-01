import Foundation

// MARK: - Typed Error Domains for Swift 6

/// Errors that can occur during export operations
enum ExportError: Error {
    case formatNotSupported(ExportFormat)
    case dataEncodingFailed(String)
    case insufficientData
    case renderingFailed(String)
    case invalidConfiguration

    var localizedDescription: String {
        switch self {
        case .formatNotSupported(let format):
            return "Export format '\(format.displayName)' is not supported on this platform"
        case .dataEncodingFailed(let reason):
            return "Failed to encode data: \(reason)"
        case .insufficientData:
            return "No data available to export"
        case .renderingFailed(let reason):
            return "Rendering failed: \(reason)"
        case .invalidConfiguration:
            return "Invalid export configuration"
        }
    }
}

/// Errors that can occur during import operations
enum ImportError: Error {
    case invalidFormat(String)
    case invalidData(String)
    case missingRequiredField(String)
    case corruptedData
    case unsupportedVersion
    case parsingFailed(String)

    var localizedDescription: String {
        switch self {
        case .invalidFormat(let details):
            return "Invalid format: \(details)"
        case .invalidData(let details):
            return "Invalid data: \(details)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .corruptedData:
            return "Data is corrupted and cannot be read"
        case .unsupportedVersion:
            return "This file version is not supported"
        case .parsingFailed(let reason):
            return "Parsing failed: \(reason)"
        }
    }
}

/// Errors that can occur during persistence operations
enum PersistenceError: Error {
    case encodingFailed(String)
    case decodingFailed(String)
    case fileSystemError(String)
    case permissionDenied
    case diskSpaceInsufficient
    case corruptedStorage

    var localizedDescription: String {
        switch self {
        case .encodingFailed(let reason):
            return "Encoding failed: \(reason)"
        case .decodingFailed(let reason):
            return "Decoding failed: \(reason)"
        case .fileSystemError(let details):
            return "File system error: \(details)"
        case .permissionDenied:
            return "Permission denied to access storage"
        case .diskSpaceInsufficient:
            return "Insufficient disk space"
        case .corruptedStorage:
            return "Storage is corrupted"
        }
    }
}
