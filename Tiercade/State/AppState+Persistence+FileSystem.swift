import Foundation
import SwiftUI
import os
import TiercadeCore

// MARK: - File System Helpers

extension AppState {
    func getAvailableSaveFiles() -> [String] {
        do {
            let projects = try projectsDirectory()
            let fileURLs = try FileManager.default.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil)
            return fileURLs
                .filter { $0.pathExtension == "tierproj" }
                .map { $0.deletingPathExtension().lastPathComponent }
                .sorted()
        } catch {
            Logger.persistence.error("Could not list save files: \(error.localizedDescription)")
            return []
        }
    }

    func writeProjectBundle(_ artifacts: ProjectExportArtifacts, to destination: URL) throws(PersistenceError) {
        let fileManager = FileManager.default

        do {
            try ensureDirectoryExists(at: destination.deletingLastPathComponent())
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }

            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

            let projectURL = destination.appendingPathComponent("project.json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(artifacts.project)
            try data.write(to: projectURL, options: .atomic)

            for exportFile in artifacts.files {
                let destinationURL = destination.appendingPathComponent(exportFile.relativePath)
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

    func loadProjectBundle(from url: URL) throws -> Project {
        let fileManager = FileManager.default

        do {
            guard fileManager.fileExists(atPath: url.path) else {
                throw PersistenceError.fileSystemError("Bundle not found at \(url.path)")
            }

            let projectURL = url.appendingPathComponent("project.json")
            guard fileManager.fileExists(atPath: projectURL.path) else {
                throw PersistenceError.fileSystemError("Missing project.json in \(url.path)")
            }

            let data = try Data(contentsOf: projectURL)
            let project = try ModelResolver.decodeProject(from: data)
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

    func relocateProject(_ project: Project, extractedAt tempDirectory: URL) throws -> Project {
        var updatedItems: [String: Project.Item] = [:]
        for (id, item) in project.items {
            var newItem = item
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

        var updatedOverrides = project.overrides
        if let overrides = project.overrides {
            var mapped: [String: Project.ItemOverride] = [:]
            for (id, override) in overrides {
                var newOverride = override
                if let result = try relocateMediaList(override.media, extractedAt: tempDirectory) {
                    newOverride.media = result.list
                }
                mapped[id] = newOverride
            }
            updatedOverrides = mapped
        }

        var output = project
        output.items = updatedItems
        output.overrides = updatedOverrides
        return output
    }

    struct MediaRelocationResult {
        let list: [Project.Media]
        let primaryThumb: String?
    }

    func relocateMediaList(
        _ mediaList: [Project.Media]?,
        extractedAt tempDirectory: URL
    ) throws -> MediaRelocationResult? {
        guard let mediaList else { return nil }
        var relocated: [Project.Media] = []
        var firstThumb: String?

        for media in mediaList {
            let updated = try relocateMedia(media, extractedAt: tempDirectory)
            if firstThumb == nil, let thumb = updated.thumbUri {
                firstThumb = thumb
            }
            relocated.append(updated)
        }

        return MediaRelocationResult(list: relocated, primaryThumb: firstThumb)
    }

    func relocateMedia(_ media: Project.Media, extractedAt tempDirectory: URL) throws -> Project.Media {
        var updated = media

        let uri = media.uri
        if let destination = try relocateFile(fromBundleURI: uri, extractedAt: tempDirectory) {
            updated.uri = destination.absoluteString
        }

        if let thumb = media.thumbUri,
           let destination = try relocateFile(fromBundleURI: thumb, extractedAt: tempDirectory) {
            updated.thumbUri = destination.absoluteString
        }

        return updated
    }

    func relocateFile(fromBundleURI uri: String, extractedAt tempDirectory: URL) throws -> URL? {
        guard let relativePath = bundleRelativePath(from: uri) else { return nil }

        let fileManager = FileManager.default
        let sourceURL = tempDirectory.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw PersistenceError.fileSystemError("Missing asset inside bundle at \(relativePath)")
        }

        let destinationBase: URL
        if relativePath.hasPrefix("Media/") {
            destinationBase = try mediaStoreDirectory()
        } else if relativePath.hasPrefix("Thumbs/") {
            destinationBase = try thumbsStoreDirectory()
        } else {
            destinationBase = try mediaStoreDirectory()
        }

        let fileName = (relativePath as NSString).lastPathComponent
        let destinationURL = destinationBase.appendingPathComponent(fileName)
        try copyReplacingItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    func projectsDirectory() throws -> URL {
        let root = try applicationSupportRoot()
        let directory = root.appendingPathComponent("Projects", isDirectory: true)
        try ensureDirectoryExists(at: directory)
        return directory
    }

    func mediaStoreDirectory() throws -> URL {
        let root = try applicationSupportRoot()
        let directory = root.appendingPathComponent("Media", isDirectory: true)
        try ensureDirectoryExists(at: directory)
        return directory
    }

    func thumbsStoreDirectory() throws -> URL {
        let root = try applicationSupportRoot()
        let directory = root.appendingPathComponent("Thumbs", isDirectory: true)
        try ensureDirectoryExists(at: directory)
        return directory
    }

    func applicationSupportRoot() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let root = base.appendingPathComponent("Tiercade", isDirectory: true)
        try ensureDirectoryExists(at: root)
        return root
    }

    func ensureDirectoryExists(at url: URL) throws {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
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

    func copyReplacingItem(at source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
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

    func bundleRelativePath(from uri: String) -> String? {
        guard uri.hasPrefix("file://") else { return nil }
        let trimmed = String(uri.dropFirst("file://".count))
        if trimmed.hasPrefix("/") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    func sanitizeFileName(_ fileName: String) -> String {
        let sanitized = fileName
            .replacingOccurrences(of: "[^A-Za-z0-9-_]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return sanitized.isEmpty ? "tiercade-project" : sanitized
    }
    // MARK: - SwiftData helpers

}
