-- Shop System Module
-- Handles all shop-related functionality

local UISystem = require("ui_system")
local PlayerSystem = require("player_system")

local ShopSystem = {}

-- Shop state
local shopInventory = {}
local selectedShopItem = nil

-- Initialize shop system
function ShopSystem.init(itemRegistry)
    -- Build shop inventory from item registry
    shopInventory = {}
    for itemId, itemData in pairs(itemRegistry) do
        if itemData.shopInfo then
            table.insert(shopInventory, {
                itemId = itemId,
                price = itemData.shopInfo.price,
                description = itemData.shopInfo.description
            })
        end
    end
    
    -- Sort by price for consistent ordering
    table.sort(shopInventory, function(a, b) return a.price < b.price end)
    
    selectedShopItem = nil
end

-- Open the shop (selects first item by default)
function ShopSystem.open()
    selectedShopItem = 1
end

-- Close the shop
function ShopSystem.close()
    selectedShopItem = nil
end

-- Get shop inventory
function ShopSystem.getInventory()
    return shopInventory
end

-- Get selected shop item index
function ShopSystem.getSelectedItem()
    return selectedShopItem
end

-- Set selected shop item
function ShopSystem.selectItem(index)
    if index >= 1 and index <= #shopInventory then
        selectedShopItem = index
    end
end

-- Get the currently selected shop item data
function ShopSystem.getSelectedItemData()
    if selectedShopItem and shopInventory[selectedShopItem] then
        return shopInventory[selectedShopItem]
    end
    return nil
end

-- Check if player can afford an item
function ShopSystem.canAfford(itemPrice)
    return PlayerSystem.getGold() >= itemPrice
end

-- Purchase an item (returns success, message, color)
function ShopSystem.purchaseItem(shopItem, itemRegistry)
    
    if not shopItem then
        return false, "Invalid item!", {1, 0, 0}
    end
    
    -- Check if player already owns the item
    if PlayerSystem.hasItem(shopItem.itemId) then
        return false, "You already own this item!", {1, 0.5, 0}
    end
    
    -- Check if player can afford it
    if not ShopSystem.canAfford(shopItem.price) then
        return false, "Not enough gold!", {1, 0, 0}
    end
    
    -- Process purchase
    PlayerSystem.subtractGold(shopItem.price)
    PlayerSystem.addItem(shopItem.itemId)
    
    -- Get item name for message
    local itemData = itemRegistry[shopItem.itemId]
    local itemName = itemData and itemData.name or shopItem.itemId
    
    return true, "Purchased " .. itemName .. "!", {0, 1, 0}
end

-- Draw the shop UI
function ShopSystem.draw(itemRegistry)
    
    local CHAT_PANE_WIDTH = UISystem.getChatPaneWidth()
    local GAME_WIDTH = UISystem.getGameWidth()
    local GAME_HEIGHT = UISystem.getGameHeight()
    local font = UISystem.getFont()
    
    -- Start below the top UI bar (which shows gold)
    local boxX, boxY = CHAT_PANE_WIDTH + 10, 14
    local boxW, boxH = GAME_WIDTH - 20, GAME_HEIGHT - 24

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

    -- Left side: Item grid (no duplicate gold display)
    local gridX = boxX + 4
    local gridY = boxY + 18
    local slotSize = 20
    local padding = 4

    for i, shopItem in ipairs(shopInventory) do
        local slotX = gridX + ((i - 1) % 6) * (slotSize + padding)
        local slotY = gridY + math.floor((i - 1) / 6) * (slotSize + padding)

        -- Check if selected
        local isSelected = selectedShopItem == i
        local alreadyOwns = PlayerSystem.hasItem(shopItem.itemId)

        -- Slot background
        if isSelected then
            love.graphics.setColor(0.3, 0.25, 0.15, 0.9)
        else
            love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
        end
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize)

        -- Item representation
        local itemData = itemRegistry[shopItem.itemId]
        local itemTileset = UISystem.getItemTileset()
        
        -- Get icon (with fallback to placeholder at 32, 192)
        local icon = itemData and itemData.icon
        local spriteX = icon and icon.x or 32
        local spriteY = icon and icon.y or 192
        
        if alreadyOwns then
            love.graphics.setColor(0.4, 0.4, 0.4)
        else
            love.graphics.setColor(1, 1, 1)
        end
        
        local quad = love.graphics.newQuad(
            spriteX, spriteY,
            16, 16,
            itemTileset:getDimensions()
        )
        -- Center the 16x16 sprite in the 20x20 slot
        love.graphics.draw(itemTileset, quad, slotX+2, slotY+2)

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
            local alreadyOwns = PlayerSystem.hasItem(shopItem.itemId)
            local canAfford = PlayerSystem.getGold() >= shopItem.price

            local detailX = boxX + 150
            local detailY = boxY + 30
            local detailW = boxW - 150 - 8

            -- Item display (2x size)
            local displaySize = 40
            love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
            love.graphics.rectangle("fill", detailX, detailY, displaySize, displaySize)

            -- Draw item sprite at 2x scale
            local itemTileset = UISystem.getItemTileset()
            local icon = itemData and itemData.icon
            local spriteX = icon and icon.x or 32
            local spriteY = icon and icon.y or 192

            if alreadyOwns then
                love.graphics.setColor(0.4, 0.4, 0.4)
            else
                love.graphics.setColor(1, 1, 1)
            end

            local quad = love.graphics.newQuad(
                spriteX, spriteY,
                16, 16,
                itemTileset:getDimensions()
            )
            -- Center the 32x32 sprite (16x16 at 2x scale) in the 40x40 display box
            love.graphics.draw(itemTileset, quad, detailX + 4, detailY + 4, 0, 2, 2)

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

                local isHovered = UISystem.isMouseOverButton(btnX, btnY, btnW, btnH)

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

-- Handle shop clicks (returns true if click was handled)
function ShopSystem.handleClick(x, y, purchaseCallback)
    
    -- Convert screen coordinates to canvas coordinates
    -- Need to account for canvas shift during transition
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local CHAT_PANE_WIDTH = UISystem.getChatPaneWidth()
    local GAME_WIDTH = UISystem.getGameWidth()
    local GAME_HEIGHT = UISystem.getGameHeight()
    local TOTAL_WIDTH = CHAT_PANE_WIDTH + GAME_WIDTH
    local SCALE = UISystem.getScale()
    
    -- Get transition progress to account for canvas shift
    local transitionProgress = UISystem.getChatPaneTransitionProgress()
    local currentVisibleWidth = GAME_WIDTH + (CHAT_PANE_WIDTH * transitionProgress)
    
    local offsetX = math.floor((screenWidth - currentVisibleWidth * SCALE) / 2 / SCALE) * SCALE
    local offsetY = math.floor((screenHeight - GAME_HEIGHT * SCALE) / 2 / SCALE) * SCALE
    
    -- Account for canvas shift to hide chat pane initially
    offsetX = offsetX - (CHAT_PANE_WIDTH * (1 - transitionProgress) * SCALE)
    
    local canvasX = (x - offsetX) / SCALE
    local canvasY = (y - offsetY) / SCALE
    
    local boxX, boxY = CHAT_PANE_WIDTH + 10, 10
    local boxW = GAME_WIDTH - 20
    local boxH = GAME_HEIGHT - 20

    -- Check grid item clicks
    local gridX = boxX + 4
    local gridY = boxY + 30
    local slotSize = 20
    local padding = 4

    for i, shopItem in ipairs(shopInventory) do
        local slotX = gridX + ((i - 1) % 6) * (slotSize + padding)
        local slotY = gridY + math.floor((i - 1) / 6) * (slotSize + padding)

        if canvasX >= slotX and canvasX <= slotX + slotSize and canvasY >= slotY and canvasY <= slotY + slotSize then
            ShopSystem.selectItem(i)
            return true
        end
    end

    -- Check purchase button click
    if selectedShopItem then
        local shopItem = shopInventory[selectedShopItem]
        if shopItem then
            local alreadyOwns = PlayerSystem.hasItem(shopItem.itemId)
            local canAfford = PlayerSystem.getGold() >= shopItem.price

            if not alreadyOwns then
                local btnY = boxY + boxH - 40
                local btnW = 80
                local btnH = 20
                local detailX = boxX + 150
                local detailW = boxW - 150 - 8
                local btnX = detailX + (detailW - btnW) / 2

                if canvasX >= btnX and canvasX <= btnX + btnW and canvasY >= btnY and canvasY <= btnY + btnH then
                    if canAfford then
                        -- Call purchase callback with the shop item
                        if purchaseCallback then
                            purchaseCallback(shopItem)
                        end
                    else
                        -- Show insufficient funds message via callback
                        if purchaseCallback then
                            purchaseCallback(nil)  -- nil indicates insufficient funds
                        end
                    end
                    return true
                end
            end
        end
    end

    return false
end

return ShopSystem
