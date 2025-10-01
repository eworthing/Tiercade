#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const axios = require('axios');
const Jimp = require('jimp');

// TMDb API configuration
const TMDB_API_KEY = process.env.TMDB_API_KEY || '';
const TMDB_BASE_URL = 'https://api.themoviedb.org/3';
const TMDB_IMAGE_BASE = 'https://image.tmdb.org/t/p/original';

function usage() {
  console.log('Usage: node fetch_media_and_thumb.js <project.json> [options]');
  console.log('Options:');
  console.log('  --out <file>           Output JSON file (default: <input>.media.json)');
  console.log('  --tmdb                 Enable TMDb API lookups for movies/TV');
  console.log('  --xcode-assets <path>  Organize images into Xcode Assets.xcassets');
  console.log('  --asset-group <name>   Asset catalog group name (default: BundledTierlists)');
  console.log('');
  console.log('Environment Variables:');
  console.log('  TMDB_API_KEY          Your TMDb API key (get from themoviedb.org)');
  process.exit(2);
}

const args = process.argv.slice(2);
if (args.length < 1) usage();

// Parse command-line arguments
const projectPath = path.resolve(args[0]);
const outPath = args.includes('--out') ? path.resolve(args[args.indexOf('--out')+1]) : projectPath.replace(/\.json$/, '.media.json');
const useTmdb = args.includes('--tmdb');
const xcodeAssetsPath = args.includes('--xcode-assets') ? path.resolve(args[args.indexOf('--xcode-assets')+1]) : null;
const assetGroup = args.includes('--asset-group') ? args[args.indexOf('--asset-group')+1] : 'BundledTierlists';

if (!fs.existsSync(projectPath)) { console.error('Project file not found:', projectPath); process.exit(1); }
if (useTmdb && !TMDB_API_KEY) { 
  console.error('TMDb API key required. Set TMDB_API_KEY environment variable.'); 
  console.error('Get your free API key at https://www.themoviedb.org/settings/api');
  process.exit(1); 
}

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

// TMDb API functions
async function searchTMDb(query, type = 'movie') {
  if (!TMDB_API_KEY) return null;
  try {
    const endpoint = type === 'tv' ? 'search/tv' : 'search/movie';
    const res = await axios.get(`${TMDB_BASE_URL}/${endpoint}`, {
      params: { api_key: TMDB_API_KEY, query, language: 'en-US', page: 1 },
      timeout: 10000
    });
    return res.data.results?.[0] || null;
  } catch (err) {
    console.error(`TMDb search failed for "${query}":`, err.message);
    return null;
  }
}

async function getTMDbDetails(id, type = 'movie') {
  if (!TMDB_API_KEY) return null;
  try {
    const endpoint = type === 'tv' ? `tv/${id}` : `movie/${id}`;
    const res = await axios.get(`${TMDB_BASE_URL}/${endpoint}`, {
      params: { api_key: TMDB_API_KEY, language: 'en-US' },
      timeout: 10000
    });
    return res.data;
  } catch (err) {
    console.error(`TMDb details failed for ${type} ${id}:`, err.message);
    return null;
  }
}

function getTMDbImageUrl(posterPath) {
  return posterPath ? `${TMDB_IMAGE_BASE}${posterPath}` : null;
}

// Xcode asset catalog functions
function createXcodeAssetCatalog(basePath, groupName, itemId, imagePath) {
  const assetName = `${groupName}/${itemId}`;
  const assetDir = path.join(basePath, `${assetName}.imageset`);
  fs.mkdirSync(assetDir, { recursive: true });

  // Copy image to asset catalog
  const ext = path.extname(imagePath);
  const destName = `${itemId}${ext}`;
  const destPath = path.join(assetDir, destName);
  fs.copyFileSync(imagePath, destPath);

  // Create Contents.json
  const contentsJson = {
    images: [
      {
        filename: destName,
        idiom: "universal",
        scale: "1x"
      },
      {
        idiom: "universal",
        scale: "2x"
      },
      {
        idiom: "universal",
        scale: "3x"
      }
    ],
    info: {
      author: "xcode",
      version: 1
    }
  };

  fs.writeFileSync(path.join(assetDir, 'Contents.json'), JSON.stringify(contentsJson, null, 2));
  return assetName;
}

async function processMedia() {
  let tmdbLookups = 0;
  let imagesDownloaded = 0;
  let assetsCreated = 0;

  for (const itemId of Object.keys(projectJson.items || {})) {
    const item = projectJson.items[itemId];
    
    // Try TMDb lookup if enabled and item doesn't have imageUrl yet
    if (useTmdb && !item.imageUrl) {
      const itemName = item.name || itemId;
      console.log(`Looking up "${itemName}" on TMDb...`);
      
      // Determine if it's a TV show or movie based on item properties
      const isTV = item.seasonNumber || item.seasonString || 
                   itemName.toLowerCase().includes('series') ||
                   itemName.toLowerCase().includes('season');
      
      const result = await searchTMDb(itemName, isTV ? 'tv' : 'movie');
      
      if (result) {
        tmdbLookups++;
        const details = await getTMDbDetails(result.id, isTV ? 'tv' : 'movie');
        
        if (details) {
          // Get poster image
          const posterUrl = getTMDbImageUrl(details.poster_path);
          if (posterUrl) {
            const ext = '.jpg';
            const filename = `${itemId}${ext}`;
            const localPath = path.join(mediaDir, filename);
            
            try {
              console.log(`  Downloading poster for "${itemName}"...`);
              await download(posterUrl, localPath);
              imagesDownloaded++;
              
              // Update item with image URL
              if (xcodeAssetsPath) {
                const assetName = createXcodeAssetCatalog(xcodeAssetsPath, assetGroup, itemId, localPath);
                item.imageUrl = assetName; // Reference to asset catalog
                assetsCreated++;
                console.log(`  Added to asset catalog: ${assetName}`);
              } else {
                item.imageUrl = `file://${localPath}`;
              }
              
              // Add metadata
              if (!item.description && details.overview) {
                item.description = details.overview;
              }
              
              // Add additional metadata as needed
              if (details.release_date || details.first_air_date) {
                const year = (details.release_date || details.first_air_date).split('-')[0];
                if (!item.seasonString) {
                  item.seasonString = year;
                }
              }
            } catch (err) {
              console.error(`  Failed to download poster:`, err.message);
            }
          }
        }
      } else {
        console.log(`  No TMDb results found for "${itemName}"`);
      }
      
      // Rate limit: wait 250ms between API calls
      await new Promise(resolve => setTimeout(resolve, 250));
    }
    
    // Process existing media entries
    if (item.media) {
      for (const m of item.media) {
        if (!m.uri || !m.kind) continue;
        try {
          const url = m.uri;
          const ext = path.extname(new URL(url).pathname) || (m.kind === 'image' ? '.jpg' : '.bin');
          const filename = `${itemId}-${m.id}${ext}`.replace(/[^a-zA-Z0-9._-]/g, '_');
          const localPath = path.join(mediaDir, filename);
          if (!fs.existsSync(localPath)) {
            await download(url, localPath);
            imagesDownloaded++;
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
            
            // Add to Xcode assets if path provided
            if (xcodeAssetsPath) {
              const assetName = createXcodeAssetCatalog(xcodeAssetsPath, assetGroup, `${itemId}-${m.id}`, localPath);
              m.uri = assetName;
              assetsCreated++;
            } else {
              m.uri = `file://${localPath}`;
            }
          } else if (m.kind === 'video') {
            // for videos, keep uri but copy posterUri if present
            if (m.posterUri) {
              try {
                const posterUrl = m.posterUri;
                const posterExt = path.extname(new URL(posterUrl).pathname) || '.jpg';
                const posterName = `${itemId}-${m.id}-poster${posterExt}`.replace(/[^a-zA-Z0-9._-]/g, '_');
                const posterPath = path.join(mediaDir, posterName);
                if (!fs.existsSync(posterPath)) {
                  await download(posterUrl, posterPath);
                  imagesDownloaded++;
                }
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
  }
  
  fs.writeFileSync(outPath, JSON.stringify(projectJson, null, 2));
  console.log('\n✅ Media fetch complete!');
  console.log(`   Output: ${outPath}`);
  if (useTmdb) console.log(`   TMDb lookups: ${tmdbLookups}`);
  console.log(`   Images downloaded: ${imagesDownloaded}`);
  if (xcodeAssetsPath) console.log(`   Assets created: ${assetsCreated} in ${xcodeAssetsPath}`);
}

processMedia().catch(err => { console.error('Fatal error:', err); process.exit(1); });
