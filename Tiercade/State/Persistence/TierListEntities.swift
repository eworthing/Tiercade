import Foundation
import SwiftData

@Model
final class TierListEntity {
    @Attribute(.unique) var identifier: UUID
    internal var title: String
    internal var fileName: String?
    internal var createdAt: Date
    internal var updatedAt: Date
    internal var isActive: Bool
    internal var cardDensityRaw: String
    internal var selectedThemeID: UUID?
    internal var customThemesData: Data?
    internal var globalSortModeData: Data?
    internal var sourceRaw: String
    internal var externalIdentifier: String?
    internal var subtitle: String?
    internal var iconSystemName: String?
    internal var lastOpenedAt: Date
    internal var projectData: Data?
    @Relationship(deleteRule: .cascade, inverse: \TierEntity.list)
    internal var tiers: [TierEntity]

    internal init(
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
        tiers: [TierEntity] = []
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
}

@Model
final class TierEntity {
    @Attribute(.unique) var identifier: UUID
    internal var key: String
    internal var displayName: String
    internal var colorHex: String?
    internal var order: Int
    internal var isLocked: Bool
    @Relationship(deleteRule: .cascade, inverse: \TierItemEntity.tier)
    internal var items: [TierItemEntity]
    @Relationship var list: TierListEntity?

    internal init(
        identifier: UUID = UUID(),
        key: String,
        displayName: String,
        colorHex: String?,
        order: Int,
        isLocked: Bool,
        items: [TierItemEntity] = []
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

@Model
final class TierItemEntity {
    @Attribute(.unique) var identifier: UUID
    internal var itemID: String
    internal var name: String?
    internal var seasonString: String?
    internal var seasonNumber: Int?
    internal var status: String?
    internal var details: String?
    internal var imageUrl: String?
    internal var videoUrl: String?
    internal var position: Int
    @Relationship var tier: TierEntity?

    internal init(
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
        tier: TierEntity? = nil
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

internal extension TierEntity {
    internal var normalizedKey: String {
        key.lowercased() == "unranked" ? "unranked" : key
    }
}
