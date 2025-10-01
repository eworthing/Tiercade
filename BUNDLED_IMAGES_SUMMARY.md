# Bundled Tier Lists - Images & Metadata Guide

This document provides image sources and enhanced metadata for the three bundled tier lists in Tiercade.

> **🚀 Quick Start**: We now have automated tools! See [tools/README_IMAGES.md](tools/README_IMAGES.md) for the complete guide, or run:
> ```bash
> export TMDB_API_KEY='your-key'
> ./tools/fetch_bundled_images.sh
> ```

## 1. Survivor Winners (survivor-legends)

### Overview
- **Count**: 13 winners from seasons 1-44 (representative sample)
- **Image Sources**: CBS official promotional photos, contestant portraits
- **Recommended Dimensions**: 400×600px (portrait orientation)
- **Image Format**: JPEG or PNG

### Image Acquisition Strategy

**Option A: Official CBS/Paramount Photos**
- CBS MediaVillage (press site): https://www.cbsmediacenter.com/
- Survivor Wiki: https://survivor.fandom.com/ (fan-maintained, high quality)
- Each winner has official promotional photos from their winning season

**Option B: Getty Images (Licensed)**
- Getty Images has 18,620+ Survivor CBS photos
- Professional quality, but requires licensing

**Option C: Public Domain/Fair Use**
- Wikipedia contestant pages often have promotional images
- Lower resolution but freely available

### Individual Winner Images Needed

1. **Richard Hatch** (Season 1: Borneo)
   - Search: "Richard Hatch Survivor Borneo official photo"
   - Alternative: Survivor Wiki contestant page

2. **Tina Wesson** (Season 2: Australian Outback)
   - Search: "Tina Wesson Survivor Australian Outback"

3. **Sandra Diaz-Twine** (Season 7: Pearl Islands, Season 20: Heroes vs. Villains)
   - Search: "Sandra Diaz-Twine Survivor official photo"
   - Note: Two-time winner, iconic status

4. **Amber Brkich Mariano** (Season 8: All-Stars)
   - Search: "Amber Brkich Mariano Survivor All-Stars"

5. **Tom Westman** (Season 10: Palau)
   - Search: "Tom Westman Survivor Palau"

6. **Parvati Shallow** (Season 16: Micronesia)
   - Search: "Parvati Shallow Survivor Micronesia"

7. **Jeremy Collins** (Season 31: Cambodia)
   - Search: "Jeremy Collins Survivor Cambodia"

8. **Michele Fitzgerald** (Season 32: Kaôh Rōng)
   - Search: "Michele Fitzgerald Survivor Kaoh Rong"

9. **Tony Vlachos** (Season 28: Cagayan, Season 40: Winners at War)
   - Search: "Tony Vlachos Survivor official photo"
   - Note: Two-time winner, Season 40 featured all winners

10. **Maryanne Oketch** (Season 42)
    - Search: "Maryanne Oketch Survivor 42"

11. **Mike Holloway** (Season 30: Worlds Apart)
    - Search: "Mike Holloway Survivor Worlds Apart"

12. **Yul Kwon** (Season 13: Cook Islands)
    - Search: "Yul Kwon Survivor Cook Islands"

### Enhanced Metadata to Add

For each winner, consider adding:
- **seasonNumber**: Integer (e.g., 1, 2, 7, etc.)
- **seasonName**: String (e.g., "Borneo", "Australian Outback")
- **airYear**: Integer (2000-2024)
- **imageUrl**: String (URL to portrait image)
- **thumbnailUrl**: String (smaller version for grid views)
- **voteTally**: String (e.g., "4-3", "7-0-0")
- **age**: Integer (age when they won)
- **occupation**: String

---

## 2. Star Wars Films (star-wars-saga)

### Overview
- **Count**: 12 theatrical films
- **Image Sources**: Official Lucasfilm/Disney promotional materials
- **Recommended Dimensions**: 600×900px (standard movie poster ratio 2:3)
- **Image Format**: JPEG

### Image Acquisition Strategy

**Option A: Official StarWars.com**
- StarWars.com media gallery has official posters
- High resolution, officially sanctioned

**Option B: The Movie Database (TMDb)**
- API access: https://www.themoviedb.org/
- Free API for non-commercial use
- Comprehensive collection of official posters

**Option C: Disney+ / Lucasfilm Press Kit**
- Official promotional materials
- Requires press credentials

### Individual Film Posters Needed

1. **Episode IV — A New Hope** (1977)
   - Use original theatrical poster (iconic Luke holding lightsaber)
   - Alternative: Special Edition (1997) poster

2. **Episode V — The Empire Strikes Back** (1980)
   - Classic poster with Vader looming over cast

3. **Episode VI — Return of the Jedi** (1983)
   - Poster featuring Jabba's palace or space battle

4. **Episode I — The Phantom Menace** (1999)
   - Young Anakin with Vader shadow poster

5. **Episode II — Attack of the Clones** (2002)
   - Arena battle or Anakin/Padmé poster

6. **Episode III — Revenge of the Sith** (2005)
   - Anakin's transformation poster

7. **Episode VII — The Force Awakens** (2015)
   - Rey, Finn, and Kylo Ren theatrical poster

8. **Episode VIII — The Last Jedi** (2017)
   - Red-themed theatrical poster

9. **Episode IX — The Rise of Skywalker** (2019)
   - Final saga poster with Rey

10. **Rogue One: A Star Wars Story** (2016)
    - Jyn Erso and rebels poster

11. **Solo: A Star Wars Story** (2018)
    - Han Solo character poster

12. **Star Wars: The Clone Wars** (2008)
    - Animated film theatrical poster

### Enhanced Metadata to Add

For each film:
- **episodeNumber**: Integer or null (1-9 for saga films)
- **releaseYear**: Integer
- **director**: String
- **runtime**: Integer (minutes)
- **imdbId**: String (for linking)
- **rottenTomatoesScore**: Integer (percentage)
- **boxOffice**: Integer (millions USD)
- **imageUrl**: String (poster URL)
- **backdropUrl**: String (landscape background image)
- **era**: String ("Original", "Prequel", "Sequel", "Anthology")

---

## 3. 90s Animated Classics (animated-classics)

### Overview
- **Count**: 17 iconic animated series
- **Image Sources**: Network promotional art, title cards, key art
- **Recommended Dimensions**: 640×480px (4:3 ratio to match original broadcasts)
- **Image Format**: PNG preferred (for transparency)

### Image Acquisition Strategy

**Option A: Official Network Archives**
- Warner Bros., Nickelodeon, Disney archives
- Requires licensing for most

**Option B: Fan Wikis (High Quality)**
- Batman Animated Wiki, ToonZone, etc.
- Often has official promotional art
- Check licensing for each

**Option C: The Movie Database / TVDb**
- TV show posters and key art
- API available for automated retrieval

### Individual Show Images Needed

1. **Batman: The Animated Series** (1992-1995, Fox/WB)
   - Use iconic title card or Batman silhouette
   - Search: "Batman Animated Series official logo"

2. **X-Men: The Animated Series** (1992-1997, Fox)
   - Team lineup promotional art
   - Iconic opening sequence frame

3. **Animaniacs** (1993-1998, Fox/WB)
   - Warner siblings (Yakko, Wakko, Dot) key art
   - Water tower background

4. **Gargoyles** (1994-1997, Disney)
   - Goliath and clan promotional art
   - Manhattan skyline background

5. **Doug** (1991-1994, Nickelodeon; 1996-1999, ABC/Disney)
   - Doug Funnie character art
   - Simple, clean design

6. **Rugrats** (1991-2004, Nickelodeon)
   - Babies group shot
   - Playpen or nursery background

7. **Hey Arnold!** (1996-2004, Nickelodeon)
   - Arnold with football head
   - Urban setting background

8. **Spider-Man: The Animated Series** (1994-1998, Fox)
   - Spider-Man swinging pose
   - NYC skyline

9. **Sailor Moon** (1992-1997, various)
   - Sailor Moon transformation or team
   - Manga-style key art

10. **Pokémon** (1997-present, various)
    - Ash and Pikachu original series art
    - Kanto starters

11. **The Powerpuff Girls** (1998-2005, Cartoon Network)
    - Blossom, Bubbles, Buttercup flying
    - Townsville background

12. **ReBoot** (1994-2001, various)
    - Bob, Dot, Enzo characters
    - Digital world aesthetic

13. **Beast Wars: Transformers** (1996-1999, various)
    - Maximals vs Predacons
    - CGI key art

14. **SpongeBob SquarePants** (1999-present, Nickelodeon)
    - SpongeBob iconic pose
    - Note: Technically started in '99, fits the era

15. **Tiny Toon Adventures** (1990-1995, Fox/WB)
    - Buster and Babs Bunny
    - Acme Looniversity

16. **Darkwing Duck** (1991-1992, Disney)
    - Darkwing in cape pose
    - "I am the terror that flaps in the night"

17. **Arthur** (1996-2022, PBS)
    - Arthur Read character art
    - Educational PBS aesthetic

### Enhanced Metadata to Add

For each show:
- **startYear**: Integer
- **endYear**: Integer
- **network**: String ("Fox", "Nickelodeon", "Cartoon Network", "PBS", "Disney")
- **seasons**: Integer
- **episodes**: Integer (approximate)
- **creators**: Array of strings
- **genre**: Array of strings (e.g., ["Action", "Adventure", "Comedy"])
- **imageUrl**: String (show key art)
- **logoUrl**: String (show logo/title card)
- **imdbId**: String
- **themes**: Array of strings (e.g., ["Superhero", "Mystery", "Friendship"])

---

## Implementation Notes

### Asset Storage Options

1. **Local Assets (Recommended for App Store)**
   - Include images in app bundle under `Assets.xcassets`
   - Organized in folders: `BundledTierlists/Survivor/`, `BundledTierlists/StarWars/`, etc.
   - Benefits: Offline access, no network calls, consistent UX
   - Drawbacks: Increases app size

2. **Remote CDN**
   - Host on Cloudflare, AWS S3, or similar
   - Benefits: Smaller app bundle, can update without app release
   - Drawbacks: Requires network, costs, cache management

3. **Hybrid Approach**
   - Thumbnails in app bundle
   - Full-res images from CDN with caching

### Code Changes Needed

Update `Project.Item` model to include:
```swift
public struct Item: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let summary: String?
    public let imageUrl: String?        // NEW
    public let thumbnailUrl: String?    // NEW
    public let metadata: [String: String]? // NEW: flexible key-value for additional data
    
    // ... rest of implementation
}
```

Update `ItemsFactory` to include image paths:
```swift
static func item(
    id: String, 
    title: String, 
    summary: String,
    imageUrl: String? = nil,
    metadata: [String: String]? = nil
) -> Project.Item {
    Project.Item(
        id: id, 
        title: title, 
        summary: summary,
        imageUrl: imageUrl,
        thumbnailUrl: nil,
        metadata: metadata
    )
}
```

### Image Licensing Considerations

- **Survivor**: CBS/Paramount+ owns contestant photos; consider fair use for educational/reference
- **Star Wars**: Lucasfilm/Disney owns posters; official API or fair use doctrine
- **Animated Series**: Various networks; check individual licensing
- **Recommendation**: Use TMDb/TVDb APIs when possible, or create original artwork

### Tools Available

You already have `tools/fetch_media_and_thumb.js` which can be extended to:
1. Fetch images from TMDb API
2. Generate thumbnails
3. Save to appropriate asset catalog locations
4. Update Swift code with image paths

---

## Next Steps

1. **Choose asset storage strategy** (local bundle vs CDN)
2. **Acquire/license images** for all items
3. **Update `Project.Item` model** to include image fields
4. **Extend `ItemsFactory`** with image URLs
5. **Update UI components** (`BundledProjectCard`) to display images
6. **Test on tvOS** to ensure image loading and focus behavior
7. **Optimize images** for tvOS resolution (layered images if using focus engine)

## tvOS-Specific Considerations

- **Focus Engine**: Consider using layered images for parallax effects
- **Resolution**: tvOS supports up to 4K, but 1920×1080 is sufficient for most assets
- **Caching**: Use `SDWebImage` or `Kingfisher` for remote image caching
- **Accessibility**: Ensure all images have proper accessibility labels
- **Dark Mode**: Test image visibility in both light/dark appearances

---

## Resources

### APIs
- **The Movie Database (TMDb)**: https://www.themoviedb.org/documentation/api
- **TVDb**: https://thetvdb.com/api-information
- **OMDb API**: http://www.omdbapi.com/

### Image Sources
- **StarWars.com**: https://www.starwars.com/
- **Survivor Wiki**: https://survivor.fandom.com/
- **Unsplash** (for placeholders): https://unsplash.com/

### Design Guidelines
- **tvOS Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/tvos
- **Layered Images**: https://developer.apple.com/documentation/uikit/uitableviewcell/1623228-imageview
