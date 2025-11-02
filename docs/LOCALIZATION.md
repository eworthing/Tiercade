# Localization Guide

## Overview

Tiercade is being prepared for internationalization (i18n). This document outlines the strategy and migration plan.

## Current Status

**Foundation Established**: Basic `Localizable.strings` file created  
**Migration Progress**: 0% (all strings currently hardcoded)  
**Target Languages**: English (base), with structure ready for additional languages

## File Structure

```
Tiercade/
├── Localizable.strings          # Base English strings (created)
└── [future: es.lproj, fr.lproj, etc.]
```

## Usage Pattern

### Before (Hardcoded)
```swift
Button("Save") {
    // action
}

Text("Export Failed")
```

### After (Localized)
```swift
Button(NSLocalizedString("action.save", comment: "Save button")) {
    // action
}

Text(NSLocalizedString("toast.error.export_failed", comment: "Export error"))
```

### SwiftUI Helper Extension (Recommended)
```swift
extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    func localized(comment: String) -> String {
        NSLocalizedString(self, comment: comment)
    }
}

// Usage:
Button("action.save".localized) {
    // action
}
```

## Migration Strategy

### Phase 1: Infrastructure (✅ Complete)
- [x] Create `Localizable.strings` foundation file
- [x] Add to Xcode project
- [x] Document migration process

### Phase 2: String Extraction (In Progress)
- [ ] Audit all user-facing strings
- [ ] Categorize by domain (actions, errors, tooltips, etc.)
- [ ] Add to `Localizable.strings`

### Phase 3: Code Migration (Pending)
- [ ] Create String extension helper
- [ ] Migrate high-priority strings (errors, actions)
- [ ] Migrate medium-priority (tooltips, labels)
- [ ] Migrate low-priority (debug messages, internal states)

### Phase 4: Additional Languages (Future)
- [ ] Add Spanish (es.lproj)
- [ ] Add French (fr.lproj)
- [ ] Add German (de.lproj)
- [ ] Add Japanese (ja.lproj)

## String Key Naming Convention

Use dot notation with context prefix:

```
{domain}.{context}.{identifier}

Examples:
- action.save
- action.cancel
- toolbar.new_tier_list
- error.persistence.encoding_failed
- toast.success.file_saved
- h2h.skip
- analysis.balance_score
```

## Testing Localization

### 1. Pseudolocalization
Enable in Xcode scheme: Product → Scheme → Edit Scheme → Run → App Language → Double-Length Pseudolanguage

### 2. Language Testing
Product → Scheme → Edit Scheme → Run → App Language → [Choose language]

### 3. Right-to-Left (RTL) Testing
Test with Arabic or Hebrew to ensure UI flips correctly

## Priority Strings for Migration

### High Priority (User-facing errors and actions)
1. Error messages (PersistenceError, ImportError, ExportError)
2. Toast notifications (success/failure messages)
3. Button actions (Save, Cancel, Export, etc.)
4. Toolbar labels

### Medium Priority (UI labels and tooltips)
1. Tier names (S, A, B, C, D, F, Unranked)
2. Export format names
3. Analysis labels
4. Head-to-head UI

### Low Priority (Internal/debug)
1. Debug log messages
2. Internal state descriptions
3. Developer-facing text

## Exclusions

Do **not** localize:
- User-generated content (item names, tier labels)
- File names and extensions
- JSON/CSV data fields
- API endpoints
- Debug identifiers

## Related Documentation

- Apple's Localization Guide: https://developer.apple.com/localization/
- Swift String Catalog: https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog

## Contributing

When adding new user-facing strings:
1. Add to `Localizable.strings` first
2. Use the localization helper in code
3. Add comment explaining context
4. Test with pseudolocalization

## Notes for Maintainers

- **String freeze**: Before releasing, establish string freeze dates for translators
- **Context matters**: Always provide comments for translators (especially with %@ placeholders)
- **Pluralization**: Use `.stringsdict` for complex plural rules
- **Format strings**: Document placeholder order and types (e.g., "%@ %d" means string then number)

---

**Last Updated**: November 2, 2025  
**Status**: Foundation established, migration pending  
**Contact**: See CONTRIBUTING.md (when created)
