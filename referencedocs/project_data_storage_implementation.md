# Project Data Storage Implementation

This brief outlines the offline v1 storage pipeline for Tiercade projects,
covering local persistence, import/export behavior, and future-ready schema
constraints.

## What to implement

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

## Files to reference

- `tierlist.schema.json` (authoritative schema; optional `storage` and `links` keep us cloud-ready later)
- `ProjectDataModels.swift` (authoritative Swift models)

## Cloud-ready notes (future)

- Schema allows `Media.uri`/`thumbUri` as any `uri` (http(s) etc.). v1 uses `file://` only.
- Optional `storage` lets the app declare `"mode": "cloud"` and describe a remote store later without breaking v1 code.
