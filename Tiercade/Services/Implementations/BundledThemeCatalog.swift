import Foundation
import os
import SwiftData

/// Theme catalog that provides bundled system themes and user custom themes
///
/// This implementation wraps TierThemeCatalog for bundled themes and
/// uses SwiftData for persisting custom themes.
@MainActor
final class BundledThemeCatalog: ThemeCatalogProviding {

    // MARK: Lifecycle

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: Internal

    func allThemes() async -> [TierTheme] {
        let bundled = await bundledThemes()
        let custom = await customThemes()
        return bundled + custom
    }

    func bundledThemes() async -> [TierTheme] {
        TierThemeCatalog.allThemes
    }

    func customThemes() async -> [TierTheme] {
        do {
            let descriptor = FetchDescriptor<TierThemeEntity>(
                sortBy: [SortDescriptor(\.displayName)],
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { TierTheme(entity: $0) }
        } catch {
            logger.error("Failed to fetch custom themes: \(error.localizedDescription)")
            return []
        }
    }

    func saveCustomTheme(_ theme: TierTheme) async throws {
        do {
            // Check if theme already exists
            let themeID = theme.id
            let descriptor = FetchDescriptor<TierThemeEntity>(
                predicate: #Predicate { $0.themeID == themeID },
            )
            let existing = try modelContext.fetch(descriptor).first

            if let existing {
                // Update existing theme
                existing.slug = theme.slug
                existing.displayName = theme.displayName
                existing.shortDescription = theme.shortDescription

                // Remove old tiers
                for tier in existing.tiers {
                    modelContext.delete(tier)
                }

                // Add new tiers
                existing.tiers = theme.tiers.map { tier in
                    let colorEntity = TierColorEntity(
                        tierID: tier.id,
                        index: tier.index,
                        name: tier.name,
                        colorHex: tier.colorHex,
                        isUnranked: tier.isUnranked,
                        theme: existing,
                    )
                    return colorEntity
                }
            } else {
                // Create new theme
                let colorEntities = theme.tiers.map { tier in
                    TierColorEntity(
                        tierID: tier.id,
                        index: tier.index,
                        name: tier.name,
                        colorHex: tier.colorHex,
                        isUnranked: tier.isUnranked,
                    )
                }

                let entity = TierThemeEntity(
                    themeID: theme.id,
                    slug: theme.slug,
                    displayName: theme.displayName,
                    shortDescription: theme.shortDescription,
                    tiers: colorEntities,
                )
                modelContext.insert(entity)
            }

            try modelContext.save()

            logger.info("Saved custom theme: \(theme.displayName)")
        } catch {
            logger.error("Failed to save theme \(theme.displayName): \(error.localizedDescription)")
            throw ThemeError.saveFailed(error.localizedDescription)
        }
    }

    func deleteCustomTheme(id: String) async throws {
        guard let uuid = UUID(uuidString: id) else {
            throw ThemeError.themeNotFound(id)
        }

        // Check if it's a bundled theme
        if TierThemeCatalog.theme(id: uuid) != nil {
            throw ThemeError.cannotDeleteBundledTheme
        }

        do {
            let descriptor = FetchDescriptor<TierThemeEntity>(
                predicate: #Predicate { $0.themeID == uuid },
            )
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw ThemeError.themeNotFound(id)
            }

            modelContext.delete(entity)
            try modelContext.save()

            logger.info("Deleted custom theme: \(id)")
        } catch let error as ThemeError {
            throw error
        } catch {
            logger.error("Failed to delete theme \(id): \(error.localizedDescription)")
            throw ThemeError.saveFailed(error.localizedDescription)
        }
    }

    func findTheme(id: String) async -> TierTheme? {
        guard let uuid = UUID(uuidString: id) else {
            return nil
        }

        // Check bundled themes first
        if let bundled = TierThemeCatalog.theme(id: uuid) {
            return bundled
        }

        // Check custom themes
        do {
            let descriptor = FetchDescriptor<TierThemeEntity>(
                predicate: #Predicate { $0.themeID == uuid },
            )
            if let entity = try modelContext.fetch(descriptor).first {
                return TierTheme(entity: entity)
            }
        } catch {
            logger.error("Failed to find theme \(id): \(error.localizedDescription)")
        }

        return nil
    }

    // MARK: Private

    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.tiercade.themes", category: "Catalog")

}

// Note: TierThemeEntity is defined in Design/TierThemeSchema.swift
// and is already part of the SwiftData schema.
//
// Note: ThemeCatalogProviding protocol requires Sendable conformance.
// Since BundledThemeCatalog is @MainActor and all its methods are async,
// it can safely conform to Sendable through the protocol.
