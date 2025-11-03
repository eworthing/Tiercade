import Foundation
import SwiftUI
import os
import TiercadeCore

// MARK: - File System Helpers

internal extension AppState {
    internal func getAvailableSaveFiles() -> [String] {
        do {
            internal let projects = try projectsDirectory()
            internal let fileURLs = try FileManager.default.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil)
            return fileURLs
                .filter { $0.pathExtension == "tierproj" }
                .map { $0.deletingPathExtension().lastPathComponent }
                .sorted()
        } catch {
            Logger.persistence.error("Could not list save files: \(error.localizedDescription)")
            return []
        }
    }

    internal func writeProjectBundle(_ artifacts: ProjectExportArtifacts, to destination: URL) throws(PersistenceError) {
        internal let fileManager = FileManager.default

        do {
            try ensureDirectoryExists(at: destination.deletingLastPathComponent())
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }

            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

            internal let projectURL = destination.appendingPathComponent("project.json")
            internal let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            internal let data = try encoder.encode(artifacts.project)
            try data.write(to: projectURL, options: .atomic)

            for exportFile in artifacts.files {
                // Validate relative path to prevent traversal attacks
                guard try validateExportPath(exportFile.relativePath) else {
                    throw PersistenceError.fileSystemError(
                        "Export path contains invalid components (traversal attempt): \(exportFile.relativePath)"
                    )
                }

                internal let destinationURL = destination.appendingPathComponent(exportFile.relativePath)
                try fileManager.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if fileManager.fileExists(atPath: destinationURL.path) {
                    continue
                }
                guard fileManager.fileExists(atPath: exportFile.sourceURL.path) else {
                    throw PersistenceError.fileSystemError("Missing media asset at \(exportFile.sourceURL.path)")
                }
                try fileManager.copyItem(at: exportFile.sourceURL, to: destinationURL)
            }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.fileSystemError("Failed to assemble bundle: \(error.localizedDescription)")
        }
    }

    internal func loadProjectBundle(from url: URL) throws -> Project {
        internal let fileManager = FileManager.default

        do {
            guard fileManager.fileExists(atPath: url.path) else {
                throw PersistenceError.fileSystemError("Bundle not found at \(url.path)")
            }

            internal let projectURL = url.appendingPathComponent("project.json")
            guard fileManager.fileExists(atPath: projectURL.path) else {
                throw PersistenceError.fileSystemError("Missing project.json in \(url.path)")
            }

            internal let data = try Data(contentsOf: projectURL)
            internal let project = try ModelResolver.decodeProject(from: data)
            return try relocateProject(project, extractedAt: url)
        } catch let error as PersistenceError {
            throw error
        } catch let error as ImportError {
            throw error
        } catch let error as DecodingError {
            throw ImportError.parsingFailed(error.localizedDescription)
        } catch let error as NSError where error.domain == "Tiercade" {
            throw ImportError.invalidData(error.localizedDescription)
        } catch {
            throw PersistenceError.fileSystemError("Failed to read bundle: \(error.localizedDescription)")
        }
    }

    internal func relocateProject(_ project: Project, extractedAt tempDirectory: URL) throws -> Project {
        internal var updatedItems: [String: Project.Item] = [:]
        for (id, item) in project.items {
            internal var newItem = item
            if let result = try relocateMediaList(item.media, extractedAt: tempDirectory) {
                newItem.media = result.list
                if var attributes = item.attributes {
                    if let thumb = result.primaryThumb {
                        attributes["thumbUri"] = .string(thumb)
                    }
                    newItem.attributes = attributes
                }
            }
            updatedItems[id] = newItem
        }

        internal var updatedOverrides = project.overrides
        if let overrides = project.overrides {
            internal var mapped: [String: Project.ItemOverride] = [:]
            for (id, override) in overrides {
                internal var newOverride = override
                if let result = try relocateMediaList(override.media, extractedAt: tempDirectory) {
                    newOverride.media = result.list
                }
                mapped[id] = newOverride
            }
            updatedOverrides = mapped
        }

        internal var output = project
        output.items = updatedItems
        output.overrides = updatedOverrides
        return output
    }

    internal struct MediaRelocationResult {
        internal let list: [Project.Media]
        internal let primaryThumb: String?
    }

    internal func relocateMediaList(
        _ mediaList: [Project.Media]?,
        extractedAt tempDirectory: URL
    ) throws -> MediaRelocationResult? {
        guard let mediaList else { return nil }
        internal var relocated: [Project.Media] = []
        internal var firstThumb: String?

        for media in mediaList {
            internal let updated = try relocateMedia(media, extractedAt: tempDirectory)
            if firstThumb == nil, let thumb = updated.thumbUri {
                firstThumb = thumb
            }
            relocated.append(updated)
        }

        return MediaRelocationResult(list: relocated, primaryThumb: firstThumb)
    }

    internal func relocateMedia(_ media: Project.Media, extractedAt tempDirectory: URL) throws -> Project.Media {
        internal var updated = media

        internal let uri = media.uri
        if let destination = try relocateFile(fromBundleURI: uri, extractedAt: tempDirectory) {
            updated.uri = destination.absoluteString
        }

        if let thumb = media.thumbUri,
           internal let destination = try relocateFile(fromBundleURI: thumb, extractedAt: tempDirectory) {
            updated.thumbUri = destination.absoluteString
        }

        return updated
    }

    internal func relocateFile(fromBundleURI uri: String, extractedAt tempDirectory: URL) throws -> URL? {
        guard let relativePath = bundleRelativePath(from: uri) else { return nil }

        internal let fileManager = FileManager.default
        // Canonicalize and ensure the source lives under the extraction directory
        internal let base = tempDirectory.resolvingSymlinksInPath()
        internal let sourceURL = base.appendingPathComponent(relativePath).resolvingSymlinksInPath()
        guard sourceURL.path.hasPrefix(base.path + "/"), fileManager.fileExists(atPath: sourceURL.path) else {
            throw PersistenceError.fileSystemError("Missing asset inside bundle at \(relativePath)")
        }

        internal let destinationBase: URL
        if relativePath.hasPrefix("Media/") {
            destinationBase = try mediaStoreDirectory()
        } else if relativePath.hasPrefix("Thumbs/") {
            destinationBase = try thumbsStoreDirectory()
        } else {
            destinationBase = try mediaStoreDirectory()
        }

        internal let fileName = (relativePath as NSString).lastPathComponent
        internal let destinationURL = destinationBase.appendingPathComponent(fileName)
        try copyReplacingItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    internal func projectsDirectory() throws -> URL {
        internal let root = try applicationSupportRoot()
        internal let directory = root.appendingPathComponent("Projects", isDirectory: true)
        try ensureDirectoryExists(at: directory)
        return directory
    }

    internal func mediaStoreDirectory() throws -> URL {
        internal let root = try applicationSupportRoot()
        internal let directory = root.appendingPathComponent("Media", isDirectory: true)
        try ensureDirectoryExists(at: directory)
        return directory
    }

    internal func thumbsStoreDirectory() throws -> URL {
        internal let root = try applicationSupportRoot()
        internal let directory = root.appendingPathComponent("Thumbs", isDirectory: true)
        try ensureDirectoryExists(at: directory)
        return directory
    }

    internal func applicationSupportRoot() throws -> URL {
        internal let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        internal let root = base.appendingPathComponent("Tiercade", isDirectory: true)
        try ensureDirectoryExists(at: root)
        return root
    }

    internal func ensureDirectoryExists(at url: URL) throws {
        internal var isDirectory: ObjCBool = false
        internal let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if exists {
            if !isDirectory.boolValue {
                throw PersistenceError.fileSystemError("Expected directory at \(url.path) but found a file.")
            }
            return
        }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw PersistenceError.fileSystemError(
                "Could not create directory at \(url.path): \(error.localizedDescription)"
            )
        }
    }

    internal func copyReplacingItem(at source: URL, to destination: URL) throws {
        internal let fileManager = FileManager.default
        try ensureDirectoryExists(at: destination.deletingLastPathComponent())
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            throw PersistenceError.fileSystemError(
                "Failed to copy asset to \(destination.path): \(error.localizedDescription)"
            )
        }
    }

    internal func bundleRelativePath(from uri: String) -> String? {
        guard uri.hasPrefix("file://") else { return nil }
        internal let trimmed = String(uri.dropFirst("file://".count))
        internal let path = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
        // Reject attempts at path traversal or absolute paths
        if path.contains("..") || path.hasPrefix("/") { return nil }
        return path
    }

    /// Validates that an export path doesn't contain traversal sequences
    /// Returns true if path is safe, false if it should be rejected
    private func validateExportPath(_ path: String) throws(PersistenceError) -> Bool {
        // Reject absolute paths
        guard !path.hasPrefix("/") else { return false }

        // Reject paths with traversal sequences
        guard !path.contains("..") else { return false }

        // Canonicalize and verify it stays relative
        internal let components = path.split(separator: "/").map(String.init)
        internal var normalized: [String] = []
        for component in components {
            if component == ".." {
                return false  // Reject any .. components
            } else if component != "." && !component.isEmpty {
                normalized.append(component)
            }
        }

        // Ensure the normalized path is non-empty and still relative
        return !normalized.isEmpty && !normalized.joined(separator: "/").hasPrefix("/")
    }

    internal func sanitizeFileName(_ fileName: String) -> String {
        internal let sanitized = fileName
            .replacingOccurrences(of: "[^A-Za-z0-9-_]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return sanitized.isEmpty ? "tiercade-project" : sanitized
    }
    // MARK: - SwiftData helpers

}
