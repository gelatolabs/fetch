#!/bin/bash

# Script to generate 16x16 tile PNGs for game map
# Requires ImageMagick to be installed (brew install imagemagick)

# Create tiles directory if it doesn't exist
TILES_DIR="tiles"
mkdir -p "$TILES_DIR"

echo "Generating 16x16 game tiles..."

# Flower tile (red flower with green stem)
magick -size 16x16 xc:transparent \
  -fill '#2d5016' -draw 'rectangle 7,10 8,15' \
  -fill '#ff4444' -draw 'circle 7.5,8 7.5,6' \
  -fill '#ffaa44' -draw 'circle 7.5,8 7.5,7' \
  "$TILES_DIR/flower.png"
echo "Created flower.png"

# Tree tile (brown trunk with green foliage)
magick -size 16x16 xc:transparent \
  -fill '#4a3520' -draw 'rectangle 6,8 9,15' \
  -fill '#2d5016' -draw 'circle 7.5,6 7.5,2' \
  -fill '#3a6b1f' -draw 'circle 7.5,6 7.5,3' \
  "$TILES_DIR/tree.png"
echo "Created tree.png"

# Grass clump tile (tufts of grass)
magick -size 16x16 xc:transparent \
  -fill '#3a7d1f' -draw 'rectangle 2,12 3,15' \
  -fill '#3a7d1f' -draw 'rectangle 5,10 6,15' \
  -fill '#2d6016' -draw 'rectangle 8,11 9,15' \
  -fill '#3a7d1f' -draw 'rectangle 11,13 12,15' \
  -fill '#2d6016' -draw 'rectangle 13,10 14,15' \
  "$TILES_DIR/grass_clump.png"
echo "Created grass_clump.png"

# Rock tile (gray stone)
magick -size 16x16 xc:transparent \
  -fill '#666666' -draw 'polygon 4,12 8,5 12,8 10,13' \
  -fill '#888888' -draw 'polygon 8,5 10,7 9,9 6,8' \
  -fill '#444444' -draw 'polygon 9,9 10,13 6,12 6,10' \
  "$TILES_DIR/rock.png"
echo "Created rock.png"

# Bush tile (dense green foliage)
magick -size 16x16 xc:transparent \
  -fill '#2d5016' -draw 'ellipse 8,10 6,5 0,360' \
  -fill '#3a6b1f' -draw 'ellipse 8,9 5,4 0,360' \
  "$TILES_DIR/bush.png"
echo "Created bush.png"

# Water tile (blue with lighter ripples)
magick -size 16x16 xc:'#4488ff' \
  -fill '#66aaff' -draw 'circle 4,4 4,2' \
  -fill '#66aaff' -draw 'circle 12,10 12,8' \
  "$TILES_DIR/water.png"
echo "Created water.png"

# Sand tile (beige with texture)
magick -size 16x16 xc:'#d4b896' \
  -fill '#c4a886' -draw 'point 3,3' \
  -fill '#c4a886' -draw 'point 7,5' \
  -fill '#c4a886' -draw 'point 11,8' \
  -fill '#c4a886' -draw 'point 5,10' \
  -fill '#c4a886' -draw 'point 13,12' \
  -fill '#c4a886' -draw 'point 8,14' \
  "$TILES_DIR/sand.png"
echo "Created sand.png"

# Dirt tile (brown with dark spots)
magick -size 16x16 xc:'#8b6f47' \
  -fill '#6b4f27' -draw 'point 2,2' \
  -fill '#6b4f27' -draw 'point 6,4' \
  -fill '#6b4f27' -draw 'point 10,7' \
  -fill '#6b4f27' -draw 'point 4,9' \
  -fill '#6b4f27' -draw 'point 12,11' \
  -fill '#6b4f27' -draw 'point 7,13' \
  "$TILES_DIR/dirt.png"
echo "Created dirt.png"

# Path/Stone tile (gray cobblestone)
magick -size 16x16 xc:'#999999' \
  -fill '#777777' -draw 'rectangle 0,0 7,7' \
  -fill '#777777' -draw 'rectangle 8,8 15,15' \
  -fill '#bbbbbb' -draw 'line 7,0 7,15' \
  -fill '#bbbbbb' -draw 'line 0,7 15,7' \
  "$TILES_DIR/path.png"
echo "Created path.png"

# Yellow flower variant
magick -size 16x16 xc:transparent \
  -fill '#2d5016' -draw 'rectangle 7,10 8,15' \
  -fill '#ffdd44' -draw 'circle 7.5,8 7.5,6' \
  -fill '#ffee88' -draw 'circle 7.5,8 7.5,7' \
  "$TILES_DIR/flower_yellow.png"
echo "Created flower_yellow.png"

# Blue flower variant
magick -size 16x16 xc:transparent \
  -fill '#2d5016' -draw 'rectangle 7,10 8,15' \
  -fill '#4488ff' -draw 'circle 7.5,8 7.5,6' \
  -fill '#88bbff' -draw 'circle 7.5,8 7.5,7' \
  "$TILES_DIR/flower_blue.png"
echo "Created flower_blue.png"

# Small rock
magick -size 16x16 xc:transparent \
  -fill '#777777' -draw 'ellipse 8,11 4,3 0,360' \
  -fill '#999999' -draw 'ellipse 7,10 3,2 0,360' \
  "$TILES_DIR/rock_small.png"
echo "Created rock_small.png"

# Mushroom tile (red cap with white spots)
magick -size 16x16 xc:transparent \
  -fill '#dddddd' -draw 'rectangle 6,9 9,15' \
  -fill '#cc3333' -draw 'ellipse 7.5,8 5,4 0,360' \
  -fill '#ffffff' -draw 'circle 5,7 5,6' \
  -fill '#ffffff' -draw 'circle 9,6 9,5.5' \
  "$TILES_DIR/mushroom.png"
echo "Created mushroom.png"

echo ""
echo "All tiles generated successfully in '$TILES_DIR/' directory!"
echo "Total: 13 tiles created"

