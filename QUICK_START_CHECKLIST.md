# Quick Start Checklist

Follow these steps to add images to your bundled tier lists.

## ✅ Phase 1: Setup (5 minutes)

- [ ] **Get TMDb API Key**
  - Go to: https://www.themoviedb.org/settings/api
  - Sign up if needed
  - Request API key (choose "Developer")
  - Copy your key

- [ ] **Set Environment Variable**
  ```bash
  export TMDB_API_KEY='paste-your-key-here'
  ```

- [ ] **Test the Tools**
  ```bash
  cd /Users/Shared/git/Tiercade/tools
  ./test_image_tools.sh
  ```
  Expected: All tests pass ✅

## ✅ Phase 2: Fetch Images (2 minutes)

- [ ] **Run Automated Script**
  ```bash
  ./fetch_bundled_images.sh
  ```

- [ ] **Verify Downloaded Images**
  ```bash
  ls -la tools/media/star-wars-saga/
  ls -la tools/media/animated-classics/
  ```
  Expected: ~20 JPG files

- [ ] **Verify Asset Catalog**
  ```bash
  ls -la Tiercade/Assets.xcassets/BundledTierlists/StarWars/
  ls -la Tiercade/Assets.xcassets/BundledTierlists/Animated/
  ```
  Expected: Multiple .imageset directories

## ✅ Phase 3: Update Swift Code (10 minutes)

- [ ] **Open BundledProjects.swift**
  ```bash
  open TiercadeCore/Sources/TiercadeCore/Bundled/BundledProjects.swift
  ```

- [ ] **Update item() Function**
  - Find: `static func item(id: String, title: String, summary: String)`
  - Add parameter: `imageUrl: String? = nil`
  - Add to Project.Item init: `imageUrl: imageUrl`
  - See `tools/BundledProjects_Example.swift` for complete example

- [ ] **Add imageUrl to Star Wars Items** (11 items)
  Example:
  ```swift
  item(
      id: "a-new-hope",
      title: "Episode IV — A New Hope",
      summary: "The 1977 original that launched the galaxy.",
      imageUrl: "BundledTierlists/StarWars/a-new-hope"
  )
  ```

- [ ] **Add imageUrl to Animated Items** (8 items)
  Example:
  ```swift
  item(
      id: "batman-tas",
      title: "Batman: The Animated Series",
      summary: "Stylish noir take on Gotham's protector.",
      imageUrl: "BundledTierlists/Animated/batman-tas"
  )
  ```

- [ ] **Build TiercadeCore**
  ```bash
  cd TiercadeCore
  swift build
  ```
  Expected: Build succeeds with no errors

## ✅ Phase 4: UI Integration (15 minutes)

- [ ] **Update BundledProjectCard View**
  File: `Tiercade/Views/Overlays/BundledTierlistSelector.swift`
  
  Add image display:
  ```swift
  if let imageUrl = project.project.items[itemId]?.imageUrl {
      Image(imageUrl)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 300, height: 450)
  } else {
      Image(systemName: "photo")
          .resizable()
          .frame(width: 300, height: 450)
  }
  ```

- [ ] **Build tvOS App**
  ```bash
  xcodebuild -project Tiercade.xcodeproj \
             -scheme Tiercade \
             -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest' \
             build
  ```

- [ ] **Test in Simulator**
  - Open Apple TV simulator
  - Launch Tiercade
  - Go to "Load Bundled Tier List"
  - Verify images appear for Star Wars and Animated items

- [ ] **Test Focus Behavior**
  - Use Siri Remote or keyboard arrows
  - Ensure focus highlights work with images
  - Test selection of items

## ✅ Phase 5: Survivor Images (Manual - Optional)

Only needed if you want Survivor images (TMDb doesn't have reality TV contestants).

- [ ] **Source CBS Photos**
  - Find official Survivor contestant photos
  - Download 13 images for winners list
  - Save as: `richard-hatch.jpg`, `tina-wesson.jpg`, etc.

- [ ] **Create Asset Catalog Entries**
  For each image:
  ```bash
  mkdir -p "Tiercade/Assets.xcassets/BundledTierlists/Survivor/richard-hatch.imageset"
  cp richard-hatch.jpg "Tiercade/Assets.xcassets/BundledTierlists/Survivor/richard-hatch.imageset/"
  ```

- [ ] **Create Contents.json**
  See template in `tools/README_IMAGES.md`

- [ ] **Add imageUrl to Survivor Items**
  Same pattern as Star Wars/Animated

## 📋 Verification Steps

Run these to confirm everything works:

```bash
# 1. TiercadeCore builds
cd TiercadeCore && swift build

# 2. tvOS app builds
xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest' \
  build

# 3. Images exist in asset catalog
find Tiercade/Assets.xcassets/BundledTierlists -name "*.jpg" | wc -l
# Expected: ~19 images

# 4. All imagesets have Contents.json
find Tiercade/Assets.xcassets/BundledTierlists -name "Contents.json" | wc -l
# Expected: ~19 files
```

## 🎉 Done!

When all boxes are checked:
- ✅ Star Wars items have images (11)
- ✅ Animated items have images (8)
- ✅ Asset catalog is properly organized
- ✅ Swift code is updated
- ✅ UI displays images
- ✅ App builds and runs

## 📚 Need Help?

Check these docs:
- **Overview**: `IMPLEMENTATION_COMPLETE.md`
- **Complete Guide**: `tools/README_IMAGES.md`
- **Code Examples**: `tools/BundledProjects_Example.swift`
- **Workflow Diagram**: `WORKFLOW_DIAGRAM.md`

## 🚨 Troubleshooting

### Images not appearing in Xcode
```bash
# Close Xcode, then:
rm -rf ~/Library/Developer/Xcode/DerivedData/*
# Reopen Xcode
```

### Script fails with TMDb error
```bash
# Verify API key:
echo $TMDB_API_KEY
# Should print your key, not empty

# Test API manually:
curl "https://api.themoviedb.org/3/search/movie?api_key=$TMDB_API_KEY&query=star+wars"
# Should return JSON with results
```

### Build fails after changes
```bash
# Clean build:
cd TiercadeCore && swift package clean && swift build
# Then rebuild tvOS app
```

### Node dependencies missing
```bash
cd tools
rm -rf node_modules package-lock.json
npm install
```

---

**Time Estimate**: 30-40 minutes for Phases 1-4
**Difficulty**: Easy (mostly automated)
**Prerequisites**: Node.js, Xcode, TMDb API key
