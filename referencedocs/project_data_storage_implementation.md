# Project Data Storage Implementation

## Current Implementation (v2 - SwiftData)

Tiercade now uses **SwiftData** for persistence with automatic saving:

- **Primary storage**: SwiftData `ModelContainer` with `TierListModel` entities
- **Auto-save**: Changes persist automatically via SwiftData's change tracking
- **Crash recovery**: SwiftData provides automatic persistence guarantees
- **Migration**: Legacy UserDefaults data is migrated on first launch (`AppState+LegacyMigration.swift`)

### Export Formats (Current)

| Format | Extension | Platform Support |
|--------|-----------|------------------|
| JSON | `.json` | All platforms |
| CSV | `.csv` | All platforms |
| Markdown | `.md` | All platforms |
| Plain Text | `.txt` | All platforms |
| PNG | `.png` | All platforms |
| PDF | `.pdf` | iOS, macOS only (not tvOS) |

### Security Limits

- **JSON import size**: 50MB maximum (DoS prevention)
- **URL validation**: HTTPS-only for external resources
- **Path traversal**: Blocked via path containment validation
- **CSV sanitization**: Formula injection prevention (=, +, -, @)

See `TiercadeTests/SecurityTests/` for validation test coverage.

---

## Legacy Reference (v1 - Filesystem)

> **Note**: The following describes the original v1 filesystem-based approach.
> This is retained for reference but is no longer the primary storage mechanism.

This brief outlines the offline v1 storage pipeline for Tiercade projects,
covering local persistence, import/export behavior, and future-ready schema
constraints.

### What to implement (v1 Legacy)

- V1 constraint: `storage.mode` must be `local` or omitted; all `Media.uri`/`posterUri`/`thumbUri` MUST be `file://`.
- Cloud-ready: Schema already allows http(s) for future cloud; no changes to Swift models required yet.
- Local storage layout (macOS):
  - `~/Library/Application Support/Tiercade/Projects/{projectId}/project.json`
  - `~/Library/Application Support/Tiercade/Media/<sha256>.<ext>`
  - `~/Library/Application Support/Tiercade/Thumbs/<sha256>_256.jpg`
- Import (CSV/JSON): copy local files, generate thumbs, set `file://` URIs.
- Resolve: merge `items{}` + `overrides{}` (override media replaces canonical media).
- Export: write `.tierproj` (zip of project.json + Media + Thumbs).
- Tests: follow `project_data_validation_test_plan.md`.

### Files to reference (v1 Legacy)

- `tierlist.schema.json` (authoritative schema; optional `storage` and `links` keep us cloud-ready later)
- `ProjectDataModels.swift` (authoritative Swift models)

### Cloud-ready notes (v1 Legacy)

- Schema allows `Media.uri`/`thumbUri` as any `uri` (http(s) etc.). v1 uses `file://` only.
- Optional `storage` lets the app declare `"mode": "cloud"` and describe a remote store later without breaking v1 code.
