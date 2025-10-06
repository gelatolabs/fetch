-- Cheat Console System
-- Provides a developer console for debugging and testing

local sti = require "sti"
local UISystem = require "ui_system"
local PlayerSystem = require "player_system"
local MapSystem = require "map_system"
local Camera = require "camera"

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

-- Helper function to find item by name or alias
local function findItemByNameOrAlias(param, itemRegistry)
    -- First try direct lookup
    local itemData = itemRegistry[param]
    if itemData then
        return itemData
    end
    
    -- Check aliases
    for itemId, data in pairs(itemRegistry) do
        if data.aliases then
            for _, alias in ipairs(data.aliases) do
                if alias == param then
                    return data
                end
            end
        end
    end
    
    return nil
end

-- Process a cheat code
-- gameState should contain: abilityManager, activeQuests, completedQuests, quests, inventory, itemRegistry
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
        UISystem.showToast("Noclip: " .. (CheatConsole.state.noclip and "ON" or "OFF"), {1, 0.5, 0})
        
    elseif command == "grid" then
        CheatConsole.state.showGrid = not CheatConsole.state.showGrid
        UISystem.showToast("Show Grid: " .. (CheatConsole.state.showGrid and "ON" or "OFF"), {1, 0.5, 0})
        
    elseif command == "unlock" then
        if param == "" then
            UISystem.showToast("Usage: unlock <ability> (e.g. unlock swim)", {1, 1, 0.3})
        else
            local abilityData = gameState.abilityManager:getRegisteredAbility(param)
            if abilityData then
                gameState.abilityManager:grantAbility(abilityData.id)
                UISystem.showToast("Unlocked: " .. abilityData.name, {1, 0.5, 0})
            else
                UISystem.showToast("Unknown ability: " .. param, {1, 0.3, 0.3})
            end
        end
        
    elseif command == "lock" then
        if param == "" then
            UISystem.showToast("Usage: lock <ability> (e.g. lock swim)", {1, 1, 0.3})
        else
            local abilityData = gameState.abilityManager:getRegisteredAbility(param)
            if abilityData and gameState.abilityManager:hasAbility(abilityData.id) then
                gameState.abilityManager:removeAbility(abilityData.id)
                UISystem.showToast("Locked: " .. abilityData.name, {1, 0.5, 0})
            else
                UISystem.showToast("Unknown or not unlocked ability: " .. param, {1, 0.3, 0.3})
            end
        end
        
    elseif command == "god" or command == "godmode" then
        if param == "off" then
            -- Turn off god mode
            CheatConsole.state.noclip = false
            -- Remove all abilities
            for _, abilityId in ipairs(gameState.abilityManager:getAllRegisteredAbilityIds()) do
                gameState.abilityManager:removeAbility(abilityId)
            end
            UISystem.showToast("God Mode Deactivated!", {1, 0.5, 0})
        else
            -- Turn on god mode
            CheatConsole.state.noclip = true
            for _, abilityId in ipairs(gameState.abilityManager:getAllRegisteredAbilityIds()) do
                gameState.abilityManager:grantAbility(abilityId)
            end
            UISystem.showToast("God Mode Activated!", {1, 0.5, 0})
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
            UISystem.showToast("Completed " .. count .. " quest(s)", {1, 0.5, 0})
        else
            UISystem.showToast("No active quests", {1, 0.5, 0})
        end
        
    elseif command == "fetch" then
        if param == "" then
            UISystem.showToast("Usage: fetch <item> or fetch all", {1, 1, 0.3})
        elseif param == "all" then
            -- Clear inventory and add all items
            PlayerSystem.clearInventory()
            -- Get all item IDs from registry
            for itemId, _ in pairs(gameState.itemRegistry) do
                PlayerSystem.addItem(itemId)
            end
            UISystem.showToast("Given all items", {1, 0.5, 0})
        else
            -- Look up item in registry
            local itemData = findItemByNameOrAlias(param, gameState.itemRegistry)
            
            if itemData then
                -- Check if already have it
                if not PlayerSystem.hasItem(itemData.id) then
                    PlayerSystem.addItem(itemData.id)
                    UISystem.showToast("Received: " .. itemData.name, {1, 0.5, 0})
                else
                    UISystem.showToast("You already have that item!", {1, 0.5, 0})
                end
            else
                UISystem.showToast("Unknown item: " .. param, {1, 0.3, 0.3})
            end
        end
        
    elseif command == "toss" then
        if param == "" then
            UISystem.showToast("Usage: toss <item> or toss all", {1, 1, 0.3})
        elseif param == "all" then
            local count = PlayerSystem.clearInventory()
            UISystem.showToast("Tossed " .. count .. " items from inventory", {1, 0.5, 0})
        else
            -- Look up item in registry
            local itemData = findItemByNameOrAlias(param, gameState.itemRegistry)
            
            if itemData then
                -- Check if player has the item
                if PlayerSystem.hasItem(itemData.id) then
                    PlayerSystem.removeItem(itemData.id)
                    UISystem.showToast("Tossed: " .. itemData.name, {1, 0.5, 0})
                else
                    UISystem.showToast("You don't have that item!", {1, 0.5, 0})
                end
            else
                UISystem.showToast("Unknown item: " .. param, {1, 0.3, 0.3})
            end
        end
        
    elseif command == "abilities" or command == "unlockall" then
        for _, abilityId in ipairs(gameState.abilityManager:getAllRegisteredAbilityIds()) do
            gameState.abilityManager:grantAbility(abilityId)
        end
        UISystem.showToast("Unlocked all abilities", {1, 0.5, 0})
        
    elseif command == "gold" or command == "money" then
        if param == "" then
            UISystem.showToast("Usage: gold <amount> (e.g. gold 100)", {1, 1, 0.3})
        else
            local amount = tonumber(param)
            if amount then
                PlayerSystem.setGold(PlayerSystem.getGold() + amount)
                UISystem.showToast("Added " .. amount .. " gold", {1, 0.5, 0})
            else
                UISystem.showToast("Invalid amount: " .. param, {1, 0.3, 0.3})
            end
        end
        
    elseif command == "setgold" or command == "setmoney" then
        if param == "" then
            UISystem.showToast("Usage: setgold <amount> (e.g. setgold 500)", {1, 1, 0.3})
        else
            local amount = tonumber(param)
            if amount then
                PlayerSystem.setGold(amount)
                UISystem.showToast("Set gold to " .. amount, {1, 0.5, 0})
            else
                UISystem.showToast("Invalid amount: " .. param, {1, 0.3, 0.3})
            end
        end
        
    elseif command == "screenfetch" then
        local screenfetch = [[   __
 <(o )___
  ( ._> /
   `---'

OS: DuckOS 0.1
Kernel: Mallard 4.20
Shell: /bin/quack
WM: PondView
CPU: Feather 6502
RAM: 4KB DDR0.5
GPU: GooseForce 128]]
        UISystem.showToast(screenfetch, {0.3, 0.8, 1})

    elseif command == "jarf" then
        -- Open chat pane if it's closed
        local wasHidden = not UISystem.isChatPaneVisible()
        if wasHidden then
            UISystem.toggleChatPane()
        end
        
        -- Progress dialog
        UISystem.progressJarfScript()
        if wasHidden then
            UISystem.showToast("Chat opened & dialog progressed", {0.5, 1, 0.5})
        else
            UISystem.showToast("Dialog progressed", {0.5, 1, 0.5})
        end

    elseif command == "nojarf" then
        UISystem.toggleChatPane()
        UISystem.showToast("Chat pane toggled", {1, 0.5, 0})
        
    elseif command == "teleport" then
        if param == "" then
            UISystem.showToast("Usage: teleport <map> [x y] (e.g. teleport shop or teleport map 10 15)", {1, 1, 0.3})
        else
            local mapName = parts[2]
            local x = tonumber(parts[3])
            local y = tonumber(parts[4])
            
            -- Validate map exists using MapSystem
            if not MapSystem.isValidMap(mapName) then
                local validMaps = MapSystem.getAllMapNames()
                UISystem.showToast("Unknown map: " .. mapName .. "\nValid: " .. table.concat(validMaps, ", "), {1, 0.3, 0.3})
            else
                -- If x and y are provided, validate they're numbers
                if (parts[3] and not x) or (parts[4] and not y) then
                    UISystem.showToast("Invalid coordinates. Use: teleport " .. mapName .. " <x> <y>", {1, 0.3, 0.3})
                else
                    -- Load the new map
                    MapSystem.setCurrentMap(mapName)
                    local newMap = sti(MapSystem.getMapPath(mapName))
                    MapSystem.hideNPCLayer(newMap)
                    MapSystem.setMapObject(newMap)
                    MapSystem.calculateMapBounds()
                    
                    -- If coordinates provided, teleport to that position
                    -- Otherwise, teleport to center of map
                    if x and y then
                        -- Convert grid coordinates to world coordinates
                        PlayerSystem.setPosition(x * 16 + 8, y * 16 + 8, x, y)
                        UISystem.showToast("Teleported to " .. mapName .. " (" .. x .. ", " .. y .. ")", {1, 0.5, 0})
                    else
                        -- Teleport to center of map
                        local minX, minY, maxX, maxY = MapSystem.getWorldBounds()
                        local centerX = math.floor((maxX + minX) / 2 / 16)
                        local centerY = math.floor((maxY + minY) / 2 / 16)
                        PlayerSystem.setPosition(centerX * 16 + 8, centerY * 16 + 8, centerX, centerY)
                        UISystem.showToast("Teleported to " .. mapName .. " (center)", {1, 0.5, 0})
                    end
                    
                    -- Stop player movement
                    local player = PlayerSystem.getPlayer()
                    player.moving = false
                    
                    -- Update camera
                    Camera.update()
                    
                    -- Update music for new map
                    MapSystem.updateMusicForCurrentMap()
                end
            end
        end
        
    elseif command == "help" or command == "?" then
        UISystem.showToast("Cheats: noclip, grid, unlock/lock, god, fetch, toss, gold/setgold, teleport, jarf, nojarf, screenfetch", {1, 1, 0.3})

    else
        UISystem.showToast("Unknown cheat: " .. code, {1, 0.3, 0.3})
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
function CheatConsole.keyPressed(key, gameState, currentGameState)
    -- Don't allow opening console on main menu or settings
    local canOpenConsole = currentGameState ~= "mainMenu" and currentGameState ~= "settings"

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
        if canOpenConsole then
            CheatConsole.state.showPrompt = not CheatConsole.state.showPrompt
            CheatConsole.state.input = ""
        end
        return true
    end
    
    return false  -- Key not handled
end

-- Check if noclip is active
function CheatConsole.isNoclipActive()
    return CheatConsole.state.noclip
end

-- Check if grid is active
function CheatConsole.isGridActive()
    return CheatConsole.state.showGrid
end

-- Check if console is open
function CheatConsole.isOpen()
    return CheatConsole.state.showPrompt
end

-- Get console input
function CheatConsole.getInput()
    return CheatConsole.state.input
end

-- Get console history
function CheatConsole.getHistory()
    return CheatConsole.state.history
end

return CheatConsole

