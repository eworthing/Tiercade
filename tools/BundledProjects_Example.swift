// Example: How to update BundledProjects.swift after fetching images
//
// This file shows the pattern for adding imageUrl to bundled tier list items.
// After running fetch_bundled_images.sh, copy the asset names and update
// the ItemsFactory methods in BundledProjects.swift

// BEFORE (no images):
static func item(id: String, title: String, summary: String) -> Project.Item {
    Project.Item(id: id, title: title, summary: summary)
}

static let starWarsFilms: [Project.Item] = [
    item(
        id: "a-new-hope",
        title: "Episode IV — A New Hope",
        summary: "The 1977 original that launched the galaxy."
    )
    // ... more items
]

// AFTER (with images):
static func item(
    id: String,
    title: String,
    summary: String,
    imageUrl: String? = nil
) -> Project.Item {
    Project.Item(
        id: id,
        name: title,   // Note: Item struct uses 'name', not 'title'
        description: summary,
        imageUrl: imageUrl
    )
}

static let starWarsFilms: [Project.Item] = [
    item(
        id: "a-new-hope",
        title: "Episode IV — A New Hope",
        summary: "The 1977 original that launched the galaxy.",
        imageUrl: "BundledTierlists/StarWars/a-new-hope"
    ),
    item(
        id: "empire-strikes-back",
        title: "Episode V — The Empire Strikes Back",
        summary: "The darker middle chapter with an iconic twist.",
        imageUrl: "BundledTierlists/StarWars/empire-strikes-back"
    ),
    item(
        id: "return-of-the-jedi",
        title: "Episode VI — Return of the Jedi",
        summary: "Ewoks, redemption, and an emotional finale.",
        imageUrl: "BundledTierlists/StarWars/return-of-the-jedi"
    ),
    item(
        id: "phantom-menace",
        title: "Episode I — The Phantom Menace",
        summary: "The prequel opener featuring podracing and the Sith.",
        imageUrl: "BundledTierlists/StarWars/phantom-menace"
    ),
    item(
        id: "attack-of-the-clones",
        title: "Episode II — Attack of the Clones",
        summary: "Clones, politics, and the rise of the Republic's army.",
        imageUrl: "BundledTierlists/StarWars/attack-of-the-clones"
    ),
    item(
        id: "revenge-of-the-sith",
        title: "Episode III — Revenge of the Sith",
        summary: "Anakin's fall and Order 66 reshape the galaxy.",
        imageUrl: "BundledTierlists/StarWars/revenge-of-the-sith"
    ),
    item(
        id: "force-awakens",
        title: "Episode VII — The Force Awakens",
        summary: "A new generation rises against the First Order.",
        imageUrl: "BundledTierlists/StarWars/force-awakens"
    ),
    item(
        id: "last-jedi",
        title: "Episode VIII — The Last Jedi",
        summary: "Subverted expectations and a focus on legacy.",
        imageUrl: "BundledTierlists/StarWars/last-jedi"
    ),
    item(
        id: "rise-of-skywalker",
        title: "Episode IX — The Rise of Skywalker",
        summary: "The dramatic conclusion to the Skywalker saga.",
        imageUrl: "BundledTierlists/StarWars/rise-of-skywalker"
    ),
    item(
        id: "rogue-one",
        title: "Rogue One: A Star Wars Story",
        summary: "Rebels steal the Death Star plans in a gritty war story.",
        imageUrl: "BundledTierlists/StarWars/rogue-one"
    ),
    item(
        id: "solo",
        title: "Solo: A Star Wars Story",
        summary: "Han Solo's origin tale filled with heists and heart.",
        imageUrl: "BundledTierlists/StarWars/solo"
    )
]

static let animatedClassics: [Project.Item] = [
    item(
        id: "batman-tas",
        title: "Batman: The Animated Series",
        summary: "Stylish noir take on Gotham's protector.",
        imageUrl: "BundledTierlists/Animated/batman-tas"
    ),
    item(
        id: "x-men-tas",
        title: "X-Men: The Animated Series",
        summary: "Mutant soap opera with an unforgettable theme.",
        imageUrl: "BundledTierlists/Animated/x-men-tas"
    ),
    item(
        id: "animaniacs",
        title: "Animaniacs",
        summary: "Variety show chaos with the Warner siblings.",
        imageUrl: "BundledTierlists/Animated/animaniacs"
    ),
    item(
        id: "gargoyles",
        title: "Gargoyles",
        summary: "Mythic stone guardians awaken in modern Manhattan.",
        imageUrl: "BundledTierlists/Animated/gargoyles"
    ),
    item(
        id: "spider-man",
        title: "Spider-Man: The Animated Series",
        summary: "Web-slinging hero faces iconic rogues.",
        imageUrl: "BundledTierlists/Animated/spider-man"
    ),
    item(
        id: "pokemon",
        title: "Pokémon",
        summary: "Ash and Pikachu's journey through Kanto and beyond.",
        imageUrl: "BundledTierlists/Animated/pokemon"
    ),
    item(
        id: "powerpuff-girls",
        title: "The Powerpuff Girls",
        summary: "Sugar, spice, and Chemical X-powered heroes.",
        imageUrl: "BundledTierlists/Animated/powerpuff-girls"
    ),
    item(
        id: "spongebob",
        title: "SpongeBob SquarePants",
        summary: "Undersea optimism with endless quotables.",
        imageUrl: "BundledTierlists/Animated/spongebob"
    )
]

// For Survivor winners, you'll need to manually add images to:
// Assets.xcassets/BundledTierlists/Survivor/
// Then reference them like:
static let survivorWinners: [Project.Item] = [
    item(
        id: "richard-hatch",
        title: "Richard Hatch",
        summary: "Borneo pioneer and original social strategist.",
        imageUrl: "BundledTierlists/Survivor/richard-hatch"
    )
    // ... etc
]
