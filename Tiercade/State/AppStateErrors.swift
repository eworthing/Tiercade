import Foundation

// MARK: - ExportError

/// Errors that can occur during export operations
enum ExportError: Error {
    case formatNotSupported(ExportFormat)
    case dataEncodingFailed(String)
    case insufficientData
    case renderingFailed(String)
    case invalidConfiguration

    var localizedDescription: String {
        switch self {
        case let .formatNotSupported(format):
            "Export format '\(format.displayName)' is not supported on this platform"
        case let .dataEncodingFailed(reason):
            "Failed to encode data: \(reason)"
        case .insufficientData:
            "No data available to export"
        case let .renderingFailed(reason):
            "Rendering failed: \(reason)"
        case .invalidConfiguration:
            "Invalid export configuration"
        }
    }
}

// MARK: - ImportError

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
        case let .invalidFormat(details):
            "Invalid format: \(details)"
        case let .invalidData(details):
            "Invalid data: \(details)"
        case let .missingRequiredField(field):
            "Missing required field: \(field)"
        case .corruptedData:
            "Data is corrupted and cannot be read"
        case .unsupportedVersion:
            "This file version is not supported"
        case let .parsingFailed(reason):
            "Parsing failed: \(reason)"
        }
    }
}

// MARK: - PersistenceError

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
        case let .encodingFailed(reason):
            "Encoding failed: \(reason)"
        case let .decodingFailed(reason):
            "Decoding failed: \(reason)"
        case let .fileSystemError(details):
            "File system error: \(details)"
        case .permissionDenied:
            "Permission denied to access storage"
        case .diskSpaceInsufficient:
            "Insufficient disk space"
        case .corruptedStorage:
            "Storage is corrupted"
        }
    }
}
