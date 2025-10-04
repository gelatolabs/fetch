-- Libraries
local sti = require "sti"
local questData = require "quests"
local CheatConsole = require "cheat_console"
local AbilitySystem = require "ability_system"
local DialogSystem = require "dialog_system"
local UISystem = require "ui_system"
local MapSystem = require "map_system"

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

-- Audio
local quackSound

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
local nearbyDoor = nil
local mouseX = 0
local mouseY = 0
local selectedShopItem = nil
local questTurnInData = nil  -- Stores {npc, quest} for quest turn-in UI
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

    -- Load audio
    quackSound = love.audio.newSource("audio/quack.wav", "static")

    -- Load Tiled map
    map = sti(mapPaths[currentMap])
    
    -- Initialize MapSystem
    MapSystem.init(map, world, CheatConsole, npcs, currentMap)
    MapSystem.calculateMapBounds()

    -- Load game data
    loadGameData()
    
    -- Validate player spawn position
    local newX, newY, success = MapSystem.findValidSpawnPosition(player.x, player.y, "Player", 15)
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

function loadGameData()
    -- Load NPCs from quest data, validating positions
    for _, npcData in ipairs(questData.npcs) do
        local newX, newY, success = MapSystem.findValidSpawnPosition(npcData.x, npcData.y, "NPC '" .. npcData.name .. "'", 20)
        npcData.x = newX
        npcData.y = newY
        
        table.insert(npcs, npcData)
    end

    -- Load quests from quest data
    for questId, questInfo in pairs(questData.questData) do
        quests[questId] = questInfo
    end
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
                local isOnWater = MapSystem.isWaterTile(endX, endY)
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
                    local tileBlocked = MapSystem.isColliding(targetPixelX, targetPixelY, canCrossWater)
                    local npcBlocked = MapSystem.isNPCAt(targetPixelX, targetPixelY)

                    -- Check if we should jump over an obstacle
                    if tileBlocked and canJump and MapSystem.isJumpableObstacle(targetPixelX, targetPixelY) then
                        -- Try to jump OVER the obstacle (2 tiles total)
                        local jumpLandingX = newGridX + (newGridX - player.gridX)
                        local jumpLandingY = newGridY + (newGridY - player.gridY)
                        local landingPixelX = jumpLandingX * 16 + 8
                        local landingPixelY = jumpLandingY * 16 + 8

                        -- Check if landing spot is valid
                        local landingBlocked = MapSystem.isColliding(landingPixelX, landingPixelY, canCrossWater)
                        local landingNpcBlocked = MapSystem.isNPCAt(landingPixelX, landingPixelY)

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
                local tileBlocked = MapSystem.isColliding(targetPixelX, targetPixelY, canCrossWater)
                local npcBlocked = MapSystem.isNPCAt(targetPixelX, targetPixelY)
                
                -- Check if we should jump over an obstacle
                if tileBlocked and canJump and MapSystem.isJumpableObstacle(targetPixelX, targetPixelY) then
                    -- Try to jump OVER the obstacle (2 tiles total)
                    local jumpLandingX = newGridX + (newGridX - player.gridX)
                    local jumpLandingY = newGridY + (newGridY - player.gridY)
                    local landingPixelX = jumpLandingX * 16 + 8
                    local landingPixelY = jumpLandingY * 16 + 8
                    
                    -- Check if landing spot is valid (not blocked and not an NPC there)
                    local landingBlocked = MapSystem.isColliding(landingPixelX, landingPixelY, canCrossWater)
                    local landingNpcBlocked = MapSystem.isNPCAt(landingPixelX, landingPixelY)
                    
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
            local callbacks = {
                onQuestAccept = function(quest)
                    quest.active = true
                    table.insert(activeQuests, quest.id)
                    showToast("Quest Accepted: " .. quest.name, {1, 1, 0})
                end,
                onQuestComplete = function(quest)
                    removeItem(quest.requiredItem)
                    completeQuest(quest)
                end,
                onItemReceive = function(itemId)
                    table.insert(inventory, itemId)
                    local itemData = itemRegistry[itemId]
                    local itemName = itemData and itemData.name or itemId
                    showToast("Received: " .. itemName, {0.7, 0.5, 0.9})
                end,
                onAbilityLearn = function(abilityId, quest)
                    playerAbilities[abilityId] = true
                    completeQuest(quest)
                end
            }
            local newState, shouldClear = DialogSystem.handleInput(callbacks)
            if newState then
                gameState = newState
            end
            if shouldClear then
                DialogSystem.clearDialog()
            end
        end
    elseif key == "l" then
        if gameState == "playing" then
            gameState = "questLog"
        elseif gameState == "questLog" then
            gameState = "playing"
        end
    elseif key == "q" then
        if gameState == "playing" then
            quackSound:play()
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
            DialogSystem.clearDialog()
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
    
    -- Update MapSystem references
    MapSystem.updateReferences(map, currentMap)
    MapSystem.calculateMapBounds()

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
    if npc.isShopkeeper then
        -- Open shop UI
        selectedShopItem = 1  -- Select first item by default
        gameState = "shop"
    elseif npc.isQuestGiver then
        local quest = quests[npc.questId]
        if not quest.active and not quest.completed then
            -- Offer quest
            local questText = quest.description
            gameState = DialogSystem.showDialog({
                type = "questOffer",
                npc = npc,
                quest = quest,
                text = questText
            })
        elseif quest.active and quest.requiredItem and hasItem(quest.requiredItem) then
            -- Turn in quest - show inventory selection UI (not using DialogSystem for this special UI)
            questTurnInData = {npc = npc, quest = quest}
            gameState = "questTurnIn"
        else
            -- Quest already active (but no item yet) or completed
            local text = quest.active and (quest.reminderText or "Come back when you have the item!") or "Thanks again!"
            gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = text
            })
        end
    elseif npc.givesItem then
        -- Check if the required quest is active
        local requiredQuest = npc.requiresQuest and quests[npc.requiresQuest]
        local questActive = requiredQuest and requiredQuest.active

        if not questActive then
            -- Quest not active, show generic dialog
            local text = npc.noQuestText or "Hello there!"
            gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = text
            })
        elseif not hasItem(npc.givesItem) then
            -- Quest active and don't have item, give it
            local text = npc.itemGiveText or "Here, take this!"
            gameState = DialogSystem.showDialog({
                type = "itemGive",
                npc = npc,
                item = npc.givesItem,
                text = text
            })
        else
            -- Already have the item
            local text = "I already gave you the item!"
            gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = text
            })
        end
    elseif npc.givesAbility then
        -- Check if the required quest is active
        local requiredQuest = npc.requiresQuest and quests[npc.requiresQuest]
        local questActive = requiredQuest and requiredQuest.active

        if not questActive then
            -- Quest not active, show generic dialog
            local text = npc.noQuestText or "Hello there!"
            gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = text
            })
        elseif not playerAbilities[npc.givesAbility] then
            -- Quest active and don't have ability, give it
            local text = npc.abilityGiveText or "You learned a new ability!"
            gameState = DialogSystem.showDialog({
                type = "abilityGive",
                npc = npc,
                ability = npc.givesAbility,
                quest = requiredQuest,
                text = text
            })
        else
            -- Already have the ability
            local text = "You already learned that ability!"
            gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = text
            })
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
    if not questTurnInData then
        return
    end

    local quest = questTurnInData.quest

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
                gameState = DialogSystem.showDialog({
                    type = "generic",
                    npc = questTurnInData.npc,
                    text = quest.reward,
                    completedMainQuest = quest.isMainQuest  -- Track if this was a main quest
                })
                questTurnInData = nil
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
                    gameState = DialogSystem.showDialog({
                        type = "generic",
                        npc = npc,
                        text = npc.introText
                    })
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



-- Helper function to get the current player sprite set based on conditions
local function getPlayerSpriteSet()
    -- Don't use water sprites when jumping
    if player.jumping then
        return playerQuads.regular
    end
    
    -- Get the tile at player's position
    local tileX = math.floor(player.x / world.tileSize)
    local tileY = math.floor(player.y / world.tileSize)
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

function love.draw()
    -- Draw to canvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.1, 0.1, 0.1)

    if gameState == "mainMenu" then
        UISystem.drawMainMenu(GAME_WIDTH, GAME_HEIGHT, titleFont, font, mouseX, mouseY, SCALE)
    elseif gameState == "settings" then
        UISystem.drawSettings(GAME_WIDTH, GAME_HEIGHT, volume, mouseX, mouseY, SCALE)
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
            UISystem.drawTextBox(GAME_WIDTH/2 - 45, GAME_HEIGHT - 14, 90, 12, doorText, {1, 1, 1}, true)
        elseif nearbyNPC and gameState == "playing" then
            UISystem.drawTextBox(GAME_WIDTH/2 - 45, GAME_HEIGHT - 14, 90, 12, "[E] Talk", {1, 1, 1}, true)
        end

        -- Draw dialog
        if gameState == "dialog" then
            DialogSystem.draw(GAME_WIDTH, GAME_HEIGHT, UISystem.drawFancyBorder)
        end

        -- Draw tile grid overlay (cheat)
        CheatConsole.drawGrid(camX, camY, GAME_WIDTH, GAME_HEIGHT)

        -- Draw UI hints
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, 12)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("L: Quest log  I: Inventory", 2, -2)
        
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
        UISystem.drawPauseMenu(GAME_WIDTH, GAME_HEIGHT, mouseX, mouseY, SCALE)

    elseif gameState == "questLog" then
        UISystem.drawQuestLog(GAME_WIDTH, GAME_HEIGHT, activeQuests, completedQuests, quests)
    elseif gameState == "inventory" then
        UISystem.drawInventory(GAME_WIDTH, GAME_HEIGHT, inventory, itemRegistry)
    elseif gameState == "shop" then
        UISystem.drawShop(GAME_WIDTH, GAME_HEIGHT, shopInventory, selectedShopItem, playerGold, inventory, itemRegistry, font, mouseX, mouseY, SCALE, hasItem)
    elseif gameState == "questTurnIn" then
        UISystem.drawQuestTurnIn(GAME_WIDTH, GAME_HEIGHT, questTurnInData, inventory, itemRegistry, map, camera, npcs, currentMap, npcSprite, player, playerTileset, getPlayerSpriteSet)
    elseif gameState == "winScreen" then
        UISystem.drawWinScreen(GAME_WIDTH, GAME_HEIGHT, titleFont, font, playerGold, completedQuests)
    end

    -- Draw cheat console (overlay on top of everything)
    CheatConsole.draw(GAME_WIDTH, GAME_HEIGHT, font)

    -- Draw toasts (always on top)
    UISystem.drawToasts(toasts, font, GAME_WIDTH)

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

-- All draw functions have been moved to ui_system.lua

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
