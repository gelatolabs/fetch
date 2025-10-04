-- UI System Module
-- Handles all UI drawing functionality

local UISystem = {}

-- Helper function to draw WoW-style decorative borders
function UISystem.drawFancyBorder(x, y, w, h, color)
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

-- Helper function to draw text boxes
function UISystem.drawTextBox(x, y, w, h, text, color, centered)
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

-- Helper function to check if mouse is over a button
function UISystem.isMouseOverButton(mouseX, mouseY, btnX, btnY, btnWidth, btnHeight, GAME_WIDTH, GAME_HEIGHT, SCALE)
    -- Convert screen coordinates to canvas coordinates
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local offsetX = math.floor((screenWidth - GAME_WIDTH * SCALE) / 2 / SCALE) * SCALE
    local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
    local canvasX = (mouseX - offsetX) / SCALE
    local canvasY = (mouseY - offsetY) / SCALE

    return canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= btnY and canvasY <= btnY + btnHeight
end

-- Draw toasts
function UISystem.drawToasts(toasts, font, GAME_WIDTH)
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

        y = y + boxH + 4
    end
end

-- Draw pause menu
function UISystem.drawPauseMenu(GAME_WIDTH, GAME_HEIGHT, mouseX, mouseY, SCALE)
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
    local resumeHover = UISystem.isMouseOverButton(mouseX, mouseY, btnX, 100, btnWidth, btnHeight, GAME_WIDTH, GAME_HEIGHT, SCALE)
    love.graphics.setColor(resumeHover and 0.3 or 0.2, resumeHover and 0.2 or 0.15, resumeHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(resumeHover and 1 or 0.8, resumeHover and 0.8 or 0.6, resumeHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Resume", btnX, 100 + 3, btnWidth, "center")

    -- Quit Game button
    local quitHover = UISystem.isMouseOverButton(mouseX, mouseY, btnX, 130, btnWidth, btnHeight, GAME_WIDTH, GAME_HEIGHT, SCALE)
    love.graphics.setColor(quitHover and 0.3 or 0.2, quitHover and 0.2 or 0.15, quitHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(quitHover and 1 or 0.8, quitHover and 0.8 or 0.6, quitHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Quit Game", btnX, 130 + 3, btnWidth, "center")
end

-- Draw main menu
function UISystem.drawMainMenu(GAME_WIDTH, GAME_HEIGHT, titleFont, font, mouseX, mouseY, SCALE)
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
    local playHover = UISystem.isMouseOverButton(mouseX, mouseY, btnX, 100, btnWidth, btnHeight, GAME_WIDTH, GAME_HEIGHT, SCALE)
    love.graphics.setColor(playHover and 0.3 or 0.2, playHover and 0.2 or 0.15, playHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(playHover and 1 or 0.8, playHover and 0.8 or 0.6, playHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Play", btnX, 100 + 3, btnWidth, "center")

    -- Settings button
    local settingsHover = UISystem.isMouseOverButton(mouseX, mouseY, btnX, 130, btnWidth, btnHeight, GAME_WIDTH, GAME_HEIGHT, SCALE)
    love.graphics.setColor(settingsHover and 0.3 or 0.2, settingsHover and 0.2 or 0.15, settingsHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(settingsHover and 1 or 0.8, settingsHover and 0.8 or 0.6, settingsHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Settings", btnX, 130 + 3, btnWidth, "center")

    -- Quit button
    local quitHover = UISystem.isMouseOverButton(mouseX, mouseY, btnX, 160, btnWidth, btnHeight, GAME_WIDTH, GAME_HEIGHT, SCALE)
    love.graphics.setColor(quitHover and 0.3 or 0.2, quitHover and 0.2 or 0.15, quitHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(quitHover and 1 or 0.8, quitHover and 0.8 or 0.6, quitHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Quit", btnX, 160 + 3, btnWidth, "center")
end

-- Draw settings menu
function UISystem.drawSettings(GAME_WIDTH, GAME_HEIGHT, volume, mouseX, mouseY, SCALE)
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
    local backHover = UISystem.isMouseOverButton(mouseX, mouseY, btnX, 160, btnWidth, btnHeight, GAME_WIDTH, GAME_HEIGHT, SCALE)
    love.graphics.setColor(backHover and 0.3 or 0.2, backHover and 0.2 or 0.15, backHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(backHover and 1 or 0.8, backHover and 0.8 or 0.6, backHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Back", btnX, 160 + 3, btnWidth, "center")
end

-- Draw quest log
function UISystem.drawQuestLog(GAME_WIDTH, GAME_HEIGHT, activeQuests, completedQuests, quests)
    local boxX, boxY = 10, 10
    local boxW, boxH = GAME_WIDTH - 20, GAME_HEIGHT - 20

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 0.98)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)

    -- Fancy border
    UISystem.drawFancyBorder(boxX, boxY, boxW, boxH, {0.7, 0.5, 0.2})

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
    love.graphics.print("[L] Close", boxX+4, boxY+boxH-15)
end

-- Draw quest turn-in UI
function UISystem.drawQuestTurnIn(GAME_WIDTH, GAME_HEIGHT, questTurnInData, inventory, itemRegistry, map, camera, npcs, currentMap, npcSprite, player, playerTileset, getPlayerSpriteSet)
    if not questTurnInData then
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
        player.y - player.size/2 - camY - player.jumpHeight,
        0,
        scaleX,
        1
    )

    -- Draw dialog box
    local quest = questTurnInData.quest
    local boxX = GAME_WIDTH / 2 - 75
    local boxY = GAME_HEIGHT - 90
    local boxW = 150
    local boxH = 85

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 0.98)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)

    -- Fancy border
    UISystem.drawFancyBorder(boxX, boxY, boxW, boxH, {0.7, 0.5, 0.2})

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
    local startY = boxY + 30

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

-- Draw quest offer UI
function UISystem.drawQuestOffer(GAME_WIDTH, GAME_HEIGHT, questOfferData, mouseX, mouseY, SCALE)
    if not questOfferData then
        return
    end

    local quest = questOfferData.quest
    local npc = questOfferData.npc

    -- Dialog box
    local boxX = GAME_WIDTH / 2 - 100
    local boxY = GAME_HEIGHT / 2 - 60
    local boxW = 200
    local boxH = 120

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 0.98)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)

    -- Fancy border
    local borderColor = quest.isMainQuest and {1, 0.8, 0.3} or {0.7, 0.5, 0.2}
    UISystem.drawFancyBorder(boxX, boxY, boxW, boxH, borderColor)

    -- Title bar
    love.graphics.setColor(0.15, 0.1, 0.05, 0.9)
    love.graphics.rectangle("fill", boxX+2, boxY+2, boxW-4, 12)

    if quest.isMainQuest then
        love.graphics.setColor(1, 0.84, 0)
        love.graphics.printf("MAIN QUEST", boxX, boxY, boxW, "center")
    else
        love.graphics.setColor(0.9, 0.7, 0.3)
        love.graphics.printf("Quest Offered", boxX, boxY, boxW, "center")
    end

    -- Quest name
    love.graphics.setColor(1, 0.9, 0.7)
    love.graphics.printf(quest.name, boxX+4, boxY+18, boxW-8, "center")

    -- Quest description
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf(quest.description, boxX+6, boxY+34, boxW-12, "left")

    -- Buttons
    local btnW = 70
    local btnH = 18
    local btnY = boxY + boxH - btnH - 6
    local acceptX = boxX + boxW/2 - btnW - 4
    local rejectX = boxX + boxW/2 + 4

    -- Accept button
    local acceptHover = UISystem.isMouseOverButton(mouseX, mouseY, acceptX, btnY, btnW, btnH, GAME_WIDTH, GAME_HEIGHT, SCALE)
    love.graphics.setColor(acceptHover and 0.2 or 0.15, acceptHover and 0.35 or 0.25, acceptHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", acceptX, btnY, btnW, btnH)
    love.graphics.setColor(acceptHover and 0.4 or 0.2, acceptHover and 0.8 or 0.6, acceptHover and 0.3 or 0.2)
    love.graphics.rectangle("line", acceptX, btnY, btnW, btnH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Accept", acceptX, btnY + 2, btnW, "center")

    -- Reject button
    local rejectHover = UISystem.isMouseOverButton(mouseX, mouseY, rejectX, btnY, btnW, btnH, GAME_WIDTH, GAME_HEIGHT, SCALE)
    love.graphics.setColor(rejectHover and 0.35 or 0.25, rejectHover and 0.2 or 0.15, rejectHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", rejectX, btnY, btnW, btnH)
    love.graphics.setColor(rejectHover and 0.9 or 0.7, rejectHover and 0.4 or 0.3, rejectHover and 0.3 or 0.2)
    love.graphics.rectangle("line", rejectX, btnY, btnW, btnH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Reject", rejectX, btnY + 2, btnW, "center")
end

-- Draw inventory
function UISystem.drawInventory(GAME_WIDTH, GAME_HEIGHT, inventory, itemRegistry)
    local boxX, boxY = 10, 10
    local boxW, boxH = GAME_WIDTH - 20, GAME_HEIGHT - 20

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 0.98)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)

    -- Fancy border
    UISystem.drawFancyBorder(boxX, boxY, boxW, boxH, {0.5, 0.3, 0.6})

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

-- Draw shop
function UISystem.drawShop(GAME_WIDTH, GAME_HEIGHT, shopInventory, selectedShopItem, playerGold, inventory, itemRegistry, font, mouseX, mouseY, SCALE, hasItem)
    local boxX, boxY = 10, 10
    local boxW, boxH = GAME_WIDTH - 20, GAME_HEIGHT - 20

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 0.98)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)

    -- Fancy border
    UISystem.drawFancyBorder(boxX, boxY, boxW, boxH, {0.8, 0.6, 0.2})

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

                local isHovered = UISystem.isMouseOverButton(mouseX, mouseY, btnX, btnY, btnW, btnH, GAME_WIDTH, GAME_HEIGHT, SCALE)

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

-- Draw win screen
function UISystem.drawWinScreen(GAME_WIDTH, GAME_HEIGHT, titleFont, font, playerGold, completedQuests)
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

return UISystem
