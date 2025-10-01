# Fetching Images for Bundled Tier Lists

This guide explains how to use the enhanced `fetch_media_and_thumb.js` script to automatically fetch images from TMDb and organize them into your Xcode asset catalog.

## Quick Start

### 1. Get a TMDb API Key (Free)

1. Sign up at [The Movie Database](https://www.themoviedb.org/)
2. Go to Settings → API
3. Request an API key (select "Developer" and describe your project)
4. Copy your API key

### 2. Set Up Your Environment

```bash
cd tools
npm install
export TMDB_API_KEY='your-api-key-here'
```

### 3. Run the Automated Fetch Script

```bash
chmod +x fetch_bundled_images.sh
./fetch_bundled_images.sh
```

This will:
- ✅ Automatically search TMDb for Star Wars films and animated series
- ✅ Download high-quality poster images
- ✅ Organize them into `Tiercade/Assets.xcassets/BundledTierlists/`
- ✅ Create proper Xcode asset catalog structure with Contents.json

## Manual Usage

### Fetch Images for a Custom Project

```bash
node fetch_media_and_thumb.js your-project.json \
    --tmdb \
    --xcode-assets ../Tiercade/Assets.xcassets \
    --asset-group "BundledTierlists/Custom"
```

### Options

- `--tmdb` - Enable TMDb API lookups
- `--xcode-assets <path>` - Path to your Assets.xcassets folder
- `--asset-group <name>` - Organizes images under this group (creates subfolders)
- `--out <file>` - Output JSON file with updated imageUrl references

## What Gets Updated

### 1. Images Downloaded

Images are saved to `tools/media/<project-id>/`:
- Original high-res images
- Thumbnails (for media arrays)

### 2. Xcode Assets Created

For each item, an imageset is created:
```
Assets.xcassets/
  BundledTierlists/
    StarWars/
      a-new-hope.imageset/
        Contents.json
        a-new-hope.jpg
    Animated/
      batman-tas.imageset/
        Contents.json
        batman-tas.jpg
```

### 3. JSON Updated

The output JSON includes `imageUrl` for each item:
```json
{
  "id": "a-new-hope",
  "name": "Star Wars: Episode IV - A New Hope",
  "imageUrl": "BundledTierlists/StarWars/a-new-hope"
}
```

## Updating Swift Code

After fetching images, update `BundledProjects.swift`:

```swift
static let starWarsFilms: [Project.Item] = [
    item(
        id: "a-new-hope",
        title: "Episode IV — A New Hope",
        summary: "The 1977 original that launched the galaxy.",
        imageUrl: "BundledTierlists/StarWars/a-new-hope"
    ),
    // ... rest of items
]

// Update the item factory function
static func item(
    id: String, 
    title: String, 
    summary: String,
    imageUrl: String? = nil
) -> Project.Item {
    Project.Item(
        id: id, 
        name: title, 
        description: summary,
        imageUrl: imageUrl
    )
}
```

## Content-Specific Notes

### Star Wars Films ✅
TMDb has excellent coverage of all Star Wars movies. The script will automatically find and download official posters.

### 90s Animated Series ⚠️
TMDb has most popular animated series, but coverage varies:
- ✅ Batman TAS, X-Men, Spider-Man, Pokémon
- ⚠️ Some shows may need manual image sourcing
- Consider using TV show promotional art from official sources

### Survivor Winners ❌
Reality TV contestants are not in TMDb. You'll need to:
1. Download official CBS promotional photos
2. Manually add them to `Assets.xcassets/BundledTierlists/Survivor/`
3. Create Contents.json for each imageset (see template below)
4. Update BundledProjects.swift with asset names

## Manual Asset Creation Template

If you need to manually add images to the asset catalog:

### 1. Create folder structure:
```bash
mkdir -p "Tiercade/Assets.xcassets/BundledTierlists/Survivor/richard-hatch.imageset"
```

### 2. Add your image:
```bash
cp richard-hatch.jpg "Tiercade/Assets.xcassets/BundledTierlists/Survivor/richard-hatch.imageset/"
```

### 3. Create Contents.json:
```json
{
  "images" : [
    {
      "filename" : "richard-hatch.jpg",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

### 4. Reference in Swift:
```swift
imageUrl: "BundledTierlists/Survivor/richard-hatch"
```

## Using Images in SwiftUI

Once images are in the asset catalog, use them in your views:

```swift
// In BundledProjectCard or similar
if let imageUrl = project.item.imageUrl {
    Image(imageUrl)
        .resizable()
        .aspectRatio(contentMode: .fit)
} else {
    // Fallback placeholder
    Image(systemName: "photo")
}
```

## Troubleshooting

### "No TMDb results found"
- Check the item name spelling
- Try adding year: "Batman (1992)"
- Some content may not be in TMDb - add manually

### "TMDb API key required"
```bash
export TMDB_API_KEY='your-key-here'
```

### Images not appearing in Xcode
1. Close and reopen Xcode
2. Clean build folder (Cmd+Shift+K)
3. Verify Contents.json is valid JSON

### Rate Limiting
The script includes automatic 250ms delays between API calls to respect TMDb rate limits.

## Best Practices

1. **Test First**: Run on a small sample before processing all items
2. **Backup**: Keep downloaded images in `tools/media/` as backup
3. **Review**: Check image quality and correctness before committing
4. **Optimize**: Images are automatically optimized, but verify sizes for tvOS
5. **Licensing**: Ensure you have rights to use images (TMDb images are typically fair use)

## Resources

- TMDb API Docs: https://developers.themoviedb.org/3
- Xcode Asset Catalog Format: https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/
- Image Guidelines for tvOS: https://developer.apple.com/design/human-interface-guidelines/tvos/visual-design/images
