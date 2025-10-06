-- Cheat Console System
-- Provides a developer console for debugging and testing

local UISystem = require "ui_system"
local PlayerSystem = require "player_system"
local MapSystem = require "map_system"
local Camera = require "camera"
local sti = require "sti"

local CheatConsole = {}

-- Console state
CheatConsole.state = {
    showGrid = false,        -- Show tile grid overlay
    showPrompt = false,      -- Console visible?
    input = "",              -- Current cheat code being typed
    history = {},            -- History of entered cheats
    historyIndex = 0,        -- Current position in history (0 = new command)
    tempInput = "",          -- Temporary storage for unsaved input when browsing history
    savedAbilities = nil     -- Saved ability state before god mode (for restoration)
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
        if gameState.abilityManager:hasAbility("noclip") then
            gameState.abilityManager:removeAbility("noclip")
            UISystem.showToast("Noclip: OFF", {1, 0.5, 0})
        else
            gameState.abilityManager:grantAbility("noclip")
            UISystem.showToast("Noclip: ON", {1, 0.5, 0})
        end
        
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
            -- Turn off god mode - restore saved abilities or clear all
            if CheatConsole.state.savedAbilities then
                -- First remove all abilities
                for _, abilityId in ipairs(gameState.abilityManager:getAllRegisteredAbilityIds()) do
                    gameState.abilityManager:removeAbility(abilityId)
                end
                
                -- Then restore the saved abilities
                for _, abilityId in ipairs(CheatConsole.state.savedAbilities) do
                    gameState.abilityManager:grantAbility(abilityId)
                end
                
                CheatConsole.state.savedAbilities = nil
                UISystem.showToast("God Mode Deactivated! Abilities Restored.", {1, 0.5, 0})
            else
                -- No saved state, just clear everything
                for _, abilityId in ipairs(gameState.abilityManager:getAllRegisteredAbilityIds()) do
                    gameState.abilityManager:removeAbility(abilityId)
                end
                UISystem.showToast("God Mode Deactivated!", {1, 0.5, 0})
            end
        else
            -- Turn on god mode - save current abilities then grant all
            -- Save current ability state (including cheat abilities like noclip)
            CheatConsole.state.savedAbilities = {}
            for _, ability in pairs(gameState.abilityManager:getAllAbilities()) do
                table.insert(CheatConsole.state.savedAbilities, ability.id)
            end
            
            -- Grant all abilities
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
            -- Add all items (allows duplicates, doesn't clear inventory)
            local count = 0
            for itemId, _ in pairs(gameState.itemRegistry) do
                PlayerSystem.addItem(itemId)
                count = count + 1
            end
            UISystem.showToast("Added " .. count .. " items", {1, 0.5, 0})
        else
            -- Look up item in registry
            local itemData = findItemByNameOrAlias(param, gameState.itemRegistry)
            
            if itemData then
                -- Always add the item (allow duplicates via cheat console)
                PlayerSystem.addItem(itemData.id)
                UISystem.showToast("Received: " .. itemData.name, {1, 0.5, 0})
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
        
    elseif command == "teleport" or command == "tp" then
        if param == "" then
            UISystem.showToast("Usage: teleport <map> [x y] (e.g. teleport shop or teleport map 10 20)", {1, 1, 0.3})
        else
            local targetMap = param
            local targetX = tonumber(parts[3])
            local targetY = tonumber(parts[4])
            
            -- First, load the map to check its dimensions (don't update MapSystem yet)
            local mapPath = MapSystem.getMapPath(targetMap)
            if not mapPath then
                UISystem.showToast("Unknown map: " .. targetMap, {1, 0.3, 0.3})
                return
            end
            
            -- Load the map to get dimensions
            local testMapObj = sti(mapPath)
            
            -- If no coordinates provided, use center of map
            if not targetX or not targetY then
                targetX = math.floor(testMapObj.width / 2)
                targetY = math.floor(testMapObj.height / 2)
            end
            
            -- Validate coordinates are within map bounds
            if targetX < 0 or targetX >= testMapObj.width or targetY < 0 or targetY >= testMapObj.height then
                UISystem.showToast("Coordinates out of bounds! Valid: (0-" .. (testMapObj.width-1) .. ", 0-" .. (testMapObj.height-1) .. ")", {1, 0.3, 0.3})
                return
            end
            

            -- All validation passed, now actually teleport
            -- Load the new map (this updates MapSystem)
            local loadSuccess, result = MapSystem.loadMap(targetMap)
            if not loadSuccess then
                UISystem.showToast(result, {1, 0.3, 0.3})
                return
            end

            -- Play music for target map
            MapSystem.playMusicForMap(targetMap)
            
            -- Set player position
            PlayerSystem.setPosition(targetX * 16 + 8, targetY * 16 + 8, targetX, targetY)
            local player = PlayerSystem.getPlayer()
            player.moving = false
            
            -- Update camera
            Camera.update(player.x, player.y)
            
            UISystem.showToast("Teleported to " .. targetMap .. " (" .. targetX .. ", " .. targetY .. ")", {1, 0.5, 0})
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

