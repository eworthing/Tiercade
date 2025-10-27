# Mac Catalyst to Native macOS Migration Report

**Project:** Tiercade
**Current State:** Mac Catalyst (UIKit-based iOS app on macOS)
**Target State:** Native macOS app with SwiftUI/AppKit
**Target Platforms:** tvOS 26 (primary), iOS 26, macOS 26 Tahoe, iPadOS 26
**Swift Version:** Swift 6.2 with strict concurrency
**Date:** October 2025

---

## Executive Summary

This report provides a comprehensive, step-by-step migration strategy for converting Tiercade from a Mac Catalyst application to a native macOS application. The migration preserves cross-platform tooling, leverages macOS 26 Tahoe's Liquid Glass design system, maintains the existing SwiftUI-first architecture, and keeps tvOS as the primary platform with minimal disruption to the iOS and iPadOS codebases.

**Key Benefits of Migration:**
- Access to native macOS APIs (NSPasteboard, AppKit controls, native menus)
- Better integration with macOS 26 Tahoe Liquid Glass design system
- Improved performance and memory characteristics
- Removal of Catalyst-specific workarounds and scaling hacks
- First-class macOS citizen with native keyboard shortcuts and menu bar
- Maintained cross-platform codebase with minimal conditional compilation

**Migration Scope:**
- 7 files with UIKit dependencies requiring API replacements
- 13 files with platform-specific conditional compilation requiring updates
- Build configuration updates (Xcode project settings, Package.swift)
- Platform check refactoring (`targetEnvironment(macCatalyst)` → `os(macOS)`)
- Minimal new code—primarily API replacements and build setting adjustments

---

## Table of Contents

1. [Current Architecture Analysis](#current-architecture-analysis)
2. [UIKit to Native macOS API Mapping](#uikit-to-native-macos-api-mapping)
3. [Platform Conditional Refactoring Strategy](#platform-conditional-refactoring-strategy)
4. [Build Configuration Changes](#build-configuration-changes)
5. [File-by-File Migration Guide](#file-by-file-migration-guide)
6. [macOS 26 Tahoe Feature Integration](#macos-26-tahoe-feature-integration)
7. [Testing Strategy](#testing-strategy)
8. [Rollout Plan](#rollout-plan)
9. [Risk Mitigation](#risk-mitigation)

---

## Current Architecture Analysis

### Platform Distribution
Tiercade currently uses a **single iOS codebase** that serves:
- **tvOS 26+** (primary platform) - remote-first UX, focus management
- **iOS 26+** - touch-first, compact/regular size classes
- **iPadOS 26+** - pointer + touch, NavigationSplitView
- **macOS 26+ via Mac Catalyst** - UIKit-based iOS app running on macOS

### Current Mac Catalyst Implementation

**Build Configuration:**
```
SUPPORTED_PLATFORMS = "appletvos appletvsimulator iphoneos iphonesimulator macosx"
SUPPORTS_MACCATALYST = YES
SDKROOT = auto
SWIFT_VERSION = 6.0
```

**Build Script (build_install_launch.sh:72-77):**
```bash
catalyst|mac)
  DESTINATION='platform=macOS,variant=Mac Catalyst'
  DEVICE_NAME='Mac'
  BUNDLE_ID='eworthing.Tiercade'
  EMOJI="💻"
  ;;
```

### Conditional Compilation Patterns

**Current Platform Checks:**
```swift
// Catalyst/macOS detection (INCORRECT for native macOS)
#if os(macOS) || targetEnvironment(macCatalyst)
import AppKit
#endif

// iOS family (includes Catalyst)
#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit
#endif

// tvOS-specific
#if os(tvOS)
// tvOS-only code
#endif
```

**Problem:** The `os(macOS) || targetEnvironment(macCatalyst)` pattern is actually checking for **native macOS OR Catalyst**. Currently, the app only runs as Catalyst, so this works. After migration, we'll use `os(macOS)` directly.

### UIKit Dependencies Inventory

| File | UIKit API | Purpose | Line(s) |
|------|-----------|---------|---------|
| **OpenExternal.swift** | `UIApplication.shared.open()` | Open URLs externally | 13-16 |
| **AIChatOverlay.swift** | `UIPasteboard.general.string` | Clipboard copy | 289 |
| **AIChatOverlay+ImageGeneration.swift** | `UIImage(cgImage:)` | CGImage → UIImage conversion | 73-75 |
| **ContentView+TierGrid.swift** | Indirect via platform layout | Catalyst scaling (1.12x) | 251-252 |
| **ContentView+Overlays.swift** | `UIImage(systemName:)` | Symbol attachment for toast | 139 |
| **ContentView+Analysis.swift** | `UIColor.systemGray4` | Color for chart stroke | 251 |
| **MediaGalleryView.swift** | None (TabView style difference) | `.page` style unavailable | 32-37 |

### Navigation Architecture

**MainAppView.swift Platform Switching (Lines 51-65):**
```swift
return Group {
    #if os(tvOS)
    tvOSPrimaryContent(modalBlockingFocus: modalBlockingFocus)
    #elseif os(macOS) || targetEnvironment(macCatalyst)
    macSplitView(modalBlockingFocus: modalBlockingFocus)
    #elseif os(iOS)
    if horizontalSizeClass == .regular {
        regularWidthSplitView(modalBlockingFocus: modalBlockingFocus)
    } else {
        compactStack(modalBlockingFocus: modalBlockingFocus)
    }
    #endif
}
```

**macOS/Catalyst Navigation (MainAppView.swift:284-299):**
```swift
@ViewBuilder
private func macSplitView(modalBlockingFocus: Bool) -> some View {
    NavigationSplitView {
        SidebarView(tierOrder: app.tierOrder)
            .allowsHitTesting(!modalBlockingFocus)
            .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
    } detail: {
        tierGridLayer(modalBlockingFocus: modalBlockingFocus)
            .toolbar { ToolbarView(app: app) }
            .navigationTitle("Tiercade")
    }
    .navigationSplitViewStyle(.balanced)
    .toolbarRole(.editor)
}
```

**Key Insight:** The NavigationSplitView implementation is **already native SwiftUI** and will work unchanged on native macOS. No migration needed here.

### Design System Status

**Liquid Glass Implementation (AGENTS.md:176-185):**
> Liquid Glass (`glassEffect`) is available on iOS, iPadOS, macOS (including Catalyst), and tvOS 26+. We intentionally lead with tvOS styling, but the same modifiers work on other OSes.

**Current Status:** App already uses Liquid Glass via SwiftUI's tvOS 26 APIs:
- `glassEffect(_:in:)` for chrome surfaces
- `GlassEffectContainer` helper
- `.buttonStyle(.glass)` / `GlassProminentButtonStyle`
- `.tvGlassRounded()` custom modifier

**Implication:** No Liquid Glass migration needed—existing code works natively on macOS 26 Tahoe.

---

## UIKit to Native macOS API Mapping

### 1. URL Opening

**Current (Catalyst):**
```swift
// OpenExternal.swift:13-16
#if canImport(UIKit)
UIApplication.shared.open(url) { ok in
    Task { @MainActor in
        completion(ok ? .success : .unsupported)
    }
}
#endif
```

**Native macOS Replacement:**
```swift
// OpenExternal.swift (UPDATED)
#if os(macOS)
import AppKit
NSWorkspace.shared.open(url)
Task { @MainActor in
    completion(.success)  // NSWorkspace.open returns void, assume success
}
#elseif os(iOS)
import UIKit
UIApplication.shared.open(url) { ok in
    Task { @MainActor in
        completion(ok ? .success : .unsupported)
    }
}
#endif
```

**Apple Documentation:** `NSWorkspace.shared.open(_:)` is the standard macOS API for opening URLs with the default application.

### 2. Clipboard Access

**Current (Catalyst):**
```swift
// AIChatOverlay.swift:284-290
private func copyToClipboard(_ text: String) {
    #if os(macOS) && !targetEnvironment(macCatalyst)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #elseif os(iOS) || targetEnvironment(macCatalyst)
    UIPasteboard.general.string = text
    #endif

    app.showSuccessToast("Copied", message: "Response copied to clipboard")
}
```

**Native macOS Replacement:**
```swift
// AIChatOverlay.swift:284-290 (UPDATED)
private func copyToClipboard(_ text: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #elseif os(iOS)
    UIPasteboard.general.string = text
    #endif

    app.showSuccessToast("Copied", message: "Response copied to clipboard")
}
```

**Change:** Remove `!targetEnvironment(macCatalyst)` check—native macOS always uses NSPasteboard.

**Apple Documentation:**
- `NSPasteboard` (AppKit) - macOS clipboard API
- `UIPasteboard` (UIKit) - iOS clipboard API
- Both APIs follow similar patterns but are platform-specific

### 3. Image Conversion (CGImage → Platform Image)

**Current (Catalyst):**
```swift
// AIChatOverlay+ImageGeneration.swift:68-76
#if os(macOS) && !targetEnvironment(macCatalyst)
let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
generatedImage = Image(nsImage: nsImage)
imageGenerated = true
#elseif os(iOS) || targetEnvironment(macCatalyst)
let uiImage = UIImage(cgImage: cgImage)
generatedImage = Image(uiImage: uiImage)
imageGenerated = true
#endif
```

**Native macOS Replacement:**
```swift
// AIChatOverlay+ImageGeneration.swift:68-76 (UPDATED)
#if os(macOS)
let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
generatedImage = Image(nsImage: nsImage)
imageGenerated = true
#elseif os(iOS)
let uiImage = UIImage(cgImage: cgImage)
generatedImage = Image(uiImage: uiImage)
imageGenerated = true
#endif
```

**Change:** Remove `!targetEnvironment(macCatalyst)` check—native macOS always uses NSImage.

**SwiftUI Bridge:** Both `Image(nsImage:)` and `Image(uiImage:)` are native SwiftUI initializers that work seamlessly on their respective platforms.

### 4. Symbol Attachment (Toast Messages)

**Current (Catalyst):**
```swift
// ContentView+Overlays.swift:137-145
private func makeSymbolAttachment(named symbolName: String) -> NSTextAttachment? {
    #if canImport(UIKit)
    guard let image = UIImage(systemName: symbolName) else { return nil }
    let attachment = NSTextAttachment()
    attachment.image = image
    return attachment
    #else
    return nil
    #endif
}
```

**Native macOS Replacement:**
```swift
// ContentView+Overlays.swift:137-145 (UPDATED)
private func makeSymbolAttachment(named symbolName: String) -> NSTextAttachment? {
    #if os(iOS)
    guard let image = UIImage(systemName: symbolName) else { return nil }
    let attachment = NSTextAttachment()
    attachment.image = image
    return attachment
    #elseif os(macOS)
    guard let image = NSImage(systemName: symbolName) else { return nil }
    let attachment = NSTextAttachment()
    attachment.image = image
    return attachment
    #else
    return nil
    #endif
}
```

**Change:** Add explicit macOS branch using `NSImage(systemName:)` (available macOS 11.0+).

**Apple Documentation:** Both UIImage and NSImage support SF Symbols via `systemName:` initializer.

### 5. UIColor to NSColor

**Current (Catalyst):**
```swift
// ContentView+Analysis.swift:247-255
let strokeColor: Color = {
    #if os(tvOS)
    return Palette.surfHi
    #elseif canImport(UIKit)
    return Color(UIColor.systemGray4)
    #else
    return Palette.surfHi
    #endif
}()
```

**Native macOS Replacement:**
```swift
// ContentView+Analysis.swift:247-255 (UPDATED)
let strokeColor: Color = {
    #if os(tvOS)
    return Palette.surfHi
    #elseif os(iOS)
    return Color(UIColor.systemGray4)
    #elseif os(macOS)
    return Color(NSColor.systemGray)  // NSColor.systemGray is closest to UIColor.systemGray4
    #else
    return Palette.surfHi
    #endif
}()
```

**Change:** Use `NSColor.systemGray` on macOS (AppKit semantic color).

**Apple Documentation:**
- `UIColor.systemGray4` - iOS semantic color (lighter gray)
- `NSColor.systemGray` - macOS semantic color
- SwiftUI's `Color()` bridges both automatically

**Alternative (Platform-Agnostic):** Since this is just a chart stroke, consider using a design token from `Palette.swift` instead of platform-specific system colors to maintain visual consistency.

### 6. Catalyst Scaling Removal

**Current (Catalyst):**
```swift
// PlatformCardLayout.swift:50-63
let scale: CGFloat = {
    #if targetEnvironment(macCatalyst)
    return 1.12
    #else
    switch horizontalSizeClass {
    case .some(.regular):
        return 1.04
    case .some(.compact):
        return 0.96
    default:
        return 1.0
    }
    #endif
}()
```

**Native macOS Replacement:**
```swift
// PlatformCardLayout.swift:50-63 (UPDATED)
let scale: CGFloat = {
    #if os(macOS)
    return 1.0  // Native macOS needs no scaling adjustment
    #else
    switch horizontalSizeClass {
    case .some(.regular):
        return 1.04
    case .some(.compact):
        return 0.96
    default:
        return 1.0
    }
    #endif
}()
```

**Rationale:** The 1.12x Catalyst scaling was a workaround for Catalyst's upscaled iOS interface. Native macOS apps render at native resolution and don't need artificial scaling.

### 7. TabView Page Style

**Current (Catalyst):**
```swift
// MediaGalleryView.swift:32-37
#if os(tvOS)
.tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
#elseif os(iOS) && !targetEnvironment(macCatalyst)
.tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
#else
// Mac Catalyst: .page style isn't available, use automatic
.tabViewStyle(.automatic)
#endif
```

**Native macOS Replacement:**
```swift
// MediaGalleryView.swift:32-37 (UPDATED)
#if os(tvOS) || os(iOS)
.tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
#elseif os(macOS)
.tabViewStyle(.automatic)  // macOS doesn't support .page style
#endif
```

**Rationale:** The `.page` TabView style is iOS/tvOS-specific. macOS uses tab-based navigation natively. This change simplifies the conditional and is functionally equivalent.

---

## Platform Conditional Refactoring Strategy

### Pattern Replacement Rules

**Rule 1: Remove Catalyst Environment Checks**
```swift
// BEFORE (Catalyst)
#if targetEnvironment(macCatalyst)
// Catalyst code
#endif

// AFTER (Native macOS)
#if os(macOS)
// macOS code
#endif
```

**Rule 2: Split iOS/macOS from Combined Checks**
```swift
// BEFORE (Catalyst)
#if os(macOS) || targetEnvironment(macCatalyst)
// macOS OR Catalyst code
#endif

// AFTER (Native macOS)
#if os(macOS)
// Native macOS code
#endif
```

**Rule 3: Update iOS Family Checks**
```swift
// BEFORE (Catalyst)
#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit
#endif

// AFTER (Native macOS)
#if os(iOS)
import UIKit
#endif
```

**Rule 4: Preserve tvOS-Specific Logic**
```swift
// NO CHANGE NEEDED
#if os(tvOS)
// tvOS code remains unchanged
#endif
```

### Import Statement Refactoring

**Current Pattern (AIChatOverlay.swift:7-13):**
```swift
#if os(macOS) || targetEnvironment(macCatalyst)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif
```

**Updated Pattern:**
```swift
#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif
```

**Affected Files:**
- AIChatOverlay.swift
- AIChatOverlay+ImageGeneration.swift
- ContentView+Overlays.swift (UIKit import)
- ContentView+Analysis.swift (indirect via UIColor)

### File Exclusions

**ToolbarExportFormatSheetView.swift (Entire File Wrapped):**
```swift
// Current: Line 1
#if os(iOS) || targetEnvironment(macCatalyst)
// ... 212 lines of iOS/Catalyst-only code ...
#endif

// Updated: Line 1
#if os(iOS)
// ... 212 lines of iOS-only code ...
// Add macOS alternative implementation OR exclude from macOS build
#endif
```

**Decision Point:** This file uses iOS-specific `FileDocument` and `.fileExporter()`. Two options:

**Option A (Recommended):** Keep iOS-only, implement macOS alternative:
```swift
#if os(iOS)
// Existing iOS sheet with FileDocument
#endif

#if os(macOS)
// macOS alternative using NSSavePanel
internal struct ExportFormatSheetView<Coordinator: ToolbarExportCoordinating>: View {
    // Implement using macOS-native file save dialog
}
#endif
```

**Option B:** Exclude from macOS entirely and use alternative export UX (e.g., direct save to Downloads).

**Recommendation:** Implement Option A to maintain feature parity. macOS users expect native file save dialogs.

---

## Build Configuration Changes

### Xcode Project Settings (Tiercade.xcodeproj)

**Current Settings:**
```
SUPPORTED_PLATFORMS = "appletvos appletvsimulator iphoneos iphonesimulator macosx"
SUPPORTS_MACCATALYST = YES
SDKROOT = auto
```

**Updated Settings:**
```
SUPPORTED_PLATFORMS = "appletvos appletvsimulator iphoneos iphonesimulator macosx"
SUPPORTS_MACCATALYST = NO
SDKROOT = auto
MACOSX_DEPLOYMENT_TARGET = 26.0
```

**Changes:**
1. Set `SUPPORTS_MACCATALYST = NO` to disable Catalyst runtime
2. Add explicit `MACOSX_DEPLOYMENT_TARGET = 26.0` (matches tvOS/iOS 26 targets)
3. Keep `SDKROOT = auto` to support multi-platform builds

**Targeted Device Family:**
```
TARGETED_DEVICE_FAMILY = "1,2,3,4"
```
- 1 = iPhone
- 2 = iPad
- 3 = Apple TV
- 4 = Apple Watch (not used)
- **No change needed** - macOS doesn't use device family identifiers

### Build Script Updates (build_install_launch.sh)

**Current Catalyst Configuration (Lines 72-77):**
```bash
catalyst|mac)
  DESTINATION='platform=macOS,variant=Mac Catalyst'
  DEVICE_NAME='Mac'
  BUNDLE_ID='eworthing.Tiercade'
  EMOJI="💻"
  ;;
```

**Updated Native macOS Configuration:**
```bash
macos|mac)
  DESTINATION='platform=macOS,name=My Mac'
  DEVICE_NAME='Mac'
  BUNDLE_ID='eworthing.Tiercade'
  EMOJI="💻"
  ;;
```

**Changes:**
1. Remove `variant=Mac Catalyst` - targets native macOS
2. Add `name=My Mac` to specify the local Mac
3. Rename command from `catalyst` to `macos` (keeping `mac` alias)

**Usage:**
```bash
# tvOS (default)
./build_install_launch.sh

# macOS (native)
./build_install_launch.sh macos
```

### Package.swift (TiercadeCore)

**Current Configuration:**
```swift
platforms: [
    .iOS(.v26),
    .macOS(.v26),
    .tvOS(.v26)
],
targets: [
    .target(
        name: "TiercadeCore",
        swiftSettings: [
            .enableUpcomingFeature("StrictConcurrency"),
            .unsafeFlags(["-strict-concurrency=complete"])
        ]
    )
]
```

**No Changes Needed:** TiercadeCore is platform-agnostic Swift code with no UIKit/AppKit dependencies. It already supports native macOS 26.

### Info.plist Updates

**Add macOS-Specific Keys:**
```xml
<key>LSApplicationCategoryType</key>
<string>public.app-category.productivity</string>

<key>LSMinimumSystemVersion</key>
<string>26.0</string>

<key>NSSupportsAutomaticTermination</key>
<true/>

<key>NSSupportsSuddenTermination</key>
<true/>
```

**Explanation:**
- `LSApplicationCategoryType` - App Store category for macOS
- `LSMinimumSystemVersion` - Minimum macOS version (26.0 Tahoe)
- Automatic/Sudden Termination - macOS app lifecycle best practices

---

## File-by-File Migration Guide

This section provides exact changes needed for each affected file, ordered by complexity.

### 1. OpenExternal.swift (24 lines)

**Location:** `Tiercade/Util/OpenExternal.swift`

**Current Code (Lines 1-24):**
```swift
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

internal enum ExternalOpenResult { case success, handoff, unsupported }

internal struct OpenExternal {
    internal static func open(_ url: URL, completion: @escaping @MainActor (ExternalOpenResult) -> Void) {
        #if canImport(UIKit)
        UIApplication.shared.open(url) { ok in
            Task { @MainActor in
                completion(ok ? .success : .unsupported)
            }
        }
        #else
        Task { @MainActor in
            completion(.unsupported)
        }
        #endif
    }
}
```

**Updated Code:**
```swift
import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

internal enum ExternalOpenResult { case success, handoff, unsupported }

internal struct OpenExternal {
    internal static func open(_ url: URL, completion: @escaping @MainActor (ExternalOpenResult) -> Void) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        Task { @MainActor in
            completion(.success)
        }
        #elseif os(iOS)
        UIApplication.shared.open(url) { ok in
            Task { @MainActor in
                completion(ok ? .success : .unsupported)
            }
        }
        #else
        Task { @MainActor in
            completion(.unsupported)
        }
        #endif
    }
}
```

**Changes Summary:**
- ✅ Replace `canImport(UIKit)` with explicit `os(macOS)` and `os(iOS)` checks
- ✅ Add `import AppKit` for macOS
- ✅ Use `NSWorkspace.shared.open()` on macOS
- ✅ Keep UIKit path for iOS

---

### 2. AIChatOverlay.swift (435 lines)

**Location:** `Tiercade/Views/Overlays/AIChat/AIChatOverlay.swift`

**Changes Required:**

**A. Import Statements (Lines 7-13):**
```swift
// BEFORE
#if os(macOS) || targetEnvironment(macCatalyst)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

// AFTER
#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif
```

**B. Clipboard Function (Lines 284-294):**
```swift
// BEFORE
private func copyToClipboard(_ text: String) {
    #if os(macOS) && !targetEnvironment(macCatalyst)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #elseif os(iOS) || targetEnvironment(macCatalyst)
    UIPasteboard.general.string = text
    #endif

    app.showSuccessToast("Copied", message: "Response copied to clipboard")
}

// AFTER
private func copyToClipboard(_ text: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #elseif os(iOS)
    UIPasteboard.general.string = text
    #endif

    app.showSuccessToast("Copied", message: "Response copied to clipboard")
}
```

**Changes Summary:**
- ✅ Remove `!targetEnvironment(macCatalyst)` from NSPasteboard branch
- ✅ Remove `|| targetEnvironment(macCatalyst)` from UIPasteboard branch
- ✅ Update import guards

---

### 3. AIChatOverlay+ImageGeneration.swift (124 lines)

**Location:** `Tiercade/Views/Overlays/AIChat/AIChatOverlay+ImageGeneration.swift`

**Changes Required:**

**A. Import Statements (Lines 7-13):**
```swift
// BEFORE
#if os(macOS) || targetEnvironment(macCatalyst)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

// AFTER
#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif
```

**B. Image Conversion (Lines 68-76):**
```swift
// BEFORE
#if os(macOS) && !targetEnvironment(macCatalyst)
let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
generatedImage = Image(nsImage: nsImage)
imageGenerated = true
#elseif os(iOS) || targetEnvironment(macCatalyst)
let uiImage = UIImage(cgImage: cgImage)
generatedImage = Image(uiImage: uiImage)
imageGenerated = true
#endif

// AFTER
#if os(macOS)
let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
generatedImage = Image(nsImage: nsImage)
imageGenerated = true
#elseif os(iOS)
let uiImage = UIImage(cgImage: cgImage)
generatedImage = Image(uiImage: uiImage)
imageGenerated = true
#endif
```

**Changes Summary:**
- ✅ Remove `!targetEnvironment(macCatalyst)` from NSImage branch
- ✅ Remove `|| targetEnvironment(macCatalyst)` from UIImage branch
- ✅ Update import guards

---

### 4. ContentView+Overlays.swift (294 lines)

**Location:** `Tiercade/Views/Main/ContentView+Overlays.swift`

**Changes Required:**

**A. Import Statement (Lines 3-8):**
```swift
// BEFORE
#if canImport(UIKit)
import UIKit
#endif
#if os(iOS) || targetEnvironment(macCatalyst)
import UniformTypeIdentifiers
#endif

// AFTER
#if os(iOS)
import UIKit
import UniformTypeIdentifiers
#endif
#if os(macOS)
import AppKit
#endif
```

**B. Symbol Attachment (Lines 137-146):**
```swift
// BEFORE
private func makeSymbolAttachment(named symbolName: String) -> NSTextAttachment? {
    #if canImport(UIKit)
    guard let image = UIImage(systemName: symbolName) else { return nil }
    let attachment = NSTextAttachment()
    attachment.image = image
    return attachment
    #else
    return nil
    #endif
}

// AFTER
private func makeSymbolAttachment(named symbolName: String) -> NSTextAttachment? {
    #if os(iOS)
    guard let image = UIImage(systemName: symbolName) else { return nil }
    let attachment = NSTextAttachment()
    attachment.image = image
    return attachment
    #elseif os(macOS)
    guard let image = NSImage(systemName: symbolName) else { return nil }
    let attachment = NSTextAttachment()
    attachment.image = image
    return attachment
    #else
    return nil
    #endif
}
```

**C. Accessibility Traits (Lines 95-98):**
```swift
// BEFORE
#if os(iOS) || targetEnvironment(macCatalyst)
.focusable(interactions: .activate)
.accessibilityAddTraits(.isModal)
#endif

// AFTER
#if os(iOS)
.focusable(interactions: .activate)
.accessibilityAddTraits(.isModal)
#endif
```

**Changes Summary:**
- ✅ Add explicit macOS branch for NSImage-based symbol attachment
- ✅ Update all platform checks to remove Catalyst references
- ✅ Add AppKit import for macOS

---

### 5. ContentView+Analysis.swift (345 lines)

**Location:** `Tiercade/Views/Main/ContentView+Analysis.swift`

**Changes Required:**

**A. Toolbar Placement (Lines 48-67):**
```swift
// NO CHANGE NEEDED
// This code already uses #if !os(macOS) correctly
#if !os(macOS)
#if !os(tvOS)
.navigationBarTitleDisplayMode(.large)
#endif
.toolbar { ... }
#endif
```

**B. UIColor Usage (Lines 247-255):**
```swift
// BEFORE
let strokeColor: Color = {
    #if os(tvOS)
    return Palette.surfHi
    #elseif canImport(UIKit)
    return Color(UIColor.systemGray4)
    #else
    return Palette.surfHi
    #endif
}()

// AFTER (Option 1: Platform-specific colors)
let strokeColor: Color = {
    #if os(tvOS)
    return Palette.surfHi
    #elseif os(iOS)
    return Color(UIColor.systemGray4)
    #elseif os(macOS)
    return Color(NSColor.systemGray)
    #else
    return Palette.surfHi
    #endif
}()

// AFTER (Option 2: Use design token - RECOMMENDED)
let strokeColor: Color = Palette.surfHi
```

**Recommendation:** Use Option 2 (design token) to eliminate platform conditionals entirely. `Palette.surfHi` already provides a consistent stroke color across all platforms.

**Changes Summary:**
- ✅ Replace `canImport(UIKit)` with explicit platform checks OR
- ✅ (Preferred) Remove platform conditionals and use design token

---

### 6. PlatformCardLayout.swift (174 lines)

**Location:** `Tiercade/Views/Components/PlatformCardLayout.swift`

**Changes Required:**

**A. File Header (Lines 1-3):**
```swift
// NO CHANGE - Already excludes tvOS
#if !os(tvOS)
internal struct PlatformCardLayout {
```

**B. Scaling Factor (Lines 50-63):**
```swift
// BEFORE
let scale: CGFloat = {
    #if targetEnvironment(macCatalyst)
    return 1.12
    #else
    switch horizontalSizeClass {
    case .some(.regular):
        return 1.04
    case .some(.compact):
        return 0.96
    default:
        return 1.0
    }
    #endif
}()

// AFTER
let scale: CGFloat = {
    #if os(macOS)
    return 1.0  // Native macOS uses 1:1 scaling
    #else
    switch horizontalSizeClass {
    case .some(.regular):
        return 1.04
    case .some(.compact):
        return 0.96
    default:
        return 1.0
    }
    #endif
}()
```

**Changes Summary:**
- ✅ Remove Catalyst-specific 1.12x scaling
- ✅ Use 1.0 (no scaling) for native macOS

---

### 7. MediaGalleryView.swift (72 lines)

**Location:** `Tiercade/Views/Components/MediaGalleryView.swift`

**Changes Required:**

**A. TabView Style (Lines 24-38):**
```swift
// BEFORE
#if os(tvOS)
.tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
.focusSection()
.onChange(of: selection) { _, newValue in
    guard pages.indices.contains(newValue) else { return }
    let announcement = "Image \(newValue + 1) of \(pages.count)"
    AccessibilityNotification.Announcement(announcement).post()
}
#elseif os(iOS) && !targetEnvironment(macCatalyst)
.tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
#else
// Mac Catalyst: .page style isn't available, use automatic
.tabViewStyle(.automatic)
#endif

// AFTER
#if os(tvOS)
.tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
.focusSection()
.onChange(of: selection) { _, newValue in
    guard pages.indices.contains(newValue) else { return }
    let announcement = "Image \(newValue + 1) of \(pages.count)"
    AccessibilityNotification.Announcement(announcement).post()
}
#elseif os(iOS)
.tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
#elseif os(macOS)
.tabViewStyle(.automatic)  // macOS uses tab-based navigation
#endif
```

**Changes Summary:**
- ✅ Simplify iOS check (remove `&& !targetEnvironment(macCatalyst)`)
- ✅ Add explicit macOS branch
- ✅ Update comment to reflect native macOS behavior

---

### 8. ContentView+TierGrid.swift (540 lines)

**Location:** `Tiercade/Views/Main/ContentView+TierGrid.swift`

**Changes Required:**

**A. Platform Guard (Lines 251-252):**
```swift
// BEFORE (Line 251)
#if os(iOS) && !os(tvOS) || targetEnvironment(macCatalyst)
.accessibilityAddTraits(.isButton)
#endif

// AFTER
#if os(iOS) || os(macOS)
.accessibilityAddTraits(.isButton)
#endif
```

**Note:** The `!os(tvOS)` check is redundant since tvOS is not iOS. Simplify to `os(iOS) || os(macOS)`.

**Changes Summary:**
- ✅ Remove `targetEnvironment(macCatalyst)` check
- ✅ Simplify to `os(iOS) || os(macOS)`

---

### 9. ToolbarExportFormatSheetView.swift (212 lines) - DEFERRED

**Location:** `Tiercade/Views/Toolbar/ToolbarExportFormatSheetView.swift`

**Current Status:** Entire file wrapped in `#if os(iOS) || targetEnvironment(macCatalyst)`

**Migration Strategy:**

**Phase 1 (Immediate):** Update conditional to exclude Catalyst:
```swift
// Line 1
#if os(iOS)  // Remove Catalyst support, defer macOS implementation
```

**Phase 2 (Follow-up):** Implement native macOS file export using `NSSavePanel`:
```swift
#if os(macOS)
internal struct ExportFormatSheetView<Coordinator: ToolbarExportCoordinating>: View {
    // Implement using NSSavePanel.beginSheetModal(for:completionHandler:)
    // Reference: https://developer.apple.com/documentation/appkit/nssavepanel
}
#endif
```

**Rationale:** The iOS `FileDocument` + `.fileExporter()` pattern is iOS-specific. macOS should use native `NSSavePanel` for better UX. This can be implemented in a follow-up PR to keep the initial migration focused.

**Changes Summary:**
- ✅ Phase 1: Remove Catalyst support (change line 1 from `os(iOS) || targetEnvironment(macCatalyst)` to `os(iOS)`)
- ⏸️ Phase 2: Implement macOS-native file export (separate PR)

---

### 10. MainAppView.swift (502 lines)

**Location:** `Tiercade/Views/Main/MainAppView.swift`

**Changes Required:**

**A. Platform Switching (Lines 52-54):**
```swift
// BEFORE
#elseif os(macOS) || targetEnvironment(macCatalyst)
macSplitView(modalBlockingFocus: modalBlockingFocus)

// AFTER
#elseif os(macOS)
macSplitView(modalBlockingFocus: modalBlockingFocus)
```

**B. NavigationSplitView Implementation (Lines 284-299):**
```swift
// NO CHANGE NEEDED
// NavigationSplitView already works natively on macOS
#if os(macOS) || targetEnvironment(macCatalyst)
@ViewBuilder
private func macSplitView(modalBlockingFocus: Bool) -> some View {
    NavigationSplitView {
        SidebarView(tierOrder: app.tierOrder)
            .allowsHitTesting(!modalBlockingFocus)
            .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
    } detail: {
        tierGridLayer(modalBlockingFocus: modalBlockingFocus)
            .toolbar { ToolbarView(app: app) }
            .navigationTitle("Tiercade")
    }
    .navigationSplitViewStyle(.balanced)
    .toolbarRole(.editor)
}
#endif
```

**Update Conditional:**
```swift
#if os(macOS)
@ViewBuilder
private func macSplitView(modalBlockingFocus: Bool) -> some View {
    // ... rest unchanged ...
}
#endif
```

**Changes Summary:**
- ✅ Remove `|| targetEnvironment(macCatalyst)` from platform switch
- ✅ Update `#if` guard for `macSplitView` method
- ✅ NavigationSplitView implementation remains unchanged (already native SwiftUI)

---

## macOS 26 Tahoe Feature Integration

### Liquid Glass Design System

**Current Status:** ✅ Already Implemented

The app already uses Liquid Glass via SwiftUI's tvOS 26 APIs, which work identically on macOS 26 Tahoe:

```swift
// GlassEffects.swift
@ViewBuilder func GlassContainer<S: Shape, V: View>(_ shape: S, @ViewBuilder _ content: () -> V) -> some View {
  #if os(tvOS)
  content().glassBackgroundEffect(in: shape, displayMode: .fill)
  #else
  content().background(.ultraThinMaterial, in: shape)
  #endif
}
```

**Opportunity for macOS 26:** Update the `#else` branch to use native Liquid Glass on macOS 26:

```swift
// GlassEffects.swift (UPDATED)
@ViewBuilder func GlassContainer<S: Shape, V: View>(_ shape: S, @ViewBuilder _ content: () -> V) -> some View {
  #if os(tvOS) || os(macOS)
  if #available(macOS 26.0, *) {
    content().glassBackgroundEffect(in: shape, displayMode: .fill)
  } else {
    content().background(.ultraThinMaterial, in: shape)
  }
  #else
  content().background(.ultraThinMaterial, in: shape)
  #endif
}
```

**References:**
- macOS 26 Release Notes: Foundation Models framework, Liquid Glass support
- Web Search: "Developers will be able to build apps using new Liquid Glass materials via SwiftUI, UIKit, and AppKit"

### Menu Bar and Keyboard Shortcuts

**Current Status:** ⚠️ Not Implemented

macOS apps should provide native menu bar commands for common actions.

**Implementation (New File: `MacMenuCommands.swift`):**
```swift
#if os(macOS)
import SwiftUI

struct TiercadeMenuCommands: Commands {
    @ObservedObject var app: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tier List") {
                app.beginNewProject()
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("Tier List") {
            Button("Head-to-Head") {
                if app.canStartHeadToHead() {
                    app.beginHeadToHead()
                }
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(!app.canStartHeadToHead())

            Button("Multi-Select") {
                app.toggleMultiSelect()
            }
            .keyboardShortcut("m", modifiers: .command)

            Divider()

            Button("Generate Analysis") {
                Task { await app.generateAnalysis() }
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(!app.canShowAnalysis())
        }

        CommandGroup(after: .importExport) {
            Button("Export...") {
                app.showExportSheet()
            }
            .keyboardShortcut("e", modifiers: .command)

            Button("Import...") {
                app.showImportSheet()
            }
            .keyboardShortcut("i", modifiers: .command)
        }
    }
}
#endif
```

**Integration in TiercadeApp.swift:**
```swift
// TiercadeApp.swift
var body: some Scene {
    WindowGroup {
        // ... existing code ...
    }
    .modelContainer(modelContainer)
    #if os(macOS)
    .commands {
        TiercadeMenuCommands(app: appState)
    }
    #endif
}
```

### Native File Management

**Current Gap:** `ToolbarExportFormatSheetView.swift` uses iOS-specific `FileDocument`

**macOS-Native Implementation:**
```swift
#if os(macOS)
struct MacExportPanel {
    static func showSavePanel(
        format: ExportFormat,
        defaultName: String,
        completion: @escaping (URL?) -> Void
    ) {
        let panel = NSSavePanel()
        panel.title = "Export Tier List"
        panel.message = "Choose a location to save your tier list"
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }
}
#endif
```

---

## Testing Strategy

### Build Verification

**1. Clean Build Test:**
```bash
# Clean all build artifacts
xcodebuild clean -project Tiercade.xcodeproj -scheme Tiercade -configuration Debug

# Build tvOS (primary platform)
./build_install_launch.sh

# Build macOS (native)
./build_install_launch.sh macos

# Build iOS (secondary)
./build_install_launch.sh ios  # Add if script supports iOS target
```

**Success Criteria:**
- ✅ All platforms build without errors
- ✅ No "undefined symbol" linker errors
- ✅ No Swift 6 strict concurrency violations
- ✅ No deprecation warnings related to platform APIs

**2. Cross-Platform Parity Test:**
```bash
# Build all platforms sequentially
./build_install_launch.sh && \
./build_install_launch.sh macos
```

**Success Criteria:**
- ✅ Both builds complete successfully
- ✅ No platform-specific build failures
- ✅ Shared TiercadeCore package builds for all targets

### Runtime Verification

**3. Feature Parity Checklist:**

| Feature | tvOS | iOS | macOS (Native) | Test Method |
|---------|------|-----|----------------|-------------|
| Tier list creation | ✅ | ✅ | ⏸️ Test | Create new project, verify all tiers appear |
| Item drag & drop | ✅ | ✅ | ⏸️ Test | Drag item between tiers |
| Quick rank overlay | ✅ | ✅ | ⏸️ Test | Click item, verify overlay shows |
| Head-to-head mode | ✅ | ✅ | ⏸️ Test | Start H2H, verify pair selection |
| Multi-select | ✅ | ✅ | ⏸️ Test | Enter selection mode, batch move |
| Clipboard copy (AI chat) | ✅ | ✅ | ⏸️ Test | Copy AI response, paste into TextEdit |
| External URL open | ✅ | ✅ | ⏸️ Test | Open URL from app, verify browser launches |
| Image generation | ✅ | ✅ | ⏸️ Test | Generate image via ImagePlayground |
| Export to JSON | ✅ | ✅ | ⏸️ Test | Export project, verify file saves |
| Import from JSON | ✅ | ✅ | ⏸️ Test | Import saved project, verify data loads |
| NavigationSplitView | N/A | ✅ iPad | ⏸️ Test | Verify sidebar + detail columns |
| Liquid Glass effects | ✅ | ✅ | ⏸️ Test | Verify translucent chrome surfaces |
| Keyboard navigation | ✅ | ⏸️ iPad | ⏸️ Test | Arrow keys navigate grid, Space activates |
| Focus management | ✅ | N/A | N/A | tvOS-specific, skip on macOS |

**4. Platform-Specific API Tests:**

**macOS API Verification Script:**
```swift
#if DEBUG && os(macOS)
struct MacOSAPITests {
    static func runAll() {
        testNSWorkspace()
        testNSPasteboard()
        testNSImage()
    }

    static func testNSWorkspace() {
        let url = URL(string: "https://www.apple.com")!
        NSWorkspace.shared.open(url)
        print("✅ NSWorkspace.open() succeeded")
    }

    static func testNSPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("test", forType: .string)
        let result = NSPasteboard.general.string(forType: .string)
        assert(result == "test", "❌ NSPasteboard test failed")
        print("✅ NSPasteboard read/write succeeded")
    }

    static func testNSImage() {
        let image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)
        assert(image != nil, "❌ NSImage(systemSymbolName:) failed")
        print("✅ NSImage SF Symbols succeeded")
    }
}
#endif
```

**Add to TiercadeApp.swift:**
```swift
#if DEBUG && os(macOS)
.onAppear {
    if CommandLine.arguments.contains("-runMacAPITests") {
        MacOSAPITests.runAll()
    }
}
#endif
```

**Run:**
```bash
./build_install_launch.sh macos --args -runMacAPITests
```

### Package Tests (TiercadeCore)

**5. Swift Package Tests:**
```bash
cd TiercadeCore
swift test --enable-code-coverage
```

**Success Criteria:**
- ✅ All tests pass on macOS 26
- ✅ No platform-specific failures
- ✅ Code coverage remains >80%

### UI Automation Tests

**6. Accessibility Identifier Validation:**

All existing UI test accessibility identifiers should work unchanged:
```swift
// Example: Quick Rank overlay
XCTAssert(app.otherElements["QuickRank_Overlay"].exists)
XCTAssert(app.buttons["QuickRank_Tier_S"].exists)

// Example: Toolbar actions
XCTAssert(app.buttons["Toolbar_H2H"].exists)
XCTAssert(app.buttons["Toolbar_MultiSelect"].exists)
```

**Run Existing UI Tests:**
```bash
xcodebuild test -project Tiercade.xcodeproj \
  -scheme Tiercade \
  -destination 'platform=macOS,name=My Mac'
```

**Success Criteria:**
- ✅ All existing UI tests pass on native macOS
- ✅ Focus paths behave correctly (keyboard navigation)
- ✅ Overlays appear and dismiss properly

---

## Rollout Plan

### Phase 1: Code Migration (Week 1)

**Day 1-2: UIKit API Replacements**
1. Update `OpenExternal.swift` (NSWorkspace)
2. Update `AIChatOverlay.swift` (NSPasteboard)
3. Update `AIChatOverlay+ImageGeneration.swift` (NSImage)
4. Update `ContentView+Overlays.swift` (NSImage symbols, accessibility traits)
5. Update `ContentView+Analysis.swift` (NSColor or design token)

**Day 3-4: Platform Conditional Refactoring**
1. Update all import statements (remove Catalyst checks)
2. Refactor `PlatformCardLayout.swift` (remove 1.12x scaling)
3. Update `MediaGalleryView.swift` (TabView style)
4. Update `ContentView+TierGrid.swift` (accessibility traits)
5. Update `MainAppView.swift` (platform switch, method guards)

**Day 5: Build Configuration**
1. Update `Tiercade.xcodeproj` settings (`SUPPORTS_MACCATALYST = NO`)
2. Update `build_install_launch.sh` (native macOS destination)
3. Update `Info.plist` (add macOS-specific keys)
4. Verify clean builds on all platforms

**Deliverable:** All code changes committed, builds successfully on tvOS, iOS, and native macOS

### Phase 2: Testing & Validation (Week 2)

**Day 1-2: Runtime Testing**
1. Manual feature parity testing (use checklist from Testing Strategy)
2. API-specific tests (NSWorkspace, NSPasteboard, NSImage)
3. UI automation test runs

**Day 3-4: Bug Fixes**
1. Address any runtime issues discovered
2. Fix platform-specific edge cases
3. Validate keyboard navigation and focus management

**Day 5: Code Review & Documentation**
1. Code review with team
2. Update AGENTS.md to reflect native macOS patterns
3. Update README build instructions

**Deliverable:** All tests passing, bug fixes merged, documentation updated

### Phase 3: macOS-Specific Enhancements (Week 3)

**Day 1-2: Menu Bar Commands**
1. Implement `TiercadeMenuCommands` (keyboard shortcuts)
2. Add to `TiercadeApp.swift`
3. Test all menu actions

**Day 3-4: Native File Management**
1. Implement macOS-native `ExportFormatSheetView` using `NSSavePanel`
2. Maintain iOS version (FileDocument) in parallel
3. Test export flows on both platforms

**Day 5: Liquid Glass Refinement**
1. Update `GlassContainer` to use native Liquid Glass on macOS 26
2. Visual QA pass on macOS Tahoe
3. Accessibility review

**Deliverable:** macOS-native features implemented, visual polish complete

### Phase 4: Deployment (Week 4)

**Day 1: Release Build Testing**
1. Build Release configuration for all platforms
2. TestFlight deployment (iOS/iPadOS)
3. Mac App Store build (macOS)

**Day 2-3: Beta Testing**
1. Internal testing on real hardware
2. Gather feedback on macOS-specific UX
3. Performance profiling

**Day 4-5: App Store Submission**
1. Update App Store metadata (macOS category, screenshots)
2. Submit for review
3. Monitor for issues

**Deliverable:** Native macOS app live on App Store

---

## Risk Mitigation

### Risk 1: API Behavior Differences

**Risk:** NSWorkspace, NSPasteboard, NSImage may have subtle behavior differences from UIKit equivalents.

**Mitigation:**
- Add comprehensive unit tests for each API replacement
- Test on multiple macOS versions (26.0, 26.1 beta)
- Use debug logging to catch edge cases early
- Reference Apple documentation for each API migration

**Fallback:** Keep platform-specific error handling with clear user feedback

### Risk 2: Layout Issues on macOS

**Risk:** UI layouts optimized for Catalyst's scaled interface may look different at native resolution.

**Mitigation:**
- Test on multiple Mac screen sizes (13", 16", external displays)
- Use design tokens (Metrics, TypeScale) instead of hardcoded sizes
- Leverage SwiftUI's adaptive layout system
- Run visual regression tests comparing Catalyst vs native

**Fallback:** Add macOS-specific layout adjustments if needed (prefer design token updates)

### Risk 3: Build Breakage During Migration

**Risk:** Simultaneous platform changes could break other targets.

**Mitigation:**
- Use feature branches for migration work
- Run automated CI builds on every commit
- Test all platforms before each merge
- Keep tvOS (primary platform) always buildable

**Fallback:** Revert partially merged changes, complete migration in smaller PRs

### Risk 4: Performance Regression

**Risk:** Native macOS app might perform differently than Catalyst (better or worse).

**Mitigation:**
- Profile app launch time (Instruments → Time Profiler)
- Measure memory usage (Instruments → Allocations)
- Test SwiftData persistence performance
- Benchmark Apple Intelligence requests

**Baseline Metrics (Catalyst):**
```bash
# Capture baseline before migration
instruments -t "Time Profiler" -D ~/Desktop/catalyst_profile.trace \
  ~/Library/Developer/Xcode/DerivedData/.../Tiercade.app
```

**Target:** Native macOS should be ≥ Catalyst performance (expect improvement)

### Risk 5: Broken UI Tests

**Risk:** Accessibility identifiers or focus paths might behave differently.

**Mitigation:**
- Run full UI test suite before and after migration
- Update tests incrementally with code changes
- Use XCTest's `XCTSkip` for platform-specific tests
- Maintain separate test targets for tvOS/iOS/macOS if needed

**Fallback:** Disable failing tests temporarily, fix in follow-up PR (don't block migration)

### Risk 6: Feature Parity Gaps

**Risk:** Some iOS/Catalyst features might not have direct macOS equivalents.

**Known Gaps:**
- `.page` TabView style (use `.automatic` on macOS)
- iOS-specific FileDocument API (implement NSSavePanel)

**Mitigation:**
- Document all feature differences in AGENTS.md
- Implement macOS-native alternatives where possible
- Use graceful degradation for non-critical features

**Acceptance Criteria:** Core tier list functionality must work identically across all platforms

---

## Appendix A: Complete File Manifest

### Files Requiring Code Changes (9 files)

1. `Tiercade/Util/OpenExternal.swift` - NSWorkspace API
2. `Tiercade/Views/Overlays/AIChat/AIChatOverlay.swift` - NSPasteboard, imports
3. `Tiercade/Views/Overlays/AIChat/AIChatOverlay+ImageGeneration.swift` - NSImage conversion
4. `Tiercade/Views/Main/ContentView+Overlays.swift` - NSImage symbols, imports
5. `Tiercade/Views/Main/ContentView+Analysis.swift` - NSColor (or design token)
6. `Tiercade/Views/Components/PlatformCardLayout.swift` - Remove 1.12x scaling
7. `Tiercade/Views/Components/MediaGalleryView.swift` - TabView style
8. `Tiercade/Views/Main/ContentView+TierGrid.swift` - Accessibility traits
9. `Tiercade/Views/Main/MainAppView.swift` - Platform switch guards

### Files Requiring Build Configuration Changes (3 files)

1. `Tiercade.xcodeproj/project.pbxproj` - `SUPPORTS_MACCATALYST = NO`
2. `build_install_launch.sh` - Native macOS destination
3. `Tiercade/Info.plist` - macOS-specific keys

### Files Requiring Deferred Implementation (1 file)

1. `Tiercade/Views/Toolbar/ToolbarExportFormatSheetView.swift` - NSSavePanel (Phase 3)

### New Files to Create (2 files)

1. `Tiercade/macOS/MacMenuCommands.swift` - Menu bar and keyboard shortcuts
2. `Tiercade/macOS/MacExportPanel.swift` - Native file save panel (Phase 3)

### Files with No Changes Required

- `TiercadeApp.swift` - Works as-is (add menu commands in Phase 3)
- `TiercadeCore/` - Platform-agnostic, already supports native macOS
- All `State/AppState+*.swift` - No platform-specific code
- All `Design/*.swift` - Design tokens work universally
- `GlassEffects.swift` - Works as-is (optimize in Phase 3)

---

## Appendix B: Platform API Reference

### Clipboard APIs

| iOS (UIKit) | macOS (AppKit) | SwiftUI Alternative |
|-------------|----------------|---------------------|
| `UIPasteboard.general.string = "text"` | `NSPasteboard.general.setString("text", forType: .string)` | None (must use platform APIs) |
| `UIPasteboard.general.string` | `NSPasteboard.general.string(forType: .string)` | None |

### URL Opening APIs

| iOS (UIKit) | macOS (AppKit) | SwiftUI Alternative |
|-------------|----------------|---------------------|
| `UIApplication.shared.open(url) { ... }` | `NSWorkspace.shared.open(url)` | `Link(destination:)` for in-app links |

### Image APIs

| iOS (UIKit) | macOS (AppKit) | SwiftUI Alternative |
|-------------|----------------|---------------------|
| `UIImage(cgImage:)` | `NSImage(cgImage:size:)` | `Image(nsImage:)` / `Image(uiImage:)` |
| `UIImage(systemName:)` | `NSImage(systemSymbolName:accessibilityDescription:)` | `Image(systemName:)` (cross-platform) |

### Color APIs

| iOS (UIKit) | macOS (AppKit) | SwiftUI Alternative |
|-------------|----------------|---------------------|
| `UIColor.systemGray4` | `NSColor.systemGray` | `Color.gray` (design tokens preferred) |

### File Management APIs

| iOS (UIKit/SwiftUI) | macOS (AppKit) | SwiftUI Alternative |
|---------------------|----------------|---------------------|
| `.fileExporter()` + `FileDocument` | `NSSavePanel.beginSheetModal()` | `.fileExporter()` (iOS-only) |

---

## Appendix C: Testing Checklist

### Build Tests

- [ ] `./build_install_launch.sh` (tvOS) succeeds
- [ ] `./build_install_launch.sh macos` (macOS native) succeeds
- [ ] `cd TiercadeCore && swift test` (all tests pass)
- [ ] No Swift 6 concurrency warnings
- [ ] No deprecation warnings

### Runtime Tests (macOS)

- [ ] App launches successfully
- [ ] NavigationSplitView shows sidebar + detail
- [ ] Tier grid displays all tiers correctly
- [ ] Drag & drop item between tiers works
- [ ] Quick rank overlay appears and functions
- [ ] Head-to-head mode starts correctly
- [ ] Multi-select mode activates
- [ ] Toolbar buttons are clickable
- [ ] Export to JSON saves file
- [ ] Import from JSON loads project
- [ ] AI chat opens and responds
- [ ] Clipboard copy works (paste into TextEdit)
- [ ] External URL opens in default browser
- [ ] Image generation works (if supported)
- [ ] Liquid Glass effects render correctly
- [ ] Keyboard navigation works (arrow keys, Space, Escape)

### Cross-Platform Parity Tests

- [ ] Create same project on tvOS and macOS - data identical
- [ ] Export on macOS, import on iOS - no data loss
- [ ] Visual consistency across platforms (design tokens)
- [ ] Accessibility identifiers unchanged

### Performance Tests

- [ ] App launch time < 2 seconds
- [ ] Memory usage < 200 MB at idle
- [ ] No memory leaks (Instruments)
- [ ] Smooth scrolling in tier grid
- [ ] No frame drops during animations

---

## Appendix D: Decision Log

### Decision 1: Keep SwiftUI NavigationSplitView

**Context:** MainAppView already uses NavigationSplitView for macOS/Catalyst.

**Decision:** Keep existing implementation - it's already native SwiftUI and works on native macOS.

**Rationale:** No AppKit NSViewController bridge needed, SwiftUI handles platform adaptation automatically.

### Decision 2: Use NSColor.systemGray vs Design Token

**Context:** ContentView+Analysis uses UIColor.systemGray4 for chart stroke.

**Decision:** Recommend design token (Palette.surfHi) over NSColor.systemGray.

**Rationale:** Maintains visual consistency across platforms, reduces platform conditionals.

### Decision 3: Defer Export Sheet Migration to Phase 3

**Context:** ToolbarExportFormatSheetView uses iOS-specific FileDocument.

**Decision:** Phase 1 removes Catalyst support, Phase 3 implements NSSavePanel.

**Rationale:** Keeps initial migration focused on core functionality, export is non-critical for initial launch.

### Decision 4: Remove 1.12x Catalyst Scaling

**Context:** PlatformCardLayout applies 1.12x scale for Catalyst.

**Decision:** Use 1.0 (no scaling) for native macOS.

**Rationale:** Catalyst scaled iOS UI to match Mac screen density. Native macOS apps render at native resolution without artificial scaling.

### Decision 5: Add Menu Bar Commands in Phase 3

**Context:** macOS apps should have native menu bar with keyboard shortcuts.

**Decision:** Implement TiercadeMenuCommands after core migration complete.

**Rationale:** Keeps Phase 1 focused on API replacements and build configuration. Menu commands are enhancement, not blocker.

---

## Conclusion

This migration from Mac Catalyst to native macOS is **low-risk, high-reward** due to:

1. **Minimal Code Changes:** Only 9 files need updates, mostly simple API replacements
2. **Already SwiftUI-Native:** Navigation, design system, and state management already platform-agnostic
3. **No Architecture Changes:** Existing @Observable, NavigationSplitView, and AppState patterns remain unchanged
4. **Incremental Approach:** Phase 1 focuses on core migration, Phase 3 adds native enhancements
5. **Strong Testing Foundation:** Swift Testing suite, UI automation, and manual test checklists ensure quality

**Estimated Timeline:** 3-4 weeks from code migration to App Store submission

**Primary Benefit:** First-class macOS app with native APIs, better performance, and full access to macOS 26 Tahoe features (Liquid Glass, menu bar, file management) while maintaining cross-platform codebase with tvOS, iOS, and iPadOS.

**Next Steps:**
1. Review this report with team
2. Create feature branch `feat/native-macos-migration`
3. Begin Phase 1: Code Migration (Week 1)
4. Proceed with Testing & Validation (Week 2)

---

*Report prepared by Senior Swift Engineer*
*Target Audience: LLM Coding Agent executing migration*
*Last Updated: October 2025*
