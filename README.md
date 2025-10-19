# Tiercade

A comprehensive tier list management application built with SwiftUI. Create, manage, and analyze tier lists with professional-grade features including advanced analytics, multiple export formats, and intelligent insights.

![iOS](https://img.shields.io/badge/iOS-26.0+-blue.svg)
![tvOS](https://img.shields.io/badge/tvOS-26.0+-blue.svg)
![macOS](https://img.shields.io/badge/macOS-26.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-green.svg)
![Xcode](https://img.shields.io/badge/Xcode-26+-blue.svg)

## 🚀 Features

### **Core Tier Management**
- **Drag & Drop Interface** - Native SwiftUI drag and drop on iOS/macOS, with click-to-select Quick Move workflows on tvOS
- **Multiple Tier Support** - Customizable tier structure (S, A, B, C, D, F tiers)
- **Item Management** - Add, remove, and organize items across tiers
- **Real-time Updates** - Instant visual feedback for all operations

### **Advanced Operations**
- **Quick Rank Mode** - Rapid tier assignment with gesture shortcuts
- **Head-to-Head Voting** - Binary comparison system for difficult ranking decisions
- **Search & Filter** - Real-time search with highlighting and advanced filtering options
- **Undo/Redo System** - Comprehensive history management with unlimited undo/redo

### **Data Management**
- **Enhanced Persistence** - Auto-save with crash recovery and multiple save slots
- **Export System** - Multiple format support:
  - JSON (structured data)
  - CSV (spreadsheet compatible)
  - Markdown (documentation ready)
  - Plain Text (human readable)
- **Import Capabilities** - JSON and CSV import with validation and error handling
- **Progress Tracking** - Visual progress indicators for all file operations

### **Analytics & Insights**
- **Statistical Analysis** - Comprehensive tier distribution analysis
- **Balance Scoring** - 0-100 scale algorithm evaluating tier distribution equality
- **Visual Charts** - Animated bar charts showing tier percentages
- **Rule-based Insights** - Clear recommendations for tier optimization
- **Interactive Dashboard** - Complete analytics UI with real-time statistics

### **User Experience**
- **Toast Notifications** - Contextual feedback for user actions
- **Loading Indicators** - Progress feedback for all async operations
- **Keyboard Shortcuts** - Productivity shortcuts (Cmd+A for analysis, Cmd+Z for undo)
- **Responsive Design** - Optimized for various iOS device sizes
- **Dark/Light Mode** - Full support for iOS appearance preferences
- **Immersive Media Gallery** - SwiftUI TabView gallery with remote-friendly focus and full-screen playback on tvOS

### **tvOS Experience**
- **Remote-First Navigation** - Optimized focus rings and directional layout tuned for the Siri Remote, with safe-area-aware spacing for comfortable living-room viewing.
- **Dedicated Overlays** - Quick Move, Quick Rank, and Detail overlays appear as modal glass surfaces that pause background interaction until dismissed, keeping attention on the active task.
- **Toolbar & Action Bar** - Floating top and bottom bars adapt to tvOS conventions, exposing undo/redo, head-to-head, analysis, and selection actions with clear focus targets.
- **Exit Command Handling** - Pressing the remote’s ⌘/Menu (Exit) button inside modals dismisses the current overlay instead of backing out of the app, mirroring native tvOS behavior.
- **Deferred Skip Flow** - The Head-to-Head overlay now features a dedicated Skip card with a recirculating clock icon, updates the skipped count live, and automatically resurfaces deferred pairs after all first-pass matchups.
- **Focus Tooltips** - Custom tooltips surface helpful hints (e.g. “Randomize”, “Lock Tier”) when buttons receive focus, guiding new users through tier management on the TV.
- **Media Playback** - Item detail pages can promote images and video with full-screen playback support that respects tvOS playback gestures.
## 🏗️ Architecture

### **Technical Stack**
- **SwiftUI** - Modern declarative UI framework
- **Swift 6.0** - Latest language features with strict concurrency checking
- **OS 26.0+** - Target deployment: iOS 26.0, tvOS 26.0, macOS 26.0
- **TiercadeCore** - Platform-agnostic Swift Package for shared logic (iOS 26+/macOS 26+/tvOS 26+)

> Note: The app targets OS 26.0+ to leverage the latest platform features (Swift 6 strict concurrency, modern SwiftUI APIs, @Observable macro). The `TiercadeCore` Swift package shares the same OS 26.0+ baseline to align compiler features and simplify maintenance.

### **Design Patterns**
- **MVVM Architecture** - Clean separation of concerns with SwiftUI
- **@Observable + @MainActor** - Modern Swift 6 state management with automatic observation
- **Typed Throws** - Compile-time error handling with specific error types
- **Async/Await** - Structured concurrency for file operations and analysis
- **Protocol-Oriented Design** - Flexible, testable interfaces throughout

### **Modernization Guardrails**
- **Strict Concurrency** – All targets enable "Complete" checking; core logic favors `Sendable` value types and actors for isolation (see `AGENTS.md` for build-setting guardrails).
- **Observation-First State** – UI state uses Swift Observation macros (`@Observable`, `@Bindable`) instead of `ObservableObject`/`@Published`.
- **SwiftUI Everywhere** – Screens, overlays, and navigation are pure SwiftUI with `NavigationStack`/`NavigationSplitView`; UIKit appears only through targeted representable adapters when absolutely necessary.
- **SwiftData Persistence** – SwiftData infrastructure (ModelContext) is wired in; primary tier list state currently persists via UserDefaults with planned migration to `@Model` + `@Query` for new features.
- **Async Streams** – Legacy Combine pipelines are rewritten to `AsyncSequence`, `AsyncStream`, `async let`, or `TaskGroup` constructs.
- **Liquid Glass Chrome** – Translucent, glassy effects stay confined to top-level chrome (toolbars, sheets) to keep fast-refreshing content performant.
- **Swift Testing** – New tests rely on the Swift Testing framework (`@Test`, `#expect`) with incremental XCTest retirement.
- **SwiftPM Only** – Dependencies live in SwiftPM; feature flags and environment variants opt into [SwiftPM traits](https://github.com/apple/swift-evolution/blob/main/proposals/0450-package-manager-traits.md). Trait identifiers are project-defined (e.g. `"feature.offlineMode"`), and can be toggled per configuration without extra targets.

### **Configuration Snippets**
```swift
// Package.swift baseline for strict concurrency
.enableUpcomingFeature("StrictConcurrency"),
.unsafeFlags(["-strict-concurrency=complete"])
```

```swift
// Example SPM traits configuration (Swift 6.1+)
traits: [
    .trait("feature.offlineMode"),
    .trait("feature.aiExperiments"),
    .trait("debug.tools", enabledTraits: ["development"])
]
```

### **Core Components**

#### **AppState (@MainActor + @Observable)**
Central state management with modern Swift 6 concurrency and observation:
```swift
@MainActor
@Observable
final class AppState {
    // Core state (automatic observation via @Observable)
    var tiers: Items = ["S":[],"A":[],"B":[],"C":[],"D":[],"F":[],"unranked":[]]
    var tierOrder: [String] = ["S","A","B","C","D","F"]

    // UI/feature state
    var searchQuery: String = ""
    var isLoading: Bool = false
    var loadingMessage: String = ""
    var operationProgress: Double = 0
    var currentToast: ToastMessage?
    var analysisData: TierAnalysisData?

    // Operations with typed throws
    func move(_ id: String, to tier: String)
    func exportToFormat(_ format: ExportFormat) async throws(ExportError) -> (Data, String)
    func generateAnalysis() async
    func save() throws(PersistenceError)
    func importFromJSON(_ jsonString: String) async throws(ImportError)
    func undo()
    func redo()
}
```

#### **Feature Architecture**
Each major feature is implemented as a self-contained system:

- **Export/Import System** - `ExportFormat` enum with async operations
- **Analysis Engine** - `TierAnalysisData` with statistical calculations
- **Progress System** - `withLoadingIndicator` wrapper plus `setLoading`/`updateProgress` with Sendable-safe operations
- **Undo Management** - System undo/redo backed by tier snapshots
- **Search System** - Real-time filtering with highlighting

### **Data Flow**
```
User Interaction → SwiftUI View → AppState Method →
TiercadeCore Logic → State Update → UI Refresh
```

## 🧪 Testing

The repository currently has no active test targets. All previous unit/UI tests were intentionally removed to enable a clean slate. When we reintroduce tests, we’ll use the Swift Testing framework (`@Test`, `#expect`) and keep tvOS UI automation lean and accessibility-driven.

## 🛠️ Development

### **Requirements**

- **Xcode 26+** - Latest development environment
- **iOS 26.0+ Simulator** - For testing and development
- **tvOS 26.0+ Simulator** - For tvOS UI testing (primary focus)
- **macOS 26.0+** - For macOS development and packaging
- **Swift 6.0** - Language mode with strict concurrency checking enabled

## 📚 More documentation
- Design tokens, Liquid Glass, and focus patterns: [`Tiercade/Design/README.md`](Tiercade/Design/README.md)
- Core domain models and deterministic helpers: [`TiercadeCore/README.md`](TiercadeCore/README.md)
- Platform guardrails, tvOS focus, and build scripts: [`AGENTS.md`](AGENTS.md)
- **macOS** - Development platform
- **SwiftLint** - Enforce cyclomatic complexity thresholds (warning 8, error 12) as part of pre-commit checks

### **Project Setup**

```bash
# Clone the repository
git clone <repository-url>
cd Tiercade

# Open in Xcode
open Tiercade.xcodeproj

# Build and run
Cmd+R (or Product → Run)
```

### **Interactive tvOS Verification**

- After every successful build, boot the tvOS simulator with the latest app build, keep it open for visual review, and exercise the relevant surfaces with a Siri Remote (or keyboard arrow) pass to confirm focus, animations, and gestures.
- Preferred flow: run the "Build tvOS Tiercade (Debug)" task (or `Cmd+R` in Xcode), then leave the simulator running while iterating on focus tweaks, visual polish, and final sign-off.

### **Project Structure**

```text
Tiercade/
├── Tiercade/                  # Main app target (SwiftUI + tvOS focus)
│   ├── State/                 # AppState core and feature extensions
│   ├── Views/
│   │   ├── Main/              # Core screen composition (ContentView, MainAppView)
│   │   ├── Toolbar/           # Toolbar views and export sheets
│   │   ├── Overlays/          # QuickMove, Item menu, QR overlays
│   │   └── Components/        # Reusable detail, settings, and shared parts
│   ├── Bridges/               # UIKit/AVKit bridges for focus & galleries
│   ├── Design/                # Tokens, themes, and tvOS metrics
│   ├── Export/                # Export renderer helpers
│   ├── Util/                  # Cross-cutting utilities (focus, device checks)
│   ├── SharedCore.swift       # Shared dependency wiring
│   └── TiercadeApp.swift      # App entry point
├── TiercadeCore/              # Platform-agnostic Swift Package
│   ├── Sources/
│   │   ├── Models/            # Data structures & model resolution
│   │   ├── Logic/             # Tiering, history, head-to-head logic
│   │   └── Utilities/         # Formatters, data loaders, randomness
│   └── README.md              # Core package overview (tests will return later)
└── Tiercade.xcodeproj/        # Xcode project configuration
```

## 📊 Implementation Details

### **Export System Architecture**

Multi-format export with async operations and progress tracking:

```swift
enum ExportFormat: CaseIterable {
    case text, json, markdown, csv

    var displayName: String { /* Plain Text, JSON, Markdown, CSV */ }
    var fileExtension: String { /* txt, json, md, csv */ }
}

// Async export with progress updates — returns (data, suggestedFileName)
func exportToFormat(_ format: ExportFormat, group: String = "All", themeName: String = "Default") async -> (Data, String)? {
    await withLoadingIndicator(message: "Exporting \(format.displayName)...") {
        updateProgress(0.2)
        // produce content
        updateProgress(1.0)
        return (Data(), "tier_list.\(format.fileExtension)")
    }
}
```

### **Analysis Engine**

Comprehensive statistical analysis with balance scoring algorithm:

```swift
struct TierAnalysisData {
    let totalItems: Int
    let tierDistribution: [TierDistributionData]
    let mostPopulatedTier: String?
    let leastPopulatedTier: String?
    let balanceScore: Double   // 0-100 scale
    let insights: [String]     // Rule-based recommendations
    let unrankedCount: Int
}
```

### **Progress System**

Unified progress tracking for all async operations:

```swift
func withLoadingIndicator<T>(message: String, operation: () async throws -> T) async rethrows -> T {
    setLoading(true, message: message)
    defer { setLoading(false) }
    return try await operation()
}

// Use alongside granular updates
func setLoading(_ loading: Bool, message: String = "") { /* updates isLoading, loadingMessage */ }
func updateProgress(_ value: Double) { /* 0.0 ... 1.0 */ }
```

## 🎯 Design Decisions

### **State Management Choice: @Observable + @MainActor**

- **Rationale**: Modern Swift 6 observation replacing @ObservableObject/@Published
- **Benefits**: Automatic observation, no boilerplate, compile-time concurrency safety
- **Trade-offs**: Requires Swift 6 and latest OS versions

### **Architecture: MVVM with SwiftUI**

- **Rationale**: Natural fit for SwiftUI's declarative paradigm
- **Benefits**: Clean separation, testable business logic, reactive UI
- **Trade-offs**: Some boilerplate, complexity for simple features

### **Core Logic: Separate Swift Package (TiercadeCore)**

- **Rationale**: Platform-agnostic logic for potential multi-platform expansion
- **Benefits**: Reusability, focused testing, clear boundaries
- **Trade-offs**: Additional complexity, package management overhead

### **File Operations: Native iOS APIs**

- **Rationale**: Deep integration with iOS Files app and sharing
- **Benefits**: Native UX, security model compliance, feature richness
- **Trade-offs**: iOS-specific implementation, complexity

### **Analytics: Custom Algorithm Implementation**

- **Rationale**: Tailored balance scoring for tier list optimization
- **Benefits**: Domain-specific insights, no external dependencies
- **Trade-offs**: Custom algorithm maintenance, limited to our metrics

## 🚀 Performance Considerations

### **Async Operations**

- All file I/O operations use async/await for non-blocking UI
- Progress tracking provides user feedback during long operations
- Proper error handling with user-friendly messages

### **Memory Management**

- @MainActor ensures UI updates on main thread
- Weak references where appropriate to prevent retain cycles
- Efficient data structures for large item lists

### **UI Responsiveness**

- SwiftUI's declarative updates for smooth animations
- Debounced search to avoid excessive filtering
- Lazy loading for large datasets

## 📱 User Experience Design

### **Interaction Patterns**

- **Drag & Drop** - Primary interaction for tier management
- **Quick Actions** - Keyboard shortcuts for power users
- **Progressive Disclosure** - Advanced features accessible but not overwhelming
- **Contextual Feedback** - Toast messages and progress indicators

### **Visual Design**

- **Native iOS Patterns** - Follows Apple's Human Interface Guidelines
- **Consistent Spacing** - Systematic layout with proper margins
- **Color Coding** - Semantic colors for different states and actions
- **Typography** - iOS system fonts with appropriate hierarchy

### **Accessibility**

- VoiceOver support for screen readers
- Dynamic Type support for text scaling
- High contrast mode compatibility
- Keyboard navigation support

## 🔮 Future Enhancements

### **Planned Features**

- **Cloud Sync** - iCloud integration for cross-device synchronization
- **Collaboration** - Share tier lists with real-time collaboration
- **Templates** - Pre-built tier list templates for common categories
- **Advanced Analytics** - Machine learning insights and trends
- **Widget Support** - iOS home screen widgets for quick access

### **Technical Improvements**

- **Performance Optimization** - Core Data for large datasets
- **Offline Capabilities** - Enhanced offline-first architecture
- **Localization** - Multi-language support
- **Apple Watch** - Companion app for quick tier management

## 📄 License

This project is currently unlicensed. This is a personal project developed with GitHub Copilot assistance.

## 📚 Documentation

- **Core Package**: [TiercadeCore/README.md](TiercadeCore/README.md) - Platform-agnostic logic and models
- **Design System**: [Tiercade/Design/README.md](Tiercade/Design/README.md) - Design tokens and styles
- **Tools & Testing**: [tools/README.md](tools/README.md) - tvOS debugging and automation
- **Copilot Instructions**: [.github/copilot-instructions.md](.github/copilot-instructions.md) - Development guidance for AI assistance

## 📞 Support

For project support and questions, please open an issue on GitHub or contact the maintainer via the repository email in GitHub profile.

---

**Built with ❤️ using SwiftUI and modern iOS development practices.**
