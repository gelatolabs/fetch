-- Libraries
local sti = require "sti"
local questData = require "quests"
local CheatConsole = require "cheat_console"
local AbilitySystem = require "ability_system"
local DialogSystem = require "dialog_system"
local UISystem = require "ui_system"
local MapSystem = require "map_system"
local PlayerSystem = require "player_system"

-- Game constants (managed by UISystem)
-- Graphics resources (managed by UISystem)

-- Sprites
local npcSprites = {}  -- Table to store loaded NPC sprites

-- Audio
local quackSound

-- Game state
-- mainMenu, settings, playing, dialog, questLog, inventory, questTurnIn, shop
local gameState = "mainMenu"

-- Settings
local volume = 1.0

-- Input tracking for movement priority
local heldKeys = {}

-- Player reference (managed by PlayerSystem)
local player = nil

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

-- Register abilities
abilityManager:registerAbility({
    id = "swim",
    name = "Swim",
    aliases = {"swim", "swimming"},
    type = AbilitySystem.AbilityType.PASSIVE,
    effects = {AbilitySystem.EffectType.WATER_TRAVERSAL},
    description = "Allows you to swim across water tiles freely",
    color = {0.3, 0.8, 1.0},
    onAcquire = function(ability)
        UISystem.showToast("You can now swim across water!", {0.3, 0.8, 1.0})
    end
})

abilityManager:registerAbility({
    id = "boat",
    name = "Boat",
    aliases = {"boat", "raft"},
    type = AbilitySystem.AbilityType.CONSUMABLE,
    effects = {AbilitySystem.EffectType.WATER_TRAVERSAL},
    description = "A makeshift boat that breaks after crossing water 3 times",
    maxUses = 3,
    consumeOnUse = true,
    color = {0.7, 0.7, 1.0},
    onAcquire = function(ability)
        UISystem.showToast("Boat has " .. ability.maxUses .. " crossings", {0.7, 0.7, 1.0})
    end,
    onUse = function(ability)
        if ability.currentUses > 0 then
            UISystem.showToast("Boat crossings remaining: " .. ability.currentUses, {0.7, 0.7, 1.0})
        end
    end,
    onExpire = function()
        UISystem.showToast("Your boat broke apart!", {1, 0.5, 0.2})
    end
})

abilityManager:registerAbility({
    id = "jump",
    name = "Jump",
    aliases = {"jump", "jumping", "leap"},
    type = AbilitySystem.AbilityType.PASSIVE,
    effects = {AbilitySystem.EffectType.JUMP},
    description = "Allows you to jump over low obstacles (height ≤ 0.5)",
    color = {1.0, 0.9, 0.3},
    onAcquire = function(ability)
        UISystem.showToast("You can now jump over low obstacles!", {1.0, 0.9, 0.3})
    end
})



-- UI state
local nearbyNPC = nil
local nearbyDoor = nil
local selectedShopItem = nil
local questTurnInData = nil  -- Stores {npc, quest} for quest turn-in UI
local questOfferData = nil  -- Stores {npc, quest} for quest offer UI
local winScreenTimer = 0
local introShown = false

-- Toast system (managed by UISystem)

-- Door/Map transition system (managed by MapSystem)
local currentMap = "map"

-- Camera helper functions
local function centerCameraOnPlayer()
    camera.x = player.x - UISystem.getGameWidth() / 2
    camera.y = player.y - UISystem.getGameHeight() / 2
end

local function clampCameraToMapBounds()
    if not world.minX or not world.maxX then
        return
    end
    
    local mapWidth = world.maxX - world.minX
    local mapHeight = world.maxY - world.minY
    
    -- Only clamp if map is larger than screen
    if mapWidth > UISystem.getGameWidth() then
        camera.x = math.max(world.minX, math.min(camera.x, world.maxX - UISystem.getGameWidth()))
    else
        camera.x = world.minX + (mapWidth - UISystem.getGameWidth()) / 2
    end
    
    if mapHeight > UISystem.getGameHeight() then
        camera.y = math.max(world.minY, math.min(camera.y, world.maxY - UISystem.getGameHeight()))
    else
        camera.y = world.minY + (mapHeight - UISystem.getGameHeight()) / 2
    end
end

local function updateCamera()
    centerCameraOnPlayer()
    clampCameraToMapBounds()
end

function love.load()
    love.window.setTitle("Go Fetch")

    -- Initialize UI system (sets up window, graphics, canvas, and fonts)
    UISystem.init()

    -- Initialize Player system
    PlayerSystem.init()
    player = PlayerSystem.getPlayer()

    -- Load audio
    quackSound = love.audio.newSource("audio/quack.wav", "static")

    -- Load Tiled map
    map = sti(MapSystem.getMapPath(currentMap))
    
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
    updateCamera()
end

function loadGameData()
    -- Load NPCs from quest data, validating positions
    local npcTileset = love.graphics.newImage("tiles/fetch-tileset.png")
    for _, npcData in ipairs(questData.npcs) do
        local newX, newY, success = MapSystem.findValidSpawnPosition(npcData.x, npcData.y, "NPC '" .. npcData.name .. "'", 20)
        npcData.x = newX
        npcData.y = newY
        
        -- Load NPC sprite from tileset using quad
        if npcData.spriteX and npcData.spriteY then
            npcData.sprite = {
                tileset = npcTileset,
                quad = love.graphics.newQuad(
                    npcData.spriteX, 
                    npcData.spriteY, 
                    16, -- sprite width
                    16, -- sprite height
                    npcTileset:getDimensions()
                )
            }
        else
            -- Fallback to default sprite
            npcData.sprite = {
                image = love.graphics.newImage("sprites/npc.png")
            }
        end
        
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
    UISystem.updateToasts(dt)

    -- Update chat animation
    UISystem.updateChat(dt)

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
                            boatAbility:use()

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
                        player.lastVertical = "up"
                    elseif queuedDir == "down" then
                        newGridY = player.gridY + 1
                        player.lastVertical = "down"
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

                    local canCrossWater = abilityManager:hasEffect(AbilitySystem.EffectType.WATER_TRAVERSAL)
                    local canJump = abilityManager:hasEffect(AbilitySystem.EffectType.JUMP)
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
                        player.lastVertical = "up"  -- Add this line
                        newGridY = player.gridY - 1
                        break
                    elseif key == "s" or key == "down" then
                        moveDir = "down"
                        player.lastVertical = "down"  -- Add this line
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
                
                local canCrossWater = abilityManager:hasEffect(AbilitySystem.EffectType.WATER_TRAVERSAL)
                local canJump = abilityManager:hasEffect(AbilitySystem.EffectType.JUMP)
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
        
        -- Update camera to follow player
        updateCamera()

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
        nearbyDoor = MapSystem.findDoorAt(player.gridX, player.gridY)
    end
end


function love.mousemoved(x, y, dx, dy)
    -- Show mouse cursor when mouse is moved
    love.mouse.setVisible(true)

    -- Update UI mouse position
    UISystem.updateMouse(x, y)

    -- Handle slider dragging
    if gameState == "settings" then
        volume = UISystem.handleSliderDrag(volume, function(newVolume)
            love.audio.setVolume(newVolume)
        end)
    end
end

function love.mousepressed(x, y, button)
    love.mouse.setVisible(true)
    UISystem.updateMouse(x, y)

    if button ~= 1 then
        return
    end

    -- Handle main menu clicks
    if gameState == "mainMenu" then
        UISystem.handleMainMenuClick(x, y, {
            onPlay = function()
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
            end,
            onSettings = function()
                gameState = "settings"
            end,
            onQuit = function()
                love.event.quit()
            end
        })
        return
    end

    -- Handle pause menu clicks
    if gameState == "pauseMenu" then
        UISystem.handlePauseMenuClick(x, y, {
            onResume = function()
                gameState = "playing"
            end,
            onQuit = function()
                love.event.quit()
            end
        })
        return
    end

    -- Handle settings menu clicks
    if gameState == "settings" then
        local handled, newVolume = UISystem.handleSettingsClick(x, y, volume, {
            onBack = function()
                gameState = "mainMenu"
            end,
            onVolumeChange = function(newVolume)
                love.audio.setVolume(newVolume)
            end
        })
        if newVolume then
            volume = newVolume
        end
        return
    end

    -- Handle shop clicks
    if gameState == "shop" then
        UISystem.handleShopClick(x, y, {
            shopInventory = shopInventory,
            selectedShopItem = selectedShopItem,
            playerGold = PlayerSystem.getGold()
        }, {
            onSelectItem = function(index)
                selectedShopItem = index
            end,
            hasItem = hasItem,
            onPurchase = function(shopItem)
                PlayerSystem.subtractGold(shopItem.price)
                table.insert(inventory, shopItem.itemId)
                local itemData = itemRegistry[shopItem.itemId]
                showToast("Purchased " .. (itemData and itemData.name or shopItem.itemId) .. "!", {0, 1, 0})
            end,
            onInsufficientFunds = function()
                showToast("Not enough gold!", {1, 0, 0})
            end
        })
        return
    end

    -- Handle quest offer clicks
    if gameState == "questOffer" then
        UISystem.handleQuestOfferClick(x, y, questOfferData, {
            onAccept = function(quest)
                quest.active = true
                table.insert(activeQuests, quest.id)
                showToast("Quest Accepted: " .. quest.name, {1, 1, 0})
                questOfferData = nil
                DialogSystem.clearDialog()
                gameState = "playing"
            end,
            onReject = function()
                questOfferData = nil
                DialogSystem.clearDialog()
                gameState = "playing"
            end
        })
        return
    end

    -- Handle quest turn-in clicks
    if gameState == "questTurnIn" then
        -- Convert screen coordinates to canvas coordinates
        local screenWidth, screenHeight = love.graphics.getDimensions()
        local offsetX = math.floor((screenWidth - UISystem.getGameWidth() * UISystem.getScale()) / 2 / UISystem.getScale()) * UISystem.getScale()
        local offsetY = math.floor((screenHeight - UISystem.getGameHeight() * UISystem.getScale()) / 2 / UISystem.getScale()) * UISystem.getScale()
        local canvasX = (x - offsetX) / UISystem.getScale()
        local canvasY = (y - offsetY) / UISystem.getScale()

        UISystem.handleQuestTurnInClick(canvasX, canvasY, questTurnInData, inventory, {
            onCorrectItem = function(quest, npc)
                removeItem(quest.requiredItem)
                completeQuest(quest)
                -- Show reward dialog
                gameState = DialogSystem.showDialog({
                    type = "generic",
                    npc = npc,
                    text = quest.reward,
                    completedMainQuest = quest.isMainQuest
                })
                questTurnInData = nil
            end,
            onWrongItem = function()
                showToast("That's not the right item!", {1, 0.5, 0})
            end
        })
        return
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

    -- Handle cheat console keys
    if CheatConsole.keyPressed(key, {
        abilityManager = abilityManager,
        activeQuests = activeQuests,
        completedQuests = completedQuests,
        quests = quests,
        inventory = inventory,
        itemRegistry = itemRegistry,
        progressDialog = UISystem.progressDialog
    }, gameState) then
        return  -- Key was handled by console
    end

    -- Progress dialog with Enter key
    if key == "return" then
        UISystem.progressDialog()
        return
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
                    abilityManager:grantAbility(abilityId)
                    completeQuest(quest)
                end
            }
            local newState, shouldClear = DialogSystem.handleInput(callbacks)
            if newState then
                gameState = newState
                -- If transitioning to quest offer, store the quest data
                if newState == "questOffer" then
                    local currentDialog = DialogSystem.getCurrentDialog()
                    questOfferData = {npc = currentDialog.npc, quest = currentDialog.quest}
                end
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
    map = sti(MapSystem.getMapPath(currentMap))
    
    -- Update MapSystem references
    MapSystem.updateReferences(map, currentMap)
    MapSystem.calculateMapBounds()

    -- Set player position to target door location
    PlayerSystem.setPosition(door.targetX * 16 + 8, door.targetY * 16 + 8, door.targetX, door.targetY)
    player.moving = false

    -- Update camera to follow player
    updateCamera()
end

function interactWithNPC(npc)
    if npc.isIntroNPC then
        -- Show manifesto if intro already shown, otherwise show intro text
        local text = introShown and npc.manifestoText or npc.introText
        gameState = DialogSystem.showDialog({
            type = "generic",
            npc = npc,
            text = text
        })
    elseif npc.isShopkeeper then
        -- Open shop UI
        selectedShopItem = 1  -- Select first item by default
        gameState = "shop"
    elseif npc.isQuestGiver then
        local quest = quests[npc.questId]
        if not quest.active and not quest.completed then
            -- Show initial dialog, then quest offer
            local dialogText = npc.questOfferDialog or "I have a quest for you."
            gameState = DialogSystem.showDialog({
                type = "questOfferDialog",
                npc = npc,
                quest = quest,
                text = dialogText
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
        elseif not abilityManager:hasAbility(npc.givesAbility) then
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
function completeQuest(quest)
    quest.active = false
    quest.completed = true
    table.remove(activeQuests, indexOf(activeQuests, quest.id))
    table.insert(completedQuests, quest.id)

    -- Grant ability if quest provides one
    if quest.grantsAbility then
        abilityManager:grantAbility(quest.grantsAbility)

        local ability = abilityManager:getAbility(quest.grantsAbility)
        if ability then
            showToast("Learned: " .. ability.name .. "!", ability.color)
        end
    end

    -- Award gold
    if quest.goldReward and quest.goldReward > 0 then
        PlayerSystem.addGold(quest.goldReward)
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

-- Wrapper function for backward compatibility
function showToast(message, color)
    UISystem.showToast(message, color)
end


function love.mousereleased(x, y, button)
    if button == 1 then
        UISystem.stopSliderDrag()
    end
end




function love.draw()
    -- Draw to canvas
    love.graphics.setCanvas(UISystem.getCanvas())
    love.graphics.clear(0.1, 0.1, 0.1)

    -- Draw chat pane (always visible)
    UISystem.drawChatPane()

    if gameState == "mainMenu" then
        UISystem.drawMainMenu()
    elseif gameState == "settings" then
        UISystem.drawSettings(volume)
    elseif gameState == "playing" or gameState == "dialog" then
        -- Clip rendering to game area only (in canvas coordinates)
        love.graphics.setScissor(UISystem.getChatPaneWidth(), 0, UISystem.getGameWidth(), UISystem.getGameHeight())

        -- Draw world with chat pane offset
        local camX = camera.x
        local camY = camera.y
        local chatOffset = UISystem.getChatPaneWidth()

        -- Draw the Tiled map (offset by chat pane width)
        love.graphics.setColor(1, 1, 1)
        map:draw(chatOffset - camX, -camY)

        -- Draw NPCs (only on current map, offset by chat pane)
        for _, npc in ipairs(npcs) do
            if npc.map == currentMap then
                love.graphics.setColor(1, 1, 1)
                if npc.sprite.quad then
                    -- Draw from tileset using quad
                    love.graphics.draw(
                        npc.sprite.tileset, 
                        npc.sprite.quad,
                        chatOffset + npc.x - npc.size/2 - camX, 
                        npc.y - npc.size/2 - camY
                    )
                else
                    -- Draw fallback sprite
                    love.graphics.draw(
                        npc.sprite.image,
                        chatOffset + npc.x - npc.size/2 - camX, 
                        npc.y - npc.size/2 - camY
                    )
                end
                
                -- Draw quest indicator
                if npc.isQuestGiver then
                    local quest = quests[npc.questId]
                    if not quest.active and not quest.completed then
                        love.graphics.setColor(1, 1, 0)
                        love.graphics.circle("fill", chatOffset + npc.x - camX, npc.y - 10 - camY, 2)
                    elseif quest.active and hasItem(quest.requiredItem) then
                        love.graphics.setColor(0, 1, 0)
                        love.graphics.circle("fill", chatOffset + npc.x - camX, npc.y - 10 - camY, 2)
                    end
                end
            end
        end

        -- Draw player
        PlayerSystem.draw(camX, camY, abilityManager, MapSystem, chatOffset)

        -- Draw interaction prompt (offset by chat pane)
        if nearbyDoor and gameState == "playing" then
            local doorText = nearbyDoor.indoor and "[E] Exit" or "[E] Enter"
            UISystem.drawTextBox(chatOffset + UISystem.getGameWidth()/2 - 45, UISystem.getGameHeight() - 14, 90, 12, doorText, {1, 1, 1}, true)
        elseif nearbyNPC and gameState == "playing" then
            UISystem.drawTextBox(chatOffset + UISystem.getGameWidth()/2 - 45, UISystem.getGameHeight() - 14, 90, 12, "[E] Talk", {1, 1, 1}, true)
        end

        -- Draw dialog (offset by chat pane)
        if gameState == "dialog" then
            love.graphics.push()
            love.graphics.translate(chatOffset, 0)
            DialogSystem.draw(UISystem.getGameWidth(), UISystem.getGameHeight(), UISystem.drawFancyBorder)
            love.graphics.pop()
        end

        -- Draw tile grid overlay (cheat, offset by chat pane)
        love.graphics.push()
        love.graphics.translate(chatOffset, 0)
        UISystem.drawGrid(camX, camY, CheatConsole.isGridActive())
        love.graphics.pop()

        -- Draw UI hints (offset by chat pane)
        love.graphics.push()
        love.graphics.translate(chatOffset, 0)
        UISystem.drawUIHints()
        
        -- Draw gold display
        UISystem.drawGoldDisplay(PlayerSystem.getGold())
        
        -- Draw cheat indicators
        UISystem.drawIndicators(CheatConsole.isNoclipActive(), CheatConsole.isGridActive(), abilityManager)
        love.graphics.pop()

        -- Reset scissor
        love.graphics.setScissor()

    elseif gameState == "pauseMenu" then
        -- Clip rendering to game area only
        love.graphics.setScissor(UISystem.getChatPaneWidth(), 0, UISystem.getGameWidth(), UISystem.getGameHeight())

        -- Draw game world in background with chat pane offset
        local camX = camera.x
        local camY = camera.y
        local chatOffset = UISystem.getChatPaneWidth()

        -- Draw the Tiled map (offset by chat pane width)
        love.graphics.setColor(1, 1, 1)
        map:draw(chatOffset - camX, -camY)

        -- Draw NPCs (only on current map, offset by chat pane)
        for _, npc in ipairs(npcs) do
            if npc.map == currentMap then
                love.graphics.setColor(1, 1, 1)
                if npc.sprite.quad then
                    -- Draw from tileset using quad
                    love.graphics.draw(
                        npc.sprite.tileset, 
                        npc.sprite.quad,
                        npc.x - chatOffset + npc.size/2 - camX, 
                        npc.y - npc.size/2 - camY
                    )
                else
                    -- Draw fallback sprite
                    love.graphics.draw(
                        npc.sprite.image,
                        npc.x - npc.size/2 - camX, 
                        npc.y - npc.size/2 - camY
                    )
                end
            end
        end

        -- Draw player
        PlayerSystem.draw(camX, camY, abilityManager, MapSystem, chatOffset)

        -- Draw pause menu overlay
        UISystem.drawPauseMenu()

        -- Reset scissor
        love.graphics.setScissor()

    elseif gameState == "questLog" then
        UISystem.drawQuestLog(activeQuests, completedQuests, quests)
    elseif gameState == "inventory" then
        UISystem.drawInventory(inventory, itemRegistry)
    elseif gameState == "shop" then
        UISystem.drawShop(shopInventory, selectedShopItem, PlayerSystem.getGold(), inventory, itemRegistry, hasItem)
    elseif gameState == "questTurnIn" then
        -- Clip rendering to game area only
        love.graphics.setScissor(UISystem.getChatPaneWidth(), 0, UISystem.getGameWidth(), UISystem.getGameHeight())

        -- Draw game world in background with chat pane offset
        local camX = camera.x
        local camY = camera.y
        local chatOffset = UISystem.getChatPaneWidth()

        -- Draw the Tiled map (offset by chat pane width)
        love.graphics.setColor(1, 1, 1)
        map:draw(chatOffset - camX, -camY)

        -- Draw NPCs (only on current map, offset by chat pane)
        for _, npc in ipairs(npcs) do
            if npc.map == currentMap then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(npc.spriteImage, chatOffset + npc.x - npc.size/2 - camX, npc.y - npc.size/2 - camY)
            end
        end

        -- Draw player
        PlayerSystem.draw(camX, camY, abilityManager, MapSystem, chatOffset)

        -- Update game state references for UISystem
        UISystem.setGameStateRefs({
            inventory = inventory,
            itemRegistry = itemRegistry,
            questTurnInData = questTurnInData
        })
        UISystem.drawQuestTurnIn()

        -- Reset scissor
        love.graphics.setScissor()

    elseif gameState == "questOffer" then
        -- Clip rendering to game area only
        love.graphics.setScissor(UISystem.getChatPaneWidth(), 0, UISystem.getGameWidth(), UISystem.getGameHeight())

        -- Draw game world in background with chat pane offset
        local camX = camera.x
        local camY = camera.y
        local chatOffset = UISystem.getChatPaneWidth()

        -- Draw the Tiled map (offset by chat pane width)
        love.graphics.setColor(1, 1, 1)
        map:draw(chatOffset - camX, -camY)

        -- Draw NPCs (only on current map, offset by chat pane)
        for _, npc in ipairs(npcs) do
            if npc.map == currentMap then
                love.graphics.setColor(1, 1, 1)
                if npc.sprite.quad then
                    -- Draw from tileset using quad
                    love.graphics.draw(
                        npc.sprite.tileset, 
                        npc.sprite.quad,
                        chatOffset + npc.x - npc.size/2 - camX, 
                        npc.y - npc.size/2 - camY
                    )
                else
                    -- Draw fallback sprite
                    love.graphics.draw(
                        npc.sprite.image,
                        chatOffset + npc.x - npc.size/2 - camX, 
                        npc.y - npc.size/2 - camY
                    )
                end
            end
        end

        -- Draw player
        PlayerSystem.draw(camX, camY, abilityManager, MapSystem, chatOffset)

        -- Draw quest offer UI
        UISystem.drawQuestOffer(questOfferData)

        -- Reset scissor
        love.graphics.setScissor()

    elseif gameState == "winScreen" then
        UISystem.drawWinScreen(PlayerSystem.getGold(), completedQuests)
    end

    -- Draw cheat console (overlay on top of everything, in game area)
    love.graphics.push()
    love.graphics.translate(UISystem.getChatPaneWidth(), 0)
    UISystem.drawCheatConsole(CheatConsole)
    love.graphics.pop()

    -- Draw toasts (always on top, in game area)
    love.graphics.push()
    love.graphics.translate(UISystem.getChatPaneWidth(), 0)
    UISystem.drawToasts()
    love.graphics.pop()

    -- Draw canvas to screen (centered)
    love.graphics.setCanvas()

    -- Clear screen with black (for letterboxing in fullscreen)
    love.graphics.clear(0, 0, 0)

    love.graphics.setColor(1, 1, 1)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    -- Round offset to multiples of UISystem.getScale() to ensure pixel-perfect alignment
    local totalWidth = UISystem.getChatPaneWidth() + UISystem.getGameWidth()
    local offsetX = math.floor((screenWidth - totalWidth * UISystem.getScale()) / 2 / UISystem.getScale()) * UISystem.getScale()
    local offsetY = math.floor((screenHeight - UISystem.getGameHeight() * UISystem.getScale()) / 2 / UISystem.getScale()) * UISystem.getScale()
    love.graphics.draw(UISystem.getCanvas(), offsetX, offsetY, 0, UISystem.getScale(), UISystem.getScale())
end

-- All draw and click handler functions have been moved to ui_system.lua
