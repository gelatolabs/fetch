-- Camera System
-- Manages the game camera with Pokemon-style centering on the player

local Camera = {}

-- Dependencies
local UISystem = require "ui_system"

-- Camera state
local camera = {
    x = 0,
    y = 0
}

-- World reference (to be initialized)
local world = nil

-- Initialize the camera system
function Camera.init(worldRef)
    world = worldRef
end

-- Get the camera position
function Camera.getPosition()
    return camera.x, camera.y
end

-- Center camera on player
local function centerCameraOnPlayer(playerX, playerY)
    -- Always center on the game viewport (320x240), regardless of chat pane visibility
    camera.x = playerX - UISystem.getGameWidth() / 2
    camera.y = playerY - UISystem.getGameHeight() / 2
end

-- Clamp camera to map bounds
local function clampCameraToMapBounds()
    if not world.minX or not world.maxX then
        return
    end
    
    local mapWidth = world.maxX - world.minX
    local mapHeight = world.maxY - world.minY
    
    -- Viewport is always GAME_WIDTH x GAME_HEIGHT
    local viewportWidth = UISystem.getGameWidth()
    
    -- Only clamp if map is larger than screen
    if mapWidth > viewportWidth then
        camera.x = math.max(world.minX, math.min(camera.x, world.maxX - viewportWidth))
    else
        camera.x = world.minX + (mapWidth - viewportWidth) / 2
    end
    
    if mapHeight > UISystem.getGameHeight() then
        camera.y = math.max(world.minY, math.min(camera.y, world.maxY - UISystem.getGameHeight()))
    else
        camera.y = world.minY + (mapHeight - UISystem.getGameHeight()) / 2
    end
end

-- Update the camera (centers on player and clamps to map bounds)
function Camera.update(playerX, playerY)
    centerCameraOnPlayer(playerX, playerY)
    clampCameraToMapBounds()
end

return Camera

