-- Libraries
local sti = require "sti"
local questData = require "quests"
local CheatConsole = require "cheat_console"

-- Game constants
local GAME_WIDTH = 320
local GAME_HEIGHT = 240
local SCALE

-- Graphics resources
local canvas
local font

-- Sprites
local playerSprite
local playerWalk0
local playerWalk1
local npcSprite

-- Game state
-- playing, dialog, questLog, inventory, questTurnIn
local gameState = "playing"

-- Player (Pokemon-style grid movement)
-- Initial spawn position (will be validated and adjusted if on collision tile)
local player = {
    x = -10 * 16 + 8,  -- Current pixel position (grid -10, -10 in upper-left grassy area)
    y = -10 * 16 + 8,
    gridX = -10, -- Grid position (in tiles)
    gridY = -10,
    size = 16,
    direction = "down",
    moving = false,
    moveTimer = 0,
    moveDuration = 0.15,  -- Time to move one tile (in seconds)
    walkFrame = 0  -- 0 or 1 for animation
}

-- Camera (Pokemon-style: always centered on player)
local camera = {
    x = 0,
    y = 0
}

-- World map
local map
local world = {
    tileSize = 16,
    width = 50,
    height = 50,
    -- Simple collision map (0 = walkable, 1 = wall)
    tiles = {}
}

-- NPCs
local npcs = {}

-- Quests
local quests = {}
local activeQuests = {}
local completedQuests = {}

-- Inventory
local inventory = {}

-- Item registry (single source of truth for all items)
local itemRegistry = {
    item_cat = {id = "item_cat", name = "Fluffy Cat", aliases = {"cat"}},
    item_book = {id = "item_book", name = "Ancient Tome", aliases = {"book"}},
    item_package = {id = "item_package", name = "Sealed Package", aliases = {"package"}}
}

-- Player abilities
local playerAbilities = {
    swim = false
}

-- UI state
local nearbyNPC = nil
local currentDialog = nil
local nearbyDoor = nil

-- Toast system
local toasts = {}
local TOAST_DURATION = 3.0 -- seconds

-- Door/Map transition system
local currentMap = "map"
local mapPaths = {
    map = "tiled/map.lua",
    shop = "tiled/shop.lua"
}
local doors = {
    {
        map = "map",
        x = 21,
        y = 9,
        targetMap = "shop",
        targetX = -9,
        targetY = 0,
        indoor = false
    },
    {
        map = "shop",
        x = -10,
        y = -1,
        targetMap = "map",
        targetX = 21,
        targetY = 9,
        indoor = true
    },
    {
        map = "shop",
        x = -10,
        y = 0,
        targetMap = "map",
        targetX = 21,
        targetY = 9,
        indoor = true
    },
    {
        map = "shop",
        x = -10,
        y = 1,
        targetMap = "map",
        targetX = 21,
        targetY = 9,
        indoor = true
    }
}

function love.load()
    love.window.setTitle("Go Fetch")

    -- Calculate scale factor (highest integer multiple that fits screen)
    local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
    local scaleX = math.floor(desktopWidth / GAME_WIDTH)
    local scaleY = math.floor(desktopHeight / GAME_HEIGHT)
    SCALE = math.min(scaleX, scaleY)
    if SCALE < 1 then SCALE = 1 end

    love.window.setMode(GAME_WIDTH * SCALE, GAME_HEIGHT * SCALE, {fullscreen = true})

    -- Create canvas
    canvas = love.graphics.newCanvas(GAME_WIDTH, GAME_HEIGHT)
    canvas:setFilter("nearest", "nearest")

    -- Disable interpolation globally
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Load font (size 16 renders at 8px height)
    font = love.graphics.newFont("BitPotionExt.ttf", 16)
    font:setFilter("nearest", "nearest")
    love.graphics.setFont(font)

    -- Load sprites
    playerSprite = love.graphics.newImage("sprites/player.png")
    -- playerSprite:setFilter("nearest", "nearest")
    playerWalk0 = love.graphics.newImage("sprites/player-walk0.png")
    -- playerWalk0:setFilter("nearest", "nearest")
    playerWalk1 = love.graphics.newImage("sprites/player-walk1.png")
    -- playerWalk1:setFilter("nearest", "nearest")
    npcSprite = love.graphics.newImage("sprites/npc.png")
    -- npcSprite:setFilter("nearest", "nearest")

    -- Load Tiled map
    map = sti(mapPaths[currentMap])

    -- Calculate map bounds from chunks
    local layer = map.layers[1]
    if layer and layer.chunks then
        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge
        
        for _, chunk in ipairs(layer.chunks) do
            minX = math.min(minX, chunk.x)
            minY = math.min(minY, chunk.y)
            maxX = math.max(maxX, chunk.x + chunk.width)
            maxY = math.max(maxY, chunk.y + chunk.height)
        end
        
        -- Store map bounds in pixels
        world.minX = minX * world.tileSize
        world.minY = minY * world.tileSize
        world.maxX = maxX * world.tileSize
        world.maxY = maxY * world.tileSize
    end

    -- Initialize world (all walkable for now)
    for y = 1, world.height do
        world.tiles[y] = {}
        for x = 1, world.width do
            world.tiles[y][x] = 0
        end
    end

    -- Add border walls
    for x = 1, world.width do
        world.tiles[1][x] = 1
        world.tiles[world.height][x] = 1
    end
    for y = 1, world.height do
        world.tiles[y][1] = 1
        world.tiles[y][world.width] = 1
    end

    -- Load game data
    loadGameData()
    
    -- Validate player spawn position
    local newX, newY, success = findValidSpawnPosition(player.x, player.y, "Player", 15)
    if newX ~= player.x or newY ~= player.y then
        -- Update player position and grid position
        player.x = newX
        player.y = newY
        player.gridX = math.floor(newX / 16)
        player.gridY = math.floor(newY / 16)
    end
    
    -- Initialize camera centered on player
    camera.x = player.x - GAME_WIDTH / 2
    camera.y = player.y - GAME_HEIGHT / 2
end

-- Helper function to find a valid spawn position near a given location
function findValidSpawnPosition(x, y, entityName, maxSearchRadius)
    maxSearchRadius = maxSearchRadius or 20
    
    -- First check if current position is valid
    if not isColliding(x, y) then
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
                    
                    if not isColliding(testX, testY) then
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

function loadGameData()
    -- Load NPCs from quest data, validating positions
    for _, npcData in ipairs(questData.npcs) do
        local newX, newY, success = findValidSpawnPosition(npcData.x, npcData.y, "NPC '" .. npcData.name .. "'", 20)
        npcData.x = newX
        npcData.y = newY
        
        table.insert(npcs, npcData)
    end

    -- Load quests from quest data
    for questId, questInfo in pairs(questData.questData) do
        quests[questId] = questInfo
    end
end

function love.update(dt)
    -- Update map
    map:update(dt)

    -- Update toasts
    for i = #toasts, 1, -1 do
        toasts[i].timer = toasts[i].timer - dt
        if toasts[i].timer <= 0 then
            table.remove(toasts, i)
        end
    end

    if gameState == "playing" and not CheatConsole.isOpen() then
        -- Pokemon-style grid-based movement
        if player.moving then
            -- Increment move timer
            player.moveTimer = player.moveTimer + dt
            
            -- Calculate interpolation progress (0 to 1)
            local progress = math.min(player.moveTimer / player.moveDuration, 1)
            
            -- Smooth easing (ease-out)
            local eased = 1 - (1 - progress) * (1 - progress)
            
            -- Calculate start and end positions
            local startX = player.gridX * 16 + 8
            local startY = player.gridY * 16 + 8
            local endX = player.targetGridX * 16 + 8
            local endY = player.targetGridY * 16 + 8
            
            -- Interpolate player position
            player.x = startX + (endX - startX) * eased
            player.y = startY + (endY - startY) * eased
            
            -- Update walk animation frame
            if player.moveTimer >= player.moveDuration / 2 and player.walkFrame == 0 then
                player.walkFrame = 1
            end
            
            -- Check if movement is complete
            if progress >= 1 then
                player.gridX = player.targetGridX
                player.gridY = player.targetGridY
                player.x = endX
                player.y = endY
                player.moving = false
                player.moveTimer = 0
                player.walkFrame = 0
            end
        else
            -- Check for input to start new movement
            local moveDir = nil
            local newGridX, newGridY = player.gridX, player.gridY
            
            if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
                moveDir = "up"
                newGridY = player.gridY - 1
            elseif love.keyboard.isDown("s") or love.keyboard.isDown("down") then
                moveDir = "down"
                newGridY = player.gridY + 1
            elseif love.keyboard.isDown("a") or love.keyboard.isDown("left") then
                moveDir = "left"
                newGridX = player.gridX - 1
            elseif love.keyboard.isDown("d") or love.keyboard.isDown("right") then
                moveDir = "right"
                newGridX = player.gridX + 1
            end
            
            if moveDir then
                player.direction = moveDir
                
                -- Check collision at target grid position (with swim ability)
                local targetPixelX = newGridX * 16 + 8
                local targetPixelY = newGridY * 16 + 8
                
                if not isColliding(targetPixelX, targetPixelY, playerAbilities.swim) then
                    player.targetGridX = newGridX
                    player.targetGridY = newGridY
                    player.moving = true
                    player.moveTimer = 0
                end
            end
        end
        
        -- Pokemon-style camera: always centered on player, smooth during movement
        camera.x = player.x - GAME_WIDTH / 2
        camera.y = player.y - GAME_HEIGHT / 2
        
        -- Clamp camera to map bounds
        if world.minX and world.maxX then
            local mapWidth = world.maxX - world.minX
            local mapHeight = world.maxY - world.minY
            
            -- Only clamp if map is larger than screen
            if mapWidth > GAME_WIDTH then
                camera.x = math.max(world.minX, math.min(camera.x, world.maxX - GAME_WIDTH))
            else
                camera.x = world.minX + (mapWidth - GAME_WIDTH) / 2
            end
            
            if mapHeight > GAME_HEIGHT then
                camera.y = math.max(world.minY, math.min(camera.y, world.maxY - GAME_HEIGHT))
            else
                camera.y = world.minY + (mapHeight - GAME_HEIGHT) / 2
            end
        end

        -- Check for nearby NPCs (only on current map)
        nearbyNPC = nil
        for _, npc in ipairs(npcs) do
            if npc.map == currentMap then
                local dist = math.sqrt((player.x - npc.x)^2 + (player.y - npc.y)^2)
                if dist < 40 then
                    nearbyNPC = npc
                    break
                end
            end
        end

        -- Check for nearby doors
        nearbyDoor = nil
        local playerTileX = player.gridX
        local playerTileY = player.gridY
        for _, door in ipairs(doors) do
            if door.map == currentMap and door.x == playerTileX and door.y == playerTileY then
                nearbyDoor = door
                break
            end
        end
    end
end

function isColliding(x, y, canSwim)
    -- Noclip cheat bypasses all collision
    if CheatConsole.isNoclipActive() then
        return false
    end
    
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
                            if tile.properties and tile.properties.collides then
                                -- If it's water and player can swim, allow passage
                                if canSwim and tile.properties.is_water then
                                    return false
                                end
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
                    if tile and tile.properties and tile.properties.collides then
                        -- If it's water and player can swim, allow passage
                        if canSwim and tile.properties.is_water then
                            return false
                        end
                        return true
                    end
                end
            end
        end
    end

    -- Collision if there's no tile at all (void)
    return not hasTile
end

function love.mousepressed(x, y, button)
    if button == 1 and gameState == "questTurnIn" then
        -- Convert screen coordinates to canvas coordinates
        local screenWidth, screenHeight = love.graphics.getDimensions()
        local offsetX = math.floor((screenWidth - GAME_WIDTH * SCALE) / 2 / SCALE) * SCALE
        local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE

        local canvasX = (x - offsetX) / SCALE
        local canvasY = (y - offsetY) / SCALE

        handleQuestTurnInClick(canvasX, canvasY)
    end
end

function love.textinput(text)
    CheatConsole.textInput(text)
end

function love.keypressed(key)
    -- Create game state object for cheat console
    local gameStateForCheats = {
        showToast = showToast,
        playerAbilities = playerAbilities,
        activeQuests = activeQuests,
        completedQuests = completedQuests,
        quests = quests,
        inventory = inventory,
        getAllItemIds = getAllItemIds,
        getItemFromRegistry = getItemFromRegistry,
        hasItem = hasItem
    }
    
    -- Handle cheat console keys
    if CheatConsole.keyPressed(key, gameStateForCheats) then
        return  -- Key was handled by console
    end
    
    -- Normal game controls
    if key == "space" or key == "e" then
        if gameState == "playing" and nearbyDoor then
            enterDoor(nearbyDoor)
        elseif gameState == "playing" and nearbyNPC then
            interactWithNPC(nearbyNPC)
        elseif gameState == "dialog" then
            handleDialogInput()
        end
    elseif key == "q" then
        if gameState == "playing" then
            gameState = "questLog"
        elseif gameState == "questLog" then
            gameState = "playing"
        end
    elseif key == "i" then
        if gameState == "playing" then
            gameState = "inventory"
        elseif gameState == "inventory" then
            gameState = "playing"
        end
    elseif key == "escape" then
        if gameState ~= "playing" then
            gameState = "playing"
            currentDialog = nil
        end
    end
end

function enterDoor(door)
    -- Load the new map
    currentMap = door.targetMap
    map = sti(mapPaths[currentMap])

    -- Recalculate map bounds for new map
    local layer = map.layers[1]
    if layer and layer.chunks then
        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge

        for _, chunk in ipairs(layer.chunks) do
            -- Chunk coordinates are in tiles, convert to pixels
            local chunkMinX = chunk.x * 16
            local chunkMinY = chunk.y * 16
            local chunkMaxX = (chunk.x + chunk.width) * 16
            local chunkMaxY = (chunk.y + chunk.height) * 16

            minX = math.min(minX, chunkMinX)
            minY = math.min(minY, chunkMinY)
            maxX = math.max(maxX, chunkMaxX)
            maxY = math.max(maxY, chunkMaxY)
        end

        world.minX = minX
        world.minY = minY
        world.maxX = maxX
        world.maxY = maxY
    else
        -- If no chunks, set no bounds (allow full movement)
        world.minX = nil
        world.minY = nil
        world.maxX = nil
        world.maxY = nil
    end

    -- Set player position to target door location
    player.gridX = door.targetX
    player.gridY = door.targetY
    player.x = door.targetX * 16 + 8
    player.y = door.targetY * 16 + 8
    player.moving = false

    -- Update camera to follow player
    camera.x = math.floor(player.x - GAME_WIDTH / 2)
    camera.y = math.floor(player.y - GAME_HEIGHT / 2)

    -- Clamp camera to map bounds
    if world.minX and world.maxX then
        local mapWidth = world.maxX - world.minX
        local mapHeight = world.maxY - world.minY

        if mapWidth > GAME_WIDTH then
            camera.x = math.max(world.minX, math.min(camera.x, world.maxX - GAME_WIDTH))
        else
            camera.x = world.minX + (mapWidth - GAME_WIDTH) / 2
        end

        if mapHeight > GAME_HEIGHT then
            camera.y = math.max(world.minY, math.min(camera.y, world.maxY - GAME_HEIGHT))
        else
            camera.y = world.minY + (mapHeight - GAME_HEIGHT) / 2
        end
    end
end

function interactWithNPC(npc)
    if npc.isQuestGiver then
        local quest = quests[npc.questId]
        if not quest.active and not quest.completed then
            -- Offer quest
            currentDialog = {
                type = "questOffer",
                npc = npc,
                quest = quest
            }
            gameState = "dialog"
        elseif quest.active and hasItem(quest.requiredItem) then
            -- Turn in quest - show inventory selection UI
            currentDialog = {
                type = "questTurnIn",
                npc = npc,
                quest = quest
            }
            gameState = "questTurnIn"
        else
            -- Quest already active (but no item yet) or completed
            currentDialog = {
                type = "generic",
                npc = npc,
                text = quest.active and (quest.reminderText or "Come back when you have the item!") or "Thanks again!"
            }
            gameState = "dialog"
        end
    elseif npc.givesItem then
        -- Check if the required quest is active
        local requiredQuest = npc.requiresQuest and quests[npc.requiresQuest]
        local questActive = requiredQuest and requiredQuest.active

        if not questActive then
            -- Quest not active, show generic dialog
            currentDialog = {
                type = "generic",
                npc = npc,
                text = npc.noQuestText or "Hello there!"
            }
            gameState = "dialog"
        elseif not hasItem(npc.givesItem) then
            -- Quest active and don't have item, give it
            currentDialog = {
                type = "itemGive",
                npc = npc,
                item = npc.givesItem
            }
            gameState = "dialog"
        else
            -- Already have the item
            currentDialog = {
                type = "generic",
                npc = npc,
                text = "I already gave you the item!"
            }
            gameState = "dialog"
        end
    elseif npc.givesAbility then
        -- Check if the required quest is active
        local requiredQuest = npc.requiresQuest and quests[npc.requiresQuest]
        local questActive = requiredQuest and requiredQuest.active

        if not questActive then
            -- Quest not active, show generic dialog
            currentDialog = {
                type = "generic",
                npc = npc,
                text = npc.noQuestText or "Hello there!"
            }
            gameState = "dialog"
        elseif not playerAbilities[npc.givesAbility] then
            -- Quest active and don't have ability, give it
            currentDialog = {
                type = "abilityGive",
                npc = npc,
                ability = npc.givesAbility,
                quest = requiredQuest
            }
            gameState = "dialog"
        else
            -- Already have the ability
            currentDialog = {
                type = "generic",
                npc = npc,
                text = "You already learned that ability!"
            }
            gameState = "dialog"
        end
    end
end

function handleDialogInput()
    if currentDialog.type == "questOffer" then
        -- Accept quest
        currentDialog.quest.active = true
        table.insert(activeQuests, currentDialog.quest.id)
        showToast("Quest Accepted: " .. currentDialog.quest.name, {1, 1, 0})
        gameState = "playing"
        currentDialog = nil
    elseif currentDialog.type == "questTurnIn" then
        -- Complete quest
        removeItem(currentDialog.quest.requiredItem)
        currentDialog.quest.active = false
        currentDialog.quest.completed = true
        table.remove(activeQuests, indexOf(activeQuests, currentDialog.quest.id))
        table.insert(completedQuests, currentDialog.quest.id)
        showToast("Quest Complete: " .. currentDialog.quest.name, {0, 1, 0})
        gameState = "playing"
        currentDialog = nil
    elseif currentDialog.type == "itemGive" then
        -- Receive item
        table.insert(inventory, currentDialog.item)
        -- Get item name from registry
        local itemData = itemRegistry[currentDialog.item]
        local itemName = itemData and itemData.name or currentDialog.item
        showToast("Received: " .. itemName, {0.7, 0.5, 0.9})
        gameState = "playing"
        currentDialog = nil
    elseif currentDialog.type == "abilityGive" then
        -- Learn ability
        playerAbilities[currentDialog.ability] = true
        
        -- Complete the quest
        local quest = currentDialog.quest
        quest.active = false
        quest.completed = true
        table.remove(activeQuests, indexOf(activeQuests, quest.id))
        table.insert(completedQuests, quest.id)
        
        -- Get ability name for toast
        local abilityNames = {
            swim = "Swimming"
        }
        showToast("Learned: " .. (abilityNames[currentDialog.ability] or currentDialog.ability) .. "!", {0.3, 0.8, 1.0})
        showToast("Quest Complete: " .. quest.name, {0, 1, 0})
        gameState = "playing"
        currentDialog = nil
    else
        gameState = "playing"
        currentDialog = nil
    end
end

function hasItem(itemId)
    for _, item in ipairs(inventory) do
        if item == itemId then
            return true
        end
    end
    return false
end

-- Get item info from registry by ID or alias
function getItemFromRegistry(nameOrAlias)
    -- First check if it's a direct item ID
    if itemRegistry[nameOrAlias] then
        return itemRegistry[nameOrAlias]
    end
    
    -- Then check aliases
    for itemId, itemData in pairs(itemRegistry) do
        for _, alias in ipairs(itemData.aliases) do
            if alias == nameOrAlias then
                return itemData
            end
        end
    end
    
    return nil
end

-- Get all item IDs from registry
function getAllItemIds()
    local ids = {}
    for itemId, _ in pairs(itemRegistry) do
        table.insert(ids, itemId)
    end
    return ids
end

function removeItem(itemId)
    for i, item in ipairs(inventory) do
        if item == itemId then
            table.remove(inventory, i)
            return
        end
    end
end

function indexOf(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
    return nil
end

function showToast(message, color)
    table.insert(toasts, {
        message = message,
        timer = TOAST_DURATION,
        color = color or {1, 1, 1}
    })
end

function handleQuestTurnInClick(x, y)
    if not currentDialog or currentDialog.type ~= "questTurnIn" then
        return
    end

    local quest = currentDialog.quest

    -- Calculate item slot positions (must match drawQuestTurnIn)
    local boxX = GAME_WIDTH / 2 - 75
    local boxY = GAME_HEIGHT - 90
    local slotSize = 16
    local padding = 3
    local startY = boxY + 30

    for i, itemId in ipairs(inventory) do
        local slotX = boxX + 6
        local slotY = startY + (i - 1) * (slotSize + padding)

        -- Check if click is within this item slot
        if x >= slotX and x <= slotX + slotSize and y >= slotY and y <= slotY + slotSize then
            if itemId == quest.requiredItem then
                -- Correct item clicked! Remove item and show reward dialog
                removeItem(quest.requiredItem)
                quest.active = false
                quest.completed = true
                table.remove(activeQuests, indexOf(activeQuests, quest.id))
                table.insert(completedQuests, quest.id)
                showToast("Quest Complete: " .. quest.name, {0, 1, 0})

                -- Show reward dialog
                currentDialog = {
                    type = "generic",
                    npc = currentDialog.npc,
                    text = quest.reward
                }
                gameState = "dialog"
            else
                -- Wrong item
                showToast("That's not the right item!", {1, 0.5, 0})
            end
            return
        end
    end
end

function drawToasts()
    local y = 14 -- Start below the top bar (12px height + 2px padding)
    for i, toast in ipairs(toasts) do
        -- Calculate fade-out alpha based on remaining time
        local alpha = 1
        if toast.timer < 0.5 then
            alpha = toast.timer / 0.5
        end

        -- Measure text width
        local textWidth = font:getWidth(toast.message)
        local boxW = textWidth + 8
        local boxH = 12
        local boxX = GAME_WIDTH - boxW - 2 -- Align to right with 2px padding

        -- Background
        love.graphics.setColor(0.05, 0.05, 0.1, 0.9 * alpha)
        love.graphics.rectangle("fill", boxX, y, boxW, boxH)

        -- Border
        love.graphics.setColor(toast.color[1], toast.color[2], toast.color[3], alpha)
        love.graphics.rectangle("line", boxX, y, boxW, boxH)

        -- Text
        love.graphics.setColor(toast.color[1], toast.color[2], toast.color[3], alpha)
        love.graphics.print(toast.message, boxX + 4, y - 2)

        y = y + boxH + 2
    end
end

function love.draw()
    -- Draw to canvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.1, 0.1, 0.1)

    if gameState == "playing" or gameState == "dialog" then
        -- Draw world (manual camera offset, no translate)
        local camX = camera.x
        local camY = camera.y

        -- Draw the Tiled map
        love.graphics.setColor(1, 1, 1)
        map:draw(-camX, -camY)

        -- Draw NPCs (only on current map)
        for _, npc in ipairs(npcs) do
            if npc.map == currentMap then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(npcSprite, npc.x - npc.size/2 - camX, npc.y - npc.size/2 - camY)

                -- Draw quest indicator
                if npc.isQuestGiver then
                    local quest = quests[npc.questId]
                    if not quest.active and not quest.completed then
                        love.graphics.setColor(1, 1, 0)
                        love.graphics.circle("fill", npc.x - camX, npc.y - 10 - camY, 2)
                    elseif quest.active and hasItem(quest.requiredItem) then
                        love.graphics.setColor(0, 1, 0)
                        love.graphics.circle("fill", npc.x - camX, npc.y - 10 - camY, 2)
                    end
                end
            end
        end

        -- Draw player with appropriate sprite
        love.graphics.setColor(1, 1, 1)
        local currentSprite = playerSprite
        if player.moving then
            currentSprite = (player.walkFrame == 0) and playerWalk0 or playerWalk1
        end
        love.graphics.draw(currentSprite, player.x - player.size/2 - camX, player.y - player.size/2 - camY)

        -- Draw interaction prompt
        if nearbyDoor and gameState == "playing" then
            local doorText = nearbyDoor.indoor and "[E] Exit" or "[E] Enter"
            drawTextBox(GAME_WIDTH/2 - 45, GAME_HEIGHT - 14, 90, 12, doorText, {1, 1, 1}, true)
        elseif nearbyNPC and gameState == "playing" then
            drawTextBox(GAME_WIDTH/2 - 45, GAME_HEIGHT - 14, 90, 12, "[E] Talk", {1, 1, 1}, true)
        end

        -- Draw dialog
        if gameState == "dialog" and currentDialog then
            drawDialog()
        end

        -- Draw tile grid overlay (cheat)
        CheatConsole.drawGrid(camX, camY, GAME_WIDTH, GAME_HEIGHT)

        -- Draw UI hints
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, 12)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Q: Quest log  I: Inventory", 2, -1)
        
        -- Draw cheat indicators
        CheatConsole.drawIndicators(GAME_WIDTH, font, playerAbilities)

    elseif gameState == "questLog" then
        drawQuestLog()
    elseif gameState == "inventory" then
        drawInventory()
    elseif gameState == "questTurnIn" then
        drawQuestTurnIn()
    end

    -- Draw cheat console (overlay on top of everything)
    CheatConsole.draw(GAME_WIDTH, GAME_HEIGHT, font)

    -- Draw toasts (always on top)
    drawToasts()

    -- Draw canvas to screen (centered)
    love.graphics.setCanvas()

    -- Clear screen with black (for letterboxing in fullscreen)
    love.graphics.clear(0, 0, 0)

    love.graphics.setColor(1, 1, 1)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    -- Round offset to multiples of SCALE to ensure pixel-perfect alignment
    local offsetX = math.floor((screenWidth - GAME_WIDTH * SCALE) / 2 / SCALE) * SCALE
    local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
    love.graphics.draw(canvas, offsetX, offsetY, 0, SCALE, SCALE)
end

-- Helper function to draw WoW-style decorative borders
function drawFancyBorder(x, y, w, h, color)
    color = color or {0.8, 0.6, 0.2}
    local borderThick = 2

    -- Outer border (gold)
    love.graphics.setColor(color)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.rectangle("line", x-1, y-1, w+2, h+2)

    -- Inner shadow
    love.graphics.setColor(0.1, 0.1, 0.1, 0.5)
    love.graphics.rectangle("line", x+1, y+1, w-2, h-2)

    -- Corner decorations
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x-1, y-1, 3, 3)
    love.graphics.rectangle("fill", x+w-2, y-1, 3, 3)
    love.graphics.rectangle("fill", x-1, y+h-2, 3, 3)
    love.graphics.rectangle("fill", x+w-2, y+h-2, 3, 3)
end

function drawTextBox(x, y, w, h, text, color, centered)
    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 0.95)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Border
    love.graphics.setColor(0.3, 0.25, 0.15)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setColor(0.6, 0.5, 0.3)
    love.graphics.rectangle("line", x-1, y-1, w+2, h+2)

    -- Text
    love.graphics.setColor(color)
    if centered then
        love.graphics.printf(text, x, y-2, w, "center")
    else
        love.graphics.print(text, x+2, y-2)
    end
end

function drawDialog()
    local boxX, boxY = 20, GAME_HEIGHT - 75
    local boxW, boxH = GAME_WIDTH - 40, 70

    -- Main dialog background
    love.graphics.setColor(0.05, 0.05, 0.1, 0.95)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)

    -- Fancy border
    drawFancyBorder(boxX, boxY, boxW, boxH, {0.7, 0.5, 0.2})

    -- Title bar
    love.graphics.setColor(0.15, 0.1, 0.05, 0.9)
    love.graphics.rectangle("fill", boxX+2, boxY+2, boxW-4, 12)
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.print(currentDialog.npc.name, boxX+4, boxY)

    -- Dialog text
    local text = ""
    local buttonText = ""

    if currentDialog.type == "questOffer" then
        text = currentDialog.quest.name .. "\n" .. currentDialog.quest.description
        buttonText = "[E] Accept"
    elseif currentDialog.type == "questTurnIn" then
        text = currentDialog.quest.reward
        buttonText = "[E] Complete"
    elseif currentDialog.type == "itemGive" then
        text = currentDialog.npc.itemGiveText or "Here, take this!"
        buttonText = "[E] Receive"
    elseif currentDialog.type == "abilityGive" then
        text = currentDialog.npc.abilityGiveText or "You learned a new ability!"
        buttonText = "[E] Learn"
    else
        text = currentDialog.text
        buttonText = "[E] Close"
    end

    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.printf(text, boxX+4, boxY+12, boxW-8, "left")

    -- Button at bottom
    local btnW = 80
    local btnH = 14
    local btnX = boxX + boxW/2 - btnW/2
    local btnY = boxY + boxH - btnH - 3

    love.graphics.setColor(0.2, 0.15, 0.1)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)
    love.graphics.setColor(0.8, 0.6, 0.2)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH)
    love.graphics.rectangle("line", btnX-1, btnY-1, btnW+2, btnH+2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(buttonText, btnX, btnY-1, btnW, "center")
end

function drawQuestLog()
    local boxX, boxY = 10, 10
    local boxW, boxH = GAME_WIDTH - 20, GAME_HEIGHT - 20

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 0.98)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)

    -- Fancy border
    drawFancyBorder(boxX, boxY, boxW, boxH, {0.7, 0.5, 0.2})

    -- Title bar
    love.graphics.setColor(0.15, 0.1, 0.05, 0.95)
    love.graphics.rectangle("fill", boxX+2, boxY+2, boxW-4, 12)
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.printf("QUEST LOG", boxX+2, boxY, boxW-4, "center")

    -- Content area
    local y = boxY + 18

    -- Active quests header
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.print("Active:", boxX+4, y)
    y = y + 12

    if #activeQuests == 0 then
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print("None", boxX+6, y)
        y = y + 12
    else
        for _, questId in ipairs(activeQuests) do
            local quest = quests[questId]
            love.graphics.setColor(1, 0.9, 0.3)
            love.graphics.print("- " .. quest.name, boxX+6, y)
            y = y + 10
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf(quest.description, boxX+8, y, boxW-12, "left")
            y = y + 24
        end
    end

    y = y + 4

    -- Completed quests header
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.print("Completed:", boxX+4, y)
    y = y + 12

    if #completedQuests == 0 then
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print("None", boxX+6, y)
    else
        for _, questId in ipairs(completedQuests) do
            local quest = quests[questId]
            love.graphics.setColor(0.3, 0.9, 0.3)
            love.graphics.print("- " .. quest.name, boxX+6, y)
            y = y + 12
        end
    end

    -- Footer
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("[Q] Close", boxX+4, boxY+boxH-15)
end

function drawQuestTurnIn()
    if not currentDialog or currentDialog.type ~= "questTurnIn" then
        return
    end

    -- Draw the game world in the background
    local camX = camera.x
    local camY = camera.y

    -- Draw the Tiled map
    love.graphics.setColor(1, 1, 1)
    map:draw(-camX, -camY)

    -- Draw NPCs (only on current map)
    for _, npc in ipairs(npcs) do
        if npc.map == currentMap then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(npcSprite, npc.x - npc.size/2 - camX, npc.y - npc.size/2 - camY)
        end
    end

    -- Draw player
    love.graphics.setColor(1, 1, 1)
    local currentSprite = playerSprite
    if player.isWalking then
        currentSprite = (player.walkFrame == 0) and playerWalk0 or playerWalk1
    end
    love.graphics.draw(currentSprite, player.x - player.size/2 - camX, player.y - player.size/2 - camY)

    -- Draw dialog box
    local quest = currentDialog.quest
    local boxX = GAME_WIDTH / 2 - 75
    local boxY = GAME_HEIGHT - 90
    local boxW = 150
    local boxH = 85

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 0.98)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)

    -- Fancy border
    drawFancyBorder(boxX, boxY, boxW, boxH, {0.7, 0.5, 0.2})

    -- Title bar
    love.graphics.setColor(0.15, 0.1, 0.05, 0.9)
    love.graphics.rectangle("fill", boxX+2, boxY+2, boxW-4, 12)
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.printf("Turn In Quest", boxX, boxY, boxW, "center")

    -- Instruction
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Click the item:", boxX + 4, boxY + 14)

    -- Draw inventory items
    local slotSize = 16
    local padding = 3
    local startY = boxY + 30 -- More padding between instruction and items

    for i, itemId in ipairs(inventory) do
        local slotX = boxX + 6
        local slotY = startY + (i - 1) * (slotSize + padding)

        -- Slot background
        love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize)

        -- Slot border
        love.graphics.setColor(0.3, 0.25, 0.2)
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize)

        -- Item icon (simple colored square)
        love.graphics.setColor(0.7, 0.5, 0.9)
        love.graphics.rectangle("fill", slotX + 2, slotY + 2, slotSize - 4, slotSize - 4)

        -- Item name from registry
        local itemData = itemRegistry[itemId]
        local itemName = itemData and itemData.name or itemId
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(itemName, slotX + slotSize + 4, slotY + 2)
    end

    -- Footer hint
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("[ESC] Cancel", boxX + 4, boxY + boxH - 17)
end

function drawCheatPrompt()
    local boxX, boxY = 10, GAME_HEIGHT - 92
    local boxW, boxH = GAME_WIDTH - 20, 87

    -- Background with slight transparency
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)

    -- Border (console green style)
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.print("CHEAT CONSOLE", boxX+4, boxY+4)
    
    -- Hint
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("Type 'help' for available cheats", boxX+4, boxY+16)

    -- History (last 3 commands)
    local y = boxY + 30
    love.graphics.setColor(0.4, 0.8, 0.4)
    for i = math.min(3, #cheats.cheatHistory), 1, -1 do
        love.graphics.print("> " .. cheats.cheatHistory[i], boxX+4, y)
        y = y + 10
    end

    -- Input prompt
    y = boxY + boxH - 24
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.print("> ", boxX+4, y)
    
    -- Input text
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(cheats.cheatInput, boxX+16, y)
    
    -- Cursor (blinking)
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local cursorX = boxX + 16 + font:getWidth(cheats.cheatInput)
        love.graphics.rectangle("fill", cursorX, y, 6, 10)
    end
    
    -- Instructions (inside the box, with padding)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("[Enter] Submit  [Up/Down] History  [Esc/~] Close", boxX+4, boxY+boxH-14)
end

function drawInventory()
    local boxX, boxY = 10, 10
    local boxW, boxH = GAME_WIDTH - 20, GAME_HEIGHT - 20

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 0.98)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)

    -- Fancy border
    drawFancyBorder(boxX, boxY, boxW, boxH, {0.5, 0.3, 0.6})

    -- Title bar
    love.graphics.setColor(0.1, 0.05, 0.15, 0.95)
    love.graphics.rectangle("fill", boxX+2, boxY+2, boxW-4, 12)
    love.graphics.setColor(0.8, 0.6, 0.9)
    love.graphics.printf("INVENTORY", boxX+2, boxY, boxW-4, "center")

    -- Content area with item slots
    local slotSize = 20
    local padding = 4
    local slotsPerRow = 12
    local startY = boxY + 16

    -- Draw item slots
    for i = 0, 23 do
        local row = math.floor(i / slotsPerRow)
        local col = i % slotsPerRow
        local slotX = boxX + 4 + col * (slotSize + padding)
        local slotY = startY + row * (slotSize + padding)

        -- Slot background
        love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize)

        -- Slot border
        love.graphics.setColor(0.3, 0.25, 0.2)
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize)

        -- Draw item if present
        if inventory[i+1] then
            love.graphics.setColor(0.7, 0.5, 0.9)
            love.graphics.rectangle("fill", slotX+2, slotY+2, slotSize-4, slotSize-4)
            love.graphics.setColor(0.9, 0.7, 1)
            love.graphics.rectangle("line", slotX+2, slotY+2, slotSize-4, slotSize-4)
        end
    end

    -- Item list below slots
    local listY = startY + 60
    love.graphics.setColor(0.8, 0.6, 0.9)
    love.graphics.print("Items:", boxX+4, listY)
    listY = listY + 12

    if #inventory == 0 then
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print("Empty", boxX+6, listY)
    else
        for _, itemId in ipairs(inventory) do
            local itemData = itemRegistry[itemId]
            local itemName = itemData and itemData.name or itemId
            love.graphics.setColor(0.7, 0.5, 0.9)
            love.graphics.print("- " .. itemName, boxX+6, listY)
            listY = listY + 12
        end
    end

    -- Footer
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("[I] Close", boxX+4, boxY+boxH-15)
end
