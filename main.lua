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
local Camera = require "camera"

-- Game constants (managed by UISystem)
-- Graphics resources (managed by UISystem)

-- Game state
-- mainMenu, settings, playing, dialog, questLog, inventory, questTurnIn, shop
local gameState = "mainMenu"
local previousState = nil  -- Track where we came from (for settings back button)

-- Settings
local volume = 0.5

-- Input tracking for movement priority
local heldKeys = {}

-- Player reference (managed by PlayerSystem)
local player = nil

-- World map (managed by MapSystem)
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
    feathers = {x = 240, y = 192},
    toilet_paper_piece = {x = 176, y = 208},
    sock = {x = 208, y = 192},
    glitched_item = {x = 192, y = 192},
    underpants = {x = 272, 192}
}

-- Item registry (single source of truth for all items)
local itemRegistry = {
    item_cat = {id = "item_cat", name = "Fluffy Cat", aliases = {"cat"}, icon = Icons.cat},
    item_book = {id = "item_book", name = "Ancient Tome", aliases = {"book"}, icon = Icons.book},
    item_package = {id = "item_package", name = "Sealed Package", aliases = {"package"}, icon = Icons.package},
    item_floaties = {id = "item_floaties", name = "Swimming Floaties", aliases = {"floaties", "floaty"}, icon = Icons.floaties},
    item_wood = {id = "item_wood", name = "Wooden Planks", aliases = {"wood", "planks"}, icon = Icons.planks},
    item_shoes = {id = "item_shoes", name = "Running Shoes", aliases = {"shoes", "boots", "running shoes"}, icon = Icons.shoes},
    item_rubber_duck = {id = "item_rubber_duck", name = "Rubber Duck", aliases = {"duck", "rubber duck"}, icon = Icons.rubber_duck, shopInfo = {price = 10, description = "A cheerful rubber duck. Perfect for bath time or just keeping you company!"}},
    item_labubu = {id = "item_labubu", name = "Labubu", aliases = {"labubu"}, icon = Icons.labubu, shopInfo = {price = 10000, description = "An extremely rare and adorable Labubu collectible. Highly sought after by collectors!"}},
    item_wizard_hat = {id = "item_wizard_hat", name = "Wizard's Hat", aliases = {"hat"}, icon = Icons.hat},
    item_goose_feathers = {id = "item_goose_feathers", name = "Goose Feathers", aliases = {"feathers", "goose feathers"}, icon = Icons.feathers},
    item_toilet_paper_piece = {id = "item_toilet_paper_piece", name = "Toilet Paper", aliases = {"toilet_paper_piece", "tp"}, icon = Icons.toilet_paper_piece, hidden = true},
    item_sock = {id = "item_sock", name = "Socks", aliases = {"socks", "sock"}, icon = Icons.sock},
    item_glitched_item = {id = "item_glitched_item", name = "Glitched Item", aliases = {"glitched_item"}, icon = Icons.glitched_item},
    item_underpants = {id = "item_underpants", name = "Underpants", aliases = {"underpants"}, icon = Icons.underpants}
}

-- UI state
local nearbyNPC = nil
local nearbyDoor = nil
local questTurnInData = nil  -- Stores {npc, quest} for quest turn-in UI
local questOfferData = nil  -- Stores {npc, quest} for quest offer UI
local winScreenTimer = 0
local introShown = false

-- Toast system (managed by UISystem)

-- Pickup system
local pickups = {}  -- Table of active pickups: {map, x, y, gridX, gridY, itemId, spriteX, spriteY}
local pickupTileset = nil  -- Loaded in loadGameData()

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

-- Helper function to check if a pickup should be visible
local function isPickupVisible(pickup)
    local itemData = itemRegistry[pickup.itemId]
    if not itemData then return true end

    -- If item is not marked as hidden, it's always visible
    if not itemData.hidden then return true end

    -- Item is hidden, check if any active quest shows it
    for _, questId in ipairs(activeQuests) do
        local quest = questData.questData[questId]
        if quest and quest.showsPickup == pickup.itemId then
            return true
        end
    end

    -- Hidden and no quest shows it
    return false
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

    -- Set itemRegistry reference for quest system
    questData.itemRegistry = itemRegistry

    -- Initialize Audio system
    AudioSystem.init()
    AudioSystem.setVolume(volume)
    AudioSystem.playMusic("intro")

    -- Initialize MapSystem (loads initial map internally)
    MapSystem.init(world, questData.npcs, "map")

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
    
    -- Initialize Camera system
    Camera.init(world)
    local player = PlayerSystem.getPlayer()
    Camera.update(player.x, player.y)
end

-- Helper function to calculate sprite quad from tile ID
local function calculateQuadFromTileID(tileID, tilesetWidth, tilesetColumns)
    -- Tile IDs start at 0, positioned left to right, top to bottom
    local col = tileID % tilesetColumns
    local row = math.floor(tileID / tilesetColumns)
    local spriteX = col * 16
    local spriteY = row * 16
    return spriteX, spriteY
end

-- Helper function to update NPC sprite to a variant
function updateNPCVariant(npcID, variant, mapObj, npcTileset, tilesetColumns)
    local npc = questData.npcs[npcID]
    if not npc then return end

    local variantType = npcID .. variant

    -- Find the tile ID for this variant
    for _, tile in ipairs(mapObj.tilesets[1].tiles or {}) do
        if tile.type == variantType then
            local spriteX, spriteY = calculateQuadFromTileID(tile.id, 320, tilesetColumns)
            npc.spriteX = spriteX
            npc.spriteY = spriteY
            npc.sprite.quad = love.graphics.newQuad(
                spriteX, spriteY,
                16, 16,
                npcTileset:getDimensions()
            )
            return
        end
    end
end

-- Helper function to extract NPC data from map NPCs layer
local function extractNPCsFromMap(mapObj, mapName, tilesetColumns)
    local npcInstances = {}

    -- Find NPCs layer
    for _, layer in ipairs(mapObj.layers) do
        if layer.name == "NPCs" then
            -- STI stores layer data in a special format:
            -- layer.data is an array where each element is a row (table)
            -- Each row table has column indices as keys pointing to tile objects
            for y = 1, layer.height do
                local row = layer.data[y]
                if row and type(row) == "table" then
                    for x, tile in pairs(row) do
                        if tile and type(tile) == "table" then
                            local gid = tile.gid or tile.id or 0

                            if gid ~= 0 then
                                -- x and y are already 1-indexed, convert to 0-indexed for grid
                                local gridX = x - 1
                                local gridY = y - 1
                                local posX = gridX * 16 + 8
                                local posY = gridY * 16 + 8

                                -- Check for flip flags
                                local flipX = false
                                if gid >= 2147483648 then
                                    flipX = true
                                    gid = gid - 2147483648
                                end

                                -- Find tile type from tileset
                                -- STI GIDs are already offset by firstgid, so we need to subtract it
                                local tilesetFirstGid = mapObj.tilesets[1].firstgid or 1
                                local tileId = gid - tilesetFirstGid

                                local npcType = nil
                                for _, tileData in ipairs(mapObj.tilesets[1].tiles or {}) do
                                    if tileData.id == tileId then
                                        npcType = tileData.type
                                        break
                                    end
                                end

                                if npcType then
                                    -- Calculate sprite position from tile ID
                                    local spriteX, spriteY = calculateQuadFromTileID(tileId, 320, tilesetColumns)

                                    table.insert(npcInstances, {
                                        type = npcType,
                                        map = mapName,
                                        x = posX,
                                        y = posY,
                                        gridX = gridX,
                                        gridY = gridY,
                                        spriteX = spriteX,
                                        spriteY = spriteY,
                                        flippedX = flipX
                                    })
                                end
                            end
                        end
                    end
                end
            end
            break
        end
    end

    return npcInstances
end

-- Helper function to extract pickup data from map Pickups layer
local function extractPickupsFromMap(mapObj, mapName, tilesetColumns)
    local pickupInstances = {}

    for _, layer in ipairs(mapObj.layers) do
        if layer.name == "Pickups" then
            for y = 1, layer.height do
                local row = layer.data[y]
                if row and type(row) == "table" then
                    for x, tile in pairs(row) do
                        if tile and type(tile) == "table" then
                            local gid = tile.gid or tile.id or 0

                            if gid ~= 0 then
                                local gridX = x - 1
                                local gridY = y - 1
                                local posX = gridX * 16 + 8
                                local posY = gridY * 16 + 8

                                local tilesetFirstGid = mapObj.tilesets[1].firstgid or 1
                                local tileId = gid - tilesetFirstGid

                                local itemType = nil
                                for _, tileData in ipairs(mapObj.tilesets[1].tiles or {}) do
                                    if tileData.id == tileId then
                                        itemType = tileData.type
                                        break
                                    end
                                end

                                if itemType and itemType:match("^item::") then
                                    -- Extract item ID (item::cat -> item_cat)
                                    local itemId = itemType:gsub("::", "_")

                                    local spriteX, spriteY = calculateQuadFromTileID(tileId, 320, tilesetColumns)

                                    table.insert(pickupInstances, {
                                        map = mapName,
                                        x = posX,
                                        y = posY,
                                        gridX = gridX,
                                        gridY = gridY,
                                        itemId = itemId,
                                        spriteX = spriteX,
                                        spriteY = spriteY
                                    })
                                elseif itemType and itemType:match("^gold") then
                                    -- Handle gold pickups (gold1, gold2, gold3)
                                    local goldAmounts = {gold1 = 250, gold2 = 500, gold3 = 1000}
                                    local goldAmount = goldAmounts[itemType]

                                    local spriteX, spriteY = calculateQuadFromTileID(tileId, 320, tilesetColumns)

                                    table.insert(pickupInstances, {
                                        map = mapName,
                                        x = posX,
                                        y = posY,
                                        gridX = gridX,
                                        gridY = gridY,
                                        isGold = true,
                                        goldAmount = goldAmount,
                                        spriteX = spriteX,
                                        spriteY = spriteY
                                    })
                                end
                            end
                        end
                    end
                end
            end
            break
        end
    end

    return pickupInstances
end

function loadGameData()
    -- Load NPC/pickup tileset
    local npcTileset = love.graphics.newImage("tiles/fetch-tileset.png")
    pickupTileset = npcTileset  -- Store for pickup rendering
    local tilesetColumns = 20 -- 320px / 16px = 20 columns

    -- Map names to scan
    local mapNames = {"map", "mapeast", "mapwest", "mapnorth", "mapsouth", "shop", "jail", "throneroom"}

    -- Extract all NPC instances from all maps
    local allNPCInstances = {}
    for _, mapName in ipairs(mapNames) do
        local mapObj = sti(MapSystem.getMapPath(mapName))
        local instances = extractNPCsFromMap(mapObj, mapName, tilesetColumns)
        for _, instance in ipairs(instances) do
            table.insert(allNPCInstances, instance)
        end
    end

    -- Extract all pickup instances from all maps
    for _, mapName in ipairs(mapNames) do
        local mapObj = sti(MapSystem.getMapPath(mapName))
        local instances = extractPickupsFromMap(mapObj, mapName, tilesetColumns)
        for _, instance in ipairs(instances) do
            table.insert(pickups, instance)
        end
    end

    -- Now match NPC instances to quest NPC definitions
    -- Quest NPCs should appear exactly once, dialog-only NPCs can appear multiple times
    for _, npcData in pairs(questData.npcs) do
        if not npcData.isDialogOnly then
            -- Find the instance of this NPC from the map
            local found = false
            for i, instance in ipairs(allNPCInstances) do
                -- Match exact ID or variant pattern (npc_id::variant)
                local baseType = instance.type:match("^([^:]+)")  -- Extract base type before ::
                if instance.type == npcData.id or baseType == npcData.id then
                    -- Found a match!
                    npcData.map = instance.map
                    npcData.x = instance.x
                    npcData.y = instance.y
                    npcData.gridX = instance.gridX
                    npcData.gridY = instance.gridY
                    npcData.spriteX = instance.spriteX
                    npcData.spriteY = instance.spriteY
                    npcData.flippedX = instance.flippedX
                    npcData.size = 16

                    -- Remove from instances list
                    table.remove(allNPCInstances, i)
                    found = true
                    break
                end
            end

            if not found then
                print("Warning: NPC '" .. npcData.id .. "' not found in any map!")
            end
        end

        -- Create sprite quad
        if npcData.spriteX and npcData.spriteY then
            npcData.sprite = {
                tileset = npcTileset,
                quad = love.graphics.newQuad(
                    npcData.spriteX,
                    npcData.spriteY,
                    16, 16,
                    npcTileset:getDimensions()
                )
            }
        end
    end

    -- Remaining instances are dialog-only NPCs (like guards)
    -- Create NPC instances for each one
    for _, instance in ipairs(allNPCInstances) do
        local baseNPC = questData.npcs[instance.type]
        if baseNPC and baseNPC.isDialogOnly then
            -- Create a unique instance for this dialog-only NPC
            local uniqueID = instance.type .. "_" .. instance.map .. "_" .. instance.gridX .. "_" .. instance.gridY
            questData.npcs[uniqueID] = {
                id = uniqueID,
                baseType = instance.type,
                name = baseNPC.name,
                dialogText = baseNPC.dialogText,
                isDialogOnly = true,
                map = instance.map,
                x = instance.x,
                y = instance.y,
                gridX = instance.gridX,
                gridY = instance.gridY,
                spriteX = instance.spriteX,
                spriteY = instance.spriteY,
                flippedX = instance.flippedX,
                size = 16,
                sprite = {
                    tileset = npcTileset,
                    quad = love.graphics.newQuad(
                        instance.spriteX,
                        instance.spriteY,
                        16, 16,
                        npcTileset:getDimensions()
                    )
                }
            }
        end
    end

end


function love.update(dt)
    -- Update map(s)
    if mapTransition.active then
        MapSystem.update(dt)
        if mapTransition.toMapObj then
            mapTransition.toMapObj:update(dt)
        end

        -- Update transition progress
        mapTransition.progress = mapTransition.progress + dt / mapTransition.duration

        if mapTransition.progress >= 1 then
            -- Transition complete
            mapTransition.active = false

            -- Update MapSystem references
            MapSystem.updateReferences(mapTransition.toMapObj, mapTransition.toMap)
            MapSystem.calculateMapBounds()

            -- Set player position to target door location with offset
            PlayerSystem.setPosition(mapTransition.targetX * 16 + 8, mapTransition.targetY * 16 + 8, mapTransition.targetX, mapTransition.targetY)
            player.moving = false

            -- Update camera
            Camera.update(player.x, player.y)
            
            -- Trigger map entry events
            local enteredMap = mapTransition.toMap
            if enteredMap == "mapwest" then
                -- Trigger JARF dialog event when entering mapwest
                UISystem.triggerDialogEvent("mapwest_entry", nil)
            end

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
        MapSystem.update(dt)
    end

    -- Check for pending NPC variant updates
    for npcID, npc in pairs(questData.npcs) do
        if npc.pendingVariant then
            updateNPCVariant(npcID, npc.pendingVariant, MapSystem.getMap(), npc.sprite.tileset, 20)
            npc.pendingVariant = nil
        end
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
        -- Update player movement (only if not transitioning and chat pane is closed)
        if not mapTransition.active and not UISystem.isChatPaneVisible() then
            PlayerSystem.update(dt, heldKeys)
        end

        -- Update camera to follow player
        Camera.update(player.x, player.y)

        -- Check for nearby NPCs (only on current map, not during transition)
        if not mapTransition.active then
            nearbyNPC = nil
            for _, npc in pairs(questData.npcs) do
                if npc.map == MapSystem.getCurrentMap() then
                    -- Check if NPC requires an ability to be visible/interactable
                    if not (npc.requiresAbility and not PlayerSystem.hasAbility(npc.requiresAbility)) then
                        local dist = math.sqrt((player.x - npc.x)^2 + (player.y - npc.y)^2)
                        if dist < 20 then
                            nearbyNPC = npc
                            break
                        end
                    end
                end
            end

            -- Check for nearby doors
            nearbyDoor = MapSystem.findDoorAt(player.gridX, player.gridY)

            -- Check for pickup collisions (only for visible pickups)
            for i = #pickups, 1, -1 do
                local pickup = pickups[i]
                if pickup.map == MapSystem.getCurrentMap() and isPickupVisible(pickup) then
                    local dist = math.sqrt((player.x - pickup.x)^2 + (player.y - pickup.y)^2)
                    if dist < 12 then  -- Pickup radius
                        if pickup.isGold then
                            -- Add gold to inventory
                            PlayerSystem.addGold(pickup.goldAmount)
                            showToast("Picked up: " .. pickup.goldAmount .. " gold", {1, 0.84, 0})
                        else
                            -- Add item to inventory
                            PlayerSystem.addItem(pickup.itemId)
                            local itemData = itemRegistry[pickup.itemId]
                            local itemName = itemData and itemData.name or pickup.itemId
                            showToast("Picked up: " .. itemName, {0.7, 0.9, 1})
                        end
                        -- Remove pickup
                        table.remove(pickups, i)
                    end
                end
            end
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
                    questData.introShown = true
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
                previousState = "mainMenu"
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
            onSettings = function()
                previousState = "pauseMenu"
                gameState = "settings"
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
                gameState = previousState or "mainMenu"
                previousState = nil
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
                questData.acceptQuest(quest.id)  -- Use encapsulated method
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
                local requiredQty = quest.requiredQuantity or 1
                PlayerSystem.removeItem(quest.requiredItem, requiredQty)
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
    if gameState == "questOffer" then
        if key == "e" then
            -- Accept quest
            questData.acceptQuest(questOfferData.quest.id)
            showToast("Quest Accepted: " .. questOfferData.quest.name, {1, 1, 0})
            questOfferData = nil
            DialogSystem.clearDialog()
            AudioSystem.stopManifestoMusic()
            gameState = "playing"
        elseif key == "r" then
            -- Reject quest
            questOfferData = nil
            DialogSystem.clearDialog()
            AudioSystem.stopManifestoMusic()
            gameState = "playing"
        end
    elseif key == "space" or key == "e" then
        if gameState == "playing" and nearbyDoor and not UISystem.isChatPaneVisible() then
            enterDoor(nearbyDoor)
        elseif gameState == "playing" and nearbyNPC and not UISystem.isChatPaneVisible() then
            questData.interactWithNPC(nearbyNPC)
            gameState = questData.gameState
            questTurnInData = questData.questTurnInData
        elseif gameState == "dialog" then
            local callbacks = {
                onQuestAccept = function(quest)
                    questData.acceptQuest(quest.id)  -- Use encapsulated method
                    showToast("Quest Accepted: " .. quest.name, {1, 1, 0})
                end,
                onQuestComplete = function(quest)
                    local requiredQty = quest.requiredQuantity or 1
                    PlayerSystem.removeItem(quest.requiredItem, requiredQty)
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
                    questOfferData = {
                        npc = currentDialog.npc, 
                        quest = currentDialog.quest,
                        questConfig = currentDialog.questConfig  -- Store questConfig for callback
                    }
                    
                    -- Call afterQuestOffer callback if it exists
                    if questOfferData.questConfig and questOfferData.questConfig.afterQuestOffer then
                        questOfferData.questConfig.afterQuestOffer()
                    end
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
            UISystem.resetQuestLogPagination()
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
            UISystem.resetInventoryPagination(PlayerSystem.getInventory())
        elseif gameState == "inventory" then
            gameState = "playing"
        end
    elseif key == "left" or key == "," or key == "<" then
        if gameState == "questTurnIn" then
            UISystem.questTurnInPrevPage()
        elseif gameState == "inventory" then
            UISystem.inventoryPrevPage()
        elseif gameState == "questLog" then
            UISystem.questLogPrevPage()
        end
    elseif key == "right" or key == "." or key == ">" then
        if gameState == "questTurnIn" then
            UISystem.questTurnInNextPage()
        elseif gameState == "inventory" then
            UISystem.inventoryNextPage()
        elseif gameState == "questLog" then
            UISystem.questLogNextPage()
        end
    elseif key == "escape" then
        if gameState == "winScreen" then
            love.event.quit()
        elseif gameState == "playing" then
            gameState = "pauseMenu"
        elseif gameState == "pauseMenu" then
            gameState = "playing"
        elseif gameState == "shop" then
            gameState = "playing"
        end
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

    -- If no direction, use instant transition
    if not transitionDirection then
        -- Play music for target map
        MapSystem.playMusicForMap(door.targetMap)
        
        -- Load the new map
        local success, result = MapSystem.loadMap(door.targetMap)
        if not success then
            print("Error loading map:", result)
            return
        end

        -- Set player position to target door location with offset
        PlayerSystem.setPosition(targetX * 16 + 8, targetY * 16 + 8, targetX, targetY)
        player.moving = false

        -- Update camera to follow player
        Camera.update(player.x, player.y)
        return
    end
    
    -- Play music for target map (before sliding transition starts)
    MapSystem.playMusicForMap(door.targetMap)

    -- Calculate player screen positions for transition
    -- Start position: where the player currently is on screen (relative to camera)
    local gameWidth = UISystem.getGameWidth()
    local gameHeight = UISystem.getGameHeight()
    local camX, camY = Camera.getPosition()
    local startScreenX = player.x - camX
    local startScreenY = player.y - camY

    -- End position: where the player will be on screen after transition
    -- Calculate the final world position where player will be
    local finalPlayerX = targetX * 16 + 8
    local finalPlayerY = targetY * 16 + 8

    -- Calculate what the camera position will be after transition
    -- The camera centers on the player and gets clamped to map bounds
    local toMapObj = sti(MapSystem.getMapPath(door.targetMap))
    MapSystem.hideNPCLayer(toMapObj)
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
    mapTransition.fromMap = MapSystem.getCurrentMap()
    mapTransition.toMap = door.targetMap
    mapTransition.fromMapObj = MapSystem.getMap()
    mapTransition.toMapObj = sti(MapSystem.getMapPath(door.targetMap))
    MapSystem.hideNPCLayer(mapTransition.toMapObj)
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

-- Helper function to calculate transition offsets
local function getTransitionOffsets()
    if not mapTransition.active then
        return nil
    end

    local progress = mapTransition.progress
    local eased = 1 - (1 - progress)^3 -- ease-out cubic
    local gameHeight = UISystem.getGameHeight()
    local gameWidth = UISystem.getGameWidth()
    local camX, camY = Camera.getPosition()

    if mapTransition.direction == "up" then
        local slideOffset = eased * gameHeight
        local newMapCamY = MapSystem.getMapHeight(mapTransition.toMapObj) - gameHeight
        return {
            {map = mapTransition.toMapObj, mapName = mapTransition.toMap, camX = camX, camY = newMapCamY, offsetX = 0, offsetY = -gameHeight + slideOffset},
            {map = mapTransition.fromMapObj, mapName = mapTransition.fromMap, camX = camX, camY = camY, offsetX = 0, offsetY = slideOffset}
        }
    elseif mapTransition.direction == "down" then
        local slideOffset = -eased * gameHeight
        local newMapCamY = MapSystem.getMapMinY(mapTransition.toMapObj)
        local oldMapCamY = MapSystem.getMapHeight(mapTransition.fromMapObj) - gameHeight
        return {
            {map = mapTransition.toMapObj, mapName = mapTransition.toMap, camX = camX, camY = newMapCamY, offsetX = 0, offsetY = gameHeight + slideOffset},
            {map = mapTransition.fromMapObj, mapName = mapTransition.fromMap, camX = camX, camY = oldMapCamY, offsetX = 0, offsetY = slideOffset}
        }
    elseif mapTransition.direction == "right" then
        local slideOffset = -eased * gameWidth
        local newMapCamX = MapSystem.getMapMinX(mapTransition.toMapObj)
        local oldMapCamX = MapSystem.getMapWidth(mapTransition.fromMapObj) - gameWidth
        return {
            {map = mapTransition.toMapObj, mapName = mapTransition.toMap, camX = newMapCamX, camY = camY, offsetX = gameWidth + slideOffset, offsetY = 0},
            {map = mapTransition.fromMapObj, mapName = mapTransition.fromMap, camX = oldMapCamX, camY = camY, offsetX = slideOffset, offsetY = 0}
        }
    elseif mapTransition.direction == "left" then
        local slideOffset = eased * gameWidth
        local newMapCamX = MapSystem.getMapWidth(mapTransition.toMapObj) - gameWidth
        local oldMapCamX = MapSystem.getMapMinX(mapTransition.fromMapObj)
        return {
            {map = mapTransition.toMapObj, mapName = mapTransition.toMap, camX = newMapCamX, camY = camY, offsetX = -gameWidth + slideOffset, offsetY = 0},
            {map = mapTransition.fromMapObj, mapName = mapTransition.fromMap, camX = oldMapCamX, camY = camY, offsetX = slideOffset, offsetY = 0}
        }
    end
end

-- Helper function to draw NPCs for a given map
function drawNPCs(mapName, camX, camY, chatOffset, offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    for _, npc in pairs(questData.npcs) do
        if npc.map == mapName then
            -- Check if NPC requires an ability to be visible
            if not npc.requiresAbility or PlayerSystem.hasAbility(npc.requiresAbility) then
                love.graphics.setColor(1, 1, 1)
                if npc.sprite.quad then
                    -- Draw from tileset using quad
                    local scaleX = npc.flippedX and -1 or 1
                    local facingOffsetX = npc.flippedX and npc.size or 0

                    love.graphics.draw(
                        npc.sprite.tileset,
                        npc.sprite.quad,
                        chatOffset + npc.x - npc.size/2 - camX + offsetX + facingOffsetX,
                        npc.y - npc.size/2 - camY + offsetY,
                        0,
                        scaleX,
                        1
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
                        elseif quest.active and quest.requiredItem then
                            local requiredQty = quest.requiredQuantity or 1
                            if PlayerSystem.hasItem(quest.requiredItem, requiredQty) then
                                -- Green indicator for quest ready to turn in
                                love.graphics.setColor(0, 1, 0)
                                love.graphics.circle("fill", chatOffset + npc.x - camX + offsetX, npc.y - 10 - camY + offsetY, 2)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Helper function to draw pickups for a specific map
function drawPickups(mapName, camX, camY, chatOffset, offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    if not pickupTileset then return end

    -- Draw pickups (only on this map)
    for _, pickup in ipairs(pickups) do
        if pickup.map == mapName and isPickupVisible(pickup) then
            love.graphics.setColor(1, 1, 1)
            local quad = love.graphics.newQuad(
                pickup.spriteX,
                pickup.spriteY,
                16, 16,
                pickupTileset:getDimensions()
            )
            love.graphics.draw(
                pickupTileset,
                quad,
                chatOffset + pickup.x - 8 - camX + offsetX,
                pickup.y - 8 - camY + offsetY
            )
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
        -- Draw world with chat pane offset (always offset by chat pane width in canvas)
        local camX, camY = Camera.getPosition()
        local chatOffset = UISystem.getChatPaneWidth()
        
        -- Clip rendering to game area only (always at chat pane offset in canvas)
        love.graphics.setScissor(UISystem.getChatPaneWidth(), 0, UISystem.getGameWidth(), UISystem.getGameHeight())

        -- Handle map transitions
        local transitionOffsets = getTransitionOffsets()
        if transitionOffsets then
            -- Draw both maps during transition
            for _, params in ipairs(transitionOffsets) do
                MapSystem.drawMapObject(params.map, params.camX, params.camY, params.offsetX, params.offsetY)
            end
        else
            -- Normal rendering (no transition)
            MapSystem.draw()
        end

        -- Draw pickups (before player, on the ground)
        if transitionOffsets then
            for _, params in ipairs(transitionOffsets) do
                drawPickups(params.mapName, params.camX, params.camY, chatOffset, params.offsetX, params.offsetY)
            end
        else
            drawPickups(MapSystem.getCurrentMap(), camX, camY, chatOffset)
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

        -- Draw NPCs after player (so quest markers aren't covered)
        if transitionOffsets then
            -- Draw NPCs for both maps during transition
            for _, params in ipairs(transitionOffsets) do
                drawNPCs(params.mapName, params.camX, params.camY, chatOffset, params.offsetX, params.offsetY)
            end
        else
            drawNPCs(MapSystem.getCurrentMap(), camX, camY, chatOffset, 0, 0)
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
        UISystem.drawIndicators(CheatConsole.isGridActive(), PlayerSystem.getAbilityManager())
        love.graphics.pop()

        -- Reset scissor
        love.graphics.setScissor()

    elseif gameState == "pauseMenu" then
        -- Draw game world in background with chat pane offset
        local camX, camY = Camera.getPosition()
        local chatOffset = UISystem.getChatPaneWidth()
        
        -- Clip rendering to game area only
        love.graphics.setScissor(UISystem.getChatPaneWidth(), 0, UISystem.getGameWidth(), UISystem.getGameHeight())

        -- Draw the map
        MapSystem.draw()

        -- Draw pickups
        drawPickups(MapSystem.getCurrentMap(), camX, camY, chatOffset)

        -- Draw player
        PlayerSystem.draw(camX, camY, chatOffset)

        -- Draw NPCs after player
        drawNPCs(MapSystem.getCurrentMap(), camX, camY, chatOffset, 0, 0)

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
        local camX, camY = Camera.getPosition()
        local chatOffset = UISystem.getChatPaneWidth()
        
        -- Clip rendering to game area only
        love.graphics.setScissor(UISystem.getChatPaneWidth(), 0, UISystem.getGameWidth(), UISystem.getGameHeight())

        -- Draw the map
        MapSystem.draw()

        -- Draw pickups
        drawPickups(MapSystem.getCurrentMap(), camX, camY, chatOffset)

        -- Draw player
        PlayerSystem.draw(camX, camY, chatOffset)

        -- Draw NPCs after player
        drawNPCs(MapSystem.getCurrentMap(), camX, camY, chatOffset, 0, 0)

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
        local camX, camY = Camera.getPosition()
        local chatOffset = UISystem.getChatPaneWidth()
        
        -- Clip rendering to game area only
        love.graphics.setScissor(UISystem.getChatPaneWidth(), 0, UISystem.getGameWidth(), UISystem.getGameHeight())

        -- Draw the map
        MapSystem.draw()

        -- Draw pickups
        drawPickups(MapSystem.getCurrentMap(), camX, camY, chatOffset)

        -- Draw player
        PlayerSystem.draw(camX, camY, chatOffset)

        -- Draw NPCs after player
        drawNPCs(MapSystem.getCurrentMap(), camX, camY, chatOffset, 0, 0)

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
