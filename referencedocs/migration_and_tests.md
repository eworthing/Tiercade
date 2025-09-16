# Migration Notes & Tests Outline

## Versioning policy
- `schemaVersion` is a monotonic integer. Major breaking changes increment this value.
- Deprecation window: keep deprecated field for at least one major version cycle and mark in changelog.

## Example migration v1 -> v2 (rename Item.summary -> Item.description)
Pseudocode:
```
function migrate_v1_to_v2(project) {
  if (project.schemaVersion !== 1) return project;
  const p2 = JSON.parse(JSON.stringify(project));
  for (const id in p2.items) {
    const it = p2.items[id];
    if (it.summary && !it.description) { it.description = it.summary; delete it.summary; }
  }
  if (p2.overrides) {
    for (const id in p2.overrides) {
      const ov = p2.overrides[id];
      if (ov.summary && !ov.description) { ov.description = ov.summary; delete ov.summary; }
    }
  }
  p2.schemaVersion = 2;
  return p2;
}
```

## Tests outline
1. **Schema validation tests**: validate sample files against `tierlist.schema.json` using AJV (Node) and jsonschema (Python).
2. **Round-trip tests (TypeScript)**: create Project object -> JSON.stringify -> parse -> deepEqual.
3. **Round-trip tests (Swift Codable)**: encode -> decode -> assert equal.
4. **CSV import/export tests**: produce CSV rows, import, export, assert equivalence for core fields.
5. **Stateful URL tests**: encode subset, decode, assert identity.
6. **Property-based tests (fast-check / SwiftCheck)**:
   - serialization invariance
   - override non-destruction
   - rating bounds
   - media.kind validity
   - tier.order uniqueness
   - id format compliance (UUID for projectId)
   - items/tier consistency (all tier.itemIds exist in items map)
7. **Performance tests**: import/export of 10k items (server-side), pagination latencies, and lazy-media load benchmarks.
8. **Security tests**: XSS checks in notes and embed HTML; CORS enforcement on media URIs.