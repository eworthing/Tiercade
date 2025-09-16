# Import / Export Specification

## JSON (canonical)
- File must validate against `tierlist.schema.json` (Draft 2020-12).
- Required top-level fields: `schemaVersion`, `projectId`, `tiers`, `items`, `audit`.
- Items map keys must match pattern `^[a-zA-Z0-9_\\-:]+$`.

## CSV
- CSV rows represent items. Required columns for import:
  - title, tierLabel
- Optional columns (map to attributes with prefix `attr_`):
  - attr_year, attr_platforms (semicolon-delimited), imageUrl, videoUrl, audioUrl, rating, tags (semicolon-delimited), notes
- Mapping example (row -> JSON):
  - `imageUrl` -> first media `{ kind: "image", uri: imageUrl, mime: inferred }`
  - `attr_releaseYear` -> `attributes.releaseYear` (number)
  - `tierLabel` -> place item in tier with same label (create if missing)

## Stateful URL (Copy-Jutsu)
- Use LZ-String `compressToEncodedURIComponent` to compress a carefully chosen subset of project state:
  - Recommended subset: { schemaVersion, projectId, title, tiers, items (only id/title/media.thumbUri), overrides (notes/tags) }
- Pseudocode (encode/decode):
  - encode: `LZString.compressToEncodedURIComponent(JSON.stringify(state))`
  - decode: `JSON.parse(LZString.decompressFromEncodedURIComponent(fragment))`
- Budget: aim for <= 8000 characters in practice. For projects that exceed budget, fall back to server-side share: POST project, return short `shareId`.

## Embed iframe
- Read-only endpoint: `/embed/{projectId}`
- Optional URL params: `?theme=dark&showUnranked=false`
- Parent/iframe sizing: use `postMessage` to communicate height.

## Media handling
- Store media URIs as either CDN URLs or content-addressed paths (`ipfs://...` supported)
- Media objects should include `thumbUri` or `posterUri` for lazy-loading and quick visual lists
- Respect CORS for browser-based rendering