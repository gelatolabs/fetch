-- Map System Module
-- Handles all map-related operations including collision detection, tile queries, and spawn positioning

local sti = require "sti"
local AudioSystem = require "audio_system"
local Camera = require "camera"
local UISystem = require "ui_system"

local MapSystem = {}

-- Module state (will be initialized by main.lua)
local map = nil
local world = nil
local npcs = nil
local currentMap = nil

-- Map paths and door definitions
local mapPaths = {
    map = "tiled/map.lua",
    mapnorth = "tiled/mapnorth.lua",
    mapsouth = "tiled/mapsouth.lua",
    mapwest = "tiled/mapwest.lua",
    mapeast = "tiled/mapeast.lua",
    jail = "tiled/jail.lua",
    throneroom = "tiled/throneroom.lua",
    shop = "tiled/shop.lua"
}

local doors = {
    {
        map = "map",
        direction = "up",
        positions = {{x = 19, y = 0}},
        targetMap = "mapnorth",
        targetX = 19,
        targetY = 46,
        text = "Travel"
    },
    {
        map = "mapnorth",
        direction = "down",
        positions = {{x = 19, y = 47}},
        targetMap = "map",
        targetX = 19,
        targetY = 1,
        text = "Travel"
    },
    {
        map = "map",
        direction = "down",
        positions = {{x = 20, y = 47}},
        targetMap = "mapsouth",
        targetX = 20,
        targetY = 1,
        text = "Travel"
    },
    {
        map = "mapsouth",
        direction = "up",
        positions = {{x = 20, y = 0}},
        targetMap = "map",
        targetX = 20,
        targetY = 46,
        text = "Travel"
    },
    {
        map = "map",
        direction = "left",
        positions = {{x = 0, y = 21}},
        targetMap = "mapwest",
        targetX = 47,
        targetY = 21,
        text = "Travel"
    },
    {
        map = "mapwest",
        direction = "right",
        positions = {{x = 47, y = 21}},
        targetMap = "map",
        targetX = 1,
        targetY = 21,
        text = "Travel"
    },
    {
        map = "map",
        direction = "right",
        positions = {{x = 47, y = 17}},
        targetMap = "mapeast",
        targetX = 1,
        targetY = 17,
        text = "Travel"
    },
    {
        map = "mapeast",
        direction = "left",
        positions = {{x = 0, y = 17}},
        targetMap = "map",
        targetX = 46,
        targetY = 17,
        text = "Travel"
    },
    {
        map = "map",
        direction = nil,
        positions = {{x = 38, y = 16}},
        targetMap = "jail",
        targetX = 5,
        targetY = 8,
        text = "Enter"
    },
    {
        map = "jail",
        direction = nil,
        positions = {{x = 5, y = 9}},
        targetMap = "map",
        targetX = 38,
        targetY = 17,
        text = "Leave"
    },
    {
        map = "mapnorth",
        direction = nil,
        positions = {{x = 32, y = 32}},
        targetMap = "throneroom",
        targetX = 1,
        targetY = 9,
        text = "Enter"
    },
    {
        map = "throneroom",
        direction = nil,
        positions = {
            {x = 0, y = 8},
            {x = 0, y = 9},
            {x = 0, y = 10}
        },
        targetMap = "mapnorth",
        targetX = 31,
        targetY = 32,
        text = "Leave"
    },
    {
        map = "map",
        direction = nil,
        positions = {{x = 37, y = 25}},
        targetMap = "shop",
        targetX = 1,
        targetY = 7,
        text = "Enter"
    },
    {
        map = "shop",
        direction = nil,
        positions = {
            {x = 0, y = 6},
            {x = 0, y = 7},
            {x = 0, y = 8}
        },
        targetMap = "map",
        targetX = 37,
        targetY = 25,
        text = "Leave"
    }
}

-- Map music associations
local mapMusic = {
    jail = "spooky",
    throneroom = "throneRoom",
    shop = "themeFunky",
    -- All other maps use "theme"
}

-- Helper function to hide NPC and Pickup layers on a map
local function hideObjectLayersInternal(mapObj)
    for _, layer in ipairs(mapObj.layers) do
        if layer.name == "NPCs" or layer.name == "Pickups" then
            layer.visible = false
        end
    end
end

-- Initialize the map system with required references
function MapSystem.init(worldRef, npcsRef, initialMapName)
    world = worldRef
    npcs = npcsRef
    currentMap = initialMapName
    
    -- Load the initial map
    local mapPath = mapPaths[initialMapName]
    if mapPath then
        map = sti(mapPath)
        hideObjectLayersInternal(map)
        MapSystem.calculateMapBounds()
    else
        error("Unknown initial map: " .. initialMapName)
    end
end

-- Update references when they change (e.g., map transitions)
function MapSystem.updateReferences(mapRef, currentMapRef)
    if mapRef then map = mapRef end
    if currentMapRef then currentMap = currentMapRef end
end

-- Public function to hide NPC layer on a map
function MapSystem.hideNPCLayer(mapObj)
    hideObjectLayersInternal(mapObj)
end

-- Get the appropriate music track for a map
function MapSystem.getMusicForMap(mapName)
    return mapMusic[mapName] or "theme"
end

-- Play the appropriate music for a map
function MapSystem.playMusicForMap(mapName)
    if AudioSystem then
        local musicTrack = MapSystem.getMusicForMap(mapName)
        AudioSystem.playMusic(musicTrack)
    end
end

-- Load a new map and update all references
-- Returns: success (boolean), mapObj or error message (string)
-- Note: Does NOT change music - call playMusicForMap separately if needed
function MapSystem.loadMap(mapName)
    -- Check if the map exists
    local mapPath = mapPaths[mapName]
    if not mapPath then
        return false, "Unknown map: " .. mapName
    end
    
    -- Load the map using sti
    local success, newMapObj = pcall(sti, mapPath)
    if not success then
        return false, "Failed to load map: " .. mapName
    end
    
    -- Hide NPC layer
    hideObjectLayersInternal(newMapObj)
    
    -- Update references
    map = newMapObj
    currentMap = mapName
    
    -- Calculate new map bounds
    MapSystem.calculateMapBounds()
    
    return true, newMapObj
end

-- Get the current map object
function MapSystem.getMap()
    return map
end

-- Get the current map name
function MapSystem.getCurrentMap()
    return currentMap
end

-- Update the current map
function MapSystem.update(dt)
    if map then
        map:update(dt)
    end
end

-- Draw the current map
function MapSystem.draw()
    local camX, camY = Camera.getPosition()
    MapSystem.drawMapObject(map, camX, camY, 0, 0)
end

-- Draw a specific map object (for transitions)
function MapSystem.drawMapObject(mapObj, camX, camY, offsetX, offsetY)
    local chatOffset = UISystem.getChatPaneWidth()

    -- Draw the Tiled map
    love.graphics.setColor(1, 1, 1)
    mapObj:draw(chatOffset - camX + offsetX, -camY + offsetY)
end

-- Get map path by name
function MapSystem.getMapPath(mapName)
    return mapPaths[mapName]
end

-- Get all doors
function MapSystem.getDoors()
    return doors
end

-- Find a door at the given position on the current map
function MapSystem.findDoorAt(gridX, gridY)
    for _, door in ipairs(doors) do
        if door.map == currentMap and door.positions then
            -- Check all defined positions
            for _, pos in ipairs(door.positions) do
                if pos.x == gridX and pos.y == gridY then
                    -- Return door with no offset
                    local doorCopy = {}
                    for k, v in pairs(door) do doorCopy[k] = v end
                    doorCopy.offsetX = 0
                    doorCopy.offsetY = 0
                    return doorCopy
                end
            end

            -- For directional doors, also check the 2 adjacent tiles
            if door.direction and #door.positions == 1 then
                local centerPos = door.positions[1]

                if door.direction == "up" or door.direction == "down" then
                    -- Horizontal 3-tile door (side by side)
                    if centerPos.y == gridY then
                        if centerPos.x - 1 == gridX then
                            -- Entered from left tile
                            local doorCopy = {}
                            for k, v in pairs(door) do doorCopy[k] = v end
                            doorCopy.offsetX = -1
                            doorCopy.offsetY = 0
                            return doorCopy
                        elseif centerPos.x + 1 == gridX then
                            -- Entered from right tile
                            local doorCopy = {}
                            for k, v in pairs(door) do doorCopy[k] = v end
                            doorCopy.offsetX = 1
                            doorCopy.offsetY = 0
                            return doorCopy
                        end
                    end
                elseif door.direction == "left" or door.direction == "right" then
                    -- Vertical 3-tile door (stacked on top of each other)
                    if centerPos.x == gridX then
                        if centerPos.y - 1 == gridY then
                            -- Entered from top tile
                            local doorCopy = {}
                            for k, v in pairs(door) do doorCopy[k] = v end
                            doorCopy.offsetX = 0
                            doorCopy.offsetY = -1
                            return doorCopy
                        elseif centerPos.y + 1 == gridY then
                            -- Entered from bottom tile
                            local doorCopy = {}
                            for k, v in pairs(door) do doorCopy[k] = v end
                            doorCopy.offsetX = 0
                            doorCopy.offsetY = 1
                            return doorCopy
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Get map height in pixels
function MapSystem.getMapHeight(mapObj)
    return (mapObj.height or 0) * 16 -- tileSize
end

-- Get map minimum Y in pixels (always 0 for non-infinite maps)
function MapSystem.getMapMinY(mapObj)
    return 0
end

-- Get map width in pixels
function MapSystem.getMapWidth(mapObj)
    return (mapObj.width or 0) * 16 -- tileSize
end

-- Get map minimum X in pixels (always 0 for non-infinite maps)
function MapSystem.getMapMinX(mapObj)
    return 0
end

-- Calculate map bounds from map dimensions
function MapSystem.calculateMapBounds()
    if map.width and map.height then
        world.minX = 0
        world.minY = 0
        world.maxX = map.width * world.tileSize
        world.maxY = map.height * world.tileSize
    else
        -- No bounds available
        world.minX = nil
        world.minY = nil
        world.maxX = nil
        world.maxY = nil
    end
end

-- Check if a position is a water tile
function MapSystem.isWaterTile(x, y)
    local tileX = math.floor(x / world.tileSize)
    local tileY = math.floor(y / world.tileSize)
    
    -- Check all tile layers
    for _, layer in ipairs(map.layers) do
        if layer.type == "tilelayer" then
            -- Handle chunked maps
            if layer.chunks then
                for _, chunk in ipairs(layer.chunks) do
                    local chunkX = chunk.x
                    local chunkY = chunk.y
                    local chunkWidth = chunk.width
                    local chunkHeight = chunk.height
                    
                    if tileX >= chunkX and tileX < chunkX + chunkWidth and
                       tileY >= chunkY and tileY < chunkY + chunkHeight then
                        
                        local localX = tileX - chunkX + 1
                        local localY = tileY - chunkY + 1
                        
                        if chunk.data[localY] and chunk.data[localY][localX] then
                            local tile = chunk.data[localY][localX]
                            if tile.properties and tile.properties.is_water then
                                return true
                            end
                        end
                        break
                    end
                end
            else
                -- Handle non-chunked maps
                if layer.data[tileY + 1] and layer.data[tileY + 1][tileX + 1] then
                    local tile = layer.data[tileY + 1][tileX + 1]
                    if tile and tile.properties and tile.properties.is_water then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Check if an NPC is at a position
function MapSystem.isNPCAt(x, y)
    for _, npc in pairs(npcs) do
        if npc.map == currentMap then
            -- Check if NPC occupies this position (using grid-based collision)
            local npcGridX = math.floor(npc.x / 16)
            local npcGridY = math.floor(npc.y / 16)
            local targetGridX = math.floor(x / 16)
            local targetGridY = math.floor(y / 16)
            
            if npcGridX == targetGridX and npcGridY == targetGridY then
                return true
            end
        end
    end
    return false
end

-- Check if a tile is a jumpable obstacle (collides and height <= 0.5)
function MapSystem.isJumpableObstacle(x, y)
    local tileX = math.floor(x / world.tileSize)
    local tileY = math.floor(y / world.tileSize)
    
    -- Check all tile layers
    for _, layer in ipairs(map.layers) do
        if layer.type == "tilelayer" then
            -- Handle chunked maps
            if layer.chunks then
                for _, chunk in ipairs(layer.chunks) do
                    local chunkX = chunk.x
                    local chunkY = chunk.y
                    local chunkWidth = chunk.width
                    local chunkHeight = chunk.height
                    
                    if tileX >= chunkX and tileX < chunkX + chunkWidth and
                       tileY >= chunkY and tileY < chunkY + chunkHeight then
                        local localX = tileX - chunkX + 1
                        local localY = tileY - chunkY + 1
                        
                        if chunk.data[localY] and chunk.data[localY][localX] then
                            local tile = chunk.data[localY][localX]
                            if tile and tile.properties and tile.properties.collides and 
                               tile.properties.height and tile.properties.height <= 0.5 then
                                return true
                            end
                        end
                        break
                    end
                end
            else
                -- Handle non-chunked maps
                if layer.data[tileY + 1] and layer.data[tileY + 1][tileX + 1] then
                    local tile = layer.data[tileY + 1][tileX + 1]
                    if tile and tile.properties and tile.properties.collides and 
                       tile.properties.height and tile.properties.height <= 0.5 then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Get tile height at a position
function MapSystem.getTileHeight(x, y)
    local tileX = math.floor(x / world.tileSize)
    local tileY = math.floor(y / world.tileSize)
    
    -- Check all tile layers for height property
    for _, layer in ipairs(map.layers) do
        if layer.type == "tilelayer" then
            -- Handle chunked maps
            if layer.chunks then
                for _, chunk in ipairs(layer.chunks) do
                    local chunkX = chunk.x
                    local chunkY = chunk.y
                    local chunkWidth = chunk.width
                    local chunkHeight = chunk.height
                    
                    if tileX >= chunkX and tileX < chunkX + chunkWidth and
                       tileY >= chunkY and tileY < chunkY + chunkHeight then
                        local localX = tileX - chunkX + 1
                        local localY = tileY - chunkY + 1
                        
                        if chunk.data[localY] and chunk.data[localY][localX] then
                            local tile = chunk.data[localY][localX]
                            if tile and tile.properties and tile.properties.height then
                                return tile.properties.height
                            end
                        end
                        break
                    end
                end
            else
                -- Handle non-chunked maps
                if layer.data[tileY + 1] and layer.data[tileY + 1][tileX + 1] then
                    local tile = layer.data[tileY + 1][tileX + 1]
                    if tile and tile.properties and tile.properties.height then
                        return tile.properties.height
                    end
                end
            end
        end
    end
    
    return 0  -- Default height is 0
end

-- Helper function to check if a tile should block movement
local function shouldCollideWithTile(tile, canSwim)
    if not tile or not tile.properties or not tile.properties.collides then
        return false
    end
    -- If it's water and player can swim, allow passage
    if canSwim and tile.properties.is_water then
        return false
    end
    return true
end

-- Check if a position is colliding with the map
-- This is a pure map query - it does not consider player abilities
-- The caller (PlayerSystem) should handle ability checks like noclip
function MapSystem.isColliding(x, y, canSwim)
    canSwim = canSwim or false
    local tileX = math.floor(x / world.tileSize)
    local tileY = math.floor(y / world.tileSize)

    -- Check if there's ANY tile at this position (to prevent walking into void)
    local hasTile = false

    -- Check all tile layers
    for _, layer in ipairs(map.layers) do
        if layer.type == "tilelayer" then
            -- Handle chunked maps
            if layer.chunks then
                for _, chunk in ipairs(layer.chunks) do
                    -- Check if the tile position is within this chunk
                    local chunkX = chunk.x
                    local chunkY = chunk.y
                    local chunkWidth = chunk.width
                    local chunkHeight = chunk.height

                    if tileX >= chunkX and tileX < chunkX + chunkWidth and
                       tileY >= chunkY and tileY < chunkY + chunkHeight then

                        -- Convert to local chunk coordinates (1-based)
                        local localX = tileX - chunkX + 1
                        local localY = tileY - chunkY + 1

                        -- Get the tile from chunk data
                        if chunk.data[localY] and chunk.data[localY][localX] then
                            local tile = chunk.data[localY][localX]
                            hasTile = true
                            if shouldCollideWithTile(tile, canSwim) then
                                return true
                            end
                        end
                        break
                    end
                end
            else
                -- Handle non-chunked maps
                if layer.data[tileY + 1] and layer.data[tileY + 1][tileX + 1] then
                    local tile = layer.data[tileY + 1][tileX + 1]
                    hasTile = true
                    if shouldCollideWithTile(tile, canSwim) then
                        return true
                    end
                end
            end
        end
    end

    -- Collision if there's no tile at all (void)
    return not hasTile
end

-- Find a valid spawn position near a given location
function MapSystem.findValidSpawnPosition(x, y, entityName, maxSearchRadius)
    maxSearchRadius = maxSearchRadius or 20
    
    -- First check if current position is valid
    if not MapSystem.isColliding(x, y) then
        return x, y, true
    end
    
    print("Warning: " .. entityName .. " spawned on collision tile at (" .. x .. ", " .. y .. ")")
    
    local gridX = math.floor(x / 16)
    local gridY = math.floor(y / 16)
    
    -- Search in expanding circles for a valid position
    for radius = 1, maxSearchRadius do
        -- Create a list of positions at this radius (prioritize closer ones)
        local positions = {}
        
        for offsetY = -radius, radius do
            for offsetX = -radius, radius do
                -- Only check positions at the current radius (not inside)
                if math.abs(offsetX) == radius or math.abs(offsetY) == radius then
                    local testX = (gridX + offsetX) * 16 + 8
                    local testY = (gridY + offsetY) * 16 + 8
                    
                    if not MapSystem.isColliding(testX, testY) then
                        -- Found a valid position
                        print("  Moved to valid position: (" .. testX .. ", " .. testY .. ") [grid: " .. (gridX + offsetX) .. ", " .. (gridY + offsetY) .. "] (searched " .. radius .. " tiles away)")
                        return testX, testY, true
                    end
                end
            end
        end
    end
    
    -- If we get here, no valid position was found
    print("  ERROR: Could not find valid spawn position within " .. maxSearchRadius .. " tiles!")
    print("  Entity will spawn at original location but may be inaccessible!")
    return x, y, false
end

return MapSystem
