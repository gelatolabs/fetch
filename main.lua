-- Libraries
local sti = require "sti"
local questData = require "quests"
local CheatConsole = require "cheat_console"
local AbilitySystem = require "ability_system"

-- Game constants
local GAME_WIDTH = 320
local GAME_HEIGHT = 240
local SCALE

-- Graphics resources
local canvas
local font
local titleFont

-- Sprites
local playerTileset
local playerQuads = {
    regular = {},
    boat = {},
    swimming = {}
}
local npcSprite

-- Game state
-- mainMenu, settings, playing, dialog, questLog, inventory, questTurnIn, shop
local gameState = "mainMenu"

-- Settings
local volume = 1.0
local draggingSlider = false

-- Input tracking for movement priority
local heldKeys = {}

-- Player (Pokemon-style grid movement)
-- Initial spawn position (will be validated and adjusted if on collision tile)
local player = {
    x = -10 * 16 + 8,  -- Current pixel position (grid -10, -10 in upper-left grassy area)
    y = -10 * 16 + 8,
    gridX = -10, -- Grid position (in tiles)
    gridY = -10,
    size = 16,
    direction = "down",
    facing = "right",  -- Add this line: remembers last horizontal direction
    moving = false,
    moveTimer = 0,
    moveDuration = 0.15,  -- Time to move one tile (in seconds)
    walkFrame = 0,  -- 0 or 1 for animation
    wasOnWater = false,  -- Track if player was on water last frame
    jumping = false,  -- Track if player is jumping
    jumpHeight = 0,  -- Current jump height offset for rendering
    queuedDirection = nil  -- Queued movement direction
}

-- Camera (Pokemon-style: always centered on player)
local camera = {
    x = 0,
    y = 0
}

-- World map
local map
local world = {
    tileSize = 16
}

-- NPCs
local npcs = {}

-- Quests
local quests = {}
local activeQuests = {}
local completedQuests = {}

-- Inventory
local inventory = {}

-- Shop inventory
local shopInventory = {
    {itemId = "item_rubber_duck", price = 10, description = "A cheerful rubber duck. Perfect for bath time or just keeping you company!"},
    {itemId = "item_labubu", price = 10000, description = "An extremely rare and adorable Labubu collectible. Highly sought after by collectors!"}
}

-- Item registry (single source of truth for all items)
local itemRegistry = {
    item_cat = {id = "item_cat", name = "Fluffy Cat", aliases = {"cat"}},
    item_book = {id = "item_book", name = "Ancient Tome", aliases = {"book"}},
    item_package = {id = "item_package", name = "Sealed Package", aliases = {"package"}},
    item_floaties = {id = "item_floaties", name = "Swimming Floaties", aliases = {"floaties", "floaty"}},
    item_wood = {id = "item_wood", name = "Wooden Planks", aliases = {"wood", "planks"}},
    item_shoes = {id = "item_shoes", name = "Jumping Shoes", aliases = {"shoes", "boots", "jumping shoes"}},
    item_rubber_duck = {id = "item_rubber_duck", name = "Rubber Duck", aliases = {"duck", "rubber duck"}},
    item_labubu = {id = "item_labubu", name = "Labubu", aliases = {"labubu"}}
}

-- Ability System
local abilityManager = AbilitySystem.PlayerAbilityManager.new()

-- Local references for convenience
local AbilityType = AbilitySystem.AbilityType
local EffectType = AbilitySystem.EffectType

-- Register abilities
abilityManager:registerAbility({
    id = "swim",
    name = "Swim",
    aliases = {"swim", "swimming"},
    type = AbilityType.PASSIVE,
    effects = {EffectType.WATER_TRAVERSAL},
    description = "Allows you to swim across water tiles freely",
    color = {0.3, 0.8, 1.0},
    onAcquire = function(context, ability)
        if context and context.showToast then
            context.showToast("You can now swim across water!", {0.3, 0.8, 1.0})
        end
    end
})

abilityManager:registerAbility({
    id = "boat",
    name = "Boat",
    aliases = {"boat", "raft"},
    type = AbilityType.CONSUMABLE,
    effects = {EffectType.WATER_TRAVERSAL},
    description = "A makeshift boat that breaks after crossing water 3 times",
    maxUses = 3,
    consumeOnUse = true,
    color = {0.7, 0.7, 1.0},
    onAcquire = function(context, ability)
        if context and context.showToast then
            context.showToast("Boat has " .. ability.maxUses .. " crossings", {0.7, 0.7, 1.0})
        end
    end,
    onUse = function(context, ability)
        if context and context.showToast then
            if ability.currentUses > 0 then
                context.showToast("Boat crossings remaining: " .. ability.currentUses, {0.7, 0.7, 1.0})
            end
        end
    end,
    onExpire = function(context)
        if context and context.showToast then
            context.showToast("Your boat broke apart!", {1, 0.5, 0.2})
        end
    end
})

abilityManager:registerAbility({
    id = "jump",
    name = "Jump",
    aliases = {"jump", "jumping", "leap"},
    type = AbilityType.PASSIVE,
    effects = {EffectType.JUMP},
    description = "Allows you to jump over low obstacles (height ≤ 0.5)",
    color = {1.0, 0.9, 0.3},
    onAcquire = function(context, ability)
        if context and context.showToast then
            context.showToast("You can now jump over low obstacles!", {1.0, 0.9, 0.3})
        end
    end
})

-- Legacy compatibility (will be removed after full migration)
local playerAbilities = {}
local boatUses = 0
local MAX_BOAT_USES = 3

-- Player gold
local playerGold = 0

-- UI state
local nearbyNPC = nil
local currentDialog = nil
local dialogPages = {}  -- Array of dialog text pages
local currentDialogPage = 1  -- Current page index
local nearbyDoor = nil
local mouseX = 0
local mouseY = 0
local selectedShopItem = nil
local winScreenTimer = 0
local introShown = false

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

    -- Load title font (twice as large)
    titleFont = love.graphics.newFont("BitPotionExt.ttf", 32)
    titleFont:setFilter("nearest", "nearest")

    -- Load sprites
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
    playerQuads.regular.left = playerQuads.regular.down
    playerQuads.regular.right = playerQuads.regular.down

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
    playerQuads.boat.left = playerQuads.boat.down
    playerQuads.boat.right = playerQuads.boat.down

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
    playerQuads.swimming.left = playerQuads.swimming.down
    playerQuads.swimming.right = playerQuads.swimming.down
    
    npcSprite = love.graphics.newImage("sprites/npc.png")

    -- Load Tiled map
    map = sti(mapPaths[currentMap])
    calculateMapBounds()

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

-- Helper function to calculate map bounds from chunks
function calculateMapBounds()
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
    else
        -- If no chunks, set no bounds (allow full movement)
        world.minX = nil
        world.minY = nil
        world.maxX = nil
        world.maxY = nil
    end
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

-- Helper function to check if a position is water
local function isWaterTile(x, y)
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

-- Helper function to check if an NPC is at a position
local function isNPCAt(x, y)
    for _, npc in ipairs(npcs) do
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

-- Helper function to check if a tile is a jumpable obstacle
local function isJumpableObstacle(x, y)
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

function areOppositeDirections(dir1, dir2)
    if (dir1 == "up" and dir2 == "down") or (dir1 == "down" and dir2 == "up") then
        return true
    end
    if (dir1 == "left" and dir2 == "right") or (dir1 == "right" and dir2 == "left") then
        return true
    end
    return false
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

    -- Handle win screen timer
    if gameState == "winScreen" then
        winScreenTimer = winScreenTimer + dt
        if winScreenTimer >= 5 then  -- 5 seconds
            love.event.quit()
        end
        return
    end

    if gameState == "playing" and not CheatConsole.isOpen() then
        -- Pokemon-style grid-based movement
        if player.moving then
            -- Check for input to queue movement
            for i = #heldKeys, 1, -1 do
                local key = heldKeys[i]
                if love.keyboard.isDown(key) then
                    local queueDir = nil
                    if key == "w" or key == "up" then
                        queueDir = "up"
                    elseif key == "s" or key == "down" then
                        queueDir = "down"
                    elseif key == "a" or key == "left" then
                        queueDir = "left"
                    elseif key == "d" or key == "right" then
                        queueDir = "right"
                    end

                    -- Queue if not opposite to current direction and not the same direction
                    if queueDir and not areOppositeDirections(player.direction, queueDir) and queueDir ~= player.direction then
                        player.queuedDirection = queueDir
                        break
                    end
                end
            end

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
            
            -- Calculate jump arc if jumping
            if player.jumping then
                -- Parabolic arc: height peaks at midpoint
                local jumpProgress = progress
                player.jumpHeight = math.sin(jumpProgress * math.pi) * 12  -- Peak height of 12 pixels
            else
                player.jumpHeight = 0
            end
            
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
                player.jumping = false
                player.jumpHeight = 0
                player.moveTimer = 0
                player.walkFrame = 0

                -- Check if player transitioned from water to land (boat use)
                -- Only check this if not jumping (jumping over water shouldn't consume boat)
                local isOnWater = isWaterTile(endX, endY)
                if not player.jumping then
                    if player.wasOnWater and not isOnWater then
                        -- Transitioning from water to land - consume boat use
                        local boatAbility = abilityManager:getAbility("boat")
                        if boatAbility and not abilityManager:hasAbility("swim") then
                            -- Use boat ability (consumes a use)
                            local context = {showToast = showToast}
                            boatAbility:use(context)

                            -- Remove ability if expired
                            if boatAbility.currentUses <= 0 then
                                abilityManager:removeAbility("boat")
                            end
                        end
                    end

                    -- Update water state for next frame (only when not jumping)
                    player.wasOnWater = isOnWater
                end

                -- Check if there's a queued movement to execute
                if player.queuedDirection then
                    local queuedDir = player.queuedDirection
                    player.queuedDirection = nil

                    -- Try to execute queued movement
                    local newGridX, newGridY = player.gridX, player.gridY

                    if queuedDir == "up" then
                        newGridY = player.gridY - 1
                    elseif queuedDir == "down" then
                        newGridY = player.gridY + 1
                    elseif queuedDir == "left" then
                        player.facing = "left"
                        newGridX = player.gridX - 1
                    elseif queuedDir == "right" then
                        player.facing = "right"
                        newGridX = player.gridX + 1
                    end

                    -- Check collision for queued movement
                    local targetPixelX = newGridX * 16 + 8
                    local targetPixelY = newGridY * 16 + 8

                    local canCrossWater = abilityManager:hasEffect(EffectType.WATER_TRAVERSAL)
                    local canJump = abilityManager:hasEffect(EffectType.JUMP)
                    local tileBlocked = isColliding(targetPixelX, targetPixelY, canCrossWater)
                    local npcBlocked = isNPCAt(targetPixelX, targetPixelY)

                    -- Check if we should jump over an obstacle
                    if tileBlocked and canJump and isJumpableObstacle(targetPixelX, targetPixelY) then
                        -- Try to jump OVER the obstacle (2 tiles total)
                        local jumpLandingX = newGridX + (newGridX - player.gridX)
                        local jumpLandingY = newGridY + (newGridY - player.gridY)
                        local landingPixelX = jumpLandingX * 16 + 8
                        local landingPixelY = jumpLandingY * 16 + 8

                        -- Check if landing spot is valid
                        local landingBlocked = isColliding(landingPixelX, landingPixelY, canCrossWater)
                        local landingNpcBlocked = isNPCAt(landingPixelX, landingPixelY)

                        if not landingBlocked and not landingNpcBlocked then
                            -- Perform jump over the obstacle
                            player.direction = queuedDir
                            player.targetGridX = jumpLandingX
                            player.targetGridY = jumpLandingY
                            player.moving = true
                            player.jumping = true
                            player.moveTimer = 0
                            player.moveDuration = 0.25
                        end
                    elseif not tileBlocked and not npcBlocked then
                        -- Normal movement
                        player.direction = queuedDir
                        player.targetGridX = newGridX
                        player.targetGridY = newGridY
                        player.moving = true
                        player.jumping = false
                        player.moveTimer = 0
                        player.moveDuration = 0.15
                    end
                end
            end
        else
            -- Check for input to start new movement
            -- Prioritize most recently pressed key (last in heldKeys)
            local moveDir = nil
            local newGridX, newGridY = player.gridX, player.gridY

            -- Check held keys in reverse order (most recent first)
            for i = #heldKeys, 1, -1 do
                local key = heldKeys[i]
                if love.keyboard.isDown(key) then
                    if key == "w" or key == "up" then
                        moveDir = "up"
                        newGridY = player.gridY - 1
                        break
                    elseif key == "s" or key == "down" then
                        moveDir = "down"
                        newGridY = player.gridY + 1
                        break
                    elseif key == "a" or key == "left" then
                        moveDir = "left"
                        player.facing = "left"
                        newGridX = player.gridX - 1
                        break
                    elseif key == "d" or key == "right" then
                        moveDir = "right"
                        player.facing = "right"
                        newGridX = player.gridX + 1
                        break
                    end
                end
            end
            
            if moveDir then
                player.direction = moveDir
                
                -- Check collision at target grid position (with abilities)
                local targetPixelX = newGridX * 16 + 8
                local targetPixelY = newGridY * 16 + 8
                
                local canCrossWater = abilityManager:hasEffect(EffectType.WATER_TRAVERSAL)
                local canJump = abilityManager:hasEffect(EffectType.JUMP)
                local tileBlocked = isColliding(targetPixelX, targetPixelY, canCrossWater)
                local npcBlocked = isNPCAt(targetPixelX, targetPixelY)
                
                -- Check if we should jump over an obstacle
                if tileBlocked and canJump and isJumpableObstacle(targetPixelX, targetPixelY) then
                    -- Try to jump OVER the obstacle (2 tiles total)
                    local jumpLandingX = newGridX + (newGridX - player.gridX)
                    local jumpLandingY = newGridY + (newGridY - player.gridY)
                    local landingPixelX = jumpLandingX * 16 + 8
                    local landingPixelY = jumpLandingY * 16 + 8
                    
                    -- Check if landing spot is valid (not blocked and not an NPC there)
                    local landingBlocked = isColliding(landingPixelX, landingPixelY, canCrossWater)
                    local landingNpcBlocked = isNPCAt(landingPixelX, landingPixelY)
                    
                    if not landingBlocked and not landingNpcBlocked then
                        -- Perform jump over the obstacle
                        player.targetGridX = jumpLandingX
                        player.targetGridY = jumpLandingY
                        player.moving = true
                        player.jumping = true
                        player.moveTimer = 0
                        player.moveDuration = 0.25  -- Jumps take a bit longer
                    end
                elseif not tileBlocked and not npcBlocked then
                    -- Normal movement
                    player.targetGridX = newGridX
                    player.targetGridY = newGridY
                    player.moving = true
                    player.jumping = false
                    player.moveTimer = 0
                    player.moveDuration = 0.15  -- Normal walk speed
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

-- Helper function to get tile height at a position
local function getTileHeight(x, y)
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

function love.mousemoved(x, y, dx, dy)
    -- Show mouse cursor when mouse is moved
    love.mouse.setVisible(true)

    -- Track mouse position
    mouseX = x
    mouseY = y

    -- Handle slider dragging
    if draggingSlider and gameState == "settings" then
        -- Convert screen coordinates to canvas coordinates
        local screenWidth, screenHeight = love.graphics.getDimensions()
        local offsetX = math.floor((screenWidth - GAME_WIDTH * SCALE) / 2 / SCALE) * SCALE
        local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
        local canvasX = (x - offsetX) / SCALE

        local sliderX = GAME_WIDTH / 2 - 50
        local sliderWidth = 100

        volume = math.max(0, math.min(1, (canvasX - sliderX) / sliderWidth))
        love.audio.setVolume(volume)
    end
end

function love.mousepressed(x, y, button)
    love.mouse.setVisible(true)

    -- Handle main menu clicks
    if gameState == "mainMenu" and button == 1 then
        handleMainMenuClick(x, y)
        return
    end

    -- Handle pause menu clicks
    if gameState == "pauseMenu" and button == 1 then
        handlePauseMenuClick(x, y)
        return
    end

    -- Handle settings menu clicks
    if gameState == "settings" and button == 1 then
        handleSettingsClick(x, y)
        return
    end

    -- Handle shop clicks
    if gameState == "shop" and button == 1 then
        handleShopClick(x, y)
        return
    end

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
    love.mouse.setVisible(false)

    -- Track movement keys for input priority
    if key == "w" or key == "up" or key == "s" or key == "down" or
       key == "a" or key == "left" or key == "d" or key == "right" then
        -- Remove if already in list
        for i = #heldKeys, 1, -1 do
            if heldKeys[i] == key then
                table.remove(heldKeys, i)
            end
        end
        -- Add to end (most recent)
        table.insert(heldKeys, key)
    end

    -- Create game state object for cheat console
    local gameStateForCheats = {
        showToast = showToast,
        abilityManager = abilityManager,
        activeQuests = activeQuests,
        completedQuests = completedQuests,
        quests = quests,
        inventory = inventory,
        getAllItemIds = getAllItemIds,
        getItemFromRegistry = getItemFromRegistry,
        getAllAbilityIds = getAllAbilityIds,
        getAbilityFromRegistry = getAbilityFromRegistry,
        hasItem = hasItem,
        getGold = function() return playerGold end,
        setGold = function(amount) playerGold = amount end
    }
    
    -- Handle cheat console keys
    if CheatConsole.keyPressed(key, gameStateForCheats, gameState) then
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
        if gameState == "playing" then
            gameState = "pauseMenu"
        elseif gameState == "pauseMenu" then
            gameState = "playing"
        elseif gameState == "shop" then
            gameState = "playing"
        elseif gameState ~= "mainMenu" and gameState ~= "settings" then
            gameState = "playing"
            currentDialog = nil
        end
    elseif key == "f" then
        love.window.setFullscreen(not love.window.getFullscreen())
    end
end

function love.keyreleased(key)
    -- Remove from held keys list
    for i = #heldKeys, 1, -1 do
        if heldKeys[i] == key then
            table.remove(heldKeys, i)
        end
    end
end

function enterDoor(door)
    -- Load the new map
    currentMap = door.targetMap
    map = sti(mapPaths[currentMap])
    calculateMapBounds()

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

-- Helper function to split text into dialog pages
local function splitDialogPages(text)
    local pages = {}
    -- Split on double newline first
    for page in text:gmatch("[^\n\n]+") do
        table.insert(pages, page)
    end
    -- If no double newlines found, return the whole text as one page
    if #pages == 0 then
        table.insert(pages, text)
    end
    return pages
end

function interactWithNPC(npc)
    if npc.isShopkeeper then
        -- Open shop UI
        selectedShopItem = 1  -- Select first item by default
        gameState = "shop"
    elseif npc.isQuestGiver then
        local quest = quests[npc.questId]
        if not quest.active and not quest.completed then
            -- Offer quest
            local questText = quest.name .. "\n" .. quest.description
            currentDialog = {
                type = "questOffer",
                npc = npc,
                quest = quest
            }
            dialogPages = splitDialogPages(questText)
            currentDialogPage = 1
            gameState = "dialog"
        elseif quest.active and quest.requiredItem and hasItem(quest.requiredItem) then
            -- Turn in quest - show inventory selection UI
            currentDialog = {
                type = "questTurnIn",
                npc = npc,
                quest = quest
            }
            gameState = "questTurnIn"
        else
            -- Quest already active (but no item yet) or completed
            local text = quest.active and (quest.reminderText or "Come back when you have the item!") or "Thanks again!"
            currentDialog = {
                type = "generic",
                npc = npc,
                text = text
            }
            dialogPages = splitDialogPages(text)
            currentDialogPage = 1
            gameState = "dialog"
        end
    elseif npc.givesItem then
        -- Check if the required quest is active
        local requiredQuest = npc.requiresQuest and quests[npc.requiresQuest]
        local questActive = requiredQuest and requiredQuest.active

        if not questActive then
            -- Quest not active, show generic dialog
            local text = npc.noQuestText or "Hello there!"
            currentDialog = {
                type = "generic",
                npc = npc,
                text = text
            }
            dialogPages = splitDialogPages(text)
            currentDialogPage = 1
            gameState = "dialog"
        elseif not hasItem(npc.givesItem) then
            -- Quest active and don't have item, give it
            local text = npc.itemGiveText or "Here, take this!"
            currentDialog = {
                type = "itemGive",
                npc = npc,
                item = npc.givesItem
            }
            dialogPages = splitDialogPages(text)
            currentDialogPage = 1
            gameState = "dialog"
        else
            -- Already have the item
            local text = "I already gave you the item!"
            currentDialog = {
                type = "generic",
                npc = npc,
                text = text
            }
            dialogPages = splitDialogPages(text)
            currentDialogPage = 1
            gameState = "dialog"
        end
    elseif npc.givesAbility then
        -- Check if the required quest is active
        local requiredQuest = npc.requiresQuest and quests[npc.requiresQuest]
        local questActive = requiredQuest and requiredQuest.active

        if not questActive then
            -- Quest not active, show generic dialog
            local text = npc.noQuestText or "Hello there!"
            currentDialog = {
                type = "generic",
                npc = npc,
                text = text
            }
            dialogPages = splitDialogPages(text)
            currentDialogPage = 1
            gameState = "dialog"
        elseif not playerAbilities[npc.givesAbility] then
            -- Quest active and don't have ability, give it
            local text = npc.abilityGiveText or "You learned a new ability!"
            currentDialog = {
                type = "abilityGive",
                npc = npc,
                ability = npc.givesAbility,
                quest = requiredQuest
            }
            dialogPages = splitDialogPages(text)
            currentDialogPage = 1
            gameState = "dialog"
        else
            -- Already have the ability
            local text = "You already learned that ability!"
            currentDialog = {
                type = "generic",
                npc = npc,
                text = text
            }
            dialogPages = splitDialogPages(text)
            currentDialogPage = 1
            gameState = "dialog"
        end
    end
end

-- Helper function to complete a quest
local function completeQuest(quest)
    quest.active = false
    quest.completed = true
    table.remove(activeQuests, indexOf(activeQuests, quest.id))
    table.insert(completedQuests, quest.id)

    -- Grant ability if quest provides one
    if quest.grantsAbility then
        local context = {showToast = showToast}
        abilityManager:grantAbility(quest.grantsAbility, context)

        local ability = abilityManager:getAbility(quest.grantsAbility)
        if ability then
            showToast("Learned: " .. ability.name .. "!", ability.color)
        end
    end

    -- Award gold
    if quest.goldReward and quest.goldReward > 0 then
        playerGold = playerGold + quest.goldReward
        showToast("+" .. quest.goldReward .. " Gold", {1, 0.84, 0})
    end

    showToast("Quest Complete: " .. quest.name, {0, 1, 0})

    -- Check if main quest was completed (win condition)
    if quest.isMainQuest then
        gameState = "winScreen"
    end
end

function handleDialogInput()
    -- Check if there are more pages to show
    if currentDialogPage < #dialogPages then
        -- Advance to next page
        currentDialogPage = currentDialogPage + 1
        return
    end
    
    -- No more pages, handle dialog completion
    if currentDialog.type == "questOffer" then
        -- Accept quest
        currentDialog.quest.active = true
        table.insert(activeQuests, currentDialog.quest.id)
        showToast("Quest Accepted: " .. currentDialog.quest.name, {1, 1, 0})
        gameState = "playing"
        currentDialog = nil
        dialogPages = {}
        currentDialogPage = 1
    elseif currentDialog.type == "questTurnIn" then
        -- Complete quest
        removeItem(currentDialog.quest.requiredItem)
        completeQuest(currentDialog.quest)
        gameState = "playing"
        currentDialog = nil
        dialogPages = {}
        currentDialogPage = 1
    elseif currentDialog.type == "itemGive" then
        -- Receive item
        table.insert(inventory, currentDialog.item)
        -- Get item name from registry
        local itemData = itemRegistry[currentDialog.item]
        local itemName = itemData and itemData.name or currentDialog.item
        showToast("Received: " .. itemName, {0.7, 0.5, 0.9})
        gameState = "playing"
        currentDialog = nil
        dialogPages = {}
        currentDialogPage = 1
    elseif currentDialog.type == "abilityGive" then
        -- Learn ability
        playerAbilities[currentDialog.ability] = true
        completeQuest(currentDialog.quest)
        gameState = "playing"
        currentDialog = nil
        dialogPages = {}
        currentDialogPage = 1
    else
        -- Check if this was a reward dialog after completing a main quest
        if currentDialog.completedMainQuest then
            gameState = "winScreen"
        else
            gameState = "playing"
        end
        currentDialog = nil
        dialogPages = {}
        currentDialogPage = 1
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

-- Get ability info from registry by ID or alias
function getAbilityFromRegistry(nameOrAlias)
    local ability = abilityManager:getRegisteredAbility(nameOrAlias)
    if ability then
        return {
            id = ability.id,
            name = ability.name,
            aliases = ability.aliases
        }
    end
    return nil
end

-- Get all ability IDs from registry
function getAllAbilityIds()
    return abilityManager:getAllRegisteredAbilityIds()
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
                -- Correct item clicked! Remove item and complete quest
                removeItem(quest.requiredItem)
                completeQuest(quest)

                -- Show reward dialog
                currentDialog = {
                    type = "generic",
                    npc = currentDialog.npc,
                    text = quest.reward,
                    completedMainQuest = quest.isMainQuest  -- Track if this was a main quest
                }
                dialogPages = splitDialogPages(quest.reward)
                currentDialogPage = 1
                gameState = "dialog"
            else
                -- Wrong item
                showToast("That's not the right item!", {1, 0.5, 0})
            end
            return
        end
    end
end

function handlePauseMenuClick(x, y)
    -- Convert screen coordinates to canvas coordinates
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local offsetX = math.floor((screenWidth - GAME_WIDTH * SCALE) / 2 / SCALE) * SCALE
    local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
    local canvasX = (x - offsetX) / SCALE
    local canvasY = (y - offsetY) / SCALE

    -- Button positions
    local btnWidth = 100
    local btnHeight = 20
    local btnX = GAME_WIDTH / 2 - btnWidth / 2
    local resumeY = 100
    local quitY = 130

    -- Check Resume button
    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= resumeY and canvasY <= resumeY + btnHeight then
        gameState = "playing"
    end

    -- Check Quit Game button
    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= quitY and canvasY <= quitY + btnHeight then
        love.event.quit()
    end
end

function handleMainMenuClick(x, y)
    -- Convert screen coordinates to canvas coordinates
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local offsetX = math.floor((screenWidth - GAME_WIDTH * SCALE) / 2 / SCALE) * SCALE
    local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
    local canvasX = (x - offsetX) / SCALE
    local canvasY = (y - offsetY) / SCALE

    -- Button positions
    local btnWidth = 100
    local btnHeight = 20
    local btnX = GAME_WIDTH / 2 - btnWidth / 2
    local playY = 100
    local settingsY = 130
    local quitY = 160

    -- Check Play button
    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= playY and canvasY <= playY + btnHeight then
        gameState = "playing"
        
        -- Show intro dialog if not shown yet
        if not introShown then
            introShown = true
            -- Find the intro NPC
            for _, npc in ipairs(npcs) do
                if npc.isIntroNPC then
                    currentDialog = {
                        type = "generic",
                        npc = npc,
                        text = npc.introText
                    }
                    dialogPages = splitDialogPages(npc.introText)
                    currentDialogPage = 1
                    gameState = "dialog"
                    break
                end
            end
        end
    end

    -- Check Settings button
    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= settingsY and canvasY <= settingsY + btnHeight then
        gameState = "settings"
    end

    -- Check Quit button
    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= quitY and canvasY <= quitY + btnHeight then
        love.event.quit()
    end
end

function handleSettingsClick(x, y)
    -- Convert screen coordinates to canvas coordinates
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local offsetX = math.floor((screenWidth - GAME_WIDTH * SCALE) / 2 / SCALE) * SCALE
    local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
    local canvasX = (x - offsetX) / SCALE
    local canvasY = (y - offsetY) / SCALE

    -- Back button
    local btnWidth = 100
    local btnHeight = 20
    local btnX = GAME_WIDTH / 2 - btnWidth / 2
    local backY = 160

    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= backY and canvasY <= backY + btnHeight then
        gameState = "mainMenu"
    end

    -- Volume slider
    local sliderX = GAME_WIDTH / 2 - 50
    local sliderY = 100
    local sliderWidth = 100
    local sliderHeight = 10

    if canvasX >= sliderX and canvasX <= sliderX + sliderWidth and canvasY >= sliderY - 5 and canvasY <= sliderY + sliderHeight + 5 then
        draggingSlider = true
        volume = math.max(0, math.min(1, (canvasX - sliderX) / sliderWidth))
        love.audio.setVolume(volume)
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        draggingSlider = false
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

        -- Split message into lines and measure dimensions
        local lines = {}
        for line in toast.message:gmatch("[^\n]+") do
            table.insert(lines, line)
        end

        -- Calculate box dimensions
        local maxWidth = 0
        for _, line in ipairs(lines) do
            local lineWidth = font:getWidth(line)
            if lineWidth > maxWidth then
                maxWidth = lineWidth
            end
        end

        local boxW = maxWidth + 8
        local boxH = #lines * 10 + 2
        local boxX = GAME_WIDTH - boxW - 2 -- Align to right with 2px padding

        -- Background
        love.graphics.setColor(0.05, 0.05, 0.1, 0.9 * alpha)
        love.graphics.rectangle("fill", boxX, y, boxW, boxH)

        -- Border
        love.graphics.setColor(toast.color[1], toast.color[2], toast.color[3], alpha)
        love.graphics.rectangle("line", boxX, y, boxW, boxH)

        -- Text (line by line)
        love.graphics.setColor(toast.color[1], toast.color[2], toast.color[3], alpha)
        for lineIdx, line in ipairs(lines) do
            love.graphics.print(line, boxX + 4, y + (lineIdx - 1) * 10 - 1)
        end

        y = y + boxH + 2
    end
end

function isMouseOverButton(btnX, btnY, btnWidth, btnHeight)
    -- Convert screen coordinates to canvas coordinates
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local offsetX = math.floor((screenWidth - GAME_WIDTH * SCALE) / 2 / SCALE) * SCALE
    local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
    local canvasX = (mouseX - offsetX) / SCALE
    local canvasY = (mouseY - offsetY) / SCALE

    return canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= btnY and canvasY <= btnY + btnHeight
end

function drawPauseMenu()
    -- Semi-transparent background overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Paused", 0, 60, GAME_WIDTH, "center")

    -- Buttons
    local btnWidth = 100
    local btnHeight = 20
    local btnX = GAME_WIDTH / 2 - btnWidth / 2

    -- Resume button
    local resumeHover = isMouseOverButton(btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(resumeHover and 0.3 or 0.2, resumeHover and 0.2 or 0.15, resumeHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(resumeHover and 1 or 0.8, resumeHover and 0.8 or 0.6, resumeHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Resume", btnX, 100 + 3, btnWidth, "center")

    -- Quit Game button
    local quitHover = isMouseOverButton(btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(quitHover and 0.3 or 0.2, quitHover and 0.2 or 0.15, quitHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(quitHover and 1 or 0.8, quitHover and 0.8 or 0.6, quitHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Quit Game", btnX, 130 + 3, btnWidth, "center")
end

function drawMainMenu()
    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.printf("Go Fetch", 0, 40, GAME_WIDTH, "center")
    love.graphics.setFont(font)

    -- Buttons
    local btnWidth = 100
    local btnHeight = 20
    local btnX = GAME_WIDTH / 2 - btnWidth / 2

    -- Play button
    local playHover = isMouseOverButton(btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(playHover and 0.3 or 0.2, playHover and 0.2 or 0.15, playHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(playHover and 1 or 0.8, playHover and 0.8 or 0.6, playHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Play", btnX, 100 + 3, btnWidth, "center")

    -- Settings button
    local settingsHover = isMouseOverButton(btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(settingsHover and 0.3 or 0.2, settingsHover and 0.2 or 0.15, settingsHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(settingsHover and 1 or 0.8, settingsHover and 0.8 or 0.6, settingsHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Settings", btnX, 130 + 3, btnWidth, "center")

    -- Quit button
    local quitHover = isMouseOverButton(btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(quitHover and 0.3 or 0.2, quitHover and 0.2 or 0.15, quitHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(quitHover and 1 or 0.8, quitHover and 0.8 or 0.6, quitHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Quit", btnX, 160 + 3, btnWidth, "center")
end

function drawSettings()
    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)

    -- Title
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.printf("Settings", 0, 40, GAME_WIDTH, "center")

    -- Volume label
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Volume", 0, 80, GAME_WIDTH, "center")

    -- Volume slider
    local sliderX = GAME_WIDTH / 2 - 50
    local sliderY = 100
    local sliderWidth = 100
    local sliderHeight = 10

    -- Slider background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", sliderX, sliderY, sliderWidth, sliderHeight)

    -- Slider fill
    love.graphics.setColor(0.8, 0.6, 0.2)
    love.graphics.rectangle("fill", sliderX, sliderY, sliderWidth * volume, sliderHeight)

    -- Slider border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", sliderX, sliderY, sliderWidth, sliderHeight)

    -- Volume percentage
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(math.floor(volume * 100) .. "%", 0, 115, GAME_WIDTH, "center")

    -- Back button
    local btnWidth = 100
    local btnHeight = 20
    local btnX = GAME_WIDTH / 2 - btnWidth / 2
    local backHover = isMouseOverButton(btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(backHover and 0.3 or 0.2, backHover and 0.2 or 0.15, backHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(backHover and 1 or 0.8, backHover and 0.8 or 0.6, backHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Back", btnX, 160 + 3, btnWidth, "center")
end

-- Helper function to get the current player sprite set based on conditions
local function getPlayerSpriteSet()
    -- Don't use water sprites when jumping
    if player.jumping then
        return playerQuads.regular
    end
    
    -- Get the tile at player's position
    local tileX = math.floor(player.x / world.tileSize)
    local tileY = math.floor(player.y / world.tileSize)
    local isOnWater = isWaterTile(player.x, player.y)

    if isOnWater then
        if abilityManager:hasAbility("swim") then
            return playerQuads.swimming
        else
            return playerQuads.boat
        end
    end
    return playerQuads.regular
end

function love.draw()
    -- Draw to canvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.1, 0.1, 0.1)

    if gameState == "mainMenu" then
        drawMainMenu()
    elseif gameState == "settings" then
        drawSettings()
    elseif gameState == "playing" or gameState == "dialog" then
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
        local spriteSet = getPlayerSpriteSet()
        local currentQuad = spriteSet[player.direction][player.moving and (player.walkFrame + 1) or 1]
        local scaleX = (player.facing == "left") and -1 or 1
        local offsetX = (player.facing == "left") and player.size or 0
        love.graphics.draw(
            playerTileset,
            currentQuad,
            player.x - player.size/2 - camX + offsetX,
            player.y - player.size/2 - camY - player.jumpHeight,  -- Apply jump height offset
            0,
            scaleX,
            1
        )

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
        love.graphics.print("Q: Quest log  I: Inventory", 2, -2)
        
        -- Draw gold display
        local goldText = "Gold: " .. playerGold
        local goldTextWidth = font:getWidth(goldText)
        love.graphics.setColor(1, 0.84, 0) -- Gold color
        love.graphics.print(goldText, GAME_WIDTH / 2 - goldTextWidth / 2, -1)
        
        -- Draw cheat indicators
        CheatConsole.drawIndicators(GAME_WIDTH, font, abilityManager)

    elseif gameState == "pauseMenu" then
        -- Draw game world in background
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
        local currentQuad = playerQuads[player.direction][player.moving and (player.walkFrame + 1) or 1]
        local scaleX = (player.facing == "left") and -1 or 1
        local offsetX = (player.facing == "left") and player.size or 0
        love.graphics.draw(
            playerTileset,
            currentQuad,
            player.x - player.size/2 - camX + offsetX,
            player.y - player.size/2 - camY - player.jumpHeight,  -- Apply jump height offset
            0,
            scaleX,
            1
        )

        -- Draw pause menu overlay
        drawPauseMenu()

    elseif gameState == "questLog" then
        drawQuestLog()
    elseif gameState == "inventory" then
        drawInventory()
    elseif gameState == "shop" then
        drawShop()
    elseif gameState == "questTurnIn" then
        drawQuestTurnIn()
    elseif gameState == "winScreen" then
        drawWinScreen()
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

    -- Page indicator (if multiple pages)
    if #dialogPages > 1 then
        love.graphics.setColor(0.7, 0.6, 0.4)
        love.graphics.printf(currentDialogPage .. "/" .. #dialogPages, boxX, boxY, boxW-4, "right")
    end

    -- Dialog text - show current page
    local text = dialogPages[currentDialogPage] or ""
    local buttonText = ""

    -- Determine button text based on dialog type and page position
    local isLastPage = currentDialogPage >= #dialogPages
    
    if not isLastPage then
        buttonText = "[E] Next"
    elseif currentDialog.type == "questOffer" then
        buttonText = "[E] Accept"
    elseif currentDialog.type == "questTurnIn" then
        buttonText = "[E] Complete"
    elseif currentDialog.type == "itemGive" then
        buttonText = "[E] Receive"
    elseif currentDialog.type == "abilityGive" then
        buttonText = "[E] Learn"
    else
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

    -- Separate main and side quests
    local activeMainQuests = {}
    local activeSideQuests = {}
    local completedMainQuests = {}
    local completedSideQuests = {}

    for _, questId in ipairs(activeQuests) do
        local quest = quests[questId]
        if quest.isMainQuest then
            table.insert(activeMainQuests, questId)
        else
            table.insert(activeSideQuests, questId)
        end
    end

    for _, questId in ipairs(completedQuests) do
        local quest = quests[questId]
        if quest.isMainQuest then
            table.insert(completedMainQuests, questId)
        else
            table.insert(completedSideQuests, questId)
        end
    end

    -- Main Quests Section
    love.graphics.setColor(1, 0.8, 0.3)
    love.graphics.print("MAIN QUEST", boxX+4, y)
    y = y + 12

    if #activeMainQuests == 0 and #completedMainQuests == 0 then
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print("None", boxX+6, y)
        y = y + 12
    else
        -- Active main quests
        for _, questId in ipairs(activeMainQuests) do
            local quest = quests[questId]
            love.graphics.setColor(1, 0.9, 0.3)
            love.graphics.print("- " .. quest.name, boxX+6, y)
            y = y + 10
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf(quest.description, boxX+8, y, boxW-12, "left")
            y = y + 24
        end

        -- Completed main quests
        for _, questId in ipairs(completedMainQuests) do
            local quest = quests[questId]
            love.graphics.setColor(0.3, 0.9, 0.3)
            love.graphics.print("- " .. quest.name .. " (Completed)", boxX+6, y)
            y = y + 12
        end
    end

    y = y + 6

    -- Side Quests Section
    love.graphics.setColor(0.8, 0.7, 0.5)
    love.graphics.print("SIDE QUESTS", boxX+4, y)
    y = y + 12

    if #activeSideQuests == 0 and #completedSideQuests == 0 then
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print("None", boxX+6, y)
    else
        -- Active side quests
        for _, questId in ipairs(activeSideQuests) do
            local quest = quests[questId]
            love.graphics.setColor(0.9, 0.8, 0.5)
            love.graphics.print("- " .. quest.name, boxX+6, y)
            y = y + 10
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf(quest.description, boxX+8, y, boxW-12, "left")
            y = y + 24
        end

        -- Completed side quests
        for _, questId in ipairs(completedSideQuests) do
            local quest = quests[questId]
            love.graphics.setColor(0.3, 0.9, 0.3)
            love.graphics.print("- " .. quest.name .. " (Completed)", boxX+6, y)
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
    local spriteSet = getPlayerSpriteSet()
    local currentQuad = spriteSet[player.direction][player.moving and (player.walkFrame + 1) or 1]
    local scaleX = (player.facing == "left") and -1 or 1
    local offsetX = (player.facing == "left") and player.size or 0
    love.graphics.draw(
        playerTileset,
        currentQuad,
        player.x - player.size/2 - camX + offsetX,
        player.y - player.size/2 - camY - player.jumpHeight,  -- Apply jump height offset
        0,
        scaleX,
        1
    )

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

function drawShop()
    local boxX, boxY = 10, 10
    local boxW, boxH = GAME_WIDTH - 20, GAME_HEIGHT - 20

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 0.98)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)

    -- Fancy border
    drawFancyBorder(boxX, boxY, boxW, boxH, {0.8, 0.6, 0.2})

    -- Title bar
    love.graphics.setColor(0.15, 0.1, 0.05, 0.95)
    love.graphics.rectangle("fill", boxX+2, boxY+2, boxW-4, 12)
    love.graphics.setColor(1, 0.8, 0.3)
    love.graphics.printf("SHOP", boxX+2, boxY, boxW-4, "center")

    -- Your gold
    local goldText = "Gold: " .. playerGold
    love.graphics.setColor(1, 0.84, 0)
    love.graphics.print(goldText, boxX+4, boxY+16)

    -- Left side: Item grid
    local gridX = boxX + 4
    local gridY = boxY + 30
    local slotSize = 20
    local padding = 4

    for i, shopItem in ipairs(shopInventory) do
        local slotX = gridX + ((i - 1) % 6) * (slotSize + padding)
        local slotY = gridY + math.floor((i - 1) / 6) * (slotSize + padding)

        -- Check if selected
        local isSelected = selectedShopItem == i
        local alreadyOwns = hasItem(shopItem.itemId)

        -- Slot background
        if isSelected then
            love.graphics.setColor(0.3, 0.25, 0.15, 0.9)
        else
            love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
        end
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize)

        -- Item representation
        if alreadyOwns then
            love.graphics.setColor(0.4, 0.4, 0.4)
        else
            love.graphics.setColor(0.9, 0.7, 0.3)
        end
        love.graphics.rectangle("fill", slotX+2, slotY+2, slotSize-4, slotSize-4)

        -- Border
        if isSelected then
            love.graphics.setColor(1, 0.8, 0.3)
        elseif alreadyOwns then
            love.graphics.setColor(0.4, 0.4, 0.4)
        else
            love.graphics.setColor(0.8, 0.6, 0.2)
        end
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize)
    end

    -- Right side: Item details
    if selectedShopItem then
        local shopItem = shopInventory[selectedShopItem]
        if shopItem then
            local itemData = itemRegistry[shopItem.itemId]
            local itemName = itemData and itemData.name or shopItem.itemId
            local alreadyOwns = hasItem(shopItem.itemId)
            local canAfford = playerGold >= shopItem.price

            local detailX = boxX + 150
            local detailY = boxY + 30
            local detailW = boxW - 150 - 8

            -- Item display (2x size)
            local displaySize = 40
            love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
            love.graphics.rectangle("fill", detailX, detailY, displaySize, displaySize)

            if alreadyOwns then
                love.graphics.setColor(0.4, 0.4, 0.4)
            else
                love.graphics.setColor(0.9, 0.7, 0.3)
            end
            love.graphics.rectangle("fill", detailX+4, detailY+4, displaySize-8, displaySize-8)

            love.graphics.setColor(0.8, 0.6, 0.2)
            love.graphics.rectangle("line", detailX, detailY, displaySize, displaySize)

            -- Item name
            love.graphics.setColor(1, 0.9, 0.7)
            love.graphics.print(itemName, detailX + displaySize + 6, detailY)

            -- Price
            if alreadyOwns then
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.print("Owned", detailX + displaySize + 6, detailY + 12)
            else
                love.graphics.setColor(1, 0.84, 0)
                love.graphics.print(shopItem.price .. "g", detailX + displaySize + 6, detailY + 12)
            end

            -- Description
            local descY = detailY + displaySize + 8
            love.graphics.setColor(0.8, 0.8, 0.8)

            -- Wrap description text
            local wrapWidth = detailW - 4
            local _, wrappedText = font:getWrap(shopItem.description, wrapWidth)
            for i, line in ipairs(wrappedText) do
                love.graphics.print(line, detailX, descY + (i-1) * 10)
            end

            -- Purchase button
            if not alreadyOwns then
                local btnY = boxY + boxH - 40
                local btnW = 80
                local btnH = 20
                local btnX = detailX + (detailW - btnW) / 2

                local isHovered = isMouseOverButton(btnX, btnY, btnW, btnH)

                -- Button background
                if not canAfford then
                    love.graphics.setColor(0.3, 0.1, 0.1, 0.7)
                elseif isHovered then
                    love.graphics.setColor(0.3, 0.25, 0.15)
                else
                    love.graphics.setColor(0.2, 0.15, 0.1)
                end
                love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)

                -- Button border
                if not canAfford then
                    love.graphics.setColor(0.6, 0.2, 0.2)
                elseif isHovered then
                    love.graphics.setColor(1, 0.8, 0.4)
                else
                    love.graphics.setColor(0.8, 0.6, 0.2)
                end
                love.graphics.rectangle("line", btnX, btnY, btnW, btnH)

                -- Button text
                if not canAfford then
                    love.graphics.setColor(0.7, 0.4, 0.4)
                else
                    love.graphics.setColor(1, 0.9, 0.7)
                end
                love.graphics.printf("Purchase", btnX, btnY + 3, btnW, "center")
            end
        end
    end

    -- Footer
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("[ESC] Close", boxX+4, boxY+boxH-15)
end

function drawWinScreen()
    -- Background
    love.graphics.setColor(0, 0, 0, 0.95)
    love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 0.84, 0)
    love.graphics.printf("QUEST COMPLETE!", 0, 60, GAME_WIDTH, "center")
    love.graphics.setFont(font)

    -- Message
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("You have completed the Royal Gift quest!", 0, 110, GAME_WIDTH, "center")
    love.graphics.printf("The King is very pleased with the Labubu!", 0, 125, GAME_WIDTH, "center")

    -- Stats
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf("Final Gold: " .. playerGold, 0, 155, GAME_WIDTH, "center")
    love.graphics.printf("Quests Completed: " .. #completedQuests, 0, 170, GAME_WIDTH, "center")

    -- Footer
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf("The game will close in a moment...", 0, 200, GAME_WIDTH, "center")
end

function handleShopClick(x, y)
    -- Convert screen coordinates to canvas coordinates
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local offsetX = math.floor((screenWidth - GAME_WIDTH * SCALE) / 2 / SCALE) * SCALE
    local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
    local canvasX = (x - offsetX) / SCALE
    local canvasY = (y - offsetY) / SCALE

    local boxX, boxY = 10, 10
    local boxW = GAME_WIDTH - 20
    local boxH = GAME_HEIGHT - 20

    -- Check grid item clicks
    local gridX = boxX + 4
    local gridY = boxY + 30
    local slotSize = 20
    local padding = 4

    for i, shopItem in ipairs(shopInventory) do
        local slotX = gridX + ((i - 1) % 6) * (slotSize + padding)
        local slotY = gridY + math.floor((i - 1) / 6) * (slotSize + padding)

        if canvasX >= slotX and canvasX <= slotX + slotSize and canvasY >= slotY and canvasY <= slotY + slotSize then
            selectedShopItem = i
            return
        end
    end

    -- Check purchase button click
    if selectedShopItem then
        local shopItem = shopInventory[selectedShopItem]
        if shopItem then
            local alreadyOwns = hasItem(shopItem.itemId)
            local canAfford = playerGold >= shopItem.price

            if not alreadyOwns then
                local btnY = boxY + boxH - 40
                local btnW = 80
                local btnH = 20
                local detailX = boxX + 150
                local detailW = boxW - 150 - 8
                local btnX = detailX + (detailW - btnW) / 2

                if canvasX >= btnX and canvasX <= btnX + btnW and canvasY >= btnY and canvasY <= btnY + btnH then
                    if canAfford then
                        -- Purchase item
                        playerGold = playerGold - shopItem.price
                        table.insert(inventory, shopItem.itemId)
                        local itemData = itemRegistry[shopItem.itemId]
                        showToast("Purchased " .. (itemData and itemData.name or shopItem.itemId) .. "!", {0, 1, 0})
                    else
                        showToast("Not enough gold!", {1, 0, 0})
                    end
                    return
                end
            end
        end
    end
end
