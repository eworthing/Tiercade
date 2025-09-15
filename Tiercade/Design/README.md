Design tokens and styles for Tiercade

Files:
- DesignTokens.swift: Palette, Metrics, TypeScale helper functions and Color(hex:)
- Styles.swift: View modifiers .card() and .panel(), and button styles PrimaryButtonStyle and GhostButtonStyle
- ThemeManager.swift: Theme preference enum

Usage:
- Use Palette.* tokens for colors. Palette is dynamic and adapts to light/dark.
- Use Metrics.* for spacing and corner radii to keep the 8pt grid.
- Apply `.card()` to item cards and `.panel()` to panels/inspectors.
- Use `PrimaryButtonStyle()` for primary actions and `GhostButtonStyle()` for neutral actions.

Examples:
    Text("Title").font(TypeScale.h3).foregroundColor(Palette.text)
    VStack { ... }.panel()
    Button("Add") { }.buttonStyle(PrimaryButtonStyle())

Accessibility:
- TypeScale fonts are based on system fonts and should respond to Dynamic Type. When needed, use `.dynamicTypeSize(...upTo: .accessibility2)` on text-heavy components.


