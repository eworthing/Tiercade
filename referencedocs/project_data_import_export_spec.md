# Import / Export Specification (Swift-only, Offline)

This app is **standalone** (no cloud/CDN, no server) and **Swift 6–only**. All data is stored locally.

## Canonical Format: JSON

- Files validate against `tierlist.schema.json` (Draft 2020-12).
- Required at root: `schemaVersion`, `projectId` (UUID v4), `tiers[]`, `items{}`, `audit`.
- Media `uri`/`thumbUri` are **file URLs** pointing into the app's local store.

## Bundle Format: `.tierproj` (zip)

A self-contained bundle for sharing or backup, containing:
```
{ProjectTitle}.tierproj/
  project.json               # canonical JSON (validates against schema)
  Media/                     # content-addressed files: <sha256>.<ext>
  Thumbs/                    # <sha256>_256.jpg (or .webp)
  README.txt                 # optional notes
```
- Content addressing: filename = SHA-256 of bytes (dedup-friendly).
- Thumbnails: generated locally at import time (max edge ~256px).

### File URL rules
- `Media` and `Thumbs` entries referenced in JSON must be `file://` URLs.
- V1 validation fails if any media URI is not `file://` (enforced in `ProjectValidation.validateOfflineV1`).
- When we flip to cloud later, we'll set `storage.mode = "cloud"` and allow http(s) URIs.
- When importing external URLs, the importer downloads/copies into `Media/`, generates a thumb into `Thumbs/`, and rewrites URIs to `file://` paths.

## CSV Import (optional)

CSV allows quick item creation. Minimum columns:
- `title`, `tierLabel`

Optional columns:
- `imagePath` (local path), `videoPath`, `audioPath`
- `rating`
- `tags` (semicolon-separated)
- `notes`
- `attr_*` → `attributes.*` (strings by default; numeric if parsable)

### Mapping
- `imagePath` → first media `{ kind: "image", uri: file://..., mime: inferred, thumbUri: file://... }`
- `tierLabel` → place item into matching tier (create tier if needed)
- `attr_year` → `attributes.year` (number if integer)

## No URL sharing / no embeds
- **Stateful URL** and **embed iframes** are out-of-scope for offline v1.
- Sharing is done by exchanging the `.tierproj` bundle.

## Integrity

- On open/import: validate JSON via schema, verify that all `file://` URIs resolve.
- On export: re-validate, then create `.tierproj` zip.

## Future expansion (cloud-ready)
- While v1 requires `file://` URIs, the schema permits generic `uri` values.
- When enabling cloud later, set `storage.mode = "cloud"` and write absolute http(s) URIs for media.
