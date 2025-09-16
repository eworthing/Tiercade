import Foundation
import SwiftUI
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Enhanced Persistence

    @discardableResult
    func save() -> Bool {
        do {
            let data = try JSONEncoder().encode(tiers)
            UserDefaults.standard.set(data, forKey: storageKey)
            hasUnsavedChanges = false
            lastSavedTime = Date()
            showSuccessToast("Saved", message: "Tier list saved successfully")
            return true
        } catch {
            print("Save failed: \(error)")
            showErrorToast("Save Failed", message: "Could not save tier list")
            return false
        }
    }
    
    @discardableResult
    func autoSave() -> Bool {
        guard hasUnsavedChanges else { return true }
        return save()
    }
    
    @discardableResult
    func saveToFile(named fileName: String) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            struct AppSaveFile: Codable {
                let tiers: Items
                let createdDate: Date
                let appVersion: String
            }

            let saveData = AppSaveFile(tiers: tiers, createdDate: Date(), appVersion: "1.0")

            let data = try encoder.encode(saveData)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
            
            try data.write(to: fileURL)
            
            currentFileName = fileName
            hasUnsavedChanges = false
            lastSavedTime = Date()
            
            showSuccessToast("File Saved", message: "Saved as \(fileName).json")
            return true
        } catch {
            print("File save failed: \(error)")
            showErrorToast("Save Failed", message: "Could not save \(fileName).json")
            return false
        }
    }

    @discardableResult
    func load() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return false }
        // Try to decode Items directly; if that fails, attempt legacy JSON fallbacks.
        do {
            let decoded = try JSONDecoder().decode(Items.self, from: data)
            tiers = decoded
            history = HistoryLogic.initHistory(tiers, limit: history.limit)
            hasUnsavedChanges = false
            lastSavedTime = UserDefaults.standard.object(forKey: "\(storageKey).timestamp") as? Date
            showSuccessToast("Loaded", message: "Tier list loaded successfully")
            return true
        } catch {
            // Fallback: try to parse as legacy JSON structure with attributes bags
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tierData = json["tiers"] as? [String: [[String: Any]]] {
                    var newTiers: Items = [:]
                    for (tierName, itemData) in tierData {
                        newTiers[tierName] = itemData.compactMap { dict in
                            guard let id = dict["id"] as? String else { return nil }
                            if let attrs = dict["attributes"] as? [String: String] {
                                return Item(id: id, attributes: attrs)
                            } else {
                                // Build attributes from top-level keys
                                var attrs: [String: String] = [:]
                                for (k, v) in dict where k != "id" {
                                    attrs[k] = String(describing: v)
                                }
                                return Item(id: id, attributes: attrs.isEmpty ? nil : attrs)
                            }
                        }
                    }
                    tiers = newTiers
                    history = HistoryLogic.initHistory(tiers, limit: history.limit)
                    hasUnsavedChanges = false
                    lastSavedTime = UserDefaults.standard.object(forKey: "\(storageKey).timestamp") as? Date
                    showSuccessToast("Loaded", message: "Tier list loaded (legacy) successfully")
                    return true
                }
            } catch {
                print("Legacy load failed: \(error)")
            }
            print("Load failed: \(error)")
            showErrorToast("Load Failed", message: "Could not load tier list")
            return false
        }
    }

    @discardableResult
    func loadFromFile(named fileName: String) -> Bool {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
            
            let data = try Data(contentsOf: fileURL)
            // Try to decode the modern app save file, fall back to legacy structures
            struct AppSaveFile: Codable { let tiers: Items; let createdDate: Date; let appVersion: String }

            if let saveData = try? JSONDecoder().decode(AppSaveFile.self, from: data) {
                tiers = saveData.tiers
                history = HistoryLogic.initHistory(tiers, limit: history.limit)
                currentFileName = fileName
                hasUnsavedChanges = false
                lastSavedTime = saveData.createdDate
                showSuccessToast("File Loaded", message: "Loaded \(fileName).json")
                return true
            }

            // Legacy fallback: parse JSON and build Items from attributes
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tierData = json["tiers"] as? [String: [[String: Any]]] {
                var newTiers: Items = [:]
                for (tierName, itemData) in tierData {
                    newTiers[tierName] = itemData.compactMap { dict in
                        guard let id = dict["id"] as? String else { return nil }
                        if let attrs = dict["attributes"] as? [String: String] {
                            return Item(id: id, attributes: attrs)
                        } else {
                            var attrs: [String: String] = [:]
                            for (k, v) in dict where k != "id" {
                                attrs[k] = String(describing: v)
                            }
                            return Item(id: id, attributes: attrs.isEmpty ? nil : attrs)
                        }
                    }
                }
                tiers = newTiers
                history = HistoryLogic.initHistory(tiers, limit: history.limit)
                currentFileName = fileName
                hasUnsavedChanges = false
                lastSavedTime = Date()
                showSuccessToast("File Loaded", message: "Loaded \(fileName).json")
                return true
            }
            history = HistoryLogic.initHistory(tiers, limit: history.limit)
            currentFileName = fileName
            hasUnsavedChanges = false
            lastSavedTime = Date()

            showSuccessToast("File Loaded", message: "Loaded \(fileName).json")
            return true
        } catch {
            print("File load failed: \(error)")
            showErrorToast("Load Failed", message: "Could not load \(fileName).json")
            return false
        }
    }

    func getAvailableSaveFiles() -> [String] {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            return fileURLs
                .filter { $0.pathExtension == "json" }
                .map { $0.deletingPathExtension().lastPathComponent }
                .sorted()
        } catch {
            print("Error listing save files: \(error)")
            return []
        }
    }

    func deleteSaveFile(named fileName: String) -> Bool {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            print("Error deleting save file: \(error)")
            return false
        }
    }

    // MARK: - Async File Operations with Progress Tracking

    func saveToFileAsync(named fileName: String) async -> Bool {
        return await withLoadingIndicator(message: "Saving \(fileName)...") {
            updateProgress(0.2)
            
            do {
                struct AppSaveFile: Codable {
                    let tiers: Items
                    let createdDate: Date
                    let appVersion: String
                }
                let saveData = AppSaveFile(tiers: tiers, createdDate: Date(), appVersion: "1.0")
                updateProgress(0.4)
                
                let data = try JSONEncoder().encode(saveData)
                updateProgress(0.6)
                
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
                updateProgress(0.8)
                
                try data.write(to: fileURL)
                
                await MainActor.run {
                    currentFileName = fileName
                    hasUnsavedChanges = false
                    lastSavedTime = Date()
                }
                updateProgress(1.0)
                
                showSuccessToast("File Saved", message: "Saved \(fileName).json")
                return true
            } catch {
                print("File save failed: \(error)")
                showErrorToast("Save Failed", message: "Could not save \(fileName).json")
                return false
            }
        }
    }

    func loadFromFileAsync(named fileName: String) async -> Bool {
        return await withLoadingIndicator(message: "Loading \(fileName)...") {
            updateProgress(0.2)
            
            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
                updateProgress(0.4)
                
                let data = try Data(contentsOf: fileURL)
                updateProgress(0.6)
                // Try modern save format first
                struct AppSaveFile: Codable { let tiers: Items; let createdDate: Date; let appVersion: String }
                if let saveData = try? JSONDecoder().decode(AppSaveFile.self, from: data) {
                    updateProgress(0.8)
                    await MainActor.run {
                        tiers = saveData.tiers
                        history = HistoryLogic.initHistory(tiers, limit: history.limit)
                        currentFileName = fileName
                        hasUnsavedChanges = false
                        lastSavedTime = saveData.createdDate
                    }
                } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let tierData = json["tiers"] as? [String: [[String: Any]]] {
                    // Legacy fallback
                    var newTiers: Items = [:]
                    for (tierName, itemData) in tierData {
                        newTiers[tierName] = itemData.compactMap { dict in
                            guard let id = dict["id"] as? String else { return nil }
                            if let attrs = dict["attributes"] as? [String: String] {
                                return Item(id: id, attributes: attrs)
                            } else {
                                var attrs: [String: String] = [:]
                                for (k, v) in dict where k != "id" {
                                    attrs[k] = String(describing: v)
                                }
                                return Item(id: id, attributes: attrs.isEmpty ? nil : attrs)
                            }
                        }
                    }
                    updateProgress(0.8)
                    await MainActor.run {
                        tiers = newTiers
                        history = HistoryLogic.initHistory(tiers, limit: history.limit)
                        currentFileName = fileName
                        hasUnsavedChanges = false
                        lastSavedTime = Date()
                    }
                } else {
                    throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unrecognized save file format"])
                }
                updateProgress(1.0)
                
                showSuccessToast("File Loaded", message: "Loaded \(fileName).json")
                return true
            } catch {
                print("File load failed: \(error)")
                showErrorToast("Load Failed", message: "Could not load \(fileName).json")
                return false
            }
        }
    }
}
