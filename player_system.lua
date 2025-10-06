-- Player System Module
-- Handles player state, movement, rendering, and related functionality

local PlayerSystem = {}

-- Dependencies
local AbilitySystem = require "ability_system"
local MapSystem = require "map_system"

-- Player state
local player = {
    x = 39 * 16 + 8,
    y = 26 * 16 + 8,
    gridX = 39, -- Grid position (in tiles)
    gridY = 26,
    size = 16,
    direction = "down",
    facing = "right",  -- Remembers last horizontal direction
    lastVertical = "down",
    moving = false,
    moveTimer = 0,
    moveDuration = 0.15,  -- Time to move one tile (in seconds)
    walkFrame = 0,  -- 0 or 1 for animation
    wasOnWater = false,  -- Track if player was on water last frame
    jumping = false,  -- Track if player is jumping
    jumpHeight = 0,  -- Current jump height offset for rendering
    queuedDirection = nil  -- Queued movement direction
}

-- Player gold
local playerGold = 0

-- Player inventory
local inventory = {}

-- Player ability manager
local abilityManager = nil

-- Player sprite resources
local playerTileset = nil
local playerQuads = {
    regular = {},
    boat = {},
    swimming = {}
}

-- Initialize player system
function PlayerSystem.init(UISystem)
    -- Initialize ability manager
    abilityManager = AbilitySystem.PlayerAbilityManager.new()
    
    -- Load player tileset
    playerTileset = love.graphics.newImage("tiles/player-tileset.png")
    
    -- Create quads for player animation
    -- Regular movement quads
    playerQuads.regular = {
        down = {
            love.graphics.newQuad(0, 0, 16, 16, playerTileset:getDimensions()),
            love.graphics.newQuad(16, 0, 16, 16, playerTileset:getDimensions())
        },
        up = {
            love.graphics.newQuad(32, 0, 16, 16, playerTileset:getDimensions()),
            love.graphics.newQuad(48, 0, 16, 16, playerTileset:getDimensions())
        }
    }

    -- Boat movement quads
    playerQuads.boat = {
        down = {
            love.graphics.newQuad(64, 0, 16, 16, playerTileset:getDimensions()),
            love.graphics.newQuad(80, 0, 16, 16, playerTileset:getDimensions())
        },
        up = {
            love.graphics.newQuad(96, 0, 16, 16, playerTileset:getDimensions()),
            love.graphics.newQuad(112, 0, 16, 16, playerTileset:getDimensions())
        }
    }

    -- Swimming movement quads
    playerQuads.swimming = {
        down = {
            love.graphics.newQuad(128, 0, 16, 16, playerTileset:getDimensions()),
            love.graphics.newQuad(144, 0, 16, 16, playerTileset:getDimensions())
        },
        up = {
            love.graphics.newQuad(160, 0, 16, 16, playerTileset:getDimensions()),
            love.graphics.newQuad(176, 0, 16, 16, playerTileset:getDimensions())
        }
    }
    
    -- Register player abilities
    abilityManager:registerAbility({
        id = "swim",
        name = "Swim",
        aliases = {"swim", "swimming"},
        type = AbilitySystem.AbilityType.PASSIVE,
        effects = {AbilitySystem.EffectType.WATER_TRAVERSAL},
        description = "Allows you to swim across water tiles freely",
        color = {0.3, 0.8, 1.0},
        onAcquire = function(ability)
            UISystem.showToast("You can now swim across water!", {0.3, 0.8, 1.0})
        end
    })

    abilityManager:registerAbility({
        id = "boat",
        name = "Boat",
        aliases = {"boat", "raft"},
        type = AbilitySystem.AbilityType.CONSUMABLE,
        effects = {AbilitySystem.EffectType.WATER_TRAVERSAL},
        description = "A makeshift boat that breaks after crossing water 3 times",
        maxUses = 3,
        consumeOnUse = true,
        color = {0.7, 0.7, 1.0},
        onAcquire = function(ability)
            UISystem.showToast("Boat has " .. ability.maxUses .. " crossings", {0.7, 0.7, 1.0})
        end,
        onUse = function(ability)
            if ability.currentUses > 0 then
                UISystem.showToast("Boat crossings remaining: " .. ability.currentUses, {0.7, 0.7, 1.0})
            end
        end,
        onExpire = function()
            UISystem.showToast("Your boat broke apart!", {1, 0.5, 0.2})
        end
    })

    abilityManager:registerAbility({
        id = "jump",
        name = "Jump",
        aliases = {"jump", "jumping", "leap"},
        type = AbilitySystem.AbilityType.PASSIVE,
        effects = {AbilitySystem.EffectType.JUMP},
        description = "Allows you to jump over low obstacles (height ≤ 0.5)",
        color = {1.0, 0.9, 0.3},
        onAcquire = function(ability)
            UISystem.showToast("You can now jump over low obstacles!", {1.0, 0.9, 0.3})
        end
    })

    abilityManager:registerAbility({
        id = "speed",
        name = "Speed Boost",
        aliases = {"speed", "speedboost", "fast"},
        type = AbilitySystem.AbilityType.PASSIVE,
        effects = {AbilitySystem.EffectType.SPEED},
        description = "Move 4x faster",
        color = {1.0, 0.3, 0.3},
        onAcquire = function(ability)
            UISystem.showToast("You feel lightning fast!", {1.0, 0.3, 0.3})
        end
    })
end

-- Get player state
function PlayerSystem.getPlayer()
    return player
end

-- Get player gold
function PlayerSystem.getGold()
    return playerGold
end

-- Set player gold
function PlayerSystem.setGold(amount)
    playerGold = amount
end

-- Add gold to player
function PlayerSystem.addGold(amount)
    playerGold = playerGold + amount
end

-- Subtract gold from player
function PlayerSystem.subtractGold(amount)
    playerGold = playerGold - amount
end

-- Get player inventory
function PlayerSystem.getInventory()
    return inventory
end

-- Check if player has an item
function PlayerSystem.hasItem(itemId)
    for _, item in ipairs(inventory) do
        if item == itemId then
            return true
        end
    end
    return false
end

-- Add item to player inventory
function PlayerSystem.addItem(itemId)
    table.insert(inventory, itemId)
end

-- Remove item from player inventory
function PlayerSystem.removeItem(itemId)
    for i, item in ipairs(inventory) do
        if item == itemId then
            table.remove(inventory, i)
            return true
        end
    end
    return false
end

-- Clear all items from inventory
function PlayerSystem.clearInventory()
    local count = #inventory
    for i = #inventory, 1, -1 do
        table.remove(inventory, i)
    end
    return count
end

-- Set player position
function PlayerSystem.setPosition(x, y, gridX, gridY)
    player.x = x
    player.y = y
    if gridX then player.gridX = gridX end
    if gridY then player.gridY = gridY end
end

-- Get the current player sprite set based on conditions
function PlayerSystem.getSpriteSet()
    -- Don't use water sprites when jumping
    if player.jumping then
        return playerQuads.regular
    end
    
    local isOnWater = MapSystem.isWaterTile(player.x, player.y)

    if isOnWater then
        if abilityManager:hasAbility("swim") then
            return playerQuads.swimming
        else
            return playerQuads.boat
        end
    end
    return playerQuads.regular
end

-- Draw the player
function PlayerSystem.draw(camX, camY, chatOffset)
    chatOffset = chatOffset or 0  -- Default to 0 if not provided
    love.graphics.setColor(1, 1, 1)
    local spriteSet = PlayerSystem.getSpriteSet()
    local currentQuad = spriteSet[player.lastVertical][player.moving and (player.walkFrame + 1) or 1]
    local scaleX = (player.facing == "left") and -1 or 1
    local offsetX = (player.facing == "left") and player.size or 0
    love.graphics.draw(
        playerTileset,
        currentQuad,
        player.x - player.size/2 - camX + offsetX + chatOffset,
        player.y - player.size/2 - camY - player.jumpHeight,
        0,
        scaleX,
        1
    )
end

-- Get player tileset (for external use)
function PlayerSystem.getTileset()
    return playerTileset
end

-- Get ability manager
function PlayerSystem.getAbilityManager()
    return abilityManager
end

-- Register an ability
function PlayerSystem.registerAbility(abilityData)
    abilityManager:registerAbility(abilityData)
end

-- Grant an ability to the player
function PlayerSystem.grantAbility(abilityId)
    abilityManager:grantAbility(abilityId)
end

-- Check if player has an ability
function PlayerSystem.hasAbility(abilityId)
    return abilityManager:hasAbility(abilityId)
end

-- Get an ability
function PlayerSystem.getAbility(abilityId)
    return abilityManager:getAbility(abilityId)
end

-- Helper function to check if two directions are opposite
local function areOppositeDirections(dir1, dir2)
    if (dir1 == "up" and dir2 == "down") or (dir1 == "down" and dir2 == "up") then
        return true
    end
    if (dir1 == "left" and dir2 == "right") or (dir1 == "right" and dir2 == "left") then
        return true
    end
    return false
end

-- Update player movement
function PlayerSystem.update(dt, heldKeys)
    -- Pokemon-style grid-based movement
    if player.moving then
        -- Check for input to queue movement
        for i = #heldKeys, 1, -1 do
            local key = heldKeys[i]
            if love.keyboard.isDown(key) then
                local queueDir = nil
                if key == "w" or key == "up" then
                    queueDir = "up"
                elseif key == "s" or key == "down" then
                    queueDir = "down"
                elseif key == "a" or key == "left" then
                    queueDir = "left"
                elseif key == "d" or key == "right" then
                    queueDir = "right"
                end

                -- Queue if not opposite to current direction and not the same direction
                if queueDir and not areOppositeDirections(player.direction, queueDir) and queueDir ~= player.direction then
                    player.queuedDirection = queueDir
                    break
                end
            end
        end

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
        
        -- Calculate jump arc if jumping
        if player.jumping then
            -- Parabolic arc: height peaks at midpoint
            local jumpProgress = progress
            player.jumpHeight = math.sin(jumpProgress * math.pi) * 12  -- Peak height of 12 pixels
        else
            player.jumpHeight = 0
        end
        
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
            player.jumping = false
            player.jumpHeight = 0
            player.moveTimer = 0
            player.walkFrame = 0

            -- Check if player transitioned from water to land (boat use)
            -- Only check this if not jumping (jumping over water shouldn't consume boat)
            local isOnWater = MapSystem.isWaterTile(endX, endY)
            if not player.jumping then
                if player.wasOnWater and not isOnWater then
                    -- Transitioning from water to land - consume boat use
                    local boatAbility = abilityManager:getAbility("boat")
                    if boatAbility and not abilityManager:hasAbility("swim") then
                        -- Use boat ability (consumes a use)
                        boatAbility:use()

                        -- Remove ability if expired
                        if boatAbility.currentUses <= 0 then
                            abilityManager:removeAbility("boat")
                        end
                    end
                end

                -- Update water state for next frame (only when not jumping)
                player.wasOnWater = isOnWater
            end

            -- Check if there's a queued movement to execute
            if player.queuedDirection then
                local queuedDir = player.queuedDirection
                player.queuedDirection = nil

                -- Try to execute queued movement
                local newGridX, newGridY = player.gridX, player.gridY

                if queuedDir == "up" then
                    newGridY = player.gridY - 1
                    player.lastVertical = "up"
                elseif queuedDir == "down" then
                    newGridY = player.gridY + 1
                    player.lastVertical = "down"
                elseif queuedDir == "left" then
                    player.facing = "left"
                    newGridX = player.gridX - 1
                elseif queuedDir == "right" then
                    player.facing = "right"
                    newGridX = player.gridX + 1
                end

                -- Check collision for queued movement
                local targetPixelX = newGridX * 16 + 8
                local targetPixelY = newGridY * 16 + 8

                local canCrossWater = abilityManager:hasEffect(AbilitySystem.EffectType.WATER_TRAVERSAL)
                local canJump = abilityManager:hasEffect(AbilitySystem.EffectType.JUMP)
                local tileBlocked = MapSystem.isColliding(targetPixelX, targetPixelY, canCrossWater)
                local npcBlocked = MapSystem.isNPCAt(targetPixelX, targetPixelY)

                -- Check if we should jump over an obstacle
                if tileBlocked and canJump and MapSystem.isJumpableObstacle(targetPixelX, targetPixelY) then
                    -- Try to jump OVER the obstacle (2 tiles total)
                    local jumpLandingX = newGridX + (newGridX - player.gridX)
                    local jumpLandingY = newGridY + (newGridY - player.gridY)
                    local landingPixelX = jumpLandingX * 16 + 8
                    local landingPixelY = jumpLandingY * 16 + 8

                    -- Check if landing spot is valid
                    local landingBlocked = MapSystem.isColliding(landingPixelX, landingPixelY, canCrossWater)
                    local landingNpcBlocked = MapSystem.isNPCAt(landingPixelX, landingPixelY)

                    if not landingBlocked and not landingNpcBlocked then
                        -- Perform jump over the obstacle
                        player.direction = queuedDir
                        player.targetGridX = jumpLandingX
                        player.targetGridY = jumpLandingY
                        player.moving = true
                        player.jumping = true
                        player.moveTimer = 0
                        player.moveDuration = abilityManager:hasEffect(AbilitySystem.EffectType.SPEED) and 0.25 / 4 or 0.25
                    end
                elseif not tileBlocked and not npcBlocked then
                    -- Normal movement
                    player.direction = queuedDir
                    player.targetGridX = newGridX
                    player.targetGridY = newGridY
                    player.moving = true
                    player.jumping = false
                    player.moveTimer = 0
                    player.moveDuration = abilityManager:hasEffect(AbilitySystem.EffectType.SPEED) and 0.15 / 4 or 0.15
                end
            end
        end
    else
        -- Check for input to start new movement
        -- Prioritize most recently pressed key (last in heldKeys)
        local moveDir = nil
        local newGridX, newGridY = player.gridX, player.gridY

        -- Check held keys in reverse order (most recent first)
        for i = #heldKeys, 1, -1 do
            local key = heldKeys[i]
            if love.keyboard.isDown(key) then
                if key == "w" or key == "up" then
                    moveDir = "up"
                    player.lastVertical = "up"
                    newGridY = player.gridY - 1
                    break
                elseif key == "s" or key == "down" then
                    moveDir = "down"
                    player.lastVertical = "down"
                    newGridY = player.gridY + 1
                    break
                elseif key == "a" or key == "left" then
                    moveDir = "left"
                    player.facing = "left"
                    newGridX = player.gridX - 1
                    break
                elseif key == "d" or key == "right" then
                    moveDir = "right"
                    player.facing = "right"
                    newGridX = player.gridX + 1
                    break
                end
            end
        end
        
        if moveDir then
            player.direction = moveDir
            
            -- Check collision at target grid position (with abilities)
            local targetPixelX = newGridX * 16 + 8
            local targetPixelY = newGridY * 16 + 8
            
            local canCrossWater = abilityManager:hasEffect(AbilitySystem.EffectType.WATER_TRAVERSAL)
            local canJump = abilityManager:hasEffect(AbilitySystem.EffectType.JUMP)
            local tileBlocked = MapSystem.isColliding(targetPixelX, targetPixelY, canCrossWater)
            local npcBlocked = MapSystem.isNPCAt(targetPixelX, targetPixelY)
            
            -- Check if we should jump over an obstacle
            if tileBlocked and canJump and MapSystem.isJumpableObstacle(targetPixelX, targetPixelY) then
                -- Try to jump OVER the obstacle (2 tiles total)
                local jumpLandingX = newGridX + (newGridX - player.gridX)
                local jumpLandingY = newGridY + (newGridY - player.gridY)
                local landingPixelX = jumpLandingX * 16 + 8
                local landingPixelY = jumpLandingY * 16 + 8
                
                -- Check if landing spot is valid (not blocked and not an NPC there)
                local landingBlocked = MapSystem.isColliding(landingPixelX, landingPixelY, canCrossWater)
                local landingNpcBlocked = MapSystem.isNPCAt(landingPixelX, landingPixelY)
                
                if not landingBlocked and not landingNpcBlocked then
                    -- Perform jump over the obstacle
                    player.targetGridX = jumpLandingX
                    player.targetGridY = jumpLandingY
                    player.moving = true
                    player.jumping = true
                    player.moveTimer = 0
                    player.moveDuration = abilityManager:hasEffect(AbilitySystem.EffectType.SPEED) and 0.25 / 4 or 0.25  -- Jumps take a bit longer
                end
            elseif not tileBlocked and not npcBlocked then
                -- Normal movement
                player.targetGridX = newGridX
                player.targetGridY = newGridY
                player.moving = true
                player.jumping = false
                player.moveTimer = 0
                player.moveDuration = abilityManager:hasEffect(AbilitySystem.EffectType.SPEED) and 0.15 / 4 or 0.15  -- Normal walk speed
            end
        end
    end
end

return PlayerSystem
