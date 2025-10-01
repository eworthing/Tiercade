```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Tiercade Image Fetching Workflow                         │
└─────────────────────────────────────────────────────────────────────────────┘

Step 1: Get TMDb API Key
─────────────────────────────────────────────────────────────────────────────
   https://www.themoviedb.org/settings/api
            │
            ▼
   export TMDB_API_KEY='your-key-here'


Step 2: Run Automated Script
─────────────────────────────────────────────────────────────────────────────
   ./tools/fetch_bundled_images.sh
            │
            ├─→ Generates temp project files
            │   ├─→ star-wars-saga.json
            │   └─→ animated-classics.json
            │
            ├─→ Calls fetch_media_and_thumb.js for each
            │   ├─→ Searches TMDb API
            │   ├─→ Downloads poster images
            │   └─→ Creates Xcode asset catalog entries
            │
            └─→ Organizes into asset catalog


Step 3: Result - Asset Catalog Structure
─────────────────────────────────────────────────────────────────────────────
   Tiercade/Assets.xcassets/
   └── BundledTierlists/
       ├── StarWars/
       │   ├── a-new-hope.imageset/
       │   │   ├── Contents.json ✅
       │   │   └── a-new-hope.jpg ✅
       │   ├── empire-strikes-back.imageset/
       │   ├── return-of-the-jedi.imageset/
       │   └── ... (11 total)
       │
       └── Animated/
           ├── batman-tas.imageset/
           ├── x-men-tas.imageset/
           └── ... (8 total)


Step 4: Update Swift Code
─────────────────────────────────────────────────────────────────────────────
   TiercadeCore/Sources/TiercadeCore/Bundled/BundledProjects.swift

   BEFORE:
   ┌────────────────────────────────────────────────────────────────┐
   │ static func item(id: String, title: String, summary: String)   │
   │     -> Project.Item {                                          │
   │     Project.Item(id: id, title: title, summary: summary)       │
   │ }                                                              │
   └────────────────────────────────────────────────────────────────┘

   AFTER:
   ┌────────────────────────────────────────────────────────────────┐
   │ static func item(                                              │
   │     id: String,                                                │
   │     title: String,                                             │
   │     summary: String,                                           │
   │     imageUrl: String? = nil  ← ADD THIS                        │
   │ ) -> Project.Item {                                            │
   │     Project.Item(                                              │
   │         id: id,                                                │
   │         name: title,                                           │
   │         description: summary,                                  │
   │         imageUrl: imageUrl   ← ADD THIS                        │
   │     )                                                          │
   │ }                                                              │
   └────────────────────────────────────────────────────────────────┘

   ADD TO EACH ITEM:
   ┌────────────────────────────────────────────────────────────────┐
   │ item(                                                          │
   │     id: "a-new-hope",                                          │
   │     title: "Episode IV — A New Hope",                          │
   │     summary: "The 1977 original...",                           │
   │     imageUrl: "BundledTierlists/StarWars/a-new-hope" ← ADD    │
   │ )                                                              │
   └────────────────────────────────────────────────────────────────┘


Step 5: Use in SwiftUI
─────────────────────────────────────────────────────────────────────────────
   Views/Overlays/BundledTierlistSelector.swift (or similar)

   ┌────────────────────────────────────────────────────────────────┐
   │ if let imageUrl = item.imageUrl {                              │
   │     Image(imageUrl)                                            │
   │         .resizable()                                           │
   │         .aspectRatio(contentMode: .fit)                        │
   │         .frame(width: 200, height: 300)                        │
   │ } else {                                                       │
   │     Image(systemName: "photo")                                 │
   │         .resizable()                                           │
   │         .frame(width: 200, height: 300)                        │
   │ }                                                              │
   └────────────────────────────────────────────────────────────────┘


Data Flow Diagram
─────────────────────────────────────────────────────────────────────────────

   TMDb API                    Your Script                 Xcode
   ─────────                   ────────────               ────────
   
   [Star Wars]                 fetch_media_and_thumb.js    Assets.xcassets
   [Animated]  ─────search────→                           
       │                              │                          
       │                              │                          
       └──────returns posters────────►│                          
                                      │                          
                                      ├──downloads JPG───────────►
                                      │                          
                                      ├──creates Contents.json──►
                                      │                          
                                      └──updates JSON with────────
                                         asset references         
                                              │                   
                                              │                   
                                              ▼                   
                                    BundledProjects.swift         
                                    (manual update)               
                                              │                   
                                              │                   
                                              ▼                   
                                    SwiftUI Views                 
                                    (Image(imageUrl))             


File System Layout
─────────────────────────────────────────────────────────────────────────────

   Tiercade/
   ├── Assets.xcassets/
   │   └── BundledTierlists/        ← GENERATED BY SCRIPT
   │       ├── StarWars/
   │       │   ├── a-new-hope.imageset/
   │       │   ├── empire-strikes-back.imageset/
   │       │   └── ...
   │       ├── Animated/
   │       │   ├── batman-tas.imageset/
   │       │   └── ...
   │       └── Survivor/            ← MANUAL (TMDb doesn't have)
   │           └── richard-hatch.imageset/
   │
   ├── Views/
   │   └── Overlays/
   │       └── BundledTierlistSelector.swift  ← UPDATE TO USE IMAGES
   │
   └── TiercadeCore/
       └── Sources/
           └── TiercadeCore/
               ├── Models/
               │   └── Models.swift           ← ALREADY HAS imageUrl! ✅
               └── Bundled/
                   └── BundledProjects.swift  ← UPDATE WITH imageUrl

   tools/
   ├── fetch_media_and_thumb.js     ← ENHANCED WITH TMDb
   ├── fetch_bundled_images.sh      ← NEW: AUTOMATED SCRIPT
   ├── test_image_tools.sh          ← NEW: TEST SUITE
   ├── README_IMAGES.md             ← NEW: DOCUMENTATION
   └── media/                       ← DOWNLOADED IMAGES (BACKUP)
       ├── star-wars-saga/
       └── animated-classics/


Quick Command Reference
─────────────────────────────────────────────────────────────────────────────

   # Get TMDb API key
   open https://www.themoviedb.org/settings/api
   export TMDB_API_KEY='your-key-here'

   # Test the tools
   ./tools/test_image_tools.sh

   # Fetch all bundled images
   ./tools/fetch_bundled_images.sh

   # Manual fetch for custom project
   node tools/fetch_media_and_thumb.js project.json \
       --tmdb \
       --xcode-assets Tiercade/Assets.xcassets \
       --asset-group "BundledTierlists/Custom"

   # Build tvOS app
   xcodebuild -project Tiercade.xcodeproj \
              -scheme Tiercade \
              -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest'


Coverage Matrix
─────────────────────────────────────────────────────────────────────────────

   Tier List               Items    TMDb      Status        Action
   ─────────────────────   ─────    ────────  ──────────    ─────────────
   Star Wars Films           11     ✅ Full   Automated     Run script
   90s Animated Classics      8     ✅ Good   Automated     Run script
   Survivor Winners          13     ❌ None   Manual        Source CBS photos


Success Checklist
─────────────────────────────────────────────────────────────────────────────

   Prerequisites:
   [ ] Node.js installed
   [ ] npm dependencies installed (npm install in tools/)
   [ ] TMDb API key obtained
   [ ] API key exported to environment

   Automated Fetching:
   [ ] Run ./tools/fetch_bundled_images.sh
   [ ] Verify images in tools/media/
   [ ] Verify asset catalog in Tiercade/Assets.xcassets/BundledTierlists/
   [ ] Review image quality

   Swift Code Updates:
   [ ] Update ItemsFactory.item() function signature
   [ ] Add imageUrl to Star Wars items (11 items)
   [ ] Add imageUrl to Animated items (8 items)
   [ ] Build TiercadeCore (cd TiercadeCore && swift build)

   UI Integration:
   [ ] Update BundledProjectCard or relevant view to display images
   [ ] Add placeholder for missing images
   [ ] Build tvOS app
   [ ] Test in simulator
   [ ] Verify image loading
   [ ] Verify focus behavior

   Optional - Survivor:
   [ ] Source CBS promotional photos
   [ ] Create asset catalog entries manually
   [ ] Add imageUrl to Survivor items (13 items)


Documentation Index
─────────────────────────────────────────────────────────────────────────────

   📄 IMPLEMENTATION_COMPLETE.md     ← START HERE (this summary)
   📄 tools/README_IMAGES.md         ← Complete usage guide
   📄 tools/IMAGE_FETCHING_SUMMARY.md ← Technical details
   📄 tools/BundledProjects_Example.swift ← Code examples
   📄 BUNDLED_IMAGES_SUMMARY.md      ← Original research + sources
   📄 tools/README.md                ← Updated tools index

   🔧 tools/fetch_bundled_images.sh  ← Main automation script
   🔧 tools/fetch_media_and_thumb.js ← Core fetching engine
   🧪 tools/test_image_tools.sh      ← Validation tests
```
