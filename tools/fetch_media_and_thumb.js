#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const axios = require('axios');
const Jimp = require('jimp');

function usage() {
  console.log('Usage: node fetch_media_and_thumb.js <project.json> [--out out.json]');
  process.exit(2);
}

const args = process.argv.slice(2);
if (args.length < 1) usage();

const projectPath = path.resolve(args[0]);
const outPath = args.includes('--out') ? path.resolve(args[args.indexOf('--out')+1]) : projectPath.replace(/\.json$/, '.media.json');

if (!fs.existsSync(projectPath)) { console.error('Project file not found:', projectPath); process.exit(1); }

const projectJson = JSON.parse(fs.readFileSync(projectPath, 'utf8'));
const projectId = projectJson.projectId || 'local';
const mediaDir = path.resolve(__dirname, 'media', projectId);
fs.mkdirSync(mediaDir, { recursive: true });

async function download(url, dest) {
  const writer = fs.createWriteStream(dest);
  const res = await axios({ url, method: 'GET', responseType: 'stream', timeout: 20000 });
  return new Promise((resolve, reject) => {
    res.data.pipe(writer);
    let error = null;
    writer.on('error', err => { error = err; writer.close(); reject(err); });
    writer.on('close', () => { if (!error) resolve(); });
  });
}

async function processMedia() {
  for (const itemId of Object.keys(projectJson.items || {})) {
    const item = projectJson.items[itemId];
    if (!item.media) continue;
    for (const m of item.media) {
      if (!m.uri || !m.kind) continue;
      try {
        const url = m.uri;
        const ext = path.extname(new URL(url).pathname) || (m.kind === 'image' ? '.jpg' : '.bin');
        const filename = `${itemId}-${m.id}${ext}`.replace(/[^a-zA-Z0-9._-]/g, '_');
        const localPath = path.join(mediaDir, filename);
        if (!fs.existsSync(localPath)) {
          await download(url, localPath);
        }
        // create thumbnail for images
        if (m.kind === 'image') {
          const thumbName = `${itemId}-${m.id}-thumb.jpg`;
          const thumbPath = path.join(mediaDir, thumbName);
          if (!fs.existsSync(thumbPath)) {
            const img = await Jimp.read(localPath);
            img.cover(400, 225).quality(80).write(thumbPath);
          }
          m.thumbUri = `file://${thumbPath}`;
          m.uri = `file://${localPath}`;
        } else if (m.kind === 'video') {
          // for videos, keep uri but copy posterUri if present
          if (m.posterUri) {
            try {
              const posterUrl = m.posterUri;
              const posterExt = path.extname(new URL(posterUrl).pathname) || '.jpg';
              const posterName = `${itemId}-${m.id}-poster${posterExt}`.replace(/[^a-zA-Z0-9._-]/g, '_');
              const posterPath = path.join(mediaDir, posterName);
              if (!fs.existsSync(posterPath)) await download(posterUrl, posterPath);
              m.posterUri = `file://${posterPath}`;
            } catch (e) {
              // ignore poster download failure
            }
          }
        }
      } catch (err) {
        console.error('Failed to fetch media for', itemId, m.id, err.message || err);
      }
    }
  }
  fs.writeFileSync(outPath, JSON.stringify(projectJson, null, 2));
  console.log('Media fetch complete. Output written to', outPath);
}

processMedia().catch(err => { console.error('Fatal error:', err); process.exit(1); });
