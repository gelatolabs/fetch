-- Camera System Module
-- Handles camera positioning and viewport management

local UISystem = require "ui_system"
local MapSystem = require "map_system"
local PlayerSystem = require "player_system"

local Camera = {}

-- Camera state
local camera = {
    x = 0,
    y = 0
}

-- Get camera position
function Camera.getPosition()
    return camera.x, camera.y
end

-- Set camera position
function Camera.setPosition(x, y)
    camera.x = x
    camera.y = y
end

-- Center camera on player
local function centerCameraOnPlayer()
    local player = PlayerSystem.getPlayer()
    -- Always center on the game viewport (320x240), regardless of chat pane visibility
    camera.x = player.x - UISystem.getGameWidth() / 2
    camera.y = player.y - UISystem.getGameHeight() / 2
end

-- Clamp camera to map bounds
local function clampCameraToMapBounds()
    local minX, minY, maxX, maxY = MapSystem.getWorldBounds()
    
    if not minX or not maxX then
        return
    end
    
    local mapWidth = maxX - minX
    local mapHeight = maxY - minY
    
    -- Viewport is always GAME_WIDTH x GAME_HEIGHT
    local viewportWidth = UISystem.getGameWidth()
    local viewportHeight = UISystem.getGameHeight()
    
    -- Only clamp if map is larger than screen
    if mapWidth > viewportWidth then
        camera.x = math.max(minX, math.min(camera.x, maxX - viewportWidth))
    else
        camera.x = minX + (mapWidth - viewportWidth) / 2
    end
    
    if mapHeight > viewportHeight then
        camera.y = math.max(minY, math.min(camera.y, maxY - viewportHeight))
    else
        camera.y = minY + (mapHeight - viewportHeight) / 2
    end
end

-- Update camera (centers on player and clamps to bounds)
function Camera.update()
    centerCameraOnPlayer()
    clampCameraToMapBounds()
end

return Camera

