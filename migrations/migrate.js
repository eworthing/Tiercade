#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const migrations = [];
// load known migrations
migrations.push(require('./v1_to_v2'));

function usage() {
  console.log('Usage: node migrate.js <project.json> [--out out.json]');
  process.exit(2);
}

const args = process.argv.slice(2);
if (args.length < 1) usage();

const projectPath = path.resolve(args[0]);
const outPath = args.includes('--out') ? path.resolve(args[args.indexOf('--out')+1]) : projectPath.replace(/\.json$/, '.migrated.json');

if (!fs.existsSync(projectPath)) { console.error('Project file not found:', projectPath); process.exit(1); }

const projectJson = JSON.parse(fs.readFileSync(projectPath, 'utf8'));

let current = projectJson;
for (const m of migrations) {
  const beforeVersion = current.schemaVersion || 0;
  current = m(current);
  const afterVersion = current.schemaVersion || beforeVersion;
  if (afterVersion === beforeVersion) continue;
  console.log(`Applied migration: ${beforeVersion} -> ${afterVersion}`);
}

// backup original
const backupPath = projectPath + '.bak.' + Date.now();
fs.copyFileSync(projectPath, backupPath);
fs.writeFileSync(outPath, JSON.stringify(current, null, 2));
console.log('Migration complete. Output written to:', outPath);
console.log('Original backed up to:', backupPath);
