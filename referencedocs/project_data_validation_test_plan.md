# Project Data Validation Test Plan

This plan exercises the offline Tiercade project data lifecycle, ensuring
schema integrity, serialization correctness, media handling, and guardrails for
the v1 local-only schema.

## 1) Schema validation

- Validate sample projects against `tierlist.schema.json` using a Swift
  JSON-schema validator or fixture-based Codable decoding.

## 2) Codable round-trip (Swift 6)

- Construct a complex `Project` in memory → `JSONEncoder` → `JSONDecoder` → equality on all fields.
- Ensure unknown fields pass through `additional` maps where present.

## 3) Property-based tests (SwiftCheck)

- **Serialization invariance**: encode→decode equals original.
- **Tier integrity**: every `tier.itemIds[i]` exists in `items`.
- **Tier order**: unique sequence 0..n-1 (array order authoritative).
- **Rating bounds**: 0–100 for any rating present.
- **Media kind validity**: only `image|gif|video|audio`.
- **Attributes types**: only string|number|boolean|string[]
- **Overrides non-destruction**: applying overrides never mutates canonical `items`.

## 4) Media pipeline tests

- Import of local files writes to `Media/` with SHA-256 names.
- Thumbnail generator produces `Thumbs/<sha>_256.jpg`, sets `thumbUri`.
- Broken path detection raises a clear error.

## 5) Bundle export/import round-trip

- Export `.tierproj` → unzip → open → validate → compare with original (URIs may differ only by normalized file paths).

## 6) Performance targets

- Open/resolve **≤5k items**: initial render under ~500ms on baseline dev hardware with UI virtualization.
- Thumbnail generation amortized and cached (no UI jank).

## 7) Security

- Notes are rendered as Markdown with sanitization (no script execution).
- Only `file://` URIs permitted for media in offline v1.

## 8) Validation regression tests

- URI scheme enforcement: constructing a project with any `http(s)` media URI
  throws via `ProjectValidation.validateOfflineV1`.
- Collaboration role required: missing `role` in any `collab.members` entry
  fails Codable decode (or explicit validation helper).
