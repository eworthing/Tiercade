import Foundation
import SwiftData

@Model
final class TierColorEntity {
    var tierID: UUID
    var index: Int
    var name: String
    var colorHex: String
    var isUnranked: Bool
    @Relationship(inverse: \TierThemeEntity.tiers) var theme: TierThemeEntity?

    init(
        tierID: UUID = UUID(),
        index: Int,
        name: String,
        colorHex: String,
        isUnranked: Bool = false,
        theme: TierThemeEntity? = nil
    ) {
        self.tierID = tierID
        self.index = index
        self.name = name
        self.colorHex = colorHex
        self.isUnranked = isUnranked
        self.theme = theme
    }
}

@Model
final class TierThemeEntity {
    var themeID: UUID
    var slug: String
    var displayName: String
    var shortDescription: String
    @Relationship(deleteRule: .cascade) var tiers: [TierColorEntity]

    init(
        themeID: UUID = UUID(),
        slug: String,
        displayName: String,
        shortDescription: String,
        tiers: [TierColorEntity]
    ) {
        self.themeID = themeID
        self.slug = slug
        self.displayName = displayName
        self.shortDescription = shortDescription
        let normalizedTiers = TierThemeEntity.normalizeTiers(tiers)
        let orderedTiers = normalizedTiers.sorted { left, right in
            if left.isUnranked != right.isUnranked {
                return !left.isUnranked
            }
            return left.index < right.index
        }
        self.tiers = orderedTiers
        for tier in self.tiers {
            tier.theme = self
        }
    }
}

private extension TierThemeEntity {
    static func normalizeTiers(_ tiers: [TierColorEntity]) -> [TierColorEntity] {
        var rankedKeys = Set<String>()
        var hasUnranked = false

        return tiers.reduce(into: [TierColorEntity]()) { result, tier in
            if tier.isUnranked {
                guard !hasUnranked else { return }
                hasUnranked = true
                result.append(tier)
                return
            }

            let key = normalizedKey(for: tier)
            guard rankedKeys.insert(key).inserted else { return }
            result.append(tier)
        }
    }

    static func normalizedKey(for tier: TierColorEntity) -> String {
        "\(tier.index)|\(normalizeName(tier.name))"
    }

    static func normalizeName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

@MainActor
enum TierThemeSeeds {
    static let defaults: [TierThemeEntity] = seedDefinitions

    private static let seedDefinitions: [TierThemeEntity] = [
        TierThemeEntity(
            themeID: UUID(uuidString: "E96B8A5D-7E1F-4B6C-9D4A-8BC3F46F2E9C")!,
            slug: "smashClassic",
            displayName: "Smash Classic",
            shortDescription: "Classic tier list colors",
            tiers: [
                TierColorEntity(
                    tierID: UUID(uuidString: "6E5CE5A0-3D46-49F7-8A6C-1245C4B32EC6")!,
                    index: 0,
                    name: "S",
                    colorHex: "#FF0000"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "3252B9B6-8B2B-4F4B-A7A6-38B12D7CE328")!,
                    index: 1,
                    name: "A",
                    colorHex: "#FF8000"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "01F35ECA-6B60-4605-9E6C-2705D77EDB9A")!,
                    index: 2,
                    name: "B",
                    colorHex: "#FFFF00"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "425D0B6F-4851-4E5C-A698-7A1F174F6E6B")!,
                    index: 3,
                    name: "C",
                    colorHex: "#00FF00"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "2FD9249C-62E7-4D53-BF23-D51F4ACBB451")!,
                    index: 4,
                    name: "D",
                    colorHex: "#0000FF"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "9F9D6E8D-5B94-4F9A-9122-BD8D4DF0ED6D")!,
                    index: 5,
                    name: "F",
                    colorHex: "#808080"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "35DF7601-D8E3-46CA-84BA-3E58F66B8D91")!,
                    index: 6,
                    name: "Unranked",
                    colorHex: "#6B7280",
                    isUnranked: true
                )
            ]
        ),
        TierThemeEntity(
            themeID: UUID(uuidString: "9CE1CE02-95A7-4AA2-86EC-7E9459B5A168")!,
            slug: "heatmapGradient",
            displayName: "Heatmap Gradient",
            shortDescription: "Heat intensity gradient",
            tiers: [
                TierColorEntity(
                    tierID: UUID(uuidString: "EB4B8FD0-4CC4-47BB-8C2A-DED5D9A1C112")!,
                    index: 0,
                    name: "S",
                    colorHex: "#FF0000"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "FCF80DAA-A347-4A9E-86DC-2DB640FF2666")!,
                    index: 1,
                    name: "A",
                    colorHex: "#FF8000"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "73EA00BF-4901-4A7E-A034-5735299D8E68")!,
                    index: 2,
                    name: "B",
                    colorHex: "#FFFF00"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "CBB0E6BB-A406-48A8-A8F1-4606F9E4B61E")!,
                    index: 3,
                    name: "C",
                    colorHex: "#00FF00"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "5511E48D-0B29-4330-B434-C65E9AE312CE")!,
                    index: 4,
                    name: "D",
                    colorHex: "#0080FF"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "FF96413D-1A74-43B5-A6C7-38B7A0460C51")!,
                    index: 5,
                    name: "F",
                    colorHex: "#8000FF"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "EBA2420E-DB3E-4C03-932C-0B0C5F6E4575")!,
                    index: 6,
                    name: "Unranked",
                    colorHex: "#808080",
                    isUnranked: true
                )
            ]
        ),
        TierThemeEntity(
            themeID: UUID(uuidString: "E17A24C3-EBB1-4017-A16C-8556F1DA7D92")!,
            slug: "pastel",
            displayName: "Pastel",
            shortDescription: "Soft, muted tones",
            tiers: [
                TierColorEntity(
                    tierID: UUID(uuidString: "4D109675-8B18-4A43-909B-616C1D527C45")!,
                    index: 0,
                    name: "S",
                    colorHex: "#FFB3BA"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "24E8930C-8A59-48B2-8818-A2FD18D49E74")!,
                    index: 1,
                    name: "A",
                    colorHex: "#FFDFBA"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "A46E9E6C-A920-43B3-B0F2-34675C65775A")!,
                    index: 2,
                    name: "B",
                    colorHex: "#FFFFBA"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "633E0E25-DA02-436E-8B19-6254053F5E47")!,
                    index: 3,
                    name: "C",
                    colorHex: "#BAFFC9"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "899731EF-9F1F-4C89-99C0-1B9F9F80F28E")!,
                    index: 4,
                    name: "D",
                    colorHex: "#BAE1FF"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "4EEFC128-8CEA-4934-A6C2-4E14A83C669A")!,
                    index: 5,
                    name: "F",
                    colorHex: "#E2E2E2"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "62F07389-A08B-4C1C-8BB4-80C0D6498C44")!,
                    index: 6,
                    name: "Unranked",
                    colorHex: "#CCCCCC",
                    isUnranked: true
                )
            ]
        ),
        TierThemeEntity(
            themeID: UUID(uuidString: "25D36C02-2640-4D1B-89EB-8182A81756E9")!,
            slug: "monochrome",
            displayName: "Monochrome",
            shortDescription: "Grayscale spectrum",
            tiers: [
                TierColorEntity(
                    tierID: UUID(uuidString: "5F7B0C10-80C9-4F2E-940C-7A7A1A92C92F")!,
                    index: 0,
                    name: "S",
                    colorHex: "#000000"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "FD3B399E-17B8-40EC-9E11-89ED59973587")!,
                    index: 1,
                    name: "A",
                    colorHex: "#4C4C4C"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "D89E15E4-3E59-4DF1-8159-7B3A2FCC20F6")!,
                    index: 2,
                    name: "B",
                    colorHex: "#7F7F7F"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "85F6A27E-4D26-4ABE-BE5D-3CD8A987C72F")!,
                    index: 3,
                    name: "C",
                    colorHex: "#B3B3B3"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "C1C24FC9-8885-4F83-9A7F-3A53A1C8EE9D")!,
                    index: 4,
                    name: "D",
                    colorHex: "#CCCCCC"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "0B4D23E4-F1B8-4453-A42A-CED3071E7B93")!,
                    index: 5,
                    name: "F",
                    colorHex: "#FFFFFF"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "19F1E2AC-46A7-432C-A140-FA1AB05A1624")!,
                    index: 6,
                    name: "Unranked",
                    colorHex: "#808080",
                    isUnranked: true
                )
            ]
        ),
        TierThemeEntity(
            themeID: UUID(uuidString: "6A3D2B92-AC90-4764-8F07-BF78D78F27FB")!,
            slug: "rainbow",
            displayName: "Rainbow",
            shortDescription: "Full color spectrum",
            tiers: [
                TierColorEntity(
                    tierID: UUID(uuidString: "523974D5-B7A0-43B7-A69D-6F92FE453A45")!,
                    index: 0,
                    name: "S",
                    colorHex: "#FF0000"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "7E20A8D1-40C4-4A07-8F04-9FBA7F5A120B")!,
                    index: 1,
                    name: "A",
                    colorHex: "#FF8000"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "3F1F0D76-F380-4C0A-8ED4-700D02CFE2C2")!,
                    index: 2,
                    name: "B",
                    colorHex: "#FFFF00"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "93DEE536-9538-4F74-9177-58E09F89CF3F")!,
                    index: 3,
                    name: "C",
                    colorHex: "#00FF00"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "A0A212DA-C58E-4559-85A7-031E13C69C01")!,
                    index: 4,
                    name: "D",
                    colorHex: "#0000FF"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "54C5069F-FF92-4B6E-8CFA-621D3C0D21EB")!,
                    index: 5,
                    name: "F",
                    colorHex: "#8B00FF"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "7525DFB5-7A5F-4F8A-82E4-E4B849E9AA03")!,
                    index: 6,
                    name: "Unranked",
                    colorHex: "#808080",
                    isUnranked: true
                )
            ]
        ),
        TierThemeEntity(
            themeID: UUID(uuidString: "AA363109-ED06-4D37-8BE3-7A53704A81C6")!,
            slug: "darkNeon",
            displayName: "Dark Neon",
            shortDescription: "Vibrant neon on dark",
            tiers: [
                TierColorEntity(
                    tierID: UUID(uuidString: "8A4F9787-FE6A-4C08-A4ED-B0FF61728B8C")!,
                    index: 0,
                    name: "S",
                    colorHex: "#FF2A6D"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "D705CEB9-7C02-4580-A69B-9294DE06C180")!,
                    index: 1,
                    name: "A",
                    colorHex: "#FF7A00"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "80C3AAF4-124C-4C15-8C71-0851FF849990")!,
                    index: 2,
                    name: "B",
                    colorHex: "#FFD300"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "CBB58FC2-C88E-4F93-A02D-A87601B68071")!,
                    index: 3,
                    name: "C",
                    colorHex: "#39FF14"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "10755696-D01E-48B6-B4EC-7EEFF0E5AA3E")!,
                    index: 4,
                    name: "D",
                    colorHex: "#00E5FF"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "6A8DE85D-68C7-4747-9DBD-108E6236FA59")!,
                    index: 5,
                    name: "F",
                    colorHex: "#7C00FF"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "E58E5B1E-080F-4A4E-9E3E-3AA047B12B21")!,
                    index: 6,
                    name: "Unranked",
                    colorHex: "#374151",
                    isUnranked: true
                )
            ]
        ),
        TierThemeEntity(
            themeID: UUID(uuidString: "21ABDA2A-B7BB-4C92-9C7D-B81987EEB828")!,
            slug: "nord",
            displayName: "Nord",
            shortDescription: "Scandinavian palette",
            tiers: [
                TierColorEntity(
                    tierID: UUID(uuidString: "53CFFF04-3C75-42F4-A736-6096255D08D1")!,
                    index: 0,
                    name: "S",
                    colorHex: "#BF616A"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "8F49591A-84BD-4680-9AC0-47789FFC1A0D")!,
                    index: 1,
                    name: "A",
                    colorHex: "#D08770"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "B31E2BD4-31FA-4D35-AF77-1972AFE6E6F2")!,
                    index: 2,
                    name: "B",
                    colorHex: "#EBCB8B"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "523F67B3-1F0B-4B70-A578-FA2DB13A9A6F")!,
                    index: 3,
                    name: "C",
                    colorHex: "#A3BE8C"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "6E7C6C31-04B6-4546-B58A-5C9D33EAAF5F")!,
                    index: 4,
                    name: "D",
                    colorHex: "#88C0D0"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "8F5ED11B-048D-462E-A960-4CB14559C5F6")!,
                    index: 5,
                    name: "F",
                    colorHex: "#5E81AC"
                ),
                TierColorEntity(
                    tierID: UUID(uuidString: "6D487EDB-8AF0-4168-9461-CC3E7C79C43E")!,
                    index: 6,
                    name: "Unranked",
                    colorHex: "#4C566A",
                    isUnranked: true
                )
            ]
        )
    ]
}
