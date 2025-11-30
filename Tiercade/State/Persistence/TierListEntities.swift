import Foundation
import SwiftData

// MARK: - TierListEntity

@Model
final class TierListEntity {

    // MARK: Lifecycle

    init(
        identifier: UUID = UUID(),
        title: String,
        fileName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isActive: Bool = true,
        cardDensityRaw: String,
        selectedThemeID: UUID?,
        customThemesData: Data? = nil,
        globalSortModeData: Data? = nil,
        sourceRaw: String = TierListSource.bundled.rawValue,
        externalIdentifier: String? = nil,
        subtitle: String? = nil,
        iconSystemName: String? = nil,
        lastOpenedAt: Date = Date(),
        projectData: Data? = nil,
        tiers: [TierEntity] = [],
    ) {
        self.identifier = identifier
        self.title = title
        self.fileName = fileName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
        self.cardDensityRaw = cardDensityRaw
        self.selectedThemeID = selectedThemeID
        self.customThemesData = customThemesData
        self.globalSortModeData = globalSortModeData
        self.sourceRaw = sourceRaw
        self.externalIdentifier = externalIdentifier
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.lastOpenedAt = lastOpenedAt
        self.projectData = projectData
        self.tiers = tiers
    }

    // MARK: Internal

    @Attribute(.unique) var identifier: UUID
    var title: String
    var fileName: String?
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool
    var cardDensityRaw: String
    var selectedThemeID: UUID?
    var customThemesData: Data?
    var globalSortModeData: Data?
    var sourceRaw: String
    var externalIdentifier: String?
    var subtitle: String?
    var iconSystemName: String?
    var lastOpenedAt: Date
    var projectData: Data?
    @Relationship(deleteRule: .cascade, inverse: \TierEntity.list)
    var tiers: [TierEntity]

}

// MARK: - TierEntity

@Model
final class TierEntity {
    @Attribute(.unique) var identifier: UUID
    var key: String
    var displayName: String
    var colorHex: String?
    var order: Int
    var isLocked: Bool
    @Relationship(deleteRule: .cascade, inverse: \TierItemEntity.tier)
    var items: [TierItemEntity]
    @Relationship var list: TierListEntity?

    init(
        identifier: UUID = UUID(),
        key: String,
        displayName: String,
        colorHex: String?,
        order: Int,
        isLocked: Bool,
        items: [TierItemEntity] = [],
    ) {
        self.identifier = identifier
        self.key = key
        self.displayName = displayName
        self.colorHex = colorHex
        self.order = order
        self.isLocked = isLocked
        self.items = items
    }
}

// MARK: - TierItemEntity

@Model
final class TierItemEntity {
    @Attribute(.unique) var identifier: UUID
    var itemID: String
    var name: String?
    var seasonString: String?
    var seasonNumber: Int?
    var status: String?
    var details: String?
    var imageUrl: String?
    var videoUrl: String?
    var position: Int
    @Relationship var tier: TierEntity?

    init(
        identifier: UUID = UUID(),
        itemID: String,
        name: String?,
        seasonString: String?,
        seasonNumber: Int?,
        status: String?,
        details: String?,
        imageUrl: String?,
        videoUrl: String?,
        position: Int = 0,
        tier: TierEntity? = nil,
    ) {
        self.identifier = identifier
        self.itemID = itemID
        self.name = name
        self.seasonString = seasonString
        self.seasonNumber = seasonNumber
        self.status = status
        self.details = details
        self.imageUrl = imageUrl
        self.videoUrl = videoUrl
        self.position = position
        self.tier = tier
    }
}

extension TierEntity {
    var normalizedKey: String {
        key.lowercased() == "unranked" ? "unranked" : key
    }
}
