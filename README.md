# Tiercade iOS

A comprehensive tier list management application for iOS, built with SwiftUI. Create, manage, and analyze tier lists with professional-grade features including advanced analytics, multiple export formats, and intelligent insights.

![iOS](https://img.shields.io/badge/iOS-18.5+-blue.svg)
![tvOS](https://img.shields.io/badge/tvOS-17+-lightgrey.svg)
![macOS](https://img.shields.io/badge/macOS-14+-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-green.svg)
![Xcode](https://img.shields.io/badge/Xcode-16+-blue.svg)

## 🚀 Features

### **Core Tier Management**
- **Drag & Drop Interface** - Native SwiftUI drag and drop with visual feedback
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

## 🏗️ Architecture

### **Technical Stack**
- **SwiftUI** - Modern declarative UI framework
- **Swift 6.0** - Latest language features with strict concurrency
- **iOS 18.5+** - Target deployment supporting latest iOS features
- **TiercadeCore** - Platform-agnostic Swift Package for shared logic

### **Design Patterns**
- **MVVM Architecture** - Clean separation of concerns with SwiftUI
- **@MainActor State Management** - Thread-safe UI updates with published properties
- **Async/Await** - Modern concurrency for file operations and analysis
- **Protocol-Oriented Design** - Flexible, testable interfaces throughout

### **Core Components**

#### **AppState (@MainActor)**
Central state management with comprehensive functionality:
```swift
@MainActor
final class AppState: ObservableObject {
    // Core state
    @Published var tiers: TLTiers = ["S":[],"A":[],"B":[],"C":[],"D":[],"F":[],"unranked":[]]
    @Published var tierOrder: [String] = ["S","A","B","C","D","F"]
    
    // UI/feature state
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    @Published var operationProgress: Double = 0
    @Published var currentToast: ToastMessage?
    @Published var analysisData: TierAnalysisData?

    // Operations (signatures)
    func move(_ id: String, to tier: String)
    func exportToFormat(_ format: ExportFormat, group: String, themeName: String) async -> (Data, String)?
    func generateAnalysis() async
    func randomize()
    func undo()
    func redo()
}
```

#### **Feature Architecture**
Each major feature is implemented as a self-contained system:

- **Export/Import System** - `ExportFormat` enum with async operations
- **Analysis Engine** - `TierAnalysisData` with statistical calculations
- **Progress System** - `withLoadingIndicator` wrapper plus `setLoading`/`updateProgress` with Sendable-safe operations
- **History Management** - Operation tracking with state snapshots
- **Search System** - Real-time filtering with highlighting

### **Data Flow**
```
User Interaction → SwiftUI View → AppState Method → 
TiercadeCore Logic → State Update → UI Refresh
```

## 🧪 Testing

### **Test Coverage**
- **Unit Tests** - Core logic validation in TiercadeCore (run via `swift test` inside `TiercadeCore`)
- **Integration Tests** - Feature interaction testing
- **UI Tests** - End-to-end user journey validation (iOS/tvOS simulators supported)

### **Running Tests**
```bash
# Unit tests for core logic
cd TiercadeCore && swift test

# iOS app tests (example, adjust device name as needed)
xcodebuild test -project Tiercade.xcodeproj -scheme Tiercade -destination 'platform=iOS Simulator,name=iPhone 16'

# tvOS UI tests (example using simulator UDID)
# xcodebuild test -project Tiercade.xcodeproj -scheme Tiercade -destination "platform=tvOS Simulator,id=<SIM_UDID>"
```

### **Test Architecture**
- **TiercadeCore Tests** - Platform-agnostic logic testing
- **TiercadeTests** - iOS-specific functionality testing  
- **TiercadeUITests** - User interface and interaction testing

## 🛠️ Development

### **Requirements**
- **Xcode 16+** - Latest development environment
- **iOS 18.5+ Simulator** - For testing and development (recommended)
- **tvOS 17+ Simulator** - For tvOS UI testing
- **macOS 14+** - For macOS development and packaging
- **Swift 6.0** - Language mode with strict concurrency and enhanced type safety
- **macOS** - Development platform

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

### **Project Structure**
```
Tiercade/
├── Tiercade/                  # Main iOS app target
│   ├── AppState.swift         # Central state management
│   ├── ContentView.swift      # Main UI composition
│   └── TiercadeApp.swift      # App entry point
├── TiercadeCore/              # Platform-agnostic Swift Package
│   ├── Sources/               # Core domain logic
│   └── Tests/                 # Unit tests
├── TiercadeTests/             # iOS integration tests
├── TiercadeUITests/           # UI automation tests
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
- **Rationale**: Modern SwiftUI state management with thread safety
- **Benefits**: Automatic UI updates, compile-time safety, clear data flow
- **Trade-offs**: iOS 17+ requirement, learning curve for team

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

This project is currently unlicensed in the repository. If you intend to open-source it, add a LICENSE file at the repository root (for example, MIT or Apache-2.0). For private/internal projects, include a short statement here describing distribution restrictions.

## 🤝 Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

Also see the core package docs: [TiercadeCore/README.md](TiercadeCore/README.md)

## 📞 Support

For project support and questions, please open an issue on GitHub or contact the maintainer via the repository email in GitHub profile.

---

**Built with ❤️ using SwiftUI and modern iOS development practices.**