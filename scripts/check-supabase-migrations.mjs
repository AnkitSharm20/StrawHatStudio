import { readdirSync, readFileSync } from 'node:fs';

const directory = 'supabase/migrations';
const manifestPath = `${directory}/live-versions.txt`;
const manifest = readFileSync(manifestPath, 'utf8')
  .split(/\r?\n/)
  .map(line => line.trim())
  .filter(line => line && !line.startsWith('#'))
  .sort();

const files = readdirSync(directory).filter(name => name.endsWith('.sql')).sort();
const actual = files.map(name => name.slice(0, -4));
const invalid = files.filter(name => !/^\d{14}_[a-z0-9_]+\.sql$/.test(name));
const duplicates = actual.filter((name, index) => actual.indexOf(name) !== index);

if (invalid.length || duplicates.length || JSON.stringify(actual) !== JSON.stringify(manifest)) {
  console.error('Supabase migration inventory mismatch.');
  if (invalid.length) console.error('Invalid filenames:', invalid);
  if (duplicates.length) console.error('Duplicate versions:', [...new Set(duplicates)]);
  const missing = manifest.filter(name => !actual.includes(name));
  const untracked = actual.filter(name => !manifest.includes(name));
  if (missing.length) console.error('Missing migration files:', missing);
  if (untracked.length) console.error('Untracked migration files:', untracked);
  process.exit(1);
}
console.log(`Verified ${actual.length} migration files against the live Supabase inventory.`);
