-- Player System Module
-- Handles player state, movement, rendering, and related functionality

local PlayerSystem = {}

-- Player state
local player = {
    x = -10 * 16 + 8,  -- Current pixel position (grid -10, -10 in upper-left grassy area)
    y = -10 * 16 + 8,
    gridX = -10, -- Grid position (in tiles)
    gridY = -10,
    size = 16,
    direction = "down",
    facing = "right",  -- Remembers last horizontal direction
    lastVertical = "down",
    moving = false,
    moveTimer = 0,
    moveDuration = 0.15,  -- Time to move one tile (in seconds)
    walkFrame = 0,  -- 0 or 1 for animation
    wasOnWater = false,  -- Track if player was on water last frame
    jumping = false,  -- Track if player is jumping
    jumpHeight = 0,  -- Current jump height offset for rendering
    queuedDirection = nil  -- Queued movement direction
}

-- Player gold
local playerGold = 0

-- Player sprite resources
local playerTileset = nil
local playerQuads = {
    regular = {},
    boat = {},
    swimming = {}
}

-- Initialize player system
function PlayerSystem.init()
    -- Load player tileset
    playerTileset = love.graphics.newImage("tiles/player-tileset.png")
    
    -- Create quads for player animation
    -- Regular movement quads
    playerQuads.regular = {
        down = {
            love.graphics.newQuad(0, 0, 16, 16, playerTileset:getDimensions()),
            love.graphics.newQuad(16, 0, 16, 16, playerTileset:getDimensions())
        },
        up = {
            love.graphics.newQuad(32, 0, 16, 16, playerTileset:getDimensions()),
            love.graphics.newQuad(48, 0, 16, 16, playerTileset:getDimensions())
        }
    }

    -- Boat movement quads
    playerQuads.boat = {
        down = {
            love.graphics.newQuad(64, 0, 16, 16, playerTileset:getDimensions()),
            love.graphics.newQuad(80, 0, 16, 16, playerTileset:getDimensions())
        },
        up = {
            love.graphics.newQuad(96, 0, 16, 16, playerTileset:getDimensions()),
            love.graphics.newQuad(112, 0, 16, 16, playerTileset:getDimensions())
        }
    }

    -- Swimming movement quads
    playerQuads.swimming = {
        down = {
            love.graphics.newQuad(128, 0, 16, 16, playerTileset:getDimensions()),
            love.graphics.newQuad(144, 0, 16, 16, playerTileset:getDimensions())
        },
        up = {
            love.graphics.newQuad(160, 0, 16, 16, playerTileset:getDimensions()),
            love.graphics.newQuad(176, 0, 16, 16, playerTileset:getDimensions())
        }
    }
end

-- Get player state
function PlayerSystem.getPlayer()
    return player
end

-- Get player gold
function PlayerSystem.getGold()
    return playerGold
end

-- Set player gold
function PlayerSystem.setGold(amount)
    playerGold = amount
end

-- Add gold to player
function PlayerSystem.addGold(amount)
    playerGold = playerGold + amount
end

-- Subtract gold from player
function PlayerSystem.subtractGold(amount)
    playerGold = playerGold - amount
end

-- Set player position
function PlayerSystem.setPosition(x, y, gridX, gridY)
    player.x = x
    player.y = y
    if gridX then player.gridX = gridX end
    if gridY then player.gridY = gridY end
end

-- Get the current player sprite set based on conditions
function PlayerSystem.getSpriteSet(abilityManager, MapSystem)
    -- Don't use water sprites when jumping
    if player.jumping then
        return playerQuads.regular
    end
    
    local isOnWater = MapSystem.isWaterTile(player.x, player.y)

    if isOnWater then
        if abilityManager:hasAbility("swim") then
            return playerQuads.swimming
        else
            return playerQuads.boat
        end
    end
    return playerQuads.regular
end

-- Draw the player
function PlayerSystem.draw(camX, camY, abilityManager, MapSystem, chatOffset)
    chatOffset = chatOffset or 0  -- Default to 0 if not provided
    love.graphics.setColor(1, 1, 1)
    local spriteSet = PlayerSystem.getSpriteSet(abilityManager, MapSystem)
    local currentQuad = spriteSet[player.lastVertical][player.moving and (player.walkFrame + 1) or 1]
    local scaleX = (player.facing == "left") and -1 or 1
    local offsetX = (player.facing == "left") and player.size or 0
    love.graphics.draw(
        playerTileset,
        currentQuad,
        player.x - player.size/2 - camX + offsetX + chatOffset,
        player.y - player.size/2 - camY - player.jumpHeight,
        0,
        scaleX,
        1
    )
end

-- Get player tileset (for external use)
function PlayerSystem.getTileset()
    return playerTileset
end

return PlayerSystem
