// v1_to_v2.js
// Migration: rename Item.summary -> Item.description (and same inside overrides)
module.exports = function migrate_v1_to_v2(project) {
  if (!project || project.schemaVersion !== 1) return project;
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
};
