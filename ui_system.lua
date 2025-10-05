-- UI System Module
-- Handles all UI drawing functionality

local UISystem = {}

-- UI constants
local GAME_WIDTH = 320
local GAME_HEIGHT = 240
local CHAT_PANE_WIDTH = 106
local TOTAL_WIDTH = CHAT_PANE_WIDTH + GAME_WIDTH
local SCALE = 1

-- Graphics resources
local canvas = nil

-- Font resources
local font = nil
local titleFont = nil

-- Mouse state
local mouseX = 0
local mouseY = 0

-- Slider state
local draggingSlider = false

-- Toast system
local toasts = {}
local TOAST_DURATION = 3.0 -- seconds

-- Chat UI state
local dialogScript = require("dialog_script")
local currentDialogIndex = 0
local chatMessages = {} -- {speaker, text, displayedText, animTimer}
local jarfSprite = nil
local developerSprite = nil

-- Game state references (set by main.lua)
local gameStateRefs = {
    inventory = nil,
    itemRegistry = nil,
    questTurnInData = nil
}

-- Set game state references
function UISystem.setGameStateRefs(refs)
    for key, value in pairs(refs) do
        gameStateRefs[key] = value
    end
end

-- Initialize UI system
function UISystem.init()
    -- Get desktop dimensions
    local desktopWidth, desktopHeight = love.window.getDesktopDimensions()

    -- Calculate scale factor (highest integer multiple that fits screen)
    local scaleX = math.floor(desktopWidth / TOTAL_WIDTH)
    local scaleY = math.floor(desktopHeight / GAME_HEIGHT)
    SCALE = math.min(scaleX, scaleY)
    if SCALE < 1 then SCALE = 1 end

    -- Set window mode
    love.window.setMode(TOTAL_WIDTH * SCALE, GAME_HEIGHT * SCALE, {fullscreen = true})

    -- Disable interpolation globally
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Create canvas (now includes chat pane)
    canvas = love.graphics.newCanvas(TOTAL_WIDTH, GAME_HEIGHT)
    canvas:setFilter("nearest", "nearest")

    -- Load fonts
    UISystem.loadFonts()

    -- Load chat sprites
    jarfSprite = love.graphics.newImage("sprites/jarf.png")
    jarfSprite:setFilter("nearest", "nearest")
    developerSprite = love.graphics.newImage("sprites/developer.png")
    developerSprite:setFilter("nearest", "nearest")
end

-- Get the canvas
function UISystem.getCanvas()
    return canvas
end

-- Get UI constants
function UISystem.getGameWidth()
    return GAME_WIDTH
end

function UISystem.getGameHeight()
    return GAME_HEIGHT
end

function UISystem.getScale()
    return SCALE
end

function UISystem.getChatPaneWidth()
    return CHAT_PANE_WIDTH
end

-- Initialize fonts
function UISystem.loadFonts()
    -- Load font (size 16 renders at 8px height)
    font = love.graphics.newFont("BitPotionExt.ttf", 16)
    font:setFilter("nearest", "nearest")
    love.graphics.setFont(font)

    -- Load title font (twice as large)
    titleFont = love.graphics.newFont("BitPotionExt.ttf", 32)
    titleFont:setFilter("nearest", "nearest")
end

-- Get the regular font
function UISystem.getFont()
    return font
end

-- Get the title font
function UISystem.getTitleFont()
    return titleFont
end

-- Update mouse position
function UISystem.updateMouse(x, y)
    mouseX = x
    mouseY = y
end

-- Handle slider dragging during mouse move
function UISystem.handleSliderDrag(volume, onVolumeChange)
    if not draggingSlider then
        return volume
    end

    -- Convert screen coordinates to canvas coordinates
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local offsetX = math.floor((screenWidth - TOTAL_WIDTH * SCALE) / 2 / SCALE) * SCALE
    local canvasX = (mouseX - offsetX) / SCALE

    local sliderX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - 50
    local sliderWidth = 100

    local newVolume = math.max(0, math.min(1, (canvasX - sliderX) / sliderWidth))
    if onVolumeChange then
        onVolumeChange(newVolume)
    end
    return newVolume
end

-- Start slider dragging
function UISystem.startSliderDrag(volume, onVolumeChange)
    draggingSlider = true

    -- Immediately update volume at click position
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local offsetX = math.floor((screenWidth - TOTAL_WIDTH * SCALE) / 2 / SCALE) * SCALE
    local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
    local canvasX = (mouseX - offsetX) / SCALE
    local canvasY = (mouseY - offsetY) / SCALE

    local sliderX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - 50
    local sliderY = 100
    local sliderWidth = 100
    local sliderHeight = 10

    if canvasX >= sliderX and canvasX <= sliderX + sliderWidth and canvasY >= sliderY - 5 and canvasY <= sliderY + sliderHeight + 5 then
        local newVolume = math.max(0, math.min(1, (canvasX - sliderX) / sliderWidth))
        if onVolumeChange then
            onVolumeChange(newVolume)
        end
        return newVolume
    end

    return volume
end

-- Stop slider dragging
function UISystem.stopSliderDrag()
    draggingSlider = false
end

-- Add a toast notification
function UISystem.showToast(message, color)
    table.insert(toasts, {
        message = message,
        timer = TOAST_DURATION,
        color = color or {1, 1, 1}
    })
end

-- Update toasts (call in love.update)
function UISystem.updateToasts(dt)
    for i = #toasts, 1, -1 do
        toasts[i].timer = toasts[i].timer - dt
        if toasts[i].timer <= 0 then
            table.remove(toasts, i)
        end
    end
end

-- Progress the dialog script
function UISystem.progressDialog()
    if currentDialogIndex < #dialogScript then
        currentDialogIndex = currentDialogIndex + 1
        local dialog = dialogScript[currentDialogIndex]
        table.insert(chatMessages, {
            speaker = dialog.speaker,
            text = dialog.text,
            displayedText = "",
            animTimer = 0
        })
        -- Keep only the last 8 messages
        if #chatMessages > 8 then
            table.remove(chatMessages, 1)
        end
    end
end

-- Update chat animation
function UISystem.updateChat(dt)
    for _, msg in ipairs(chatMessages) do
        if #msg.displayedText < #msg.text then
            msg.animTimer = msg.animTimer + dt
            local charsPerSecond = 30
            local charsToShow = math.floor(msg.animTimer * charsPerSecond)
            msg.displayedText = msg.text:sub(1, math.min(charsToShow, #msg.text))
        end
    end
end

-- Draw tile grid overlay (for debugging/cheats)
function UISystem.drawGrid(camX, camY, showGrid)
    if not showGrid then
        return
    end

    love.graphics.setColor(0, 1, 0, 0.3)
    local startX = math.floor(camX / 16) * 16
    local startY = math.floor(camY / 16) * 16
    for x = startX - 16, camX + GAME_WIDTH + 16, 16 do
        love.graphics.line(x - camX, 0, x - camX, GAME_HEIGHT)
    end
    for y = startY - 16, camY + GAME_HEIGHT + 16, 16 do
        love.graphics.line(0, y - camY, GAME_WIDTH, y - camY)
    end
end

-- Draw active cheat/ability indicators
function UISystem.drawIndicators(noclipActive, gridActive, abilityManager)
    local cheatText = ""

    if noclipActive then
        cheatText = cheatText .. " [NOCLIP]"
    end

    -- Show all active abilities
    if abilityManager then
        for _, ability in pairs(abilityManager:getAllAbilities()) do
            local displayText = ability.name:upper()
            if ability.type == "consumable" and ability.maxUses then
                displayText = displayText .. ":" .. ability.currentUses
            end
            cheatText = cheatText .. " [" .. displayText .. "]"
        end
    end

    if gridActive then
        cheatText = cheatText .. " [GRID]"
    end

    if cheatText ~= "" then
        love.graphics.setColor(1, 0.5, 0, 0.9)
        local textWidth = font:getWidth(cheatText)
        love.graphics.print(cheatText, GAME_WIDTH - textWidth - 2, -1)
    end
end

-- Draw cheat console
function UISystem.drawCheatConsole(CheatConsole)
    if not CheatConsole.isOpen() then
        return
    end

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
    local history = CheatConsole.getHistory()
    for i = math.min(3, #history), 1, -1 do
        love.graphics.print("> " .. history[i], boxX+4, y)
        y = y + 10
    end

    -- Input prompt
    y = boxY + boxH - 24
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.print("> ", boxX+4, y)
    
    -- Input text
    love.graphics.setColor(1, 1, 1)
    local input = CheatConsole.getInput()
    love.graphics.print(input, boxX+16, y)
    
    -- Cursor (blinking)
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local cursorX = boxX + 16 + font:getWidth(input)
        love.graphics.rectangle("fill", cursorX, y, 6, 10)
    end
    
    -- Instructions (inside the box, with padding)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("[Enter] Submit  [Up/Down] History  [Esc/~] Close", boxX+4, boxY+boxH-14)
end

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
function UISystem.isMouseOverButton(btnX, btnY, btnWidth, btnHeight)
    -- Convert screen coordinates to canvas coordinates
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local offsetX = math.floor((screenWidth - TOTAL_WIDTH * SCALE) / 2 / SCALE) * SCALE
    local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
    local canvasX = (mouseX - offsetX) / SCALE
    local canvasY = (mouseY - offsetY) / SCALE

    return canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= btnY and canvasY <= btnY + btnHeight
end

-- Draw toasts
function UISystem.drawToasts()
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
function UISystem.drawPauseMenu()
    -- Semi-transparent background overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", CHAT_PANE_WIDTH, 0, GAME_WIDTH, GAME_HEIGHT)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Paused", CHAT_PANE_WIDTH, 60, GAME_WIDTH, "center")

    -- Buttons
    local btnWidth = 100
    local btnHeight = 20
    local btnX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - btnWidth / 2

    -- Resume button
    local resumeHover = UISystem.isMouseOverButton(btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(resumeHover and 0.3 or 0.2, resumeHover and 0.2 or 0.15, resumeHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(resumeHover and 1 or 0.8, resumeHover and 0.8 or 0.6, resumeHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Resume", btnX, 100 + 3, btnWidth, "center")

    -- Quit Game button
    local quitHover = UISystem.isMouseOverButton(btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(quitHover and 0.3 or 0.2, quitHover and 0.2 or 0.15, quitHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(quitHover and 1 or 0.8, quitHover and 0.8 or 0.6, quitHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Quit Game", btnX, 130 + 3, btnWidth, "center")
end

-- Draw main menu
function UISystem.drawMainMenu()
    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.rectangle("fill", CHAT_PANE_WIDTH, 0, GAME_WIDTH, GAME_HEIGHT)

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.printf("Go Fetch", CHAT_PANE_WIDTH, 40, GAME_WIDTH, "center")
    love.graphics.setFont(font)

    -- Buttons
    local btnWidth = 100
    local btnHeight = 20
    local btnX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - btnWidth / 2

    -- Play button
    local playHover = UISystem.isMouseOverButton(btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(playHover and 0.3 or 0.2, playHover and 0.2 or 0.15, playHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(playHover and 1 or 0.8, playHover and 0.8 or 0.6, playHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 100, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Play", btnX, 100 + 3, btnWidth, "center")

    -- Settings button
    local settingsHover = UISystem.isMouseOverButton(btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(settingsHover and 0.3 or 0.2, settingsHover and 0.2 or 0.15, settingsHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(settingsHover and 1 or 0.8, settingsHover and 0.8 or 0.6, settingsHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 130, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Settings", btnX, 130 + 3, btnWidth, "center")

    -- Quit button
    local quitHover = UISystem.isMouseOverButton(btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(quitHover and 0.3 or 0.2, quitHover and 0.2 or 0.15, quitHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(quitHover and 1 or 0.8, quitHover and 0.8 or 0.6, quitHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Quit", btnX, 160 + 3, btnWidth, "center")
end

-- Draw settings menu
function UISystem.drawSettings(volume)
    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.rectangle("fill", CHAT_PANE_WIDTH, 0, GAME_WIDTH, GAME_HEIGHT)

    -- Title
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.printf("Settings", CHAT_PANE_WIDTH, 40, GAME_WIDTH, "center")

    -- Volume label
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Volume", CHAT_PANE_WIDTH, 80, GAME_WIDTH, "center")

    -- Volume slider
    local sliderX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - 50
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
    love.graphics.printf(math.floor(volume * 100) .. "%", CHAT_PANE_WIDTH, 115, GAME_WIDTH, "center")

    -- Back button
    local btnWidth = 100
    local btnHeight = 20
    local btnX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - btnWidth / 2
    local backHover = UISystem.isMouseOverButton(btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(backHover and 0.3 or 0.2, backHover and 0.2 or 0.15, backHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(backHover and 1 or 0.8, backHover and 0.8 or 0.6, backHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 160, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Back", btnX, 160 + 3, btnWidth, "center")
end

-- Draw quest log
function UISystem.drawQuestLog(activeQuests, completedQuests, quests)
    local boxX, boxY = CHAT_PANE_WIDTH + 10, 10
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

-- Draw quest turn-in UI (dialog box only)
function UISystem.drawQuestTurnIn()
    if not gameStateRefs.questTurnInData then
        return
    end

    local quest = gameStateRefs.questTurnInData.quest
    local boxX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - 75
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

    for i, itemId in ipairs(gameStateRefs.inventory) do
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
        local itemData = gameStateRefs.itemRegistry[itemId]
        local itemName = itemData and itemData.name or itemId
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(itemName, slotX + slotSize + 4, slotY + 2)
    end

    -- Footer hint
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("[ESC] Cancel", boxX + 4, boxY + boxH - 17)
end

-- Draw quest offer UI
function UISystem.drawQuestOffer(questOfferData)
    if not questOfferData then
        return
    end

    local quest = questOfferData.quest
    local npc = questOfferData.npc

    -- Dialog box
    local boxX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - 100
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
    local acceptHover = UISystem.isMouseOverButton(acceptX, btnY, btnW, btnH)
    love.graphics.setColor(acceptHover and 0.2 or 0.15, acceptHover and 0.35 or 0.25, acceptHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", acceptX, btnY, btnW, btnH)
    love.graphics.setColor(acceptHover and 0.4 or 0.2, acceptHover and 0.8 or 0.6, acceptHover and 0.3 or 0.2)
    love.graphics.rectangle("line", acceptX, btnY, btnW, btnH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Accept", acceptX, btnY + 2, btnW, "center")

    -- Reject button
    local rejectHover = UISystem.isMouseOverButton(rejectX, btnY, btnW, btnH)
    love.graphics.setColor(rejectHover and 0.35 or 0.25, rejectHover and 0.2 or 0.15, rejectHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", rejectX, btnY, btnW, btnH)
    love.graphics.setColor(rejectHover and 0.9 or 0.7, rejectHover and 0.4 or 0.3, rejectHover and 0.3 or 0.2)
    love.graphics.rectangle("line", rejectX, btnY, btnW, btnH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Reject", rejectX, btnY + 2, btnW, "center")
end

-- Draw inventory
function UISystem.drawInventory(inventory, itemRegistry)
    local boxX, boxY = CHAT_PANE_WIDTH + 10, 10
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

-- Draw win screen
function UISystem.drawWinScreen(playerGold, completedQuests)
    -- Background
    love.graphics.setColor(0, 0, 0, 0.95)
    love.graphics.rectangle("fill", CHAT_PANE_WIDTH, 0, GAME_WIDTH, GAME_HEIGHT)

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 0.84, 0)
    love.graphics.printf("QUEST COMPLETE!", CHAT_PANE_WIDTH, 60, GAME_WIDTH, "center")
    love.graphics.setFont(font)

    -- Message
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("You have completed the Royal Gift quest!", CHAT_PANE_WIDTH, 110, GAME_WIDTH, "center")
    love.graphics.printf("The King is very pleased with the Labubu!", CHAT_PANE_WIDTH, 125, GAME_WIDTH, "center")

    -- Stats
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf("Final Gold: " .. playerGold, CHAT_PANE_WIDTH, 155, GAME_WIDTH, "center")
    love.graphics.printf("Quests Completed: " .. #completedQuests, CHAT_PANE_WIDTH, 170, GAME_WIDTH, "center")

    -- Footer
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf("The game will close in a moment...", CHAT_PANE_WIDTH, 200, GAME_WIDTH, "center")
end

-- Draw UI hints bar at top of screen
function UISystem.drawUIHints()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("L: Quest log  I: Inventory", 2, -2)
end

-- Draw gold display at top center of screen
function UISystem.drawGoldDisplay(playerGold)
    local goldText = "Gold: " .. playerGold
    local goldTextWidth = font:getWidth(goldText)
    love.graphics.setColor(1, 0.84, 0) -- Gold color
    love.graphics.print(goldText, GAME_WIDTH / 2 - goldTextWidth / 2, -1)
end

-- Draw chat pane
function UISystem.drawChatPane()
    -- Dark background for the chat pane
    love.graphics.setColor(0.1, 0.1, 0.12)
    love.graphics.rectangle("fill", 0, 0, CHAT_PANE_WIDTH, GAME_HEIGHT)

    -- Border between chat and game
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.setLineWidth(1)
    love.graphics.line(CHAT_PANE_WIDTH, 0, CHAT_PANE_WIDTH, GAME_HEIGHT)

    -- Draw messages
    local y = GAME_HEIGHT - 2
    for i = #chatMessages, 1, -1 do
        local msg = chatMessages[i]
        local isJarf = msg.speaker == "J.A.R.F."

        -- Layout: [2px][16px pic][2px margin][bubble][pane edge at 106]
        -- Available space for bubble: 106 - 20 (pic+margins) = 86px max
        local maxBubbleWidth = 80
        local textPaddingLeft = 3
        local textPaddingRight = 3

        -- Wrap text to fit with padding
        local maxTextWidth = maxBubbleWidth - textPaddingLeft - textPaddingRight
        local _, wrappedText = font:getWrap(msg.displayedText, maxTextWidth)

        -- Find the actual widest line
        local actualMaxLineWidth = 0
        for _, line in ipairs(wrappedText) do
            local lineWidth = font:getWidth(line)
            if lineWidth > actualMaxLineWidth then
                actualMaxLineWidth = lineWidth
            end
        end

        local bubbleWidth = actualMaxLineWidth + textPaddingLeft + textPaddingRight
        local bubbleHeight = #wrappedText * 10 + 5

        -- Position bubble
        local bubbleX
        if isJarf then
            -- J.A.R.F.: pic at x=2 (16px wide), bubble starts at x=20
            bubbleX = 20
        else
            -- Developer: pic at x=88 (16px wide), bubble ends before it
            bubbleX = 106 - 20 - bubbleWidth
        end
        local bubbleY = y - bubbleHeight - 2

        -- Draw profile picture (16x16)
        local picX
        if isJarf then
            picX = 2
            if jarfSprite then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(jarfSprite, picX, bubbleY + bubbleHeight / 2 - 8)
            end
        else
            picX = CHAT_PANE_WIDTH - 18
            if developerSprite then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(developerSprite, picX, bubbleY + bubbleHeight / 2 - 8)
            end
        end

        -- Draw bubble background
        if isJarf then
            love.graphics.setColor(0.2, 0.25, 0.3, 0.9)
        else
            love.graphics.setColor(0.25, 0.3, 0.35, 0.9)
        end
        love.graphics.rectangle("fill", bubbleX, bubbleY, bubbleWidth, bubbleHeight, 3, 3)

        -- Draw bubble border
        love.graphics.setColor(0.4, 0.45, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", bubbleX, bubbleY, bubbleWidth, bubbleHeight, 3, 3)

        -- Draw text (with exact padding)
        love.graphics.setColor(0.9, 0.9, 0.95)
        local textX = bubbleX + textPaddingLeft
        for lineIdx, line in ipairs(wrappedText) do
            love.graphics.print(line, textX, bubbleY + (lineIdx - 1) * 10)
        end

        y = bubbleY - 3  -- Reduced from 8 to 3 for tighter spacing
    end
end

-- Helper function to convert screen coordinates to canvas coordinates
local function screenToCanvas(x, y)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local offsetX = math.floor((screenWidth - TOTAL_WIDTH * SCALE) / 2 / SCALE) * SCALE
    local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
    local canvasX = (x - offsetX) / SCALE
    local canvasY = (y - offsetY) / SCALE
    return canvasX, canvasY
end

-- Handle main menu clicks
function UISystem.handleMainMenuClick(x, y, callbacks)
    local canvasX, canvasY = screenToCanvas(x, y)

    -- Button positions (offset by chat pane)
    local btnWidth = 100
    local btnHeight = 20
    local btnX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - btnWidth / 2
    local playY = 100
    local settingsY = 130
    local quitY = 160

    -- Check Play button
    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= playY and canvasY <= playY + btnHeight then
        if callbacks.onPlay then
            callbacks.onPlay()
        end
        return true
    end

    -- Check Settings button
    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= settingsY and canvasY <= settingsY + btnHeight then
        if callbacks.onSettings then
            callbacks.onSettings()
        end
        return true
    end

    -- Check Quit button
    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= quitY and canvasY <= quitY + btnHeight then
        if callbacks.onQuit then
            callbacks.onQuit()
        end
        return true
    end

    return false
end

-- Handle pause menu clicks
function UISystem.handlePauseMenuClick(x, y, callbacks)
    local canvasX, canvasY = screenToCanvas(x, y)

    -- Button positions (offset by chat pane)
    local btnWidth = 100
    local btnHeight = 20
    local btnX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - btnWidth / 2
    local resumeY = 100
    local quitY = 130

    -- Check Resume button
    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= resumeY and canvasY <= resumeY + btnHeight then
        if callbacks.onResume then
            callbacks.onResume()
        end
        return true
    end

    -- Check Quit Game button
    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= quitY and canvasY <= quitY + btnHeight then
        if callbacks.onQuit then
            callbacks.onQuit()
        end
        return true
    end

    return false
end

-- Handle settings menu clicks
function UISystem.handleSettingsClick(x, y, volume, callbacks)
    local canvasX, canvasY = screenToCanvas(x, y)

    -- Back button (offset by chat pane)
    local btnWidth = 100
    local btnHeight = 20
    local btnX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - btnWidth / 2
    local backY = 160

    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= backY and canvasY <= backY + btnHeight then
        if callbacks.onBack then
            callbacks.onBack()
        end
        return true
    end

    -- Volume slider
    local newVolume = UISystem.startSliderDrag(volume, callbacks.onVolumeChange)
    return false, newVolume
end

-- Handle quest turn-in clicks
function UISystem.handleQuestTurnInClick(x, y, questTurnInData, inventory, callbacks)
    if not questTurnInData then
        return false
    end

    -- Note: x, y are already in canvas coordinates for this function
    local quest = questTurnInData.quest

    -- Calculate item slot positions (must match drawQuestTurnIn)
    local boxX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - 75
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
                -- Correct item clicked!
                if callbacks.onCorrectItem then
                    callbacks.onCorrectItem(quest, questTurnInData.npc)
                end
            else
                -- Wrong item
                if callbacks.onWrongItem then
                    callbacks.onWrongItem()
                end
            end
            return true
        end
    end

    return false
end

-- Handle quest offer clicks
function UISystem.handleQuestOfferClick(x, y, questOfferData, callbacks)
    if not questOfferData then
        return false
    end

    local canvasX, canvasY = screenToCanvas(x, y)

    local boxX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - 100
    local boxY = GAME_HEIGHT / 2 - 60
    local boxW = 200
    local boxH = 120

    local btnW = 70
    local btnH = 18
    local btnY = boxY + boxH - btnH - 6
    local acceptX = boxX + boxW/2 - btnW - 4
    local rejectX = boxX + boxW/2 + 4

    -- Check accept button
    if canvasX >= acceptX and canvasX <= acceptX + btnW and canvasY >= btnY and canvasY <= btnY + btnH then
        if callbacks.onAccept then
            callbacks.onAccept(questOfferData.quest)
        end
        return true
    end

    -- Check reject button
    if canvasX >= rejectX and canvasX <= rejectX + btnW and canvasY >= btnY and canvasY <= btnY + btnH then
        if callbacks.onReject then
            callbacks.onReject()
        end
        return true
    end

    return false
end

return UISystem
