# Tiercade Tier Creator — Detailed Design Spec

_Last updated: 2025-02-14_

## 1. Purpose
- Provide a tvOS-first creation workspace for authoring tier-list projects that adhere to `referencedocs/tierlist.schema.json`.
- Empower creators to define project metadata, tier frames, canonical items, and per-project overrides before handing data to the ranking surfaces.
- Maintain multiplatform parity (tvOS 26, iOS/iPadOS 26, macOS 26+) while prioritising remote-based focus navigation and Liquid Glass visual language.

## 2. Scope
- **In scope:** project metadata authoring, tier CRUD + ordering, item catalog management, override editing, validation, export/import, audit updates, inline preview.
- **Out of scope:** head-to-head ranking UI, analytics dashboards, real-time collaboration edits (display-only for now), legacy OS backports.

## 3. Experience Pillars
1. **Remote-first flow:** Every step is reachable with Siri Remote focus navigation; pointer and touch enhancements are additive.
2. **Glass-guided chrome:** High-level controls sit on Liquid Glass surfaces using documented SwiftUI modifiers (`glassEffect` and glass button styles).[1][2]
3. **Schema-aligned persistence:** SwiftData models mirror JSON schema identifiers with validation hooks and typed exports via `AppState`.

## 4. Macro Layout

| Zone | tvOS | iPadOS/macOS | iOS |
| --- | --- | --- | --- |
| **Header Toolbar** | Full-width Liquid Glass strip (Save, Export, Preview, Schema Version). Buttons styled with `.buttonStyle(.glass)`.[2] | NavigationSplitView toolbar. | Navigation bar items; same actions in primary menu. |
| **Left Rail — Tiers** | Focus section listing tiers with order, lock, collapse, count. Select opens tier editor. | Sidebar column with drag handles for reorder. | First list tab. |
| **Center — Composition Canvas** | Fixed focus section previewing tier lanes, rules button, quick actions. | Detail pane showing tier card preview. | Presented as stacked cards below tier list. |
| **Right — Item Library** | Searchable list with filters; `searchable(placement: .toolbar)` lets system choose placement.[9] | List with search field in navigation UI. | Dedicated tab; search presented automatically. |
| **Overlays / Drawers** | Glass overlay slides over content; `.onExitCommand` to dismiss without leaving screen.[4] | Sheet or inspector depending on platform idiom. | Bottom sheet or push view. |
| **Action Strip** | Floating glass bar (Undo/Redo/Validate/Publish) pinned at safe-area bottom; focus section ensures remote access. | Toolbar / command group. | Toolbar in tab or bottom sheet. |

## 5. Focus & Input Model (tvOS priority)
- Divide layout into focus sections for rail, canvas, library, action strip, and active overlays using `.focusSection()` to guide remote traversal.[3]
- Bind focus ownership with an enum-based `@FocusState` per major area. Default focus lands on the tier rail; push focus into overlays when presented.
- Handle system commands:
  - `.onExitCommand` closes modals or backs out of editing flows gracefully (Menu key).[4]
  - `.onMoveCommand` optionally refines navigation inside dense grids (future enhancement).
- Provide clear visual focus affordances using existing focus ring styles and spacing from tvOS design tokens.

## 6. Liquid Glass & Visual Language
- Apply `glassEffect()` to navigation surfaces, overlays, and floating toolbars.[1] Treat grouped panels as single glass surfaces to avoid stacking for performance.
- Use `buttonStyle(.glass)` (and `.glassProminent` where emphasised actions make sense) for primary actions.[2]
- Canvas and library interior use standard materials, keeping glass for chrome so the layered experience remains responsive.
- Manage scroll underlays with `scrollEdgeEffectStyle` when content sits beneath floating glass, ensuring scroll physics remain appropriate.[10]

## 7. SwiftData Model Outline
- Define one `@Model` per schema entity (project, tier, item, override, media, audit, collab member).[5]
- Apply `#Unique` constraints to fields that must remain globally unique (e.g., `projectId`, `tier.id`, `item.id`).[7]
- Store flexible dictionaries (`attributes`, `settings`, `links`) as JSON-encoded strings with computed `@Transient` mirrors for decode/encode-on-access behavior.[6]
- Annotate frequently queried fields (title, created timestamps) with `#Index` for search and sorting efficiency (doc link via `Index` macro family).[5]
- Relationships align with schema (project owns tiers/items/overrides; overrides link to canonical item via ID). Delete rules cascade from project -> tiers/items and nullify cross-links where appropriate.

## 8. Core Workflows
1. **Project Metadata**
   - Fields: title, description, schemaVersion picker, theme settings, tier sort order, accessibility toggles, visibility stub, audit info.
   - Auto-generate UUID project ID; update `audit.updatedAt/By` on save.
2. **Tier Management**
   - Add tier (default order at end, default color, optional label suggestions).
   - Edit properties (label, color hex, order, locked/collapsed booleans, rules text). Validation ensures colors match regex and IDs stay unique.
   - Reorder: tvOS uses focusable reorder controls; pointer/touch use drag handles.
   - Delete prompts when tier contains items; optionally move items to “unranked”.
3. **Item Authoring**
   - New/edit drawer sections: identification (title, subtitle, slug), summary, attributes key-value editor, tags chips, rating slider, media gallery (with metadata), sources list, locale strings.
   - Overrides toggles for displayTitle, notes, rating, media replacements, hidden flag.
   - Media import supports local file URLs initially; future remote toggle behind feature flag.
4. **Assignment & Preview**
   - Library lists canonical items; assign to tier via action menu (tvOS overlay) or drag/drop on pointer platforms (see section 9).
   - Preview renders formatted tier layout (read-only) to confirm structure before publishing.
5. **Validation & Persistence**
   - Inline validation banners jump focus to offending fields. Global “Validate” uses schema-level checks before enabling save.
   - Save pipeline: run validation -> serialize SwiftData snapshot -> update audit -> persist -> emit toast/progress.
   - Export share sheet offers JSON, CSV, Markdown, text using existing export subsystem.

## 9. Data Transfer & Drag/Drop
- Use `Transferable` protocol for pointer-platform drag/drop, providing both `CodableRepresentation` with custom `UTType(exportedAs: "com.tiercade.tieritem")` and `ProxyRepresentation` for text fallbacks.[8]
- On tvOS, fall back to select → choose destination via overlay; no drag/drop behavior is assumed.
- Register exported type identifiers in Info.plist to keep import/export consistent across platforms.

## 10. Search & Filtering
- Apply `.searchable` to the item library host view, letting the system pick placement per idiom (toolbar on tvOS/iPad/macOS, navigation bar on iOS).[9]
- Provide toggle filters (Unassigned, Assigned, Hidden) and tag quick filters; combine with search text.
- Large datasets rely on SwiftData queries with predicates keyed on indexed properties.

## 11. Validation Matrix
- **IDs**: Ensure uniqueness via `#Unique` plus runtime guard for cross-entity collisions.
- **Color**: Validate hex string pattern; supply palette picker on platforms with pointer/touch.
- **Ratings**: Clamp 0...100 with slider component.
- **Media**: Check required fields (`id`, `kind`, `uri`, `mime`) before save.
- **Attributes**: Key names restricted to alphanumeric + separators (match schema regex).
- **Overrides**: Only allow overriding fields present on canonical item; hidden flag prevents assignment but keeps data for exports.

## 12. Extensibility & Feature Flags
- Cloud storage section remains hidden until `cloud-sync` trait flips; reveals `storage.mode`, provider, base URL, auth config (all optional for now).
- Collaboration panel displays read-only member roster; editing rights planned later.
- Template launcher placeholder in item library header (disabled state).
- Analytics hooks capture create/update/delete events for tiers/items; integrate with existing telemetry dispatcher.

## 13. Testing Strategy
- Unit tests for SwiftData models (serialization, validation).
- UI tests: tvOS QuickSmoke covers focus routing, overlay dismissal, validation banners; iOS/mac test search/filter flows.
- Snapshot tests for preview renderer ensuring consistent tier surface per platform (leveraging existing testing frameworks).

## 14. Open Questions
1. Confirm default palette for tier colors (use design tokens or dynamic generator?).
2. Decide on structured vs. freeform tier rules editor (rich text vs. plain text).
3. Define audit user identity source (local profile vs. account system).

## References
1. SwiftUI `glassEffect(_:in:)` — https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)  
2. `GlassButtonStyle` — https://developer.apple.com/documentation/swiftui/glassbuttonstyle  
3. SwiftUI `focusSection()` — https://developer.apple.com/documentation/swiftui/view/focussection()  
4. SwiftUI `onExitCommand(perform:)` — https://developer.apple.com/documentation/swiftui/view/onexitcommand(perform:)  
5. SwiftData `@Model` macro — https://developer.apple.com/documentation/swiftdata/model()/  
6. SwiftData `@Transient` macro — https://developer.apple.com/documentation/swiftdata/transient()/  
7. SwiftData `#Unique` macro — https://developer.apple.com/documentation/swiftdata/unique(_:)  
8. CoreTransferable `Transferable` — https://developer.apple.com/documentation/coretransferable/transferable/  
9. SwiftUI `searchable(text:placement:prompt:)` — https://developer.apple.com/documentation/swiftui/view/searchable(text:placement:prompt:)  
10. SwiftUI `scrollEdgeEffectStyle(_:for:)` — https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:)  
