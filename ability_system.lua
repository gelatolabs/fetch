-- Ability System
-- Simple system for managing player abilities

local AbilitySystem = {}

-- Ability types (only what we use)
AbilitySystem.AbilityType = {
    PASSIVE = "passive",      -- Always active once learned
    CONSUMABLE = "consumable" -- Limited uses
}

-- Ability effects (only what we use)
AbilitySystem.EffectType = {
    WATER_TRAVERSAL = "water_traversal"
}

-- Ability class
local Ability = {}
Ability.__index = Ability

function Ability.new(config)
    local self = setmetatable({}, Ability)
    
    self.id = config.id
    self.name = config.name
    self.aliases = config.aliases or {}
    self.type = config.type or AbilitySystem.AbilityType.PASSIVE
    self.effects = config.effects or {}
    self.color = config.color or {1, 1, 1}
    
    -- Consumable properties
    self.maxUses = config.maxUses
    self.currentUses = config.maxUses or 0
    
    -- Callbacks
    self.onAcquire = config.onAcquire
    self.onUse = config.onUse
    self.onExpire = config.onExpire
    
    return self
end

function Ability:hasEffect(effectType)
    for _, effect in ipairs(self.effects) do
        if effect == effectType then
            return true
        end
    end
    return false
end

function Ability:use(context)
    -- Consume use if consumable
    if self.type == AbilitySystem.AbilityType.CONSUMABLE then
        self.currentUses = self.currentUses - 1
        
        if self.currentUses <= 0 and self.onExpire then
            self.onExpire(context)
        end
    end
    
    if self.onUse then
        self.onUse(context, self)
    end
    
    return true
end

-- Player Ability Manager
local PlayerAbilityManager = {}
PlayerAbilityManager.__index = PlayerAbilityManager

function PlayerAbilityManager.new()
    local self = setmetatable({}, PlayerAbilityManager)
    self.abilities = {}
    self.abilityRegistry = {}
    return self
end

function PlayerAbilityManager:registerAbility(config)
    local ability = Ability.new(config)
    self.abilityRegistry[ability.id] = ability
    return ability
end

function PlayerAbilityManager:grantAbility(abilityId, context)
    local def = self.abilityRegistry[abilityId]
    if not def then
        return false
    end
    
    -- Create instance
    local ability = Ability.new({
        id = def.id,
        name = def.name,
        aliases = def.aliases,
        type = def.type,
        effects = def.effects,
        maxUses = def.maxUses,
        onAcquire = def.onAcquire,
        onUse = def.onUse,
        onExpire = def.onExpire,
        color = def.color
    })
    
    self.abilities[abilityId] = ability
    
    if ability.onAcquire then
        ability.onAcquire(context, ability)
    end
    
    return true
end

function PlayerAbilityManager:hasAbility(abilityId)
    return self.abilities[abilityId] ~= nil
end

function PlayerAbilityManager:getAbility(abilityId)
    return self.abilities[abilityId]
end

function PlayerAbilityManager:removeAbility(abilityId)
    self.abilities[abilityId] = nil
end

function PlayerAbilityManager:hasEffect(effectType)
    for _, ability in pairs(self.abilities) do
        if ability:hasEffect(effectType) then
            -- For consumables, check if they have uses left
            if ability.type == AbilitySystem.AbilityType.CONSUMABLE then
                if ability.currentUses > 0 then
                    return true
                end
            else
                return true
            end
        end
    end
    return false
end

function PlayerAbilityManager:getAllAbilities()
    local list = {}
    for _, ability in pairs(self.abilities) do
        table.insert(list, ability)
    end
    return list
end

function PlayerAbilityManager:getRegisteredAbility(nameOrAlias)
    -- Check direct ID
    if self.abilityRegistry[nameOrAlias] then
        return self.abilityRegistry[nameOrAlias]
    end
    
    -- Check aliases
    for _, ability in pairs(self.abilityRegistry) do
        for _, alias in ipairs(ability.aliases) do
            if alias == nameOrAlias then
                return ability
            end
        end
    end
    
    return nil
end

function PlayerAbilityManager:getAllRegisteredAbilityIds()
    local ids = {}
    for id, _ in pairs(self.abilityRegistry) do
        table.insert(ids, id)
    end
    return ids
end

-- Export
AbilitySystem.Ability = Ability
AbilitySystem.PlayerAbilityManager = PlayerAbilityManager

return AbilitySystem