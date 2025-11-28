//
//  AppState+LegacyMigration.swift
//  Tiercade
//
//  Created by AI Assistant on 9/30/25.
//  Migration utilities for legacy save file formats
//

import Foundation
import SwiftUI
import TiercadeCore

@MainActor
internal extension AppState {

    /// Save file structure for migration
    private struct AppSaveFile: Codable {
        let tiers: Items
        let createdDate: Date
        let appVersion: String
    }

    /// One-time migration utility for pre-1.0 save files
    /// Converts legacy flat JSON format to modern Items structure
    func migrateLegacySaveFile(at url: URL) async throws -> Items {
        let data = try Data(contentsOf: url)

        // Try modern format first
        if let saveData = try? JSONDecoder().decode(AppSaveFile.self, from: data) {
            return saveData.tiers
        }

        // Try standard Items format
        if let items = try? JSONDecoder().decode(Items.self, from: data) {
            return items
        }

        // Legacy fallback with detailed error reporting
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MigrationError.unrecognizedFormat
        }

        // Check for legacy tier structure
        if let tierData = json["tiers"] as? [String: [[String: Any]]] {
            return try migrateLegacyTierStructure(tierData)
        }

        // Check for flat item array
        if let items = json["items"] as? [[String: Any]] {
            return try migrateFlatItemStructure(items)
        }

        throw MigrationError.unrecognizedFormat
    }

    /// Migrate legacy tier-based structure
    private func migrateLegacyTierStructure(_ tierData: [String: [[String: Any]]]) throws -> Items {
        var migratedTiers: Items = [:]

        for (tierName, itemData) in tierData {
            migratedTiers[tierName] = try itemData.map { dict in
                guard let id = dict["id"] as? String else {
                    throw MigrationError.missingRequiredField("id")
                }

                // Extract attributes from remaining fields
                var attributes: [String: String] = [:]
                for (key, value) in dict where key != "id" {
                    attributes[key] = String(describing: value)
                }

                return Item(id: id, attributes: attributes.isEmpty ? nil : attributes)
            }
        }

        return migratedTiers
    }

    /// Migrate flat item array (legacy export format)
    private func migrateFlatItemStructure(_ items: [[String: Any]]) throws -> Items {
        var migratedTiers: Items = [
            "S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []
        ]

        for itemDict in items {
            guard let id = itemDict["id"] as? String else {
                throw MigrationError.missingRequiredField("id")
            }

            let tier = (itemDict["tier"] as? String) ?? "unranked"
            var attributes: [String: String] = [:]

            for (key, value) in itemDict where key != "id" && key != "tier" {
                attributes[key] = String(describing: value)
            }

            let item = Item(id: id, attributes: attributes.isEmpty ? nil : attributes)
            migratedTiers[tier, default: []].append(item)
        }

        return migratedTiers
    }

    /// Save migrated file in modern format with backup
    func saveMigratedFile(_ tiers: Items, originalURL: URL) async throws {
        // Create backup of original file
        let backupURL = originalURL.deletingPathExtension()
            .appendingPathExtension("legacy.backup.json")

        if !FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.copyItem(at: originalURL, to: backupURL)
        }

        // Save in modern format
        let saveData = AppSaveFile(
            tiers: tiers,
            createdDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0-migrated"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(saveData)
        try data.write(to: originalURL)

        showSuccessToast("Migration Complete", message: "Legacy save file upgraded. Backup saved.")
    }

    /// Check if a file needs migration
    func needsMigration(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }

        // If it decodes as modern format, no migration needed
        if (try? JSONDecoder().decode(AppSaveFile.self, from: data)) != nil {
            return false
        }

        // If it decodes as Items, no migration needed
        if (try? JSONDecoder().decode(Items.self, from: data)) != nil {
            return false
        }

        // If it has legacy structure markers, migration needed
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if json["tiers"] != nil || json["items"] != nil {
                return true
            }
        }

        return false
    }

    /// Migration errors
    enum MigrationError: LocalizedError {
        case unrecognizedFormat
        case missingRequiredField(String)
        case corruptedData

        var errorDescription: String? {
            switch self {
            case .unrecognizedFormat:
                return "Unrecognized save file format. Please contact support with your backup file."
            case .missingRequiredField(let field):
                return "Save file is missing required field: \(field)"
            case .corruptedData:
                return "Save file data is corrupted and cannot be migrated."
            }
        }
    }
}

// MARK: - Migration Helper View

internal struct LegacyMigrationView: View {
    @Bindable var app: AppState
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var migrationError: Error?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(TypeScale.wizardIcon)
                .foregroundColor(.orange)

            Text("Legacy Save File Detected")
                .font(.title2.bold())

            Text("This save file uses an older format. Would you like to upgrade it to the modern format?")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if let error = migrationError {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Upgrade") {
                    Task {
                        await performMigration()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }
            .padding(.top)
        }
        .padding(40)
        .frame(maxWidth: 400)
        .background(Palette.cardBackground.opacity(0.95))
        .cornerRadius(16)
        .shadow(radius: 20)
    }

    private func performMigration() async {
        isLoading = true
        migrationError = nil

        do {
            let migratedTiers = try await app.migrateLegacySaveFile(at: fileURL)
            try await app.saveMigratedFile(migratedTiers, originalURL: fileURL)
            app.tiers = migratedTiers

            dismiss()
        } catch {
            migrationError = error
            isLoading = false
        }
    }
}
