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

-- Player
local player = {
    x = 160,
    y = 120,
    size = 16,
    direction = "down",
    isWalking = false,
    walkTimer = 0,
    walkFrame = 0, -- 0 or 1
    moving = false,
    targetX = 160,
    targetY = 120
}

-- Camera
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
    playerSprite:setFilter("nearest", "nearest")
    playerWalk0 = love.graphics.newImage("sprites/player-walk0.png")
    playerWalk0:setFilter("nearest", "nearest")
    playerWalk1 = love.graphics.newImage("sprites/player-walk1.png")
    playerWalk1:setFilter("nearest", "nearest")
    npcSprite = love.graphics.newImage("sprites/npc.png")
    npcSprite:setFilter("nearest", "nearest")

    -- Load Tiled map
    map = sti("tiled/map.lua")

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

    if gameState == "playing" then
        -- Grid-based movement: move to target position
        if player.moving then
            local speed = 128 -- pixels per second
            local dx = player.targetX - player.x
            local dy = player.targetY - player.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < 2 then
                -- Snap to target
                player.x = player.targetX
                player.y = player.targetY
                player.moving = false
                player.isWalking = false
            else
                -- Move towards target
                player.x = player.x + (dx / dist) * speed * dt
                player.y = player.y + (dy / dist) * speed * dt
            end

            -- Update walk animation
            player.walkTimer = player.walkTimer + dt
            if player.walkTimer >= 0.15 then
                player.walkFrame = 1 - player.walkFrame
                player.walkTimer = 0
            end
        else
            -- Check for input and start new movement
            local moveDir = nil

            if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
                moveDir = "up"
            elseif love.keyboard.isDown("s") or love.keyboard.isDown("down") then
                moveDir = "down"
            elseif love.keyboard.isDown("a") or love.keyboard.isDown("left") then
                moveDir = "left"
            elseif love.keyboard.isDown("d") or love.keyboard.isDown("right") then
                moveDir = "right"
            end

            if moveDir then
                local newX, newY = player.x, player.y

                if moveDir == "up" then
                    newY = player.y - 16
                elseif moveDir == "down" then
                    newY = player.y + 16
                elseif moveDir == "left" then
                    newX = player.x - 16
                elseif moveDir == "right" then
                    newX = player.x + 16
                end

                player.direction = moveDir

                -- Check collision at target position
                if not isColliding(newX, newY) then
                    player.targetX = newX
                    player.targetY = newY
                    player.moving = true
                    player.isWalking = true
                end
            end
        end

        -- Update camera to snap to 16px grid
        camera.x = math.floor((player.x - GAME_WIDTH / 2) / 16) * 16
        camera.y = math.floor((player.y - GAME_HEIGHT / 2) / 16) * 16

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
    local tileX = math.floor(x / world.tileSize) + 1
    local tileY = math.floor(y / world.tileSize) + 1

    -- Check collision with map tiles using STI
    for _, layer in ipairs(map.layers) do
        if layer.type == "tilelayer" and layer.visible and layer.data then
            local tile = layer.data[tileY] and layer.data[tileY][tileX]
            if tile and tile.properties and tile.properties.collides then
                return true
            end
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
        -- Give item
        if not hasItem(npc.givesItem) then
            currentDialog = {
                type = "itemGive",
                npc = npc,
                item = npc.givesItem
            }
            gameState = "dialog"
        else
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
        gameState = "playing"
        currentDialog = nil
    elseif currentDialog.type == "questTurnIn" then
        -- Complete quest
        removeItem(currentDialog.quest.requiredItem)
        currentDialog.quest.active = false
        currentDialog.quest.completed = true
        table.remove(activeQuests, indexOf(activeQuests, currentDialog.quest.id))
        table.insert(completedQuests, currentDialog.quest.id)
        gameState = "playing"
        currentDialog = nil
    elseif currentDialog.type == "itemGive" then
        -- Receive item
        table.insert(inventory, currentDialog.item)
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
        if player.isWalking then
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
        text = "Here, take this!"
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
