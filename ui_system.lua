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
local tempCanvas = nil -- Temporary canvas for shader compositing

-- Font resources
local font = nil
local titleFont = nil

-- CRT glitch shader
local crtShader = nil

-- Mouse state
local mouseX = 0
local mouseY = 0

-- Slider state
local draggingSlider = false

-- Toast system
local toasts = {}
local TOAST_DURATION = 3.0 -- seconds

-- Chat UI state
local dialogSections = require("dialog_script")  -- Event-driven dialog sections
local chatMessages = {} -- {speaker, text, displayedText, animTimer}
local jarfSprite = nil
local developerSprite = nil
local itemTileset = nil -- Tileset containing item sprites
local chatPaneVisible = false -- Track if chat pane should be visible
local chatPaneTransition = {
    active = false,
    progress = 0,
    duration = 0.5 -- seconds for the slide animation
}
local scanlineGlitchTimer = 0 -- Timer for scanline appearance glitch
local randomGlitchTimer = 0 -- Timer for random glitches while chat is open
local nextRandomGlitch = 0 -- Time until next random glitch
local timedGlitchTimer = 0 -- Timer for periodic glitch bursts
local nextTimedGlitch = 0 -- Time until next timed glitch
local permanentScanlines = false -- Permanently enable scanlines regardless of chat pane state

-- Event-driven dialog system
local activeDialogSection = nil  -- Currently playing dialog section
local dialogSectionIndex = 0  -- Current message index in the section
local dialogSectionQueue = {}  -- Queue of messages to display
local dialogSectionTimer = 0  -- Timer for auto-playing messages
local dialogCloseCallback = nil  -- Callback when dialog section completes

-- Game state references (set by main.lua)
local gameStateRefs = {
    inventory = nil,
    itemRegistry = nil,
    questTurnInData = nil
}

-- Quest turn-in pagination state
local questTurnInPage = 0  -- Current page (0-indexed)
local questTurnInMaxPage = 0  -- Maximum page index

-- Inventory pagination state
local inventoryPage = 0  -- Current page (0-indexed)
local inventoryMaxPage = 0  -- Maximum page index

-- Inventory layout constants
local INVENTORY_SLOTS_PER_COLUMN = 8
local INVENTORY_COLUMNS_PER_PAGE = 2
local INVENTORY_ITEMS_PER_PAGE = INVENTORY_SLOTS_PER_COLUMN * INVENTORY_COLUMNS_PER_PAGE

-- Quest log pagination state
local questLogPage = 0  -- Current page (0-indexed)
local questLogMaxPage = 0  -- Maximum page index
local QUEST_LOG_LINES_PER_PAGE = 15  -- Number of text lines per page

-- Set game state references
function UISystem.setGameStateRefs(refs)
    -- Only reset pagination if questTurnInData is NEW (not just being refreshed)
    local shouldResetPagination = refs.questTurnInData and 
                                   refs.questTurnInData ~= gameStateRefs.questTurnInData
    
    for key, value in pairs(refs) do
        gameStateRefs[key] = value
    end
    
    -- Reset pagination only when opening a NEW quest turn-in dialog
    if shouldResetPagination and refs.inventory then
        questTurnInPage = 0
        local itemsPerPage = 5
        local totalItems = #refs.inventory
        questTurnInMaxPage = math.max(0, math.ceil(totalItems / itemsPerPage) - 1)
    end
end

-- Navigate to previous page in quest turn-in
function UISystem.questTurnInPrevPage()
    if questTurnInPage > 0 then
        questTurnInPage = questTurnInPage - 1
    end
end

-- Navigate to next page in quest turn-in
function UISystem.questTurnInNextPage()
    if questTurnInPage < questTurnInMaxPage then
        questTurnInPage = questTurnInPage + 1
    end
end

-- Navigate to previous page in inventory
function UISystem.inventoryPrevPage()
    if inventoryPage > 0 then
        inventoryPage = inventoryPage - 1
    end
end

-- Navigate to next page in inventory
function UISystem.inventoryNextPage()
    if inventoryPage < inventoryMaxPage then
        inventoryPage = inventoryPage + 1
    end
end

-- Reset inventory pagination (call when opening inventory)
function UISystem.resetInventoryPagination(inventory)
    inventoryPage = 0
    local totalItems = #inventory
    inventoryMaxPage = math.max(0, math.ceil(totalItems / INVENTORY_ITEMS_PER_PAGE) - 1)
end

-- Navigate to previous page in quest log
function UISystem.questLogPrevPage()
    if questLogPage > 0 then
        questLogPage = questLogPage - 1
    end
end

-- Navigate to next page in quest log
function UISystem.questLogNextPage()
    if questLogPage < questLogMaxPage then
        questLogPage = questLogPage + 1
    end
end

-- Reset quest log pagination (call when opening quest log)
function UISystem.resetQuestLogPagination()
    questLogPage = 0
    -- questLogMaxPage will be calculated dynamically in drawQuestLog
    -- based on the actual quest state (single source of truth)
end

-- Enable permanent scanlines (for event triggers)
function UISystem.enablePermanentScanlines()
    permanentScanlines = true
end

-- Initialize UI system
function UISystem.init()
    -- Get desktop dimensions
    local desktopWidth, desktopHeight = love.window.getDesktopDimensions()

    -- Calculate scale factor (highest integer multiple that fits screen)
    -- Use the full width from the start to avoid resizing
    local scaleX = math.floor(desktopWidth / TOTAL_WIDTH)
    local scaleY = math.floor(desktopHeight / GAME_HEIGHT)
    SCALE = math.min(scaleX, scaleY)
    if SCALE < 1 then SCALE = 1 end

    -- Set window mode (full size from the start)
    love.window.setMode(TOTAL_WIDTH * SCALE, GAME_HEIGHT * SCALE, {fullscreen = true})

    -- Disable interpolation globally
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Create canvas (always full width to support both states)
    canvas = love.graphics.newCanvas(TOTAL_WIDTH, GAME_HEIGHT)
    canvas:setFilter("nearest", "nearest")
    
    -- Create temporary canvas for shader compositing
    tempCanvas = love.graphics.newCanvas(TOTAL_WIDTH, GAME_HEIGHT)
    tempCanvas:setFilter("nearest", "nearest")

    -- Load fonts
    UISystem.loadFonts()

    -- Load chat sprites
    jarfSprite = love.graphics.newImage("sprites/robot.png")
    jarfSprite:setFilter("nearest", "nearest")
    developerSprite = love.graphics.newImage("sprites/developer.png")
    developerSprite:setFilter("nearest", "nearest")
    
    -- Load item tileset
    itemTileset = love.graphics.newImage("tiles/fetch-tileset.png")
    itemTileset:setFilter("nearest", "nearest")
    
    -- Create CRT glitch shader
    -- Glitch shader (RGB split, horizontal distortion, noise)
    glitchShader = love.graphics.newShader([[
        uniform float time;
        uniform float glitchIntensity;
        
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            vec4 pixel = Texel(texture, texture_coords);
            
            if (glitchIntensity > 0.0) {
                // Horizontal glitch lines
                float glitchLine = sin(screen_coords.y * 0.5 + time * 50.0) * 0.5 + 0.5;
                if (glitchLine > 0.95) {
                    texture_coords.x += sin(time * 100.0) * 0.05 * glitchIntensity;
                    pixel = Texel(texture, texture_coords);
                }
                
                // RGB split
                float offset = 0.003 * glitchIntensity;
                float r = Texel(texture, texture_coords + vec2(offset, 0.0)).r;
                float g = Texel(texture, texture_coords).g;
                float b = Texel(texture, texture_coords - vec2(offset, 0.0)).b;
                pixel.rgb = vec3(r, g, b);
                
                // Scanlines (during glitch)
                float scanline = sin(screen_coords.y * 2.0) * 0.1 * glitchIntensity;
                pixel.rgb -= scanline;
                
                // Random noise
                float noise = fract(sin(dot(screen_coords + time * 10.0, vec2(12.9898, 78.233))) * 43758.5453);
                pixel.rgb += noise * 0.05 * glitchIntensity;
            }
            
            return pixel * color;
        }
    ]])
    
    -- Scanline shader (persistent CRT effect)
    scanlineShader = love.graphics.newShader([[
        uniform float time;
        uniform float scanlineIntensity;
        
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            vec4 pixel = Texel(texture, texture_coords);
            
            if (scanlineIntensity > 0.0) {
                // Intermittent tracking issues - only happens occasionally
                float trackingGlitch = sin(time * 0.3) * 0.5 + 0.5; // Slow oscillation
                float shouldGlitch = step(0.85, trackingGlitch); // Only glitch 15% of the time
                
                // Bigger, more visible scanlines with occasional movement
                float movement = shouldGlitch * sin(time * 2.0) * 3.0; // Quick drift when glitching
                float scanline = sin((screen_coords.y + movement) * 1.0) * 0.15;
                pixel.rgb -= scanline * scanlineIntensity;
                
                // Rare interference lines that sweep by
                float interferenceTime = sin(time * 0.8) * 0.5 + 0.5;
                if (interferenceTime > 0.95) {
                    float interference = sin((screen_coords.y * 0.1) + (time * 5.0)) * 0.5 + 0.5;
                    if (interference > 0.97) {
                        pixel.rgb -= 0.12 * scanlineIntensity;
                    }
                }
                
                // Subtle CRT curve darkening at edges
                vec2 uv = screen_coords / love_ScreenSize.xy;
                float vignette = 1.0 - length(uv - 0.5) * 0.3;
                pixel.rgb *= mix(1.0, vignette, scanlineIntensity * 0.5);
            }
            
            return pixel * color;
        }
    ]])
end

-- Get the canvas
function UISystem.getCanvas()
    return canvas
end

function UISystem.getTempCanvas()
    return tempCanvas
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

function UISystem.getItemTileset()
    return itemTileset
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

-- Helper function to convert screen coordinates to canvas coordinates
local function screenToCanvas(x, y)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Account for the canvas shift during transition
    local transitionProgress = chatPaneVisible and (chatPaneTransition.active and (1 - (1 - chatPaneTransition.progress)^3) or 1) or 0
    local currentVisibleWidth = GAME_WIDTH + (CHAT_PANE_WIDTH * transitionProgress)
    
    -- Calculate where the canvas is drawn
    local offsetX = math.floor((screenWidth - currentVisibleWidth * SCALE) / 2 / SCALE) * SCALE
    local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
    
    -- Account for canvas shift to hide chat pane initially
    offsetX = offsetX - (CHAT_PANE_WIDTH * (1 - transitionProgress) * SCALE)
    
    local canvasX = (x - offsetX) / SCALE
    local canvasY = (y - offsetY) / SCALE
    return canvasX, canvasY
end

-- Handle slider dragging during mouse move
function UISystem.handleSliderDrag(volume, onVolumeChange)
    if not draggingSlider then
        return volume
    end

    -- Convert screen coordinates to canvas coordinates
    local canvasX, canvasY = screenToCanvas(mouseX, mouseY)

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
    local canvasX, canvasY = screenToCanvas(mouseX, mouseY)

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

-- Trigger a dialog event (NEW EVENT-DRIVEN SYSTEM)
function UISystem.triggerDialogEvent(eventName, onCompleteCallback)
    -- Find the dialog section for this event
    local section = nil
    for key, dialogSection in pairs(dialogSections) do
        if dialogSection.event == eventName then
            section = dialogSection
            break
        end
    end
    
    if not section then
        print("Warning: Dialog event '" .. eventName .. "' not found")
        if onCompleteCallback then
            onCompleteCallback()
        end
        return
    end
    
    -- Show chat pane if hidden
    if not chatPaneVisible then
        chatPaneVisible = true
        chatPaneTransition.active = true
        chatPaneTransition.progress = 0
        scanlineGlitchTimer = 0.4
    end
    
    -- Set up the dialog section
    activeDialogSection = section
    dialogSectionIndex = 0
    dialogCloseCallback = onCompleteCallback
    dialogSectionTimer = 0
    
    -- Build the queue of messages
    dialogSectionQueue = {}
    for _, msg in ipairs(section.messages) do
        table.insert(dialogSectionQueue, msg)
    end
    
    -- If autoPlay, immediately show first message
    if section.autoPlay and #dialogSectionQueue > 0 then
        local firstMsg = table.remove(dialogSectionQueue, 1)
        table.insert(chatMessages, {
            speaker = firstMsg.speaker,
            text = firstMsg.text,
            displayedText = "",
            animTimer = 0
        })
        if #chatMessages > 8 then
            table.remove(chatMessages, 1)
        end
        dialogSectionIndex = 1
    end
end


-- Update chat animation
function UISystem.updateChat(dt)
    -- Update event-driven dialog section auto-play
    if activeDialogSection and activeDialogSection.autoPlay and #dialogSectionQueue > 0 then
        dialogSectionTimer = dialogSectionTimer + dt
        
        -- Show next message every 3 seconds
        if dialogSectionTimer >= 3.0 then
            dialogSectionTimer = 0
            local nextMsg = table.remove(dialogSectionQueue, 1)
            table.insert(chatMessages, {
                speaker = nextMsg.speaker,
                text = nextMsg.text,
                displayedText = "",
                animTimer = 0
            })
            if #chatMessages > 8 then
                table.remove(chatMessages, 1)
            end
            dialogSectionIndex = dialogSectionIndex + 1
        end
    end
    
    -- Check if dialog section is complete
    if activeDialogSection and #dialogSectionQueue == 0 and activeDialogSection.autoPlay then
        -- All messages shown, check if we should close
        if activeDialogSection.closeAfter then
            dialogSectionTimer = dialogSectionTimer + dt
            local totalDuration = (dialogSectionIndex * 3.0) + activeDialogSection.closeAfter
            
            if dialogSectionTimer >= 3.0 + activeDialogSection.closeAfter then
                -- Close chat pane
                chatPaneVisible = false
                chatPaneTransition.active = true
                chatPaneTransition.progress = 0
                
                -- Call completion callback
                if dialogCloseCallback then
                    dialogCloseCallback()
                    dialogCloseCallback = nil
                end
                
                -- Clear active section
                activeDialogSection = nil
                dialogSectionIndex = 0
                dialogSectionTimer = 0
            end
        else
            -- No auto-close, just clear the active section
            if dialogCloseCallback then
                dialogCloseCallback()
                dialogCloseCallback = nil
            end
            activeDialogSection = nil
            dialogSectionIndex = 0
            dialogSectionTimer = 0
        end
    end
    
    -- Update chat pane transition
    if chatPaneTransition.active then
        chatPaneTransition.progress = chatPaneTransition.progress + dt / chatPaneTransition.duration
        
        if chatPaneTransition.progress >= 1 then
            chatPaneTransition.progress = 1
            chatPaneTransition.active = false
        end
    end
    
    -- Update scanline glitch timer
    if scanlineGlitchTimer > 0 then
        scanlineGlitchTimer = scanlineGlitchTimer - dt
        if scanlineGlitchTimer < 0 then
            scanlineGlitchTimer = 0
        end
    end
    
    -- Timed glitch bursts while chat is open
    if chatPaneVisible and not chatPaneTransition.active then
        -- Countdown to next timed glitch
        if nextTimedGlitch <= 0 then
            -- Trigger a timed glitch burst
            timedGlitchTimer = love.math.random() * 0.3 + 0.2 -- 0.2-0.5 seconds
            -- Schedule next glitch in 4-10 seconds
            nextTimedGlitch = love.math.random() * 6 + 4
        else
            nextTimedGlitch = nextTimedGlitch - dt
        end
        
        -- Update active timed glitch
        if timedGlitchTimer > 0 then
            timedGlitchTimer = timedGlitchTimer - dt
            if timedGlitchTimer < 0 then
                timedGlitchTimer = 0
            end
        end
    else
        -- Reset timers when chat is closed
        timedGlitchTimer = 0
        nextTimedGlitch = 0
    end
    
    -- Update message text animation
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
function UISystem.drawIndicators(gridActive, abilityManager)
    local cheatText = ""

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
    love.graphics.print("[Enter] Submit  [Up/Down] History  [Esc] Close", boxX+4, boxY+boxH-14)
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
    -- Convert screen coordinates to canvas coordinates using the helper function
    local canvasX, canvasY = screenToCanvas(mouseX, mouseY)
    return canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= btnY and canvasY <= btnY + btnHeight
end

-- Draw toasts
function UISystem.drawToasts()
    local y = 14 -- Start below the top bar (12px height + 2px padding)
    local maxToastWidth = GAME_WIDTH - 20 -- Maximum width for toast (with some padding)
    
    for i, toast in ipairs(toasts) do
        -- Calculate fade-out alpha based on remaining time
        local alpha = 1
        if toast.timer < 0.5 then
            alpha = toast.timer / 0.5
        end

        -- Split message by explicit newlines first
        local paragraphs = {}
        for paragraph in toast.message:gmatch("[^\n]+") do
            table.insert(paragraphs, paragraph)
        end

        -- Wrap each paragraph to fit within max width
        local wrappedLines = {}
        for _, paragraph in ipairs(paragraphs) do
            local _, wrapped = font:getWrap(paragraph, maxToastWidth - 8) -- Account for padding
            for _, line in ipairs(wrapped) do
                table.insert(wrappedLines, line)
            end
        end

        -- Calculate box dimensions based on wrapped text
        local maxWidth = 0
        for _, line in ipairs(wrappedLines) do
            local lineWidth = font:getWidth(line)
            if lineWidth > maxWidth then
                maxWidth = lineWidth
            end
        end

        local boxW = maxWidth + 8
        local boxH = #wrappedLines * 10 + 2
        local boxX = GAME_WIDTH - boxW - 2 -- Align to right with 2px padding

        -- Background
        love.graphics.setColor(0.05, 0.05, 0.1, 0.9 * alpha)
        love.graphics.rectangle("fill", boxX, y, boxW, boxH)

        -- Border
        love.graphics.setColor(toast.color[1], toast.color[2], toast.color[3], alpha)
        love.graphics.rectangle("line", boxX, y, boxW, boxH)

        -- Text (line by line)
        love.graphics.setColor(toast.color[1], toast.color[2], toast.color[3], alpha)
        for lineIdx, line in ipairs(wrappedLines) do
            love.graphics.print(line, boxX + 4, y + (lineIdx - 1) * 10 - 1)
        end

        y = y + boxH + 4
    end
end

-- Helper function to draw a menu button (DRY)
local function drawMenuButton(x, y, width, height, text)
    local isHover = UISystem.isMouseOverButton(x, y, width, height)
    love.graphics.setColor(isHover and 0.3 or 0.2, isHover and 0.2 or 0.15, isHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(isHover and 1 or 0.8, isHover and 0.8 or 0.6, isHover and 0.4 or 0.2)
    love.graphics.rectangle("line", x, y, width, height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(text, x, y + 3, width, "center")
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

    drawMenuButton(btnX, 100, btnWidth, btnHeight, "Resume")
    drawMenuButton(btnX, 130, btnWidth, btnHeight, "Settings")
    drawMenuButton(btnX, 160, btnWidth, btnHeight, "Quit Game")
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
    love.graphics.printf("Volume", CHAT_PANE_WIDTH, 70, GAME_WIDTH, "center")

    -- Volume slider
    local sliderX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - 50
    local sliderY = 90
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
    love.graphics.printf(math.floor(volume * 100) .. "%", CHAT_PANE_WIDTH, 105, GAME_WIDTH, "center")

    -- Fullscreen toggle
    local isFullscreen = love.window.getFullscreen()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Fullscreen", CHAT_PANE_WIDTH, 125, GAME_WIDTH, "center")

    local btnWidth = 100
    local btnHeight = 20
    local btnX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - btnWidth / 2
    local fullscreenHover = UISystem.isMouseOverButton(btnX, 140, btnWidth, btnHeight)
    love.graphics.setColor(fullscreenHover and 0.3 or 0.2, fullscreenHover and 0.2 or 0.15, fullscreenHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 140, btnWidth, btnHeight)
    love.graphics.setColor(fullscreenHover and 1 or 0.8, fullscreenHover and 0.8 or 0.6, fullscreenHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 140, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(isFullscreen and "ON" or "OFF", btnX, 140 + 3, btnWidth, "center")

    -- Back button
    local backHover = UISystem.isMouseOverButton(btnX, 180, btnWidth, btnHeight)
    love.graphics.setColor(backHover and 0.3 or 0.2, backHover and 0.2 or 0.15, backHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", btnX, 180, btnWidth, btnHeight)
    love.graphics.setColor(backHover and 1 or 0.8, backHover and 0.8 or 0.6, backHover and 0.4 or 0.2)
    love.graphics.rectangle("line", btnX, 180, btnWidth, btnHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Back", btnX, 180 + 3, btnWidth, "center")
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

    -- Build quest lists directly from quest data (single source of truth)
    local activeMainQuests = {}
    local activeSideQuests = {}
    local completedMainQuests = {}
    local completedSideQuests = {}

    -- Iterate through all quests and categorize by actual state
    for questId, quest in pairs(quests) do
        if quest.active and not quest.completed then
            -- Active quest
            if quest.isMainQuest then
                table.insert(activeMainQuests, questId)
            else
                table.insert(activeSideQuests, questId)
            end
        elseif quest.completed then
            -- Completed quest
            if quest.isMainQuest then
                table.insert(completedMainQuests, questId)
            else
                table.insert(completedSideQuests, questId)
            end
        end
    end

    -- Build a flat list of all quests to display (for pagination)
    local allQuestEntries = {}
    
    -- Add "MAIN QUEST" header
    table.insert(allQuestEntries, {type = "header", text = "MAIN QUEST", color = {1, 0.8, 0.3}})
    
    -- Add main quests
    if #activeMainQuests == 0 and #completedMainQuests == 0 then
        table.insert(allQuestEntries, {type = "empty", text = "None"})
    else
        for _, questId in ipairs(activeMainQuests) do
            local quest = quests[questId]
            table.insert(allQuestEntries, {
                type = "quest",
                quest = quest,
                status = "active",
                isMain = true
            })
        end
        for _, questId in ipairs(completedMainQuests) do
            local quest = quests[questId]
            table.insert(allQuestEntries, {
                type = "quest",
                quest = quest,
                status = "completed",
                isMain = true
            })
        end
    end
    
    -- Add "SIDE QUESTS" header
    table.insert(allQuestEntries, {type = "header", text = "SIDE QUESTS", color = {0.8, 0.7, 0.5}})
    
    -- Add side quests
    if #activeSideQuests == 0 and #completedSideQuests == 0 then
        table.insert(allQuestEntries, {type = "empty", text = "None"})
    else
        for _, questId in ipairs(activeSideQuests) do
            local quest = quests[questId]
            table.insert(allQuestEntries, {
                type = "quest",
                quest = quest,
                status = "active",
                isMain = false
            })
        end
        for _, questId in ipairs(completedSideQuests) do
            local quest = quests[questId]
            table.insert(allQuestEntries, {
                type = "quest",
                quest = quest,
                status = "completed",
                isMain = false
            })
        end
    end

    -- Convert entries to renderable lines
    local allLines = {}
    for _, entry in ipairs(allQuestEntries) do
        if entry.type == "header" then
            table.insert(allLines, {
                type = "header",
                text = entry.text,
                color = entry.color,
                indent = 4
            })
        elseif entry.type == "empty" then
            table.insert(allLines, {
                type = "text",
                text = entry.text,
                color = {0.4, 0.4, 0.4},
                indent = 6
            })
        elseif entry.type == "quest" then
            local quest = entry.quest
            if entry.status == "active" then
                -- Active quest - name
                local nameColor = entry.isMain and {1, 0.9, 0.3} or {0.9, 0.8, 0.5}
                table.insert(allLines, {
                    type = "text",
                    text = "- " .. quest.name,
                    color = nameColor,
                    indent = 6
                })
                -- Active quest - description (wrapped)
                local _, wrappedDesc = font:getWrap(quest.description, boxW-12-8)
                for _, line in ipairs(wrappedDesc) do
                    table.insert(allLines, {
                        type = "text",
                        text = line,
                        color = {0.7, 0.7, 0.7},
                        indent = 8
                    })
                end
                -- Add blank line after active quest
                table.insert(allLines, {
                    type = "blank"
                })
            else
                -- Completed quest - just name
                table.insert(allLines, {
                    type = "text",
                    text = "- " .. quest.name .. " (Completed)",
                    color = {0.3, 0.9, 0.3},
                    indent = 6
                })
            end
        end
    end
    
    -- Pagination by lines
    local linesPerPage = QUEST_LOG_LINES_PER_PAGE
    local totalLines = #allLines
    local totalPages = math.max(1, math.ceil(totalLines / linesPerPage))
    questLogMaxPage = totalPages - 1
    
    -- Clamp current page to valid range
    if questLogPage > questLogMaxPage then
        questLogPage = questLogMaxPage
    end
    if questLogPage < 0 then
        questLogPage = 0
    end
    
    local startLine = questLogPage * linesPerPage + 1
    local endLine = math.min(startLine + linesPerPage - 1, totalLines)

    -- Draw paginated lines
    for i = startLine, endLine do
        local line = allLines[i]
        
        if line.type == "header" then
            love.graphics.setColor(line.color)
            love.graphics.print(line.text, boxX + line.indent, y)
            y = y + 12
        elseif line.type == "text" then
            love.graphics.setColor(line.color)
            love.graphics.print(line.text, boxX + line.indent, y)
            y = y + 10
        elseif line.type == "blank" then
            y = y + 4
        end
    end

    -- Page indicator and navigation
    if totalPages > 1 then
        local navY = boxY + boxH - 32
        local btnH = 14
        
        -- Previous button
        if questLogPage > 0 then
            local prevText = "< Prev"
            local prevW = font:getWidth(prevText) + 6
            local prevX = boxX + 4
            
            -- Button background
            love.graphics.setColor(0.2, 0.15, 0.1, 0.8)
            love.graphics.rectangle("fill", prevX, navY, prevW, btnH)
            
            -- Button border
            love.graphics.setColor(0.6, 0.5, 0.3)
            love.graphics.rectangle("line", prevX, navY, prevW, btnH)
            
            -- Button text
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(prevText, prevX + 3, navY + 1)
        end
        
        -- Page indicator (centered)
        love.graphics.setColor(0.7, 0.7, 0.7)
        local pageText = (questLogPage + 1) .. "/" .. totalPages
        local pageTextWidth = font:getWidth(pageText)
        love.graphics.print(pageText, boxX + boxW/2 - pageTextWidth/2, navY + 2)
        
        -- Next button
        if questLogPage < totalPages - 1 then
            local nextText = "Next >"
            local nextW = font:getWidth(nextText) + 6
            local nextX = boxX + boxW - nextW - 4
            
            -- Button background
            love.graphics.setColor(0.2, 0.15, 0.1, 0.8)
            love.graphics.rectangle("fill", nextX, navY, nextW, btnH)
            
            -- Button border
            love.graphics.setColor(0.6, 0.5, 0.3)
            love.graphics.rectangle("line", nextX, navY, nextW, btnH)
            
            -- Button text
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(nextText, nextX + 3, navY + 1)
        end
        
        -- Footer hint with navigation
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("[L] Close  [</>] Page", boxX + 4, boxY + boxH - 15)
    else
        -- Footer hint without navigation
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("[L] Close", boxX+4, boxY+boxH-15)
    end
end

-- Draw quest turn-in UI (dialog box only)
function UISystem.drawQuestTurnIn()
    if not gameStateRefs.questTurnInData then
        return
    end

    local quest = gameStateRefs.questTurnInData.quest
    local boxX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - 90
    local boxY = GAME_HEIGHT / 2 - 80
    local boxW = 180
    local boxH = 160

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
    love.graphics.print("Click the item:", boxX + 4, boxY + 16)

    -- Convert inventory table to sorted array for display
    local inventoryArray = {}
    for itemId, quantity in pairs(gameStateRefs.inventory) do
        table.insert(inventoryArray, {itemId = itemId, quantity = quantity})
    end
    table.sort(inventoryArray, function(a, b) return a.itemId < b.itemId end)

    -- Pagination
    local itemsPerPage = 5
    local totalItems = #inventoryArray
    local totalPages = math.max(1, math.ceil(totalItems / itemsPerPage))
    local startIndex = questTurnInPage * itemsPerPage + 1
    local endIndex = math.min(startIndex + itemsPerPage - 1, totalItems)

    -- Draw inventory items (paginated)
    local slotSize = 18
    local padding = 4
    local startY = boxY + 32

    for i = startIndex, endIndex do
        local itemEntry = inventoryArray[i]
        local itemId = itemEntry.itemId
        local quantity = itemEntry.quantity
        local slotX = boxX + 6
        local slotY = startY + (i - startIndex) * (slotSize + padding)

        -- Slot background
        love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize)

        -- Slot border
        love.graphics.setColor(0.3, 0.25, 0.2)
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize)

        -- Item icon (simple colored square)
        love.graphics.setColor(0.7, 0.5, 0.9)
        love.graphics.rectangle("fill", slotX + 2, slotY + 2, slotSize - 4, slotSize - 4)

        -- Item name from registry with quantity
        local itemData = gameStateRefs.itemRegistry[itemId]
        local itemName = itemData and itemData.name or itemId
        if quantity > 1 then
            itemName = itemName .. " x" .. quantity
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(itemName, slotX + slotSize + 4, slotY + 3)
    end

    -- Page indicator and navigation
    if totalPages > 1 then
        local navY = boxY + boxH - 32
        local btnH = 14
        
        -- Previous button
        if questTurnInPage > 0 then
            local prevText = "< Prev"
            local prevW = font:getWidth(prevText) + 6
            local prevX = boxX + 4
            
            -- Button background
            love.graphics.setColor(0.2, 0.15, 0.1, 0.8)
            love.graphics.rectangle("fill", prevX, navY, prevW, btnH)
            
            -- Button border
            love.graphics.setColor(0.6, 0.5, 0.3)
            love.graphics.rectangle("line", prevX, navY, prevW, btnH)
            
            -- Button text
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(prevText, prevX + 3, navY + 1)
        end
        
        -- Page indicator (centered)
        love.graphics.setColor(0.7, 0.7, 0.7)
        local pageText = (questTurnInPage + 1) .. "/" .. totalPages
        local pageTextWidth = font:getWidth(pageText)
        love.graphics.print(pageText, boxX + boxW/2 - pageTextWidth/2, navY + 2)
        
        -- Next button
        if questTurnInPage < totalPages - 1 then
            local nextText = "Next >"
            local nextW = font:getWidth(nextText) + 6
            local nextX = boxX + boxW - nextW - 4
            
            -- Button background
            love.graphics.setColor(0.2, 0.15, 0.1, 0.8)
            love.graphics.rectangle("fill", nextX, navY, nextW, btnH)
            
            -- Button border
            love.graphics.setColor(0.6, 0.5, 0.3)
            love.graphics.rectangle("line", nextX, navY, nextW, btnH)
            
            -- Button text
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(nextText, nextX + 3, navY + 1)
        end
        
        -- Footer hint with navigation
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("[X] Cancel  [</>] Page", boxX + 4, boxY + boxH - 15)
    else
        -- Footer hint without navigation
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("[X] Cancel", boxX + 4, boxY + boxH - 15)
    end
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
    love.graphics.printf("[E] Accept", acceptX, btnY + 1, btnW, "center")

    -- Reject button
    local rejectHover = UISystem.isMouseOverButton(rejectX, btnY, btnW, btnH)
    love.graphics.setColor(rejectHover and 0.35 or 0.25, rejectHover and 0.2 or 0.15, rejectHover and 0.15 or 0.1)
    love.graphics.rectangle("fill", rejectX, btnY, btnW, btnH)
    love.graphics.setColor(rejectHover and 0.9 or 0.7, rejectHover and 0.4 or 0.3, rejectHover and 0.3 or 0.2)
    love.graphics.rectangle("line", rejectX, btnY, btnW, btnH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("[R] Reject", rejectX, btnY + 1, btnW, "center")
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

    -- Convert inventory table to sorted array for display
    local inventoryArray = {}
    for itemId, quantity in pairs(inventory) do
        table.insert(inventoryArray, {itemId = itemId, quantity = quantity})
    end
    table.sort(inventoryArray, function(a, b) return a.itemId < b.itemId end)

    -- Pagination - use constants defined at top of file
    local slotsPerColumn = INVENTORY_SLOTS_PER_COLUMN
    local columnsPerPage = INVENTORY_COLUMNS_PER_PAGE
    local itemsPerPage = INVENTORY_ITEMS_PER_PAGE
    local totalItems = #inventoryArray
    local totalPages = math.max(1, math.ceil(totalItems / itemsPerPage))
    local startIndex = inventoryPage * itemsPerPage + 1
    local endIndex = math.min(startIndex + itemsPerPage - 1, totalItems)

    -- Content area - 2 column layout (icon on left, name on right for each item)
    local iconSize = 20
    local rowHeight = 18
    local rowPadding = 2
    local startY = boxY + 20
    local columnSpacing = 8
    local itemWidth = 135  -- Width for one item (icon + name)
    
    -- Calculate column positions
    local col1X = boxX + 6
    local col2X = col1X + itemWidth + columnSpacing

    -- Draw all slots (filled or empty) for current page
    for slotIndex = 0, itemsPerPage - 1 do
        local inventoryIndex = startIndex + slotIndex
        local row = slotIndex % slotsPerColumn
        local col = math.floor(slotIndex / slotsPerColumn)
        
        local iconX = (col == 0) and col1X or col2X
        local rowY = startY + row * (rowHeight + rowPadding)
        local nameX = iconX + iconSize + 4

        -- Icon slot background
        if inventoryIndex <= totalItems then
            love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
        else
            -- Empty slot - dimmer
            love.graphics.setColor(0.05, 0.05, 0.1, 0.6)
        end
        love.graphics.rectangle("fill", iconX, rowY, iconSize, iconSize)

        -- Icon slot border
        if inventoryIndex <= totalItems then
            love.graphics.setColor(0.3, 0.25, 0.2)
        else
            -- Empty slot - dimmer border
            love.graphics.setColor(0.2, 0.15, 0.15)
        end
        love.graphics.rectangle("line", iconX, rowY, iconSize, iconSize)

        -- Draw item if present
        if inventoryIndex <= totalItems then
            local itemEntry = inventoryArray[inventoryIndex]
            local itemId = itemEntry.itemId
            local quantity = itemEntry.quantity
            local itemData = itemRegistry[itemId]

            -- Draw item icon
            local icon = itemData and itemData.icon
            local spriteX = icon and icon.x or 32
            local spriteY = icon and icon.y or 192

            love.graphics.setColor(1, 1, 1)
            local quad = love.graphics.newQuad(
                spriteX, spriteY,
                16, 16,
                itemTileset:getDimensions()
            )
            -- Center the 16x16 sprite in the 20x20 slot
            love.graphics.draw(itemTileset, quad, iconX+2, rowY+2)

            -- Draw item name with quantity
            local itemName = itemData and itemData.name or itemId
            if quantity > 1 then
                itemName = itemName .. " x" .. quantity
            end
            love.graphics.setColor(0.9, 0.8, 0.95)
            love.graphics.print(itemName, nameX, rowY + 4)
        else
            -- Empty slot text
            love.graphics.setColor(0.3, 0.25, 0.3)
            love.graphics.print("---", nameX, rowY + 4)
        end
    end

    -- Page indicator and navigation
    if totalPages > 1 then
        local navY = boxY + boxH - 32
        local btnH = 14
        
        -- Previous button
        if inventoryPage > 0 then
            local prevText = "< Prev"
            local prevW = font:getWidth(prevText) + 6
            local prevX = boxX + 4
            
            -- Button background
            love.graphics.setColor(0.2, 0.15, 0.2, 0.8)
            love.graphics.rectangle("fill", prevX, navY, prevW, btnH)
            
            -- Button border
            love.graphics.setColor(0.6, 0.4, 0.7)
            love.graphics.rectangle("line", prevX, navY, prevW, btnH)
            
            -- Button text
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(prevText, prevX + 3, navY + 1)
        end
        
        -- Page indicator (centered)
        love.graphics.setColor(0.7, 0.6, 0.8)
        local pageText = (inventoryPage + 1) .. "/" .. totalPages
        local pageTextWidth = font:getWidth(pageText)
        love.graphics.print(pageText, boxX + boxW/2 - pageTextWidth/2, navY + 2)
        
        -- Next button
        if inventoryPage < totalPages - 1 then
            local nextText = "Next >"
            local nextW = font:getWidth(nextText) + 6
            local nextX = boxX + boxW - nextW - 4
            
            -- Button background
            love.graphics.setColor(0.2, 0.15, 0.2, 0.8)
            love.graphics.rectangle("fill", nextX, navY, nextW, btnH)
            
            -- Button border
            love.graphics.setColor(0.6, 0.4, 0.7)
            love.graphics.rectangle("line", nextX, navY, nextW, btnH)
            
            -- Button text
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(nextText, nextX + 3, navY + 1)
        end
        
        -- Footer hint with navigation
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("[I] Close  [</>] Page", boxX + 4, boxY + boxH - 15)
    else
        -- Footer hint without navigation
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("[I] Close", boxX + 4, boxY + boxH - 15)
    end
end

-- Draw win screen
function UISystem.drawWinScreen(playerGold, completedQuests, winScreenTimer)
    -- Background
    love.graphics.setColor(0, 0, 0, 0.95)
    love.graphics.rectangle("fill", CHAT_PANE_WIDTH, 0, GAME_WIDTH, GAME_HEIGHT)

    -- Scrolling credits
    local scrollSpeed = 20 -- pixels per second
    local scrollY = GAME_HEIGHT - (winScreenTimer * scrollSpeed)
    local lineHeight = 15
    local currentY = scrollY

    -- Credits content
    local credits = {
        {text = "LEVEL UP", font = titleFont, color = {1, 0.84, 0}, spacing = 20},
        {text = "You are now Level 2", font = font, color = {1, 1, 1}, spacing = 10},
        {text = "You have escaped Tutorial Island", font = font, color = {1, 1, 1}, spacing = 5},
        {text = "The end", font = font, color = {1, 1, 1}, spacing = 30},

        {text = "STATISTICS", font = titleFont, color = {0.8, 0.8, 1}, spacing = 20},
        {text = "Final Gold: " .. playerGold, font = font, color = {0.8, 0.8, 0.8}, spacing = 5},
        {text = "Quests Completed: " .. #completedQuests, font = font, color = {0.8, 0.8, 0.8}, spacing = 5},
        {text = "Labubus Collected: 1", font = font, color = {0.8, 0.8, 0.8}, spacing = 30},

        {text = "CREDITS", font = titleFont, color = {1, 0.84, 0}, spacing = 30},
        {text = "Programming", font = font, color = {1, 1, 0.5}, spacing = 10},
        {text = "Keefer <keefer.is>", font = font, color = {1, 1, 1}, spacing = 30},
        {text = "kfarwell <kfarwell.org>", font = font, color = {1, 1, 1}, spacing = 30},
        {text = "MTRooster", font = font, color = {1, 1, 1}, spacing = 30},
        {text = "J.A.R.F.", font = font, color = {1, 1, 1}, spacing = 30},

        {text = "Graphics", font = font, color = {1, 1, 0.5}, spacing = 10},
        {text = "GelatoSquid", font = font, color = {1, 1, 1}, spacing = 30},
        {text = "Keefer", font = font, color = {1, 1, 1}, spacing = 30},
        {text = "MTRooster", font = font, color = {1, 1, 1}, spacing = 30},
        {text = "Ryan Refcio", font = font, color = {1, 1, 1}, spacing = 30},

        {text = "Writing", font = font, color = {1, 1, 0.5}, spacing = 10},
        {text = "existony (x.com/existony)", font = font, color = {1, 1, 1}, spacing = 30},
        {text = "GelatoSquid", font = font, color = {1, 1, 1}, spacing = 30},
        {text = "Keefer", font = font, color = {1, 1, 1}, spacing = 30},
        {text = "kfarwell", font = font, color = {1, 1, 1}, spacing = 30},
        {text = "MTRooster", font = font, color = {1, 1, 1}, spacing = 30},
        {text = "Ryan Refcio", font = font, color = {1, 1, 1}, spacing = 30},

        {text = "Music", font = font, color = {1, 1, 0.5}, spacing = 10},
        {text = "existony", font = font, color = {1, 1, 1}, spacing = 30},
        {text = "J.A.R.F.", font = font, color = {1, 1, 1}, spacing = 30},

        {text = "Thanks for playing!", font = titleFont, color = {1, 0.84, 0}, spacing = 30},
        {text = "Press X to exit", font = font, color = {0.7, 0.7, 0.7}, spacing = 0},
    }

    -- Set scissor to clip credits to game area
    love.graphics.setScissor(CHAT_PANE_WIDTH, 0, GAME_WIDTH, GAME_HEIGHT)

    -- Draw each credit line
    for _, credit in ipairs(credits) do
        if currentY > -30 and currentY < GAME_HEIGHT + 30 then
            love.graphics.setFont(credit.font)
            love.graphics.setColor(credit.color)
            love.graphics.printf(credit.text, CHAT_PANE_WIDTH, currentY, GAME_WIDTH, "center")
        end
        currentY = currentY + lineHeight + credit.spacing
    end

    -- Reset scissor and font
    love.graphics.setScissor()
    love.graphics.setFont(font)
end

-- Draw UI hints bar at top of screen
function UISystem.drawUIHints()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("L: Quest log  I: Inventory  Q: Quack", 2, -2)
end

-- Draw gold display at top right of screen
function UISystem.drawGoldDisplay(playerGold)
    local goldText = "Gold: " .. playerGold
    local goldTextWidth = font:getWidth(goldText)
    love.graphics.setColor(1, 0.84, 0) -- Gold color
    love.graphics.print(goldText, GAME_WIDTH - goldTextWidth - 2, -1)
end

-- Check if chat pane is visible
function UISystem.isChatPaneVisible()
    return chatPaneVisible
end

-- Toggle chat pane visibility (for cheats)
function UISystem.toggleChatPane()
    chatPaneVisible = not chatPaneVisible
    if chatPaneVisible then
        -- Opening chat pane
        chatPaneTransition.active = true
        chatPaneTransition.progress = 0
        -- Trigger scanline glitch effect
        scanlineGlitchTimer = 0.4
    else
        -- Closing chat pane - reverse the transition
        chatPaneTransition.active = true
        chatPaneTransition.progress = 0
    end
end

-- Get chat pane transition progress (0 to 1)
function UISystem.getChatPaneTransitionProgress()
    if not chatPaneVisible then
        -- When closing, reverse the progress
        if chatPaneTransition.active then
            local t = chatPaneTransition.progress
            return 1 - (1 - (1 - t)^3)
        end
        return 0
    elseif chatPaneTransition.active then
        -- Ease-out cubic for smooth animation
        local t = chatPaneTransition.progress
        return 1 - (1 - t)^3
    else
        return 1
    end
end

-- Get glitch intensity based on transition
function UISystem.getGlitchIntensity()
    local intensity = 0
    
    -- Glitch during chat pane transition
    if chatPaneTransition.active then
        local progress = chatPaneTransition.progress
        if chatPaneVisible then
            -- Opening: strong glitch at start, fades out
            intensity = math.max(intensity, (1 - progress) * 1.0)
        else
            -- Closing: glitch builds up
            intensity = math.max(intensity, progress * 0.8)
        end
    end
    
    -- Additional glitch when scanlines first appear
    if scanlineGlitchTimer > 0 then
        -- Intense glitch that fades out
        intensity = math.max(intensity, (scanlineGlitchTimer / 0.4) * 1.2)
    end
    
    -- Timed glitch bursts while chat is open
    if timedGlitchTimer > 0 then
        -- Moderate intensity glitch with fade
        local normalizedTime = timedGlitchTimer / 0.5
        intensity = math.max(intensity, normalizedTime * 0.7)
    end
    
    return intensity
end

-- Check if persistent scanlines should be shown
function UISystem.shouldShowScanlines()
    return chatPaneVisible or permanentScanlines
end

-- Get glitch shader
function UISystem.getGlitchShader()
    return glitchShader
end

-- Get scanline shader
function UISystem.getScanlineShader()
    return scanlineShader
end

-- Draw the canvas with shader effects applied
-- Call this instead of manually drawing the canvas
function UISystem.drawCanvasWithShaders(offsetX, offsetY, scale)
    local glitchIntensity = UISystem.getGlitchIntensity()
    local showScanlines = UISystem.shouldShowScanlines()
    local scanlineIntensity = showScanlines and 1.0 or 0.0
    
    local hasGlitch = glitchIntensity > 0
    local hasScanlines = scanlineIntensity > 0
    
    -- If we have both effects, composite them using a temp canvas
    if hasGlitch and hasScanlines then
        -- Save current scissor state
        local sx, sy, sw, sh = love.graphics.getScissor()
        
        -- Temporarily disable scissor for rendering to temp canvas
        love.graphics.setScissor()
        
        -- First pass: draw main canvas with glitch shader to temp canvas
        love.graphics.setShader(glitchShader)
        glitchShader:send("time", love.timer.getTime())
        glitchShader:send("glitchIntensity", glitchIntensity)
        
        love.graphics.setCanvas(tempCanvas)
        love.graphics.clear()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvas, 0, 0)
        love.graphics.setCanvas()
        
        -- Restore scissor
        if sx then
            love.graphics.setScissor(sx, sy, sw, sh)
        end
        
        -- Second pass: draw temp canvas with scanline shader to screen
        love.graphics.setShader(scanlineShader)
        scanlineShader:send("time", love.timer.getTime())
        scanlineShader:send("scanlineIntensity", scanlineIntensity)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(tempCanvas, offsetX, offsetY, 0, scale, scale)
        
    elseif hasGlitch then
        -- Only glitch shader
        love.graphics.setShader(glitchShader)
        glitchShader:send("time", love.timer.getTime())
        glitchShader:send("glitchIntensity", glitchIntensity)
        love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)
        
    elseif hasScanlines then
        -- Only scanline shader
        love.graphics.setShader(scanlineShader)
        scanlineShader:send("time", love.timer.getTime())
        scanlineShader:send("scanlineIntensity", scanlineIntensity)
        love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)
        
    else
        -- No shaders
        love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)
    end
    
    -- Clear shader
    love.graphics.setShader()
end

-- Draw chat pane
function UISystem.drawChatPane()
    -- Only draw if visible
    if not chatPaneVisible then
        return
    end
    
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
        local displayText = msg.displayedText or ""
        -- Safety check for empty or invalid text
        if displayText == "" then
            displayText = " "
        end
        local _, wrappedText = font:getWrap(displayText, maxTextWidth)

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
    local settingsY = 130
    local quitY = 160

    -- Check Resume button
    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= resumeY and canvasY <= resumeY + btnHeight then
        if callbacks.onResume then
            callbacks.onResume()
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

    local btnWidth = 100
    local btnHeight = 20
    local btnX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - btnWidth / 2

    -- Fullscreen button
    local fullscreenY = 145
    if canvasX >= btnX and canvasX <= btnX + btnWidth and canvasY >= fullscreenY and canvasY <= fullscreenY + btnHeight then
        love.window.setFullscreen(not love.window.getFullscreen())
        return true
    end

    -- Back button
    local backY = 180
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
    local boxX = CHAT_PANE_WIDTH + GAME_WIDTH / 2 - 90
    local boxY = GAME_HEIGHT / 2 - 80
    local boxW = 180
    local boxH = 160
    local slotSize = 18
    local padding = 4
    local startY = boxY + 32

    -- Convert inventory table to sorted array for display
    local inventoryArray = {}
    for itemId, quantity in pairs(inventory) do
        table.insert(inventoryArray, {itemId = itemId, quantity = quantity})
    end
    table.sort(inventoryArray, function(a, b) return a.itemId < b.itemId end)

    -- Pagination
    local itemsPerPage = 5
    local totalItems = #inventoryArray
    local totalPages = math.max(1, math.ceil(totalItems / itemsPerPage))
    local startIndex = questTurnInPage * itemsPerPage + 1
    local endIndex = math.min(startIndex + itemsPerPage - 1, totalItems)

    -- Check item clicks
    for i = startIndex, endIndex do
        local itemEntry = inventoryArray[i]
        local itemId = itemEntry.itemId
        local slotX = boxX + 6
        local slotY = startY + (i - startIndex) * (slotSize + padding)

        -- Check if click is within this item slot
        if x >= slotX and x <= slotX + slotSize and y >= slotY and y <= slotY + slotSize then
            local requiredQty = quest.requiredQuantity or 1
            if itemId == quest.requiredItem and itemEntry.quantity >= requiredQty then
                -- Correct item clicked with enough quantity!
                if callbacks.onCorrectItem then
                    callbacks.onCorrectItem(quest, questTurnInData.npc)
                end
            else
                -- Wrong item or not enough quantity
                if callbacks.onWrongItem then
                    callbacks.onWrongItem()
                end
            end
            return true
        end
    end

    -- Check pagination button clicks
    if totalPages > 1 then
        local navY = boxY + boxH - 32
        local btnH = 14
        
        -- Previous button
        if questTurnInPage > 0 then
            local prevText = "< Prev"
            local prevW = font:getWidth(prevText) + 6
            local prevX = boxX + 4
            if x >= prevX and x <= prevX + prevW and y >= navY and y <= navY + btnH then
                questTurnInPage = math.max(0, questTurnInPage - 1)
                return true
            end
        end
        
        -- Next button
        if questTurnInPage < totalPages - 1 then
            local nextText = "Next >"
            local nextW = font:getWidth(nextText) + 6
            local nextX = boxX + boxW - nextW - 4
            if x >= nextX and x <= nextX + nextW and y >= navY and y <= navY + btnH then
                questTurnInPage = math.min(totalPages - 1, questTurnInPage + 1)
                return true
            end
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
