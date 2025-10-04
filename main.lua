-- Libraries
local sti = require "sti"
local questData = require "quests"

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
-- playing, dialog, questLog, inventory
local gameState = "playing"

-- Player (Pokemon-style grid movement)
local player = {
    x = 168,  -- Current pixel position
    y = 120,
    gridX = 10, -- Grid position (in tiles)
    gridY = 7,
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

-- UI state
local nearbyNPC = nil
local currentDialog = nil

-- Toast system
local toasts = {}
local TOAST_DURATION = 3.0 -- seconds

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
    map = sti("tiled/map.lua")

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
    
    -- Initialize camera centered on player
    camera.x = player.x - GAME_WIDTH / 2
    camera.y = player.y - GAME_HEIGHT / 2
end

function loadGameData()
    -- Load NPCs from quest data
    for _, npcData in ipairs(questData.npcs) do
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

    if gameState == "playing" then
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
                
                -- Check collision at target grid position
                local targetPixelX = newGridX * 16 + 8
                local targetPixelY = newGridY * 16 + 8
                
                if not isColliding(targetPixelX, targetPixelY) then
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

        -- Check for nearby NPCs
        nearbyNPC = nil
        for _, npc in ipairs(npcs) do
            local dist = math.sqrt((player.x - npc.x)^2 + (player.y - npc.y)^2)
            if dist < 40 then
                nearbyNPC = npc
                break
            end
        end
    end
end

function isColliding(x, y)
    local tileX = math.floor(x / world.tileSize)
    local tileY = math.floor(y / world.tileSize)

    -- Get the tile layer (first layer in the map)
    local layer = map.layers[1]
    
    if not layer or layer.type ~= "tilelayer" then
        return false
    end

    -- Handle chunked maps
    if layer.chunks then
        -- Check if the position is within any chunk (map bounds)
        local foundInChunk = false
        
        for _, chunk in ipairs(layer.chunks) do
            -- Check if the tile position is within this chunk
            local chunkX = chunk.x
            local chunkY = chunk.y
            local chunkWidth = chunk.width
            local chunkHeight = chunk.height
            
            if tileX >= chunkX and tileX < chunkX + chunkWidth and
               tileY >= chunkY and tileY < chunkY + chunkHeight then
                foundInChunk = true
                
                -- Convert to local chunk coordinates (1-based)
                local localX = tileX - chunkX + 1
                local localY = tileY - chunkY + 1
                
                -- Get the tile from chunk data
                if chunk.data[localY] and chunk.data[localY][localX] then
                    local tile = chunk.data[localY][localX]
                    if tile.properties and tile.properties.collides then
                        return true
                    end
                end
                break
            end
        end
        
        -- If not in any chunk, it's outside the map bounds
        if not foundInChunk then
            return true
        end
    else
        -- Handle non-chunked maps
        if layer.data[tileY + 1] and layer.data[tileY + 1][tileX + 1] then
            local tile = layer.data[tileY + 1][tileX + 1]
            if tile and tile.properties and tile.properties.collides then
                return true
            end
        else
            -- Outside map bounds
            return true
        end
    end

    return false
end

function love.keypressed(key)
    if key == "space" then
        if gameState == "playing" and nearbyNPC then
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
            -- Turn in quest
            currentDialog = {
                type = "questTurnIn",
                npc = npc,
                quest = quest
            }
            gameState = "dialog"
        else
            -- Quest already active or completed
            currentDialog = {
                type = "generic",
                npc = npc,
                text = quest.active and "Come back when you have the item!" or "Thanks again!"
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
        -- Get item name for toast
        local itemNames = {
            item_cat = "Fluffy Cat",
            item_book = "Ancient Tome",
            item_package = "Sealed Package"
        }
        showToast("Received: " .. (itemNames[currentDialog.item] or currentDialog.item), {0.7, 0.5, 0.9})
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

        -- Draw NPCs
        for _, npc in ipairs(npcs) do
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

        -- Draw player with appropriate sprite
        love.graphics.setColor(1, 1, 1)
        local currentSprite = playerSprite
        if player.moving then
            currentSprite = (player.walkFrame == 0) and playerWalk0 or playerWalk1
        end
        love.graphics.draw(currentSprite, player.x - player.size/2 - camX, player.y - player.size/2 - camY)

        -- Draw interaction prompt
        if nearbyNPC and gameState == "playing" then
            drawTextBox(GAME_WIDTH/2 - 45, GAME_HEIGHT - 14, 90, 12, "SPACE: Talk", {1, 1, 1}, true)
        end

        -- Draw dialog
        if gameState == "dialog" and currentDialog then
            drawDialog()
        end

        -- Draw UI hints
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, 12)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Q:Log I:Inv", 2, -1)

    elseif gameState == "questLog" then
        drawQuestLog()
    elseif gameState == "inventory" then
        drawInventory()
    end

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
        buttonText = "[SPACE] Accept"
    elseif currentDialog.type == "questTurnIn" then
        text = currentDialog.quest.reward
        buttonText = "[SPACE] Complete"
    elseif currentDialog.type == "itemGive" then
        text = currentDialog.npc.itemGiveText or "Here, take this!"
        buttonText = "[SPACE] Receive"
    else
        text = currentDialog.text
        buttonText = "[SPACE] Close"
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

    -- Item names
    local itemNames = {
        item_cat = "Fluffy Cat",
        item_book = "Ancient Tome",
        item_package = "Sealed Package"
    }

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
            love.graphics.setColor(0.7, 0.5, 0.9)
            love.graphics.print("- " .. (itemNames[itemId] or itemId), boxX+6, listY)
            listY = listY + 12
        end
    end

    -- Footer
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("[I] Close", boxX+4, boxY+boxH-15)
end
