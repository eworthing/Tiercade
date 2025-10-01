# Design System for Tiercade (Swift 6 + OS 26.0+)

Design tokens and styles for Tiercade built with modern SwiftUI on OS 26.0+.

## Files
- **DesignTokens.swift**: Palette, Metrics, TypeScale helper functions and Color(hex:)
- **Styles.swift**: View modifiers `.card()` and `.panel()`, and button styles PrimaryButtonStyle and GhostButtonStyle
- **ThemeManager.swift**: Theme preference enum
- **TVMetrics.swift**: tvOS-specific spacing and sizing constants

## Usage
- Use `Palette.*` tokens for colors. Palette is dynamic and adapts to light/dark mode
- Use `Metrics.*` for spacing and corner radii to keep the 8pt grid
- Apply `.card()` to item cards and `.panel()` to panels/inspectors
- Use `PrimaryButtonStyle()` for primary actions and `GhostButtonStyle()` for neutral actions

## Examples
```swift
Text("Title").font(TypeScale.h3).foregroundColor(Palette.text)
VStack { ... }.panel()
Button("Add") { }.buttonStyle(PrimaryButtonStyle())
```

## Accessibility
- TypeScale fonts are based on system fonts and respond to Dynamic Type
- When needed, use `.dynamicTypeSize(...upTo: .accessibility2)` on text-heavy components


