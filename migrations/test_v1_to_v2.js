const fs = require('fs');
const path = require('path');
const migrate = require('./v1_to_v2');

const samplePath = path.resolve(__dirname, '..', 'referencedocs', 'movie.json');
if (!fs.existsSync(samplePath)) { console.error('Sample file not found:', samplePath); process.exit(2); }
const project = JSON.parse(fs.readFileSync(samplePath, 'utf8'));
const migrated = migrate(project);
if (migrated.schemaVersion !== 2) {
  console.error('Migration failed: expected schemaVersion 2 but got', migrated.schemaVersion);
  process.exit(1);
}
if (!migrated.items || !migrated.items.movie1 || !migrated.items.movie1.description) {
  console.error('Migration failed: description missing on movie1');
  process.exit(1);
}
console.log('v1->v2 migration test: PASS');
process.exit(0);
