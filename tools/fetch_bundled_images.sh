#!/bin/bash
# Helper script to fetch images for bundled tier lists using TMDb API

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSETS_PATH="$PROJECT_ROOT/Tiercade/Assets.xcassets"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎬 Tiercade Bundled Images Fetcher${NC}"
echo

# Check for TMDb API key
if [ -z "$TMDB_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  TMDb API key not found in environment${NC}"
    echo "   To use TMDb API for automatic image lookup:"
    echo "   1. Get a free API key at https://www.themoviedb.org/settings/api"
    echo "   2. Export it: export TMDB_API_KEY='your-api-key-here'"
    echo
    echo "   Continuing without TMDb support..."
    TMDB_FLAG=""
else
    echo -e "${GREEN}✓ TMDb API key found${NC}"
    TMDB_FLAG="--tmdb"
fi

# Check if node_modules exists
if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    cd "$SCRIPT_DIR"
    npm install
    echo
fi

# Create temporary JSON files for each bundled tier list
TEMP_DIR="$SCRIPT_DIR/temp_bundled"
mkdir -p "$TEMP_DIR"

echo -e "${BLUE}📦 Generating temporary project files...${NC}"

# Generate Star Wars project JSON (most likely to work with TMDb)
cat > "$TEMP_DIR/star-wars-saga.json" << 'EOF'
{
  "schemaVersion": 1,
  "projectId": "star-wars-saga",
  "title": "Star Wars Films",
  "description": "Rank every theatrical Star Wars film",
  "tiers": [],
  "items": {
    "a-new-hope": {
      "id": "a-new-hope",
      "name": "Star Wars: Episode IV - A New Hope",
      "seasonString": "1977",
      "description": "The 1977 original that launched the galaxy."
    },
    "empire-strikes-back": {
      "id": "empire-strikes-back",
      "name": "Star Wars: Episode V - The Empire Strikes Back",
      "seasonString": "1980",
      "description": "The darker middle chapter with an iconic twist."
    },
    "return-of-the-jedi": {
      "id": "return-of-the-jedi",
      "name": "Star Wars: Episode VI - Return of the Jedi",
      "seasonString": "1983",
      "description": "Ewoks, redemption, and an emotional finale."
    },
    "phantom-menace": {
      "id": "phantom-menace",
      "name": "Star Wars: Episode I - The Phantom Menace",
      "seasonString": "1999",
      "description": "The prequel opener featuring podracing and the Sith."
    },
    "attack-of-the-clones": {
      "id": "attack-of-the-clones",
      "name": "Star Wars: Episode II - Attack of the Clones",
      "seasonString": "2002",
      "description": "Clones, politics, and the rise of the Republic's army."
    },
    "revenge-of-the-sith": {
      "id": "revenge-of-the-sith",
      "name": "Star Wars: Episode III - Revenge of the Sith",
      "seasonString": "2005",
      "description": "Anakin's fall and Order 66 reshape the galaxy."
    },
    "force-awakens": {
      "id": "force-awakens",
      "name": "Star Wars: Episode VII - The Force Awakens",
      "seasonString": "2015",
      "description": "A new generation rises against the First Order."
    },
    "last-jedi": {
      "id": "last-jedi",
      "name": "Star Wars: Episode VIII - The Last Jedi",
      "seasonString": "2017",
      "description": "Subverted expectations and a focus on legacy."
    },
    "rise-of-skywalker": {
      "id": "rise-of-skywalker",
      "name": "Star Wars: Episode IX - The Rise of Skywalker",
      "seasonString": "2019",
      "description": "The dramatic conclusion to the Skywalker saga."
    },
    "rogue-one": {
      "id": "rogue-one",
      "name": "Rogue One: A Star Wars Story",
      "seasonString": "2016",
      "description": "Rebels steal the Death Star plans in a gritty war story."
    },
    "solo": {
      "id": "solo",
      "name": "Solo: A Star Wars Story",
      "seasonString": "2018",
      "description": "Han Solo's origin tale filled with heists and heart."
    }
  }
}
EOF

# Generate 90s Animated Classics project JSON
cat > "$TEMP_DIR/animated-classics.json" << 'EOF'
{
  "schemaVersion": 1,
  "projectId": "animated-classics",
  "title": "90s Animated Classics",
  "description": "Iconic animated series from the 1990s",
  "tiers": [],
  "items": {
    "batman-tas": {
      "id": "batman-tas",
      "name": "Batman: The Animated Series",
      "seasonString": "1992-1995",
      "description": "Stylish noir take on Gotham's protector."
    },
    "x-men-tas": {
      "id": "x-men-tas",
      "name": "X-Men: The Animated Series",
      "seasonString": "1992-1997",
      "description": "Mutant soap opera with an unforgettable theme."
    },
    "animaniacs": {
      "id": "animaniacs",
      "name": "Animaniacs",
      "seasonString": "1993-1998",
      "description": "Variety show chaos with the Warner siblings."
    },
    "gargoyles": {
      "id": "gargoyles",
      "name": "Gargoyles",
      "seasonString": "1994-1997",
      "description": "Mythic stone guardians awaken in modern Manhattan."
    },
    "spider-man": {
      "id": "spider-man",
      "name": "Spider-Man: The Animated Series",
      "seasonString": "1994-1998",
      "description": "Web-slinging hero faces iconic rogues."
    },
    "pokemon": {
      "id": "pokemon",
      "name": "Pokémon",
      "seasonString": "1997",
      "description": "Ash and Pikachu's journey through Kanto and beyond."
    },
    "powerpuff-girls": {
      "id": "powerpuff-girls",
      "name": "The Powerpuff Girls",
      "seasonString": "1998-2005",
      "description": "Sugar, spice, and Chemical X-powered heroes."
    },
    "spongebob": {
      "id": "spongebob",
      "name": "SpongeBob SquarePants",
      "seasonString": "1999",
      "description": "Undersea optimism with endless quotables."
    }
  }
}
EOF

echo -e "${GREEN}✓ Generated project files${NC}"
echo

# Fetch images for Star Wars
echo -e "${BLUE}🎬 Fetching Star Wars images...${NC}"
node "$SCRIPT_DIR/fetch_media_and_thumb.js" \
    "$TEMP_DIR/star-wars-saga.json" \
    --out "$TEMP_DIR/star-wars-saga.media.json" \
    $TMDB_FLAG \
    --xcode-assets "$ASSETS_PATH" \
    --asset-group "BundledTierlists/StarWars"

echo

# Fetch images for Animated Classics
echo -e "${BLUE}📺 Fetching Animated Classics images...${NC}"
node "$SCRIPT_DIR/fetch_media_and_thumb.js" \
    "$TEMP_DIR/animated-classics.json" \
    --out "$TEMP_DIR/animated-classics.media.json" \
    $TMDB_FLAG \
    --xcode-assets "$ASSETS_PATH" \
    --asset-group "BundledTierlists/Animated"

echo
echo -e "${GREEN}✅ All done!${NC}"
echo
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review downloaded images in tools/media/"
echo "2. Check Xcode asset catalog: Tiercade/Assets.xcassets/BundledTierlists/"
echo "3. Update BundledProjects.swift ItemsFactory with imageUrl values"
echo "4. For Survivor images, you'll need to manually source them (CBS doesn't have TMDb entries)"
echo
echo -e "${YELLOW}Note: TMDb works best for movies and TV shows.${NC}"
echo "      For reality TV contestants (Survivor), you'll need manual sourcing."
