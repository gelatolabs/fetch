-- Dialog System Module
-- Handles all dialog-related functionality including multi-page dialogs

local DialogSystem = {}

-- Dialog state
local currentDialog = nil
local dialogPages = {}
local currentDialogPage = 1

-- Helper function to split text into dialog pages
local function splitDialogPages(text)
    -- Handle nil or empty text
    if not text or text == "" then
        return {""}
    end
    
    local pages = {}
    -- Split on double newline first
    for page in text:gmatch("[^\n\n]+") do
        table.insert(pages, page)
    end
    -- If no double newlines found, return the whole text as one page
    if #pages == 0 then
        table.insert(pages, text)
    end
    return pages
end

-- Show a dialog
function DialogSystem.showDialog(dialogData)
    currentDialog = dialogData
    -- Ensure text field exists, default to empty string if not
    local text = dialogData.text or ""
    dialogPages = splitDialogPages(text)
    currentDialogPage = 1
    return "dialog"  -- Return the game state to switch to
end

-- Get current dialog
function DialogSystem.getCurrentDialog()
    return currentDialog
end

-- Get current page number
function DialogSystem.getCurrentPage()
    return currentDialogPage
end

-- Get total pages
function DialogSystem.getTotalPages()
    return #dialogPages
end

-- Get current page text
function DialogSystem.getCurrentPageText()
    return dialogPages[currentDialogPage] or ""
end

-- Check if there are more pages
function DialogSystem.hasMorePages()
    return currentDialogPage < #dialogPages
end

-- Advance to next page
function DialogSystem.nextPage()
    if DialogSystem.hasMorePages() then
        currentDialogPage = currentDialogPage + 1
        return true
    end
    return false
end

-- Clear dialog state
function DialogSystem.clearDialog()
    currentDialog = nil
    dialogPages = {}
    currentDialogPage = 1
end

-- Handle dialog input (space/E key)
-- Returns: newGameState, shouldClearDialog
function DialogSystem.handleInput(callbacks)
    -- Check if there are more pages to show
    if DialogSystem.hasMorePages() then
        -- Advance to next page
        currentDialogPage = currentDialogPage + 1
        return nil, false  -- Stay in dialog, don't clear
    end
    
    -- No more pages, handle dialog completion based on type
    if currentDialog.type == "questOfferDialog" then
        -- Transition to quest offer screen
        return "questOffer", false  -- Don't clear dialog yet, we'll use it for quest offer

    elseif currentDialog.type == "questOffer" then
        -- Accept quest
        if callbacks.onQuestAccept then
            callbacks.onQuestAccept(currentDialog.quest)
        end
        return "playing", true

    elseif currentDialog.type == "questTurnIn" then
        -- Complete quest
        if callbacks.onQuestComplete then
            callbacks.onQuestComplete(currentDialog.quest)
        end
        return "playing", true
        
    elseif currentDialog.type == "itemGive" then
        -- Receive item
        if callbacks.onItemReceive then
            callbacks.onItemReceive(currentDialog.item)
        end
        return "playing", true
        
    elseif currentDialog.type == "abilityGive" then
        -- Learn ability
        if callbacks.onAbilityLearn then
            callbacks.onAbilityLearn(currentDialog.ability, currentDialog.quest)
        end
        return "playing", true
        
    else
        -- Generic dialog
        -- Check if this was a reward dialog after completing a main quest
        if currentDialog.completedMainQuest then
            return "winScreen", true
        else
            return "playing", true
        end
    end
end

-- Draw the dialog box
function DialogSystem.draw(GAME_WIDTH, GAME_HEIGHT, drawFancyBorder)
    if not currentDialog then return end
    
    local boxX, boxY = 20, GAME_HEIGHT - 81
    local boxW, boxH = GAME_WIDTH - 40, 76

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

    -- Page indicator (if multiple pages)
    if #dialogPages > 1 then
        love.graphics.setColor(0.7, 0.6, 0.4)
        love.graphics.printf(currentDialogPage .. "/" .. #dialogPages, boxX, boxY, boxW-4, "right")
    end

    -- Dialog text - show current page
    local text = dialogPages[currentDialogPage] or ""
    local buttonText = ""

    -- Determine button text based on dialog type and page position
    local isLastPage = currentDialogPage >= #dialogPages
    
    if not isLastPage then
        buttonText = "[E] Next"
    elseif currentDialog.type == "questOffer" then
        buttonText = "[E] Accept"
    elseif currentDialog.type == "questTurnIn" then
        buttonText = "[E] Complete"
    elseif currentDialog.type == "itemGive" then
        buttonText = "[E] Receive"
    elseif currentDialog.type == "abilityGive" then
        buttonText = "[E] Learn"
    else
        buttonText = "[E] Okay"
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

return DialogSystem
