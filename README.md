# Go Fetch

A charming pixel-art quest game built with LÖVE2D where you help NPCs by fetching items and completing quests.

![Game Title](sprites/player.png)

## About

**Go Fetch** is a retro-style RPG featuring grid-based movement, NPC interactions, and a quest system. Players navigate a tile-based world, talk to NPCs, accept quests, and collect items to complete various fetch quests.

### Features

- **Grid-based Movement**: Smooth character movement on a 16x16 pixel grid
- **Quest System**: Three complete quest chains with multiple NPCs
- **Pixel-Perfect Graphics**: Retro aesthetic with nearest-neighbor filtering
- **Dynamic UI**: Quest log and inventory management systems
- **Fullscreen Mode**: Automatic scaling to fit your screen while maintaining pixel-perfect rendering
- **Tiled Map Integration**: Levels designed using Tiled map editor

## Quest Chains

1. **Lost Cat** - Help the Old Lady find her missing cat
2. **Missing Book** - Retrieve a rare book for the Librarian
3. **Package Delivery** - Pick up a package for the Merchant

## Requirements

- [LÖVE2D](https://love2d.org/) (LÖVE 11.x or later)
- Supported on Windows, macOS, and Linux

## Installation

1. **Install LÖVE2D**
   - Download from [love2d.org](https://love2d.org/)
   - Or install via package manager:
     ```bash
     # macOS
     brew install love
     
     # Ubuntu/Debian
     sudo apt install love
     
     # Arch Linux
     sudo pacman -S love
     ```

2. **Clone or Download this Repository**
   ```bash
   git clone <repository-url>
   cd fetch
   ```

3. **Run the Game**
   ```bash
   love .
   ```
   
   Or drag and drop the game folder onto the LÖVE application icon.

## Controls

### Movement
- `W` / `Up Arrow` - Move up
- `S` / `Down Arrow` - Move down
- `A` / `Left Arrow` - Move left
- `D` / `Right Arrow` - Move right

### Interactions
- `Space` - Talk to NPCs / Accept quests / Progress dialog
- `Q` - Toggle Quest Log
- `I` - Toggle Inventory
- `Esc` - Close menus / Return to game

## Game Mechanics

### NPCs
NPCs are scattered throughout the world. When you're near an NPC, a prompt will appear allowing you to interact with them.

- **Yellow indicator** - Quest available
- **Green indicator** - Quest ready to turn in

### Quest System
1. Find an NPC with a quest (yellow indicator)
2. Press `Space` to talk and accept the quest
3. Find the NPC who has the required item
4. Return to the quest giver to complete the quest (green indicator)

### Inventory
Access your inventory by pressing `I`. Items are displayed in a grid-based slot system.

Items in the game:
- **Fluffy Cat** - A lost feline companion
- **Ancient Tome** - A rare library book
- **Sealed Package** - A merchant's delivery

## Project Structure

```
fetch/
├── main.lua              # Main game file with core logic
├── quests.lua            # Quest and NPC definitions
├── BitPotionExt.ttf      # Pixel art font
├── sprites/              # Character sprites
│   ├── player.png        # Player idle sprite
│   ├── player-walk0.png  # Player walk animation frame 1
│   ├── player-walk1.png  # Player walk animation frame 2
│   └── npc.png           # NPC sprite
├── tiles/                # Tile graphics
│   ├── brown.png
│   ├── green.png
│   └── wall.png
├── tiled/                # Tiled map editor files
│   ├── map.tmx           # Tiled map source
│   ├── map.lua           # Exported Lua map
│   └── tiles.tsx         # Tileset definition
└── sti/                  # Simple Tiled Implementation library
    └── ...
```

## Technical Details

- **Resolution**: 320x240 pixels (internally), scaled to fit screen
- **Tile Size**: 16x16 pixels
- **Map System**: Uses STI (Simple Tiled Implementation) for map rendering
- **Rendering**: Canvas-based rendering with pixel-perfect scaling
- **Animation**: Frame-based walk cycle with timer system

## Development

### Modifying Quests

Edit `quests.lua` to add or modify NPCs and quests:

```lua
-- Add a new NPC
{
    id = "npc_unique_id",
    x = 300,
    y = 300,
    size = 16,
    name = "NPC Name",
    questId = "quest_id",
    isQuestGiver = true
}

-- Add a new quest
quest_id = {
    id = "quest_id",
    name = "Quest Name",
    description = "Quest description",
    questGiver = "npc_unique_id",
    requiredItem = "item_id",
    reward = "Reward text",
    active = false,
    completed = false
}
```

### Editing Maps

1. Open `tiled/map.tmx` in [Tiled Map Editor](https://www.mapeditor.org/)
2. Edit tiles and properties
3. Export as Lua: File → Export As → map.lua
4. Ensure collision properties are set on wall tiles

### Adding Sprites

Place 16x16 pixel PNG files in the `sprites/` or `tiles/` directory and load them in `main.lua`:

```lua
local newSprite = love.graphics.newImage("sprites/new_sprite.png")
newSprite:setFilter("nearest", "nearest")
```

## Credits

- **Game Engine**: [LÖVE2D](https://love2d.org/)
- **Map Library**: [STI (Simple Tiled Implementation)](https://github.com/karai17/Simple-Tiled-Implementation)
- **Font**: Bit Potion Ext

## License

[Add your license information here]

## Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests
- Create new quests and maps

---

**Enjoy the game! Go fetch those items! 🎮**

