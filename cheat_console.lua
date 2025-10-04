-- Cheat Console System
-- Provides a developer console for debugging and testing

local CheatConsole = {}

-- Console state
CheatConsole.state = {
    noclip = false,          -- Walk through all walls/water
    showGrid = false,        -- Show tile grid overlay
    showPrompt = false,      -- Console visible?
    input = "",              -- Current cheat code being typed
    history = {},            -- History of entered cheats
    historyIndex = 0,        -- Current position in history (0 = new command)
    tempInput = ""           -- Temporary storage for unsaved input when browsing history
}

-- Helper string trim function
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Process a cheat code
function CheatConsole.processCode(code, gameState)
    code = trim(code:lower())
    
    -- Add to history
    if code ~= "" then
        table.insert(CheatConsole.state.history, 1, code)
        if #CheatConsole.state.history > 10 then
            table.remove(CheatConsole.state.history)
        end
    end
    
    -- Split code into command and parameters
    local parts = {}
    for part in code:gmatch("%S+") do
        table.insert(parts, part)
    end
    local command = parts[1] or ""
    local param = parts[2] or ""
    
    -- Process cheat codes
    if command == "noclip" then
        CheatConsole.state.noclip = not CheatConsole.state.noclip
        gameState.showToast("Noclip: " .. (CheatConsole.state.noclip and "ON" or "OFF"), {1, 0.5, 0})
        
    elseif command == "grid" then
        CheatConsole.state.showGrid = not CheatConsole.state.showGrid
        gameState.showToast("Show Grid: " .. (CheatConsole.state.showGrid and "ON" or "OFF"), {1, 0.5, 0})
        
    elseif command == "unlock" then
        if param == "" then
            gameState.showToast("Usage: unlock <ability> (e.g. unlock swim)", {1, 1, 0.3})
        else
            local abilityData = gameState.getAbilityFromRegistry(param)
            if abilityData then
                local context = {showToast = gameState.showToast}
                gameState.abilityManager:grantAbility(abilityData.id, context)
                gameState.showToast("Unlocked: " .. abilityData.name, {1, 0.5, 0})
            else
                gameState.showToast("Unknown ability: " .. param, {1, 0.3, 0.3})
            end
        end
        
    elseif command == "lock" then
        if param == "" then
            gameState.showToast("Usage: lock <ability> (e.g. lock swim)", {1, 1, 0.3})
        else
            local abilityData = gameState.getAbilityFromRegistry(param)
            if abilityData and gameState.abilityManager:hasAbility(abilityData.id) then
                gameState.abilityManager:removeAbility(abilityData.id)
                gameState.showToast("Locked: " .. abilityData.name, {1, 0.5, 0})
            else
                gameState.showToast("Unknown or not unlocked ability: " .. param, {1, 0.3, 0.3})
            end
        end
        
    elseif command == "god" or command == "godmode" then
        if param == "off" then
            -- Turn off god mode
            CheatConsole.state.noclip = false
            -- Remove all abilities
            for _, abilityId in ipairs(gameState.getAllAbilityIds()) do
                gameState.abilityManager:removeAbility(abilityId)
            end
            gameState.showToast("God Mode Deactivated!", {1, 0.5, 0})
        else
            -- Turn on god mode
            CheatConsole.state.noclip = true
            local context = {showToast = gameState.showToast}
            for _, abilityId in ipairs(gameState.getAllAbilityIds()) do
                gameState.abilityManager:grantAbility(abilityId, context)
            end
            gameState.showToast("God Mode Activated!", {1, 0.5, 0})
        end
        
    elseif command == "questcomplete" or command == "finishquests" then
        local count = 0
        for _, questId in ipairs(gameState.activeQuests) do
            local quest = gameState.quests[questId]
            if quest then
                quest.active = false
                quest.completed = true
                table.insert(gameState.completedQuests, questId)
                count = count + 1
            end
        end
        gameState.activeQuests = {}
        if count > 0 then
            gameState.showToast("Completed " .. count .. " quest(s)", {1, 0.5, 0})
        else
            gameState.showToast("No active quests", {1, 0.5, 0})
        end
        
    elseif command == "fetch" then
        if param == "" then
            gameState.showToast("Usage: fetch <item> or fetch all", {1, 1, 0.3})
        elseif param == "all" then
            -- Clear inventory and add all items
            for i = #gameState.inventory, 1, -1 do
                gameState.inventory[i] = nil
            end
            local allItems = gameState.getAllItemIds()
            for _, itemId in ipairs(allItems) do
                table.insert(gameState.inventory, itemId)
            end
            gameState.showToast("Given all items", {1, 0.5, 0})
        else
            -- Look up item in registry
            local itemData = gameState.getItemFromRegistry(param)
            if itemData then
                -- Check if already have it
                if not gameState.hasItem(itemData.id) then
                    table.insert(gameState.inventory, itemData.id)
                    gameState.showToast("Received: " .. itemData.name, {1, 0.5, 0})
                else
                    gameState.showToast("You already have that item!", {1, 0.5, 0})
                end
            else
                gameState.showToast("Unknown item: " .. param, {1, 0.3, 0.3})
            end
        end
        
    elseif command == "abilities" or command == "unlockall" then
        local context = {showToast = gameState.showToast}
        for _, abilityId in ipairs(gameState.getAllAbilityIds()) do
            gameState.abilityManager:grantAbility(abilityId, context)
        end
        gameState.showToast("Unlocked all abilities", {1, 0.5, 0})
        
    elseif command == "gold" or command == "money" then
        if param == "" then
            gameState.showToast("Usage: gold <amount> (e.g. gold 100)", {1, 1, 0.3})
        else
            local amount = tonumber(param)
            if amount then
                gameState.setGold(gameState.getGold() + amount)
                gameState.showToast("Added " .. amount .. " gold", {1, 0.5, 0})
            else
                gameState.showToast("Invalid amount: " .. param, {1, 0.3, 0.3})
            end
        end
        
    elseif command == "setgold" or command == "setmoney" then
        if param == "" then
            gameState.showToast("Usage: setgold <amount> (e.g. setgold 500)", {1, 1, 0.3})
        else
            local amount = tonumber(param)
            if amount then
                gameState.setGold(amount)
                gameState.showToast("Set gold to " .. amount, {1, 0.5, 0})
            else
                gameState.showToast("Invalid amount: " .. param, {1, 0.3, 0.3})
            end
        end
        
    elseif command == "help" or command == "?" then
        gameState.showToast("Cheats: noclip, grid, unlock/lock, god, fetch, gold/setgold", {1, 1, 0.3})
        
    else
        gameState.showToast("Unknown cheat: " .. code, {1, 0.3, 0.3})
    end
end

-- Handle text input
function CheatConsole.textInput(text)
    if CheatConsole.state.showPrompt then
        -- Don't add tilde/backtick characters (these are used to toggle the console)
        if text ~= "`" and text ~= "~" then
            CheatConsole.state.input = CheatConsole.state.input .. text
            CheatConsole.state.historyIndex = 0  -- Reset history when typing
        end
    end
end

-- Handle key press
function CheatConsole.keyPressed(key, gameState)
    -- Cheat prompt handling
    if CheatConsole.state.showPrompt then
        if key == "return" then
            -- Process the cheat code
            CheatConsole.processCode(CheatConsole.state.input, gameState)
            CheatConsole.state.input = ""
            CheatConsole.state.historyIndex = 0
            CheatConsole.state.tempInput = ""
            CheatConsole.state.showPrompt = false
            return true
        elseif key == "backspace" then
            CheatConsole.state.input = CheatConsole.state.input:sub(1, -2)
            CheatConsole.state.historyIndex = 0  -- Reset history when editing
            return true
        elseif key == "escape" then
            CheatConsole.state.input = ""
            CheatConsole.state.historyIndex = 0
            CheatConsole.state.tempInput = ""
            CheatConsole.state.showPrompt = false
            return true
        elseif key == "up" then
            -- Navigate up in history
            if #CheatConsole.state.history > 0 then
                if CheatConsole.state.historyIndex == 0 then
                    -- Save current input before browsing history
                    CheatConsole.state.tempInput = CheatConsole.state.input
                end
                
                if CheatConsole.state.historyIndex < #CheatConsole.state.history then
                    CheatConsole.state.historyIndex = CheatConsole.state.historyIndex + 1
                    CheatConsole.state.input = CheatConsole.state.history[CheatConsole.state.historyIndex]
                end
            end
            return true
        elseif key == "down" then
            -- Navigate down in history
            if CheatConsole.state.historyIndex > 0 then
                CheatConsole.state.historyIndex = CheatConsole.state.historyIndex - 1
                
                if CheatConsole.state.historyIndex == 0 then
                    -- Restore temp input
                    CheatConsole.state.input = CheatConsole.state.tempInput
                else
                    CheatConsole.state.input = CheatConsole.state.history[CheatConsole.state.historyIndex]
                end
            end
            return true
        end
        return true  -- Consume all keys when console is open
    end
    
    -- Toggle cheat prompt with tilde/backtick
    if key == "`" or key == "~" then
        CheatConsole.state.showPrompt = not CheatConsole.state.showPrompt
        CheatConsole.state.input = ""
        return true
    end
    
    return false  -- Key not handled
end

-- Draw the console
function CheatConsole.draw(GAME_WIDTH, GAME_HEIGHT, font)
    if not CheatConsole.state.showPrompt then
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
    for i = math.min(3, #CheatConsole.state.history), 1, -1 do
        love.graphics.print("> " .. CheatConsole.state.history[i], boxX+4, y)
        y = y + 10
    end

    -- Input prompt
    y = boxY + boxH - 24
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.print("> ", boxX+4, y)
    
    -- Input text
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(CheatConsole.state.input, boxX+16, y)
    
    -- Cursor (blinking)
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local cursorX = boxX + 16 + font:getWidth(CheatConsole.state.input)
        love.graphics.rectangle("fill", cursorX, y, 6, 10)
    end
    
    -- Instructions (inside the box, with padding)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("[Enter] Submit  [Up/Down] History  [Esc/~] Close", boxX+4, boxY+boxH-14)
end

-- Draw grid overlay
function CheatConsole.drawGrid(camX, camY, GAME_WIDTH, GAME_HEIGHT)
    if not CheatConsole.state.showGrid then
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

-- Draw active cheat indicators
function CheatConsole.drawIndicators(GAME_WIDTH, font, abilityManager)
    local cheatText = ""
    
    if CheatConsole.state.noclip then 
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
    
    if CheatConsole.state.showGrid then 
        cheatText = cheatText .. " [GRID]" 
    end
    
    if cheatText ~= "" then
        love.graphics.setColor(1, 0.5, 0, 0.9)
        local textWidth = font:getWidth(cheatText)
        love.graphics.print(cheatText, GAME_WIDTH - textWidth - 2, -1)
    end
end

-- Check if noclip is active
function CheatConsole.isNoclipActive()
    return CheatConsole.state.noclip
end

-- Check if console is open
function CheatConsole.isOpen()
    return CheatConsole.state.showPrompt
end

return CheatConsole

