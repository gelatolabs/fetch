-- Libraries
local sti = require "sti"
local questData = require "quests"
local CheatConsole = require "cheat_console"
local AbilitySystem = require "ability_system"
local DialogSystem = require "dialog_system"
local UISystem = require "ui_system"
local MapSystem = require "map_system"
local PlayerSystem = require "player_system"
local ShopSystem = require "shop_system"
local AudioSystem = require "audio_system"

-- Game constants (managed by UISystem)
-- Graphics resources (managed by UISystem)

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

-- Quests (state managed by quest module)
local quests = {}
-- Point to quest module's state
local activeQuests = questData.activeQuests
local completedQuests = questData.completedQuests

-- Icon registry
local Icons = {
    cat = {x = 0, y = 192},
    book = {x = 16, y = 192},
    placeholder = {x = 32, y = 192},
    floaties = {x = 48, y = 192},
    labubu = {x = 64, y = 192},
    package = {x = 80, y = 192},
    rubber_duck = {x = 96, y = 192},
    shoes = {x = 112, y = 192},
    planks = {x = 128, y = 192},
    hat = {x = 160, y = 192},
    feathers = {x = 240, y = 192}
}

-- Item registry (single source of truth for all items)
local itemRegistry = {
    item_cat = {id = "item_cat", name = "Fluffy Cat", aliases = {"cat"}, icon = Icons.cat},
    item_book = {id = "item_book", name = "Ancient Tome", aliases = {"book"}, icon = Icons.book},
    item_package = {id = "item_package", name = "Sealed Package", aliases = {"package"}, icon = Icons.package},
    item_floaties = {id = "item_floaties", name = "Swimming Floaties", aliases = {"floaties", "floaty"}, icon = Icons.floaties},
    item_wood = {id = "item_wood", name = "Wooden Planks", aliases = {"wood", "planks"}, icon = Icons.planks},
    item_shoes = {id = "item_shoes", name = "Jumping Shoes", aliases = {"shoes", "boots", "jumping shoes"}, icon = Icons.shoes},
    item_rubber_duck = {id = "item_rubber_duck", name = "Rubber Duck", aliases = {"duck", "rubber duck"}, icon = Icons.rubber_duck, shopInfo = {price = 10, description = "A cheerful rubber duck. Perfect for bath time or just keeping you company!"}},
    item_labubu = {id = "item_labubu", name = "Labubu", aliases = {"labubu"}, icon = Icons.labubu, shopInfo = {price = 10000, description = "An extremely rare and adorable Labubu collectible. Highly sought after by collectors!"}},
    item_wizard_hat = {id = "item_wizard_hat", name = "Wizard's Hat", aliases = {"hat"}, icon = Icons.hat},
    item_goose_feathers = {id = "item_goose_feathers", name = "Goose Feathers", aliases = {"feathers", "goose feathers"}, icon = Icons.feathers},
}

-- UI state
local nearbyNPC = nil
local nearbyDoor = nil
local questTurnInData = nil  -- Stores {npc, quest} for quest turn-in UI
local questOfferData = nil  -- Stores {npc, quest} for quest offer UI
local winScreenTimer = 0
local introShown = false

-- Toast system (managed by UISystem)

-- Door/Map transition system (managed by MapSystem)
local currentMap = "map"

-- Map transition state
local mapTransition = {
    active = false,
    fromMap = nil,
    toMap = nil,
    fromMapObj = nil,
    toMapObj = nil,
    direction = nil, -- "north", "south", "east", "west"
    progress = 0, -- 0 to 1
    duration = 0.8, -- seconds
    targetDoor = nil,
    -- Player screen position transition
    playerStartScreenX = 0,
    playerStartScreenY = 0,
    playerEndScreenX = 0,
    playerEndScreenY = 0
}

-- Camera helper functions
local function centerCameraOnPlayer()
    -- Always center on the game viewport (320x240), regardless of chat pane visibility
    camera.x = player.x - UISystem.getGameWidth() / 2
    camera.y = player.y - UISystem.getGameHeight() / 2
end

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

local function updateCamera()
    centerCameraOnPlayer()
    clampCameraToMapBounds()
end

function love.load()
    love.window.setTitle("Go Fetch")

    -- Initialize UI system (sets up window, graphics, canvas, and fonts)
    UISystem.init()

    -- Initialize Player system (includes ability registration)
    PlayerSystem.init(UISystem)
    player = PlayerSystem.getPlayer()

    -- Initialize Shop system
    ShopSystem.init(itemRegistry)

    -- Initialize Audio system
    AudioSystem.init()
    AudioSystem.playMusic("intro")

    -- Load Tiled map
    map = sti(MapSystem.getMapPath(currentMap))
    
    -- Initialize MapSystem
    MapSystem.init(map, world, CheatConsole, questData.npcs, currentMap)
    MapSystem.calculateMapBounds()

    -- Load game data
    loadGameData()
    
    -- Initialize quest lock states
    questData.initializeQuestLocks()
    
    -- Sync intro shown state
    questData.introShown = introShown
    
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
    for _, npcData in pairs(questData.npcs) do
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
    end

end


function love.update(dt)
    -- Update map(s)
    if mapTransition.active then
        map:update(dt)
        if mapTransition.toMapObj then
            mapTransition.toMapObj:update(dt)
        end

        -- Update transition progress
        mapTransition.progress = mapTransition.progress + dt / mapTransition.duration

        if mapTransition.progress >= 1 then
            -- Transition complete
            mapTransition.active = false
            currentMap = mapTransition.toMap
            map = mapTransition.toMapObj

            -- Update MapSystem references
            MapSystem.updateReferences(map, currentMap)
            MapSystem.calculateMapBounds()

            -- Set player position to target door location with offset
            PlayerSystem.setPosition(mapTransition.targetX * 16 + 8, mapTransition.targetY * 16 + 8, mapTransition.targetX, mapTransition.targetY)
            player.moving = false

            -- Update camera
            updateCamera()

            -- Clear transition state
            mapTransition.fromMap = nil
            mapTransition.toMap = nil
            mapTransition.fromMapObj = nil
            mapTransition.toMapObj = nil
            mapTransition.targetDoor = nil
            mapTransition.targetX = nil
            mapTransition.targetY = nil
        end
    else
        map:update(dt)
    end

    -- Update toasts
    UISystem.updateToasts(dt)

    -- Update chat animation
    UISystem.updateChat(dt)

    -- Handle chat pane music switching
    AudioSystem.updateChatPaneMusic(UISystem.isChatPaneVisible())

    -- Handle win screen timer
    if gameState == "winScreen" then
        winScreenTimer = winScreenTimer + dt
        if winScreenTimer >= 145 then  -- 2 minutes 25 seconds (145 seconds)
            love.event.quit()
        end
        return
    end

    if gameState == "playing" and not CheatConsole.isOpen() then
        -- Update player movement (only if not transitioning)
        if not mapTransition.active then
            PlayerSystem.update(dt, heldKeys)
        end

        -- Update camera to follow player
        updateCamera()

        -- Check for nearby NPCs (only on current map, not during transition)
        if not mapTransition.active then
            nearbyNPC = nil
            for _, npc in pairs(questData.npcs) do
                if npc.map == currentMap then
                    local dist = math.sqrt((player.x - npc.x)^2 + (player.y - npc.y)^2)
                    if dist < 20 then
                        nearbyNPC = npc
                        break
                    end
                end
            end

            -- Check for nearby doors
            nearbyDoor = MapSystem.findDoorAt(player.gridX, player.gridY)
        end
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
                AudioSystem.playMusic("theme")
                -- Show intro dialog if not shown yet
                if not introShown then
                    introShown = true
                    -- Find the intro NPC
                    for _, npc in pairs(questData.npcs) do
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
                AudioSystem.setVolume(newVolume)
            end
        })
        if newVolume then
            volume = newVolume
        end
        return
    end

    -- Handle shop clicks
    if gameState == "shop" then
        ShopSystem.handleClick(x, y, function(shopItem)
            if shopItem then
                -- Purchase the item
                local success, message, color = ShopSystem.purchaseItem(shopItem, itemRegistry)
                showToast(message, color)
            else
                -- Insufficient funds (nil indicates this)
                showToast("Not enough gold!", {1, 0, 0})
            end
        end)
        return
    end

    -- Handle quest offer clicks
    if gameState == "questOffer" then
        UISystem.handleQuestOfferClick(x, y, questOfferData, {
            onAccept = function(quest)
                questData.activateQuest(quest.id)
                table.insert(activeQuests, quest.id)
                showToast("Quest Accepted: " .. quest.name, {1, 1, 0})
                questOfferData = nil
                DialogSystem.clearDialog()
                AudioSystem.stopManifestoMusic()
                gameState = "playing"
            end,
            onReject = function()
                questOfferData = nil
                DialogSystem.clearDialog()
                AudioSystem.stopManifestoMusic()
                gameState = "playing"
            end
        })
        return
    end

    -- Handle quest turn-in clicks
    if gameState == "questTurnIn" then
        -- Convert screen coordinates to canvas coordinates
        -- Need to account for canvas shift during transition
        local screenWidth, screenHeight = love.graphics.getDimensions()
        local chatPaneWidth = UISystem.getChatPaneWidth()
        local gameWidth = UISystem.getGameWidth()
        local gameHeight = UISystem.getGameHeight()
        local totalWidth = chatPaneWidth + gameWidth
        local scale = UISystem.getScale()
        
        -- Get transition progress to account for canvas shift
        local transitionProgress = UISystem.getChatPaneTransitionProgress()
        local currentVisibleWidth = gameWidth + (chatPaneWidth * transitionProgress)
        
        local offsetX = math.floor((screenWidth - currentVisibleWidth * scale) / 2 / scale) * scale
        local offsetY = math.floor((screenHeight - gameHeight * scale) / 2 / scale) * scale
        
        -- Account for canvas shift to hide chat pane initially
        offsetX = offsetX - (chatPaneWidth * (1 - transitionProgress) * scale)
        
        local canvasX = (x - offsetX) / scale
        local canvasY = (y - offsetY) / scale

        UISystem.handleQuestTurnInClick(canvasX, canvasY, questTurnInData, PlayerSystem.getInventory(), {
            onCorrectItem = function(quest, npc)
                PlayerSystem.removeItem(quest.requiredItem)
                questData.completeQuest(quest.id)
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

    -- Handle cheat console keys first
    if CheatConsole.keyPressed(key, {
        abilityManager = PlayerSystem.getAbilityManager(),
        activeQuests = activeQuests,
        completedQuests = completedQuests,
        quests = questData.questData,
        inventory = PlayerSystem.getInventory(),
        itemRegistry = itemRegistry
    }, gameState) then
        return  -- Key was handled by console
    end

    -- Track movement keys for input priority (only during gameplay)
    if gameState == "playing" and (key == "w" or key == "up" or key == "s" or key == "down" or
       key == "a" or key == "left" or key == "d" or key == "right") then
        -- Remove if already in list
        for i = #heldKeys, 1, -1 do
            if heldKeys[i] == key then
                table.remove(heldKeys, i)
            end
        end
        -- Add to end (most recent)
        table.insert(heldKeys, key)
    end

    -- Normal game controls
    if key == "space" or key == "e" then
        if gameState == "playing" and nearbyDoor and not UISystem.isChatPaneVisible() then
            enterDoor(nearbyDoor)
        elseif gameState == "playing" and nearbyNPC and not UISystem.isChatPaneVisible() then
            questData.interactWithNPC(nearbyNPC)
            gameState = questData.gameState
            questTurnInData = questData.questTurnInData
        elseif gameState == "dialog" then
            local callbacks = {
                onQuestAccept = function(quest)
                    questData.activateQuest(quest.id)
                    table.insert(activeQuests, quest.id)
                    showToast("Quest Accepted: " .. quest.name, {1, 1, 0})
                end,
                onQuestComplete = function(quest)
                    PlayerSystem.removeItem(quest.requiredItem)
                    questData.completeQuest(quest.id)
                    gameState = questData.gameState
                end,
                onItemReceive = function(itemId)
                    PlayerSystem.addItem(itemId)
                    local itemData = itemRegistry[itemId]
                    local itemName = itemData and itemData.name or itemId
                    showToast("Received: " .. itemName, {0.7, 0.5, 0.9})
                end,
                onAbilityLearn = function(abilityId, quest)
                    PlayerSystem.grantAbility(abilityId)
                    questData.completeQuest(quest.id)
                    gameState = questData.gameState
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
                -- Call onComplete callback if it exists before clearing
                local currentDialog = DialogSystem.getCurrentDialog()
                if currentDialog and currentDialog.onComplete then
                    currentDialog.onComplete()
                end
                DialogSystem.clearDialog()
                -- Stop manifesto music if it was playing
                AudioSystem.stopManifestoMusic()
            end
        end
    elseif key == "l" then
        if gameState == "playing" and not UISystem.isChatPaneVisible() then
            gameState = "questLog"
        elseif gameState == "questLog" then
            gameState = "playing"
        end
    elseif key == "q" then
        if gameState == "playing" then
            AudioSystem.playQuack()
        end
    elseif key == "i" then
        if gameState == "playing" and not UISystem.isChatPaneVisible() then
            gameState = "inventory"
        elseif gameState == "inventory" then
            gameState = "playing"
        end
    elseif key == "left" or key == "," or key == "<" then
        if gameState == "questTurnIn" then
            UISystem.questTurnInPrevPage()
        end
    elseif key == "right" or key == "." or key == ">" then
        if gameState == "questTurnIn" then
            UISystem.questTurnInNextPage()
        end
    elseif key == "escape" then
        if gameState == "playing" then
            gameState = "pauseMenu"
        elseif gameState == "pauseMenu" then
            gameState = "playing"
        elseif gameState == "shop" then
            gameState = "playing"
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
    local transitionDirection = door.direction

    -- Calculate target position with offset
    local targetX = door.targetX + (door.offsetX or 0)
    local targetY = door.targetY + (door.offsetY or 0)

    -- Update music based on target map
    -- Track music for indoor rooms (shop, throne room)
    if door.targetMap == "shop" then
        AudioSystem.playMusic("themeFunky")
    elseif door.targetMap == "throneroom" then
        AudioSystem.playMusic("throneRoom")
    elseif currentMap == "shop" or currentMap == "throneroom" then
        -- Leaving an indoor room - return to normal theme
        AudioSystem.playMusic("theme")
    end

    -- If no direction, use instant transition
    if not transitionDirection then
        -- Load the new map
        currentMap = door.targetMap
        map = sti(MapSystem.getMapPath(currentMap))

        -- Update MapSystem references
        MapSystem.updateReferences(map, currentMap)
        MapSystem.calculateMapBounds()

        -- Set player position to target door location with offset
        PlayerSystem.setPosition(targetX * 16 + 8, targetY * 16 + 8, targetX, targetY)
        player.moving = false

        -- Update camera to follow player
        updateCamera()
        return
    end

    -- Calculate player screen positions for transition
    -- Start position: where the player currently is on screen (relative to camera)
    local gameWidth = UISystem.getGameWidth()
    local gameHeight = UISystem.getGameHeight()
    local startScreenX = player.x - camera.x
    local startScreenY = player.y - camera.y

    -- End position: where the player will be on screen after transition
    -- Calculate the final world position where player will be
    local finalPlayerX = targetX * 16 + 8
    local finalPlayerY = targetY * 16 + 8

    -- Calculate what the camera position will be after transition
    -- The camera centers on the player and gets clamped to map bounds
    local toMapObj = sti(MapSystem.getMapPath(door.targetMap))
    local finalCameraX = finalPlayerX - gameWidth / 2
    local finalCameraY = finalPlayerY - gameHeight / 2

    -- Calculate bounds for target map to clamp camera
    if toMapObj.width and toMapObj.height then
        local targetMinX = 0
        local targetMinY = 0
        local targetMaxX = toMapObj.width * world.tileSize
        local targetMaxY = toMapObj.height * world.tileSize

        -- Apply camera clamping logic
        local mapWidth = targetMaxX - targetMinX
        local mapHeight = targetMaxY - targetMinY

        if mapWidth > gameWidth then
            finalCameraX = math.max(targetMinX, math.min(finalCameraX, targetMaxX - gameWidth))
        else
            finalCameraX = targetMinX + (mapWidth - gameWidth) / 2
        end

        if mapHeight > gameHeight then
            finalCameraY = math.max(targetMinY, math.min(finalCameraY, targetMaxY - gameHeight))
        else
            finalCameraY = targetMinY + (mapHeight - gameHeight) / 2
        end
    end

    -- Calculate end screen position based on final player and clamped camera positions
    local endScreenX = finalPlayerX - finalCameraX
    local endScreenY = finalPlayerY - finalCameraY

    -- Start sliding transition for outdoor maps
    mapTransition.active = true
    mapTransition.fromMap = currentMap
    mapTransition.toMap = door.targetMap
    mapTransition.fromMapObj = map
    mapTransition.toMapObj = sti(MapSystem.getMapPath(door.targetMap))
    mapTransition.direction = transitionDirection
    mapTransition.progress = 0
    mapTransition.targetDoor = door
    mapTransition.targetX = targetX
    mapTransition.targetY = targetY
    mapTransition.playerStartScreenX = startScreenX
    mapTransition.playerStartScreenY = startScreenY
    mapTransition.playerEndScreenX = endScreenX
    mapTransition.playerEndScreenY = endScreenY
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


-- Helper function to draw a map with NPCs
function drawMapAndNPCs(mapObj, mapName, camX, camY, chatOffset, offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    -- Draw the Tiled map
    love.graphics.setColor(1, 1, 1)
    mapObj:draw(chatOffset - camX + offsetX, -camY + offsetY)

    -- Draw NPCs (only on this map)
    for _, npc in pairs(questData.npcs) do
        if npc.map == mapName then
            love.graphics.setColor(1, 1, 1)
            if npc.sprite.quad then
                -- Draw from tileset using quad
                love.graphics.draw(
                    npc.sprite.tileset,
                    npc.sprite.quad,
                    chatOffset + npc.x - npc.size/2 - camX + offsetX,
                    npc.y - npc.size/2 - camY + offsetY
                )
            else
                -- Draw fallback sprite
                love.graphics.draw(
                    npc.sprite.image,
                    chatOffset + npc.x - npc.size/2 - camX + offsetX,
                    npc.y - npc.size/2 - camY + offsetY
                )
            end

            -- Draw quest indicator
            if npc.isQuestGiver then
                local quest, questConfig = questData.getAvailableQuestForNPC(npc.id)
                if quest then
                    if not quest.active and not quest.completed then
                        -- Yellow indicator for available quest
                        love.graphics.setColor(1, 1, 0)
                        love.graphics.circle("fill", chatOffset + npc.x - camX + offsetX, npc.y - 10 - camY + offsetY, 2)
                    elseif quest.active and quest.requiredItem and PlayerSystem.hasItem(quest.requiredItem) then
                        -- Green indicator for quest ready to turn in
                        love.graphics.setColor(0, 1, 0)
                        love.graphics.circle("fill", chatOffset + npc.x - camX + offsetX, npc.y - 10 - camY + offsetY, 2)
                    end
                end
            end
        end
    end
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
        -- Draw world with chat pane offset (always offset by chat pane width in canvas)
        local camX = camera.x
        local camY = camera.y
        local chatOffset = UISystem.getChatPaneWidth()
        
        -- Clip rendering to game area only (always at chat pane offset in canvas)
        love.graphics.setScissor(UISystem.getChatPaneWidth(), 0, UISystem.getGameWidth(), UISystem.getGameHeight())

        -- Handle map transitions
        if mapTransition.active then
            local progress = mapTransition.progress
            local eased = 1 - (1 - progress)^3 -- ease-out cubic
            local gameHeight = UISystem.getGameHeight()
            local gameWidth = UISystem.getGameWidth()

            if mapTransition.direction == "up" then
                -- Moving up: new map slides in from top
                -- Show bottom of new map touching top of old map, then slide down
                local slideOffset = eased * gameHeight

                -- For the new map, we need to show its BOTTOM edge at the top
                -- This means adjusting camY to point to the bottom of the new map
                local newMapCamY = MapSystem.getMapHeight(mapTransition.toMapObj) - gameHeight

                -- Draw new map above (showing its bottom edge)
                drawMapAndNPCs(mapTransition.toMapObj, mapTransition.toMap, camX, newMapCamY, chatOffset, 0, -gameHeight + slideOffset)
                -- Draw old map below
                drawMapAndNPCs(mapTransition.fromMapObj, mapTransition.fromMap, camX, camY, chatOffset, 0, slideOffset)
            elseif mapTransition.direction == "down" then
                local slideOffset = -eased * gameHeight
                local newMapCamY = MapSystem.getMapMinY(mapTransition.toMapObj)
                local oldMapCamY = MapSystem.getMapHeight(mapTransition.fromMapObj) - gameHeight
                drawMapAndNPCs(mapTransition.toMapObj, mapTransition.toMap, camX, newMapCamY, chatOffset, 0, gameHeight + slideOffset)
                drawMapAndNPCs(mapTransition.fromMapObj, mapTransition.fromMap, camX, oldMapCamY, chatOffset, 0, slideOffset)
            elseif mapTransition.direction == "right" then
                local slideOffset = -eased * gameWidth
                local newMapCamX = MapSystem.getMapMinX(mapTransition.toMapObj)
                local oldMapCamX = MapSystem.getMapWidth(mapTransition.fromMapObj) - gameWidth
                drawMapAndNPCs(mapTransition.toMapObj, mapTransition.toMap, newMapCamX, camY, chatOffset, gameWidth + slideOffset, 0)
                drawMapAndNPCs(mapTransition.fromMapObj, mapTransition.fromMap, oldMapCamX, camY, chatOffset, slideOffset, 0)
            elseif mapTransition.direction == "left" then
                local slideOffset = eased * gameWidth
                local newMapCamX = MapSystem.getMapWidth(mapTransition.toMapObj) - gameWidth
                local oldMapCamX = MapSystem.getMapMinX(mapTransition.fromMapObj)
                drawMapAndNPCs(mapTransition.toMapObj, mapTransition.toMap, newMapCamX, camY, chatOffset, -gameWidth + slideOffset, 0)
                drawMapAndNPCs(mapTransition.fromMapObj, mapTransition.fromMap, oldMapCamX, camY, chatOffset, slideOffset, 0)
            end
        else
            -- Normal rendering (no transition)
            drawMapAndNPCs(map, currentMap, camX, camY, chatOffset)
        end

        -- Draw player
        if mapTransition.active then
            -- During transition, interpolate player's screen position
            local progress = mapTransition.progress
            local eased = 1 - (1 - progress)^3 -- ease-out cubic
            local interpolatedScreenX = mapTransition.playerStartScreenX + (mapTransition.playerEndScreenX - mapTransition.playerStartScreenX) * eased
            local interpolatedScreenY = mapTransition.playerStartScreenY + (mapTransition.playerEndScreenY - mapTransition.playerStartScreenY) * eased

            -- Draw player at the interpolated screen position
            love.graphics.setColor(1, 1, 1)
            local spriteSet = PlayerSystem.getSpriteSet()
            local currentQuad = spriteSet[player.lastVertical][player.moving and (player.walkFrame + 1) or 1]
            local scaleX = (player.facing == "left") and -1 or 1
            local offsetX = (player.facing == "left") and player.size or 0
            love.graphics.draw(
                PlayerSystem.getTileset(),
                currentQuad,
                interpolatedScreenX - player.size/2 + offsetX + chatOffset,
                interpolatedScreenY - player.size/2 - player.jumpHeight,
                0,
                scaleX,
                1
            )
        else
            PlayerSystem.draw(camX, camY, chatOffset)
        end

        -- Draw interaction prompt (offset by chat pane)
        if nearbyDoor and gameState == "playing" then
            local doorText = "[E] " .. nearbyDoor.text
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
        UISystem.drawIndicators(CheatConsole.isNoclipActive(), CheatConsole.isGridActive(), PlayerSystem.getAbilityManager())
        love.graphics.pop()

        -- Reset scissor
        love.graphics.setScissor()

    elseif gameState == "pauseMenu" then
        -- Draw game world in background with chat pane offset
        local camX = camera.x
        local camY = camera.y
        local chatOffset = UISystem.getChatPaneWidth()
        
        -- Clip rendering to game area only
        love.graphics.setScissor(UISystem.getChatPaneWidth(), 0, UISystem.getGameWidth(), UISystem.getGameHeight())

        -- Draw the map and NPCs
        drawMapAndNPCs(map, currentMap, camX, camY, chatOffset)

        -- Draw player
        PlayerSystem.draw(camX, camY, chatOffset)

        -- Draw pause menu overlay
        UISystem.drawPauseMenu()

        -- Reset scissor
        love.graphics.setScissor()

    elseif gameState == "questLog" then
        UISystem.drawQuestLog(activeQuests, completedQuests, questData.questData)
    elseif gameState == "inventory" then
        UISystem.drawInventory(PlayerSystem.getInventory(), itemRegistry)
    elseif gameState == "shop" then
        -- Draw gold display at top
        love.graphics.push()
        love.graphics.translate(UISystem.getChatPaneWidth(), 0)
        UISystem.drawGoldDisplay(PlayerSystem.getGold())
        love.graphics.pop()
        
        -- Draw shop UI
        ShopSystem.draw(itemRegistry)
    elseif gameState == "questTurnIn" then
        -- Draw game world in background with chat pane offset
        local camX = camera.x
        local camY = camera.y
        local chatOffset = UISystem.getChatPaneWidth()
        
        -- Clip rendering to game area only
        love.graphics.setScissor(UISystem.getChatPaneWidth(), 0, UISystem.getGameWidth(), UISystem.getGameHeight())

        -- Draw the map and NPCs
        drawMapAndNPCs(map, currentMap, camX, camY, chatOffset)

        -- Draw player
        PlayerSystem.draw(camX, camY, chatOffset)

        -- Update game state references for UISystem
        UISystem.setGameStateRefs({
            inventory = PlayerSystem.getInventory(),
            itemRegistry = itemRegistry,
            questTurnInData = questTurnInData
        })
        UISystem.drawQuestTurnIn()

        -- Reset scissor
        love.graphics.setScissor()

    elseif gameState == "questOffer" then
        -- Draw game world in background with chat pane offset
        local camX = camera.x
        local camY = camera.y
        local chatOffset = UISystem.getChatPaneWidth()
        
        -- Clip rendering to game area only
        love.graphics.setScissor(UISystem.getChatPaneWidth(), 0, UISystem.getGameWidth(), UISystem.getGameHeight())

        -- Draw the map and NPCs
        drawMapAndNPCs(map, currentMap, camX, camY, chatOffset)

        -- Draw player
        PlayerSystem.draw(camX, camY, chatOffset)

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

    -- Draw canvas to screen
    love.graphics.setCanvas()

    -- Clear screen with black (for letterboxing in fullscreen)
    love.graphics.clear(0, 0, 0)

    love.graphics.setColor(1, 1, 1)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Get transition progress (0 = hidden, 1 = fully visible)
    local transitionProgress = UISystem.getChatPaneTransitionProgress()
    
    local chatPaneWidth = UISystem.getChatPaneWidth()
    local gameWidth = UISystem.getGameWidth()
    local gameHeight = UISystem.getGameHeight()
    local totalWidth = chatPaneWidth + gameWidth
    local scale = UISystem.getScale()
    
    local offsetY = math.floor((screenHeight - gameHeight * scale) / 2 / scale) * scale
    
    -- The canvas layout: [chat: 0-106][game: 106-426]
    -- Initially: show game area centered (canvas at x such that game area is centered)
    -- Finally: show full canvas centered
    
    -- When progress = 0: center the game portion (106-426) in the window
    -- When progress = 1: center the full canvas (0-426) in the window
    local currentVisibleWidth = gameWidth + (chatPaneWidth * transitionProgress)
    local offsetX = math.floor((screenWidth - currentVisibleWidth * scale) / 2 / scale) * scale
    
    -- Offset the canvas drawing so the right portion is visible
    -- We need to shift left by chatPaneWidth * (1 - progress) to hide the chat initially
    offsetX = offsetX - (chatPaneWidth * (1 - transitionProgress) * scale)
    
    -- Use scissor to clip what's visible (hide the chat pane when off-screen)
    local scissorX = math.floor((screenWidth - currentVisibleWidth * scale) / 2)
    love.graphics.setScissor(scissorX, offsetY, currentVisibleWidth * scale, gameHeight * scale)
    
    -- Draw canvas with shader effects (all shader logic is in UISystem)
    UISystem.drawCanvasWithShaders(offsetX, offsetY, scale)
    
    -- Clear scissor
    love.graphics.setScissor()
end

-- All draw and click handler functions have been moved to ui_system.lua
