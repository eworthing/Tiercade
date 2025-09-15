#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

function usage() {
  console.log('Usage: node schema_validate.js <project.json> [--schema path/to/tierlist.schema.json]');
  process.exit(2);
}

const args = process.argv.slice(2);
if (args.length < 1) usage();

const projectPath = path.resolve(args[0]);
let schemaPath = path.resolve(__dirname, '..', 'referencedocs', 'tierlist.schema.json');
for (let i = 1; i < args.length; i++) {
  if (args[i] === '--schema' && i + 1 < args.length) { schemaPath = path.resolve(args[i+1]); i++; }
}

if (!fs.existsSync(projectPath)) { console.error('Project file not found:', projectPath); process.exit(1); }
if (!fs.existsSync(schemaPath)) { console.error('Schema file not found:', schemaPath); process.exit(2); }

const projectJson = JSON.parse(fs.readFileSync(projectPath, 'utf8'));
const schemaJson = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));

const ajv = new Ajv({ allErrors: true, strict: false, allowUnionTypes: true });
addFormats(ajv);

// Register Draft 2020-12 meta-schema so $schema references resolve correctly.
// Ajv v8 doesn't automatically include 2020-12 meta-schema by key.

try {
  // AJV 8 ships with a packaged 2020-12 index that pulls in meta fragments.
  // Use the index to ensure internal $ref meta fragments resolve.
  const draft2020Index = require('ajv/dist/refs/json-schema-2020-12/index.js');
  ajv.addMetaSchema(draft2020Index);
} catch (e) {
  // If that path isn't available, fall back to best-effort without the meta-schema.
}

const validate = ajv.compile(schemaJson);
const valid = validate(projectJson);
if (valid) {
  console.log('VALID: project JSON conforms to schema');
  process.exit(0);
}

console.error('INVALID: project JSON does not conform to schema');
for (const err of validate.errors) {
  console.error(`- ${err.instancePath || '/'} ${err.message} ${err.params ? JSON.stringify(err.params) : ''}`);
}
process.exit(3);
