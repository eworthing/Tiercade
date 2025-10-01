# Summary: Enhanced Image Fetching for Bundled Tier Lists

## What Was Done

### 1. ✅ Confirmed Swift Model Already Supports Images
The `Item` struct in `TiercadeCore/Sources/TiercadeCore/Models/Models.swift` already has:
- `imageUrl: String?` property
- Proper Codable support
- Convenience initializer that accepts imageUrl

### 2. ✅ Extended fetch_media_and_thumb.js with TMDb API Support
Enhanced the existing script with:
- **TMDb Integration**: Automatic movie/TV show lookup via The Movie Database API
- **Smart Detection**: Determines if item is a movie or TV show based on properties
- **Image Download**: Fetches high-quality poster images from TMDb
- **Metadata Enhancement**: Optionally adds descriptions and release dates
- **Rate Limiting**: Respects TMDb API limits with 250ms delays

### 3. ✅ Added Xcode Asset Catalog Organization
The script now:
- **Auto-organizes**: Places images in structured asset groups
- **Creates Contents.json**: Proper Xcode asset catalog format
- **Supports @1x, @2x, @3x**: Ready for all device scales
- **Updates References**: Changes imageUrl to point to asset catalog names

## New Features

### Command-Line Options
```bash
node fetch_media_and_thumb.js project.json [options]

Options:
  --tmdb                      Enable TMDb API lookups
  --xcode-assets <path>       Path to Assets.xcassets folder
  --asset-group <name>        Group name in asset catalog
  --out <file>                Output JSON file
```

### Automated Helper Script
Created `fetch_bundled_images.sh` that:
- Checks for TMDb API key
- Installs dependencies if needed
- Generates temporary project files for Star Wars and Animated Classics
- Fetches images for both tier lists
- Organizes them into `Assets.xcassets/BundledTierlists/`
- Provides clear status and next steps

## File Structure Created

```
tools/
├── fetch_media_and_thumb.js      (✨ Enhanced with TMDb + Xcode assets)
├── fetch_bundled_images.sh       (🆕 Automated fetching script)
├── README_IMAGES.md              (🆕 Complete documentation)
├── BundledProjects_Example.swift (🆕 Code examples)
└── README.md                     (✏️ Updated with image section)

Assets.xcassets/
└── BundledTierlists/            (🆕 Created by script)
    ├── StarWars/
    │   ├── a-new-hope.imageset/
    │   ├── empire-strikes-back.imageset/
    │   └── ...
    └── Animated/
        ├── batman-tas.imageset/
        ├── x-men-tas.imageset/
        └── ...
```

## How to Use

### Step 1: Get TMDb API Key
1. Sign up at https://www.themoviedb.org/
2. Go to Settings → API
3. Request API key (select "Developer")
4. Export it: `export TMDB_API_KEY='your-key-here'`

### Step 2: Run the Script
```bash
cd /Users/Shared/git/Tiercade/tools
chmod +x fetch_bundled_images.sh
./fetch_bundled_images.sh
```

### Step 3: Update Swift Code
Update `BundledProjects.swift` ItemsFactory methods to include imageUrl:

```swift
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

// Then add imageUrl to each item
item(
    id: "a-new-hope",
    title: "Episode IV — A New Hope",
    summary: "The 1977 original that launched the galaxy.",
    imageUrl: "BundledTierlists/StarWars/a-new-hope"
)
```

### Step 4: Use in SwiftUI
```swift
if let imageUrl = item.imageUrl {
    Image(imageUrl)
        .resizable()
        .aspectRatio(contentMode: .fit)
}
```

## Coverage by Content Type

| Tier List | TMDb Support | Status |
|-----------|--------------|--------|
| Star Wars Films | ✅ Excellent | Fully automated |
| 90s Animated Classics | ⚠️ Partial | Most shows covered |
| Survivor Winners | ❌ None | Manual sourcing needed |

## Next Steps

1. **Immediate**:
   - Get TMDb API key
   - Run `./fetch_bundled_images.sh`
   - Review downloaded images

2. **Swift Updates**:
   - Update `ItemsFactory.item()` function signature
   - Add imageUrl to all Star Wars items
   - Add imageUrl to all Animated Classics items

3. **Survivor Images** (Manual):
   - Source official CBS promotional photos
   - Add to `Assets.xcassets/BundledTierlists/Survivor/`
   - Create Contents.json files
   - Update Swift code with asset names

4. **UI Updates**:
   - Update `BundledProjectCard` to display images
   - Add placeholder for items without images
   - Test on tvOS simulator

## Documentation

- **Complete Guide**: `tools/README_IMAGES.md`
- **Code Examples**: `tools/BundledProjects_Example.swift`
- **Main README**: `tools/README.md` (updated)

## Technical Details

### TMDb API Integration
- Base URL: `https://api.themoviedb.org/3`
- Image URL: `https://image.tmdb.org/t/p/original`
- Endpoints used: `search/movie`, `search/tv`, `movie/{id}`, `tv/{id}`
- Rate limit: 40 requests per 10 seconds (script uses 4 req/s)

### Asset Catalog Format
- Standard Xcode imageset structure
- Universal idiom (works on all devices)
- Supports 1x, 2x, 3x scales
- Contents.json v1 format

### Image Specifications
- Format: JPEG for photos, PNG for transparency
- Original resolution preserved
- Thumbnails generated at 400×225px
- Quality: 80% for thumbnails

## Benefits

✅ **Automated**: No manual image hunting for movies/TV  
✅ **Organized**: Clean asset catalog structure  
✅ **Offline**: Images bundled in app, no network calls  
✅ **Scalable**: Easy to add more tier lists  
✅ **Consistent**: Uniform image quality from TMDb  
✅ **Fast**: Parallel downloads with rate limiting  

## Limitations

⚠️ **Reality TV**: TMDb doesn't cover Survivor contestants  
⚠️ **Some Animated Shows**: Coverage varies by popularity  
⚠️ **API Key Required**: Free but requires signup  
⚠️ **Rate Limits**: Must respect TMDb API limits  
⚠️ **Bundle Size**: Images increase app size  
