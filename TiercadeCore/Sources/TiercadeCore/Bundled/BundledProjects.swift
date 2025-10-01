import Foundation

public struct BundledProject: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let summary: String
    public let tags: [String]
    public let project: Project

    public init(
        id: String,
        title: String,
        subtitle: String,
        summary: String,
        tags: [String],
        project: Project
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.tags = tags
        self.project = project
    }

    public var itemCount: Int { project.items.count }
}

public enum BundledProjects {
    public static let all: [BundledProject] = descriptors.map(makeProject(from:))

    public static func project(withId id: String) -> BundledProject? {
        all.first { $0.id == id }
    }
}

// MARK: - Private helpers

private extension BundledProjects {
    struct Descriptor {
        let id: String
        let title: String
        let subtitle: String
        let summary: String
        let tags: [String]
        let items: [Project.Item]
    }

    static let descriptors: [Descriptor] = [
        Descriptor(
            id: "survivor-legends",
            title: "Survivor Winners",
            subtitle: "Every champion through 44 seasons",
            summary: "Rank the iconic winners from Survivor's first 44 seasons.",
            tags: ["Reality", "TV", "CBS"],
            items: ItemsFactory.survivorWinners
        ),
        Descriptor(
            id: "star-wars-saga",
            title: "Star Wars Films",
            subtitle: "Skywalker saga + stories",
            summary: "Rank every theatrical Star Wars film, from the originals to the sequels and spin-offs.",
            tags: ["Movies", "Sci-Fi", "Lucasfilm"],
            items: ItemsFactory.starWarsFilms
        ),
        Descriptor(
            id: "animated-classics",
            title: "90s Animated Classics",
            subtitle: "Saturday morning icons",
            summary: "Rank iconic animated series from the 1990s heyday of Saturday morning TV.",
            tags: ["TV", "Animation", "Nostalgia"],
            items: ItemsFactory.animatedClassics
        )
    ]

    static func makeProject(from descriptor: Descriptor) -> BundledProject {
        let createdAt = referenceDate("2024-01-01T00:00:00Z")
        let tiers = orderedTierIds.enumerated().map { index, tierId in
            Project.Tier(
                id: tierId,
                label: displayLabel(for: tierId),
                color: TierStyle.colors[tierId],
                order: index,
                locked: tierId == "unranked" ? false : nil,
                collapsed: false,
                rules: nil,
                itemIds: tierId == "unranked" ? descriptor.items.map(\.id) : []
            )
        }

        let itemsDictionary = Dictionary(uniqueKeysWithValues: descriptor.items.map { ($0.id, $0) })

        let project = Project(
            schemaVersion: 1,
            projectId: descriptor.id,
            title: descriptor.title,
            description: descriptor.summary,
            tiers: tiers,
            items: itemsDictionary,
            overrides: nil,
            links: nil,
            storage: Project.Storage(mode: "local"),
            settings: Project.Settings(showUnranked: true),
            collab: nil,
            audit: Project.Audit(
                createdAt: createdAt,
                updatedAt: createdAt,
                createdBy: "system",
                updatedBy: "system"
            )
        )

        return BundledProject(
            id: descriptor.id,
            title: descriptor.title,
            subtitle: descriptor.subtitle,
            summary: descriptor.summary,
            tags: descriptor.tags,
            project: project
        )
    }

    static func referenceDate(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso) ?? Date(timeIntervalSince1970: 1704067200)
    }

    static let orderedTierIds: [String] = ["S", "A", "B", "C", "D", "F", "unranked"]

    enum TierStyle {
        static let colors: [String: String] = [
            "S": "#FF6B6B",
            "A": "#FFD166",
            "B": "#06D6A0",
            "C": "#1B9AAA",
            "D": "#5C4B51",
            "F": "#9E2A2B",
            "unranked": "#E0E0E0"
        ]
    }

    static func displayLabel(for tierId: String) -> String {
        tierId == "unranked" ? "Unranked" : tierId
    }
}

private enum ItemsFactory {
    static let survivorWinners: [Project.Item] = [
        item(
            id: "richard-hatch",
            title: "Richard Hatch",
            summary: "Borneo pioneer and original social strategist."
        ),
        item(
            id: "tina-wesson",
            title: "Tina Wesson",
            summary: "Outback diplomat who mastered the jury."
        ),
        item(
            id: "sandra-diaz-twine",
            title: "Sandra Diaz-Twine",
            summary: "Only two-time champ with the 'anyone but me' mantra."
        ),
        item(
            id: "amber-brkich",
            title: "Amber Brkich Mariano",
            summary: "All-Stars closer with a flawless social game."
        ),
        item(
            id: "tom-westman",
            title: "Tom Westman",
            summary: "Palau firefighter who dominated on all fronts."
        ),
        item(
            id: "parvati-shallow",
            title: "Parvati Shallow",
            summary: "Fans vs. Favorites siren and alliance architect."
        ),
        item(
            id: "jeremy-collins",
            title: "Jeremy Collins",
            summary: "Cambodia hero who reinvented with second-chance allies."
        ),
        item(
            id: "michele-fitzgerald",
            title: "Michele Fitzgerald",
            summary: "Kaôh Rōng storyteller who charmed the jury."
        ),
        item(
            id: "tony-vlachos",
            title: "Tony Vlachos",
            summary: "Cagayan kingpin turned mastermind of Winners at War."
        ),
        item(
            id: "maryanne-oketch",
            title: "Maryanne Oketch",
            summary: "Season 42's joyful wildcard who timed idols perfectly."
        ),
        item(
            id: "mike-holloway",
            title: "Mike Holloway",
            summary: "Worlds Apart challenge beast with grit to the end."
        ),
        item(
            id: "yul-kwon",
            title: "Yul Kwon",
            summary: "Cook Islands strategist armed with the super idol."
        )
    ]

    static let starWarsFilms: [Project.Item] = [
        item(
            id: "a-new-hope",
            title: "Episode IV — A New Hope",
            summary: "The 1977 original that launched the galaxy."
        ),
        item(
            id: "empire-strikes-back",
            title: "Episode V — The Empire Strikes Back",
            summary: "The darker middle chapter with an iconic twist."
        ),
        item(
            id: "return-of-the-jedi",
            title: "Episode VI — Return of the Jedi",
            summary: "Ewoks, redemption, and an emotional finale."
        ),
        item(
            id: "phantom-menace",
            title: "Episode I — The Phantom Menace",
            summary: "The prequel opener featuring podracing and the Sith."
        ),
        item(
            id: "attack-of-the-clones",
            title: "Episode II — Attack of the Clones",
            summary: "Clones, politics, and the rise of the Republic's army."
        ),
        item(
            id: "revenge-of-the-sith",
            title: "Episode III — Revenge of the Sith",
            summary: "Anakin's fall and Order 66 reshape the galaxy."
        ),
        item(
            id: "force-awakens",
            title: "Episode VII — The Force Awakens",
            summary: "A new generation rises against the First Order."
        ),
        item(
            id: "last-jedi",
            title: "Episode VIII — The Last Jedi",
            summary: "Subverted expectations and a focus on legacy."
        ),
        item(
            id: "rise-of-skywalker",
            title: "Episode IX — The Rise of Skywalker",
            summary: "The dramatic conclusion to the Skywalker saga."
        ),
        item(
            id: "rogue-one",
            title: "Rogue One: A Star Wars Story",
            summary: "Rebels steal the Death Star plans in a gritty war story."
        ),
        item(
            id: "solo",
            title: "Solo: A Star Wars Story",
            summary: "Han Solo's origin tale filled with heists and heart."
        ),
        item(
            id: "clone-wars",
            title: "Star Wars: The Clone Wars",
            summary: "Animated feature bridging Episodes II and III."
        )
    ]

    static let animatedClassics: [Project.Item] = [
        item(
            id: "batman-tas",
            title: "Batman: The Animated Series",
            summary: "Stylish noir take on Gotham's protector."
        ),
        item(
            id: "x-men-tas",
            title: "X-Men: The Animated Series",
            summary: "Mutant soap opera with an unforgettable theme."
        ),
        item(
            id: "animaniacs",
            title: "Animaniacs",
            summary: "Variety show chaos with the Warner siblings."
        ),
        item(
            id: "gargoyles",
            title: "Gargoyles",
            summary: "Mythic stone guardians awaken in modern Manhattan."
        ),
        item(
            id: "doug",
            title: "Doug",
            summary: "Slice-of-life middle school adventures with imagination."
        ),
        item(
            id: "rugrats",
            title: "Rugrats",
            summary: "Toddlers explore the world through big imagination."
        ),
        item(
            id: "hey-arnold",
            title: "Hey Arnold!",
            summary: "Urban heartwarming stories set in Hillwood."
        ),
        item(
            id: "spider-man",
            title: "Spider-Man: The Animated Series",
            summary: "Web-slinging hero faces iconic rogues."
        ),
        item(
            id: "sailor-moon",
            title: "Sailor Moon",
            summary: "Magical girls defending Earth with friendship."
        ),
        item(
            id: "pokemon",
            title: "Pokémon",
            summary: "Ash and Pikachu's journey through Kanto and beyond."
        ),
        item(
            id: "powerpuff-girls",
            title: "The Powerpuff Girls",
            summary: "Sugar, spice, and Chemical X-powered heroes."
        ),
        item(
            id: "reboot",
            title: "ReBoot",
            summary: "CGI adventures inside a computer mainframe."
        ),
        item(
            id: "beast-wars",
            title: "Beast Wars: Transformers",
            summary: "Maximals and Predacons clash in prehistoric times."
        ),
        item(
            id: "spongebob",
            title: "SpongeBob SquarePants",
            summary: "Undersea optimism with endless quotables."
        ),
        item(
            id: "tiny-toons",
            title: "Tiny Toon Adventures",
            summary: "Looniversity students carry on Looney Tunes chaos."
        ),
        item(
            id: "darkwing-duck",
            title: "Darkwing Duck",
            summary: "Caped crusader parody bursting with catchphrases."
        ),
        item(
            id: "arthur",
            title: "Arthur",
            summary: "PBS lessons on empathy, friendship, and growth."
        )
    ]

    static func item(id: String, title: String, summary: String) -> Project.Item {
        Project.Item(id: id, title: title, summary: summary)
    }
}
