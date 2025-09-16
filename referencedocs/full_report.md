# Final Report: Tier List Schema Package (v1)

## Summary
This package contains a battle-tested, versioned JSON Schema (Draft 2020-12), TypeScript and Swift models, five validated example projects, import/export specification, migration notes, and a test plan. It consolidates cross-source research (TierMaker, OpenTierBoy, silverweed/tiers, SuperFola, Easy-Tier-List, Miro, Trello, Notion) into one production-ready data model.

## Contents
- tierlist.schema.json (canonical schema)
- models.ts (TypeScript interfaces)
- Models.swift (Swift 6 Codable structs)
- examples/*.json (5 domain examples)
- import_export_spec.md
- migration_and_tests.md

## Rationale (high level)
- **Normalized items map** allows canonical items, dedupe, and cross-list reuse (analogous to boards/cards and Notion databases).
- **Per-project overrides** support contextual commentary without mutating canonical data.
- **Media[]** supports multiple assets per item (image/gif/video/audio) with thumbs/posters for performant lists.
- **Attributes bag** provides domain extensibility for GPUs, movies, games, apps, etc.
- **SchemaVersion** for safe evolution; migrations are deterministic and reversible where possible.

## Trade-offs
- Normalization increases API complexity (need endpoints for paginated items) but unlocks reusability and scale.
- LZ-String stateful URLs are convenient but limited by URL size; server share is the fallback.

## Sources (primary)
- TierMaker docs & blog — https://tiermaker.com/blog/support/10/tier-list-template-creation-guide-and-faqs
- TierMaker image limits — https://tiermaker.com/blog/support/18/image-limits
- OpenTierBoy (repo & site) — https://github.com/infinia-yzl/opentierboy and https://opentierboy.com
- silverweed/tiers — https://github.com/silverweed/tiers
- SuperFola/TierListMaker — https://github.com/SuperFola/TierListMaker
- Easy-Tier-List — https://github.com/Akascape/Easy-Tier-List
- Miro developer docs (cards) — https://developers.miro.com/docs/websdk-reference-cards
- Trello REST API (cards/attachments) — https://developer.atlassian.com/cloud/trello/rest/api-group-cards/
- Notion API (databases) — https://developers.notion.com/docs/working-with-databases
- LZ-String (stateful URL compression) — https://github.com/pieroxy/lz-string

## Next steps
1. Integrate schema into a prototype backend with endpoints:
   - GET /project/{projectId}?include=tiers,items(page=1,per=100)
   - POST /project (validate + store)
   - GET /project/{id}/export.json
2. Build a minimal web UI that:
   - loads project JSON
   - renders tiers with virtualization
   - lazy-loads media thumbs
   - allows per-item overrides without mutating canonical item
3. Implement migrations & run property-based test suite.

---
Package generated on request.