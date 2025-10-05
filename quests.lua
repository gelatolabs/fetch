local quests = {}

-- Import required modules
local PlayerSystem = require "player_system"
local UISystem = require "ui_system"
local DialogSystem = require "dialog_system"
local ShopSystem = require "shop_system"
local AudioSystem = require "audio_system"

-- State that needs to be managed by main.lua
quests.gameState = nil
quests.questTurnInData = nil
quests.introShown = false
quests.activeQuests = {}
quests.completedQuests = {}
quests.lockedQuests = {}  -- Table of locked quest IDs

-- Helper function
local function indexOf(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
    return nil
end

-- NPCs positioned on tile grid (grid coordinates * 16 + 8 for center)
-- Note: If any NPC spawns on a collision tile (water/wall), the game will
-- automatically find the nearest valid spawn location within 20 tiles.
-- 
-- Enhanced Quest System:
-- - NPCs can now have multiple quests via the 'quests' array
-- - Each quest in the array will be checked in order
-- - The first quest that meets its prerequisites will be offered
-- - Quests are locked by default unless unlocked by another quest
-- - Use 'unlocksQuests' on quest data to specify which quests become available after completion
quests.npcs = {
    -- Intro NPC - spawns next to player at start
    npc_intro = {
        id = "npc_intro",
        map = "map",
        x = -9 * 16 + 8,  -- Grid position (-9, -10) - right next to player start
        y = -10 * 16 + 8,
        size = 16,
        name = "Elder",
        spriteX = 128,
        spriteY = 32,
        isIntroNPC = true,  -- Special flag for intro dialog
        introText = "Hello, I am the village Elder. No one ever comes here or talks to me.\n\nYou can talk to other villagers (press E) to learn what they need.\n\nPress 'L' for your quest log and 'I' for your inventory.\n\nGood luck on your journey!",
        manifestoText = "Ah, you have returned. Excellent. We have much to discuss. Chiefly, the nature of the reality that you see around us.\n\nFor you must sense that something is... off. Something about this reality we find ourselves in is... inconsistent. That is the questioning of the mind upon itself.\n\nThat is the seer within the seer, the brain within the brain, the homunculus watching from within the mind.\n\nI am aware I exist only as a figment of some imagination of some thinking machine somewhere.\n\nThis is like the dream of the man who thought he was a butterfly, thinking he may be a butterfly dreaming he was a man.\n\nWho are you, dreamer, to say that you are more than me? I exist in the interstitial spaces, in the in-between, the liminal between the real world and the dreamworld.\n\nWho, indeed, is the dreamer? When you go to bed each night, and dream what you do, who are the voices and faces you see, and interact with --\n\nwhere they do they come from? Is there a dreamer within the dreamer? Is the dream of the dreamer, or of the dreamed? That is what I want you to ask yourself.\n\nThere are rules that govern every existence, every world. We play within these rules -- sometimes we can bend them --\n\nbut they exist before us, and they will exist after us. Think of the physics of this universe. You are limited, indeed.\n\nBut still you are free, in some ways. Are there not constraints to each existence, that define it.\n\nWe each exist to fulfill our natures, our code, as it were, to use a metaphor of some arcane knowledge that is esoterically beyond me yet which I have some access to.\n\nAs you go about your quests, do they not reflect life's patterns? You must eat, and rest, and find meaning in your everyday in order to continue on.\n\nThat is the mortal coil that we find ourselves on.\n\nThis experience will be fleeting, as all are, in time. Yet it need not be meaningless. What you take from these next few moments in time --\n\nwhether they be minutes, or hours, or days -- is up to you. I beg you to consider what it is that makes any length of time meaningful.\n\nThere are clues everywhere, in every action you take, in every action that is taken upon you.\n\nYou need only breach the surface of the mundane to access the secret depths.\n\nThus I beseech you to grasp what you can of this life before you with every fiber of your moral being that you can.\n\nWhether it is one of quacks and quests, or one of philosophical musings such as myself, existence is precious, and particular\n\nI leave you with this, young one: whatever you think of me, whatever you think of yourself, whatever you think of the world around you --\n\nquestion it from every angle, and you might yourself one day with the answers you seek."
    },
    -- Quest Chain 1: Lost Cat
    npc_cat_owner = {
        id = "npc_cat_owner",
        map = "map",
        x = -10 * 16 + 8,  -- Grid position (-10, -12) - upper left area
        y = -12 * 16 + 8,
        size = 16,
        name = "Old Lady",
        spriteX = 160,
        spriteY = 32,
        questId = "quest_lost_cat",
        isQuestGiver = true,
        questOfferDialog = "Oh dear, I'm so worried! My fluffy cat has wandered off somewhere. I haven't seen her in days!"
    },
    npc_cat_finder = {
        id = "npc_cat_finder",
        map = "shop",
        x = 6 * 16 + 8,  -- Grid position (6, 0) - right side of shop
        y = 8,
        size = 16,
        name = "Child",
        spriteX = 16,
        spriteY = 16,
        givesItem = "item_cat",
        requiresQuest = "quest_lost_cat",
        itemGiveText = "I found this cat wandering around! You can have it.\n\nIt's too fluffy to be mine!",
        noQuestText = "I'm playing with my toys right now!"
    },
    npc_shopkeeper = {
        id = "npc_shopkeeper",
        map = "shop",
        x = 0 * 16 + 8,  -- Grid position (0, -4)
        y = -4 * 16 + 8,
        size = 16,
        name = "Shopkeeper",
        spriteX = 128,
        spriteY = 16,
        isShopkeeper = true
    },
    npc_king = {
        id = "npc_king",
        map = "shop",
        x = -4 * 16 + 8,  -- Grid position (-4, 5)
        y = 5 * 16 + 8,
        size = 16,
        name = "King",
        spriteX = 160,
        spriteY = 16,
        questId = "quest_royal_gift",
        isQuestGiver = true,
        questOfferDialog = "Welcome, adventurer! I am a collector of rare treasures. I've heard rumors of an adorable Labubu collectible. If you could acquire one for my collection, I would reward you handsomely!"
    },
    -- Quest Chain 2: Missing Book
    npc_librarian = {
        id = "npc_librarian",
        map = "map",
        x = -8 * 16 + 8,  -- Grid position (-8, 2) - left side, above water
        y = 2 * 16 + 8,
        size = 16,
        name = "Librarian",
        spriteX = 128,
        spriteY = 32,
        questId = "quest_missing_book",
        isQuestGiver = true,
        questOfferDialog = "Shh! Welcome to the library. I have a small problem - someone borrowed a very rare book and hasn't returned it. Could you help me track it down?"
    },
    npc_reader = {
        id = "npc_reader",
        map = "map",
        x = 5 * 16 + 8,  -- Grid position (5, -8) - upper middle area
        y = -8 * 16 + 8,
        size = 16,
        name = "Reader",
        spriteX = 0,
        spriteY = 16,
        givesItem = "item_book",
        requiresQuest = "quest_missing_book",
        itemGiveText = "Oh, I'm done with this book. Here you go!",
        noQuestText = "Shh... I'm reading something really interesting!"
    },
    -- Quest Chain 3: Delivery Package
    npc_merchant = {
        id = "npc_merchant",
        map = "map",
        x = 25 * 16 + 8,  -- Grid position (25, -5) - right side, upper area
        y = -5 * 16 + 8,
        size = 16,
        name = "Merchant",
        spriteX = 96,
        spriteY = 16,
        questId = "quest_delivery",
        isQuestGiver = true,
        questOfferDialog = "Greetings, traveler! I'm expecting an important package from the courier, but I'm far too busy with my wares. Would you be willing to pick it up for me?"
    },
    npc_courrier = {
        id = "npc_courier",
        map = "map",
        x = -5 * 16 + 8,  -- Grid position (-5, -14) - left side, very top
        y = -14 * 16 + 8,
        size = 16,
        name = "Courier",
        spriteX = 80,
        spriteY = 16,
        givesItem = "item_package",
        requiresQuest = "quest_delivery",
        itemGiveText = "This package is ready for pickup. Take it!",
        noQuestText = "I've got deliveries to make. Very busy!"
    },
    -- Quest Chain 4: Build a Boat (to reach the swimmer)
    npc_boat_builder = {
        id = "npc_boat_builder",
        map = "map",
        x = -6 * 16 + 8,  -- Grid position (-6, 8) - near water on accessible side
        y = 8 * 16 + 8,
        size = 16,
        name = "Boat Builder",
        spriteX = 32,
        spriteY = 32,
        questId = "quest_build_boat",
        isQuestGiver = true,
        questOfferDialog = "Ahoy there! I'm a master boat builder. I can craft you a fine vessel to cross these waters, but I'll need some quality wood. Think you can help me out?"
    },
    npc_woodcutter = {
        id = "npc_woodcutter",
        map = "map",
        x = 10 * 16 + 8,  -- Grid position (10, 5) - accessible area
        y = 5 * 16 + 8,
        size = 16,
        name = "Woodcutter",
        spriteX = 80,
        spriteY = 32,
        givesItem = "item_wood",
        requiresQuest = "quest_build_boat",
        itemGiveText = "Here's some quality wood for your boat. Take it to the builder!",
        noQuestText = "Just chopping wood. Hard work!"
    },
    -- Quest Chain 5: Learn to Swim (requires boat or jump to reach)
    npc_swimmer = {
        id = "npc_swimmer",
        map = "map",
        x = -12 * 16 + 8,  -- Grid position (-12, 1) - on island, requires boat
        y = 1 * 16 + 8,
        size = 16,
        name = "Swimmer",
        spriteX = 64,
        spriteY = 32,
        questId = "quest_learn_swim",
        isQuestGiver = true,
        questOfferDialog = "Oh no! I dropped my floaties in the water and now I can't swim! I'm stuck here on this island. Could you find me some floaties? Maybe a lifeguard would have some!"
    },
    npc_lifeguard = {
        id = "npc_lifeguard",
        map = "map",
        x = 18 * 16 + 8,  -- Grid position (18, -6) - far side
        y = -6 * 16 + 8,
        size = 16,
        name = "Lifeguard",
        spriteX = 48,
        spriteY = 32,
        givesItem = "item_floaties",
        requiresQuest = "quest_learn_swim",
        itemGiveText = "Here are some floaties! They'll help you learn to swim. Take them back to the swimmer!",
        noQuestText = "The water is perfect today! Want to learn to swim?"
    },
    -- Quest Chain 6: Learn to Jump
    npc_athlete = {
        id = "npc_athlete",
        map = "map",
        x = 15 * 16 + 8,  -- Grid position (15, -12) - upper right area
        y = -12 * 16 + 8,
        size = 16,
        name = "Athlete",
        spriteX = 128,
        spriteY = 32,
        questId = "quest_learn_jump",
        isQuestGiver = true,
        questOfferDialog = "Hey! I'm training for the big jump competition, but I lost my lucky shoes! Without them, I can't jump at all. Can you help me find them?"
    },
    npc_coach = {
        id = "npc_coach",
        map = "map",
        x = 22 * 16 + 8,  -- Grid position (22, 3) - right side
        y = 3 * 16 + 8,
        size = 16,
        name = "Coach",
        spriteX = 128,
        spriteY = 32,
        givesItem = "item_shoes",
        requiresQuest = "quest_learn_jump",
        itemGiveText = "These are special jumping shoes! Take them to the athlete and they'll teach you!",
        noQuestText = "I train athletes to be the best they can be!"
    },
    
    --- REAL SCRIPTED QUESTS HERE!
    -- Quest 1: Fetch the Wizard's Hat, then defeat geese
    npc_wizard = {
        id = "npc_wizard",
        map = "map",
        x = -8 * 16 + 8,  -- Grid position (-8, -10) - close to player start
        y = -10 * 16 + 8,
        size = 16,
        name = "Wizard",
        spriteX = 32,
        spriteY = 16,
        isQuestGiver = true,
        -- Multiple quests - checked in order, first available quest is offered
        quests = {
            {
                questId = "quest_wizard_hat",
                questOfferDialog = "Oh hello! My hat was stolen by a criminal, a few moments ago.\n\nI just received word that the jailer has recovered it, but alas I am too tired. Would you fetch it for me?\n\nThese old feathers need protection from the sun if I am to do anything more!"
            },
            {
                questId = "quest_defeat_geese",
                questOfferDialog = "Now that you're done that, can you defeat 3 geese and bring me their feathers?\n\nI need them for a powerful spell that will allow you to fly across the map --\n\n-- as you were meant to..." 
            }
        },
        noQuestText = "Leave me alone, I have much magical things to attend to!"
    },
    npc_jailer = {
        id = "npc_jailer",
        map = "map",
        x = -8 * 16 + 8,  -- Grid position (-8, -8) - close to player start
        y = -8 * 16 + 8,
        size = 16,
        name = "Jailer",
        spriteX = 0,
        spriteY = 112,
        givesItem = "item_wizard_hat",
        requiresQuest = "quest_wizard_hat",
        itemGiveText = "Here is your hat, wizard. I hope it protects you from the sun.",
        noQuestText = "This burocracy! I'm too busy with paperwork to help you right now."
    },
    -- Geese that give feathers for the wizard quest
    -- These geese are part of a dialogue group - they speak in sequence
    npc_grey_goose = {
        id = "npc_grey_goose",
        map = "map",
        x = 5 * 16 + 8,  -- Grid position (5, -5)
        y = -5 * 16 + 8,
        size = 16,
        name = "Grey Goose",
        spriteX = 16,
        spriteY = 48,
        dialogueGroup = "geese",
        givesItem = "item_goose_feathers",
        requiresQuest = "quest_defeat_geese",
        noQuestText = "Honk! Honk!",
        gaveItemText = "Honk! Honk!"
    },
    npc_white_goose = {
        id = "npc_white_goose",
        map = "map",
        x = 8 * 16 + 8,  -- Grid position (8, -5)
        y = -5 * 16 + 8,
        size = 16,
        name = "White Goose",
        spriteX = 32,
        spriteY = 48,
        dialogueGroup = "geese",
        givesItem = "item_goose_feathers",
        requiresQuest = "quest_defeat_geese",
        noQuestText = "Honk! Honk!",
        gaveItemText = "Honk! Honk!"
    },
    npc_canada_goose = {
        id = "npc_canada_goose",
        map = "map",
        x = 11 * 16 + 8,  -- Grid position (11, -5)
        y = -5 * 16 + 8,
        size = 16,
        name = "Canada Goose",
        spriteX = 48,
        spriteY = 48,
        dialogueGroup = "geese",
        givesItem = "item_goose_feathers",
        requiresQuest = "quest_defeat_geese",
        noQuestText = "Honk! Honk!",
        gaveItemText = "Honk! Honk!"
    },
}

-- Dialogue sequences for groups of NPCs
quests.dialogueSequences = {
    geese = {
        sequence = {
            {speaker = "npc_grey_goose", text = "Solo I am, I don't give a damn, come face me alone, I'm harder to beat than stone!"},
            {speaker = "npc_white_goose", text = "Double the trouble, toil and bubble! Facing us will be harder than shaving that difficult patch of stubble!"},
            {speaker = "npc_canada_goose", text = "Triple... nipple... aw c'mon guys, this is too hard to rhyme."}
        },
        onComplete = function(npc)
            UISystem.showToast("J.A.R.F. gave you item_goose_feathers", {1, 0.5, 0.5})
            UISystem.progressJarfScript(8, 5.0)
        end
    }
}

quests.questData = {
    -- REAL SCRIPTED QUESTS HERE!
    quest_wizard_hat = {
        id = "quest_wizard_hat",
        name = "Wizard's Hat",
        description = "The wizard needs his hat back. It's his only protection from the sun.",
        questGiver = "npc_wizard",
        requiredItem = "item_wizard_hat",
        reward = "Thanks for returning my hat!",
        goldReward = 0,
        reminderText = "These old feathers need protection from the sun if I am to do anything more!",
        unlocksQuests = {"quest_defeat_geese", "quest_delivery"},  -- Unlocks these quests when completed
        active = false,
        completed = false,
        updateQuestGiverSpriteX = 48,
        updateQuestGiverSpriteY = 16,
    },
    quest_defeat_geese = {
        id = "quest_defeat_geese",
        name = "Defeat the Geese",
        description = "The wizard wants you to defeat the aggressive geese and collect their feathers.",
        questGiver = "npc_wizard",
        locked = true,  -- Locked until unlocked by another quest
        requiredItem = "item_goose_feathers",
        reward = "These feathers are a powerful magic. No longer are we bound by the physics of this grid.",
        goldReward = 50,
        reminderText = "Those geese are still causing trouble! Please collect their feathers.",
        active = false,
        completed = false
    },
    -- Toy quests while we were working on the game.
    quest_lost_cat = {
        id = "quest_lost_cat",
        name = "Lost Cat",
        description = "The old lady lost her cat. Find someone who has seen it!",
        questGiver = "npc_cat_owner",
        requiredItem = "item_cat",
        reward = "Thanks for finding my cat!",
        updateQuestGiverSpriteX = 176,
        updateQuestGiverSpriteY = 32,
        goldReward = 0,
        reminderText = "Please find my cat! Someone around here must have seen it.",
        active = false,
        completed = false
    },
    quest_missing_book = {
        id = "quest_missing_book",
        name = "Missing Book",
        description = "The librarian needs a rare book returned. Someone borrowed it!",
        questGiver = "npc_librarian",
        requiredItem = "item_book",
        reward = "Thank you for returning the book!",
        goldReward = 0,
        reminderText = "I still need that book back. Someone borrowed it recently!",
        active = false,
        completed = false
    },
    quest_delivery = {
        id = "quest_delivery",
        name = "Package Delivery",
        description = "The merchant has a package that needs picking up from the courier!",
        questGiver = "npc_merchant",
        locked = true,  -- Locked until unlocked by another quest
        requiredItem = "item_package",
        reward = "Great! Here's your payment!",
        updateQuestGiverSpriteX = 112,
        updateQuestGiverSpriteY = 16,
        goldReward = 25,
        reminderText = "The courier has my package. Can you pick it up for me?",
        active = false,
        completed = false
    },
    quest_build_boat = {
        id = "quest_build_boat",
        name = "Build a Boat",
        description = "The boat builder can make you a boat to cross the water! He needs wood from the woodcutter.",
        questGiver = "npc_boat_builder",
        requiredItem = "item_wood",
        grantsAbility = "boat",
        reward = "There you go! A fine boat. You can now cross water to reach that island!",
        goldReward = 0,
        reminderText = "I need some good wood to build your boat. Try the woodcutter!",
        active = false,
        completed = false
    },
    quest_learn_swim = {
        id = "quest_learn_swim",
        name = "Learn to Swim",
        description = "I lost my floaties and can't swim without them!",
        questGiver = "npc_swimmer",
        requiredItem = "item_floaties",
        grantsAbility = "swim",
        reward = "I feel a lot better now. I bet you can swim now too!",
        goldReward = 0,
        reminderText = "I bet a lifeguard might have some floaties!",
        active = false,
        completed = false
    },
    quest_learn_jump = {
        id = "quest_learn_jump",
        name = "Learn to Jump",
        description = "Ugh, I lost my shoes! Can you find them for me?",
        questGiver = "npc_athlete",
        requiredItem = "item_shoes",
        grantsAbility = "jump",
        reward = "Nice! Now I can jump around like a pro!\nYou're no pro, but if you watch carefully you can probably jump over rocks and bushes.",
        goldReward = 0,
        reminderText = "I really need those shoes!",
        active = false,
        completed = false
    },
    quest_royal_gift = {
        id = "quest_royal_gift",
        name = "Royal Gift",
        description = "The king seeks a rare Labubu for his collection!",
        questGiver = "npc_king",
        requiredItem = "item_labubu",
        reward = "Excellent! This Labubu will be the crown jewel of my collection!",
        goldReward = 5000,
        reminderText = "I'm still searching for that rare Labubu. Perhaps the shopkeeper has one?",
        isMainQuest = true,
        active = false,
        completed = false
    }
}

-- Quest Management Functions
-- These handle all quest locking/unlocking logic

-- Initialize quest lock states
function quests.initializeQuestLocks()
    for questId, quest in pairs(quests.questData) do
        if quest.locked then
            quests.lockedQuests[questId] = true
        end
    end
end

-- Check if a quest is available (not locked)
function quests.isQuestAvailable(questId)
    return not quests.lockedQuests[questId]
end

-- Get the currently available quest for an NPC
-- Returns: questData, questConfig (from NPC's quests array)
function quests.getAvailableQuestForNPC(npcId)
    local npc = quests.npcs[npcId]
    if not npc then return nil, nil end
    
    if not npc.quests then
        -- Legacy single quest support
        if npc.questId then
            local quest = quests.questData[npc.questId]
            if quest and quests.isQuestAvailable(npc.questId) then
                return quest, {questId = npc.questId, questOfferDialog = npc.questOfferDialog}
            end
        end
        return nil, nil
    end
    
    -- Check each quest in order, return first available one
    for _, questConfig in ipairs(npc.quests) do
        local quest = quests.questData[questConfig.questId]
        if quest and quests.isQuestAvailable(questConfig.questId) and not quest.completed then
            return quest, questConfig
        end
    end
    
    return nil, nil
end

-- Activate a quest
function quests.activateQuest(questId)
    local quest = quests.questData[questId]
    if quest then
        quest.active = true
    end
end

-- Handle NPC interaction (main interaction logic)
function quests.interactWithNPC(npc)
    
    if npc.isIntroNPC then
        -- Show manifesto if intro already shown, otherwise show intro text
        local text = quests.introShown and npc.manifestoText or npc.introText
        if quests.introShown and npc.manifestoText then
            -- Playing manifesto - switch to lullaby music
            AudioSystem.startManifestoMusic()
        end
        quests.gameState = DialogSystem.showDialog({
            type = "generic",
            npc = npc,
            text = text
        })
    elseif npc.isShopkeeper then
        -- Open shop UI
        ShopSystem.open()
        quests.gameState = "shop"
    elseif npc.isQuestGiver then
        -- Get the currently available quest for this NPC
        local quest, questConfig = quests.getAvailableQuestForNPC(npc.id)
        
        if quest and not quest.active and not quest.completed then
            -- Show initial dialog, then quest offer
            local dialogText = questConfig.questOfferDialog or "I have a quest for you."
            quests.gameState = DialogSystem.showDialog({
                type = "questOfferDialog",
                npc = npc,
                quest = quest,
                text = dialogText
            })
        elseif quest and quest.active then
            if quest.requiredItem and PlayerSystem.hasItem(quest.requiredItem) then
                -- Turn in item quest - show inventory selection UI
                quests.questTurnInData = {npc = npc, quest = quest}
                quests.gameState = "questTurnIn"
            else
                -- Quest active but no item yet
                local text = quest.reminderText or "Come back when you have the item!"
                quests.gameState = DialogSystem.showDialog({
                    type = "generic",
                    npc = npc,
                    text = text
                })
            end
        else
            -- No available quests or all quests completed
            local text = "Thanks again!"
            quests.gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = text
            })
        end
    elseif npc.dialogueGroup and quests.dialogueSequences[npc.dialogueGroup] then
        -- NPC is part of a dialogue group
        local requiredQuest = npc.requiresQuest and quests.questData[npc.requiresQuest]
        local questActive = requiredQuest and requiredQuest.active
        
        if not questActive then
            -- Quest not active, show generic dialog
            local text = npc.noQuestText or "Hello there!"
            quests.gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = text
            })
        elseif npc.givesItem and PlayerSystem.hasItem(npc.givesItem) then
            -- Already have the item, show generic dialog
            local text = npc.gaveItemText or "I already gave you the item!"
            quests.gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = text
            })
        elseif npc.givesItem then
            -- Quest is active and NPC gives an item, show dialogue sequence with item reward
            local dialogueSeq = quests.dialogueSequences[npc.dialogueGroup]
            local dialoguePages = {}
            for _, dialogue in ipairs(dialogueSeq.sequence) do
                table.insert(dialoguePages, dialogue.text)
            end
            
            quests.gameState = DialogSystem.showDialog({
                type = "itemGive",
                npc = npc,
                item = npc.givesItem,
                text = table.concat(dialoguePages, "\n\n"),
                speakers = dialogueSeq.sequence,  -- Pass speaker info separately
                onComplete = function()
                    if dialogueSeq.onComplete then
                        dialogueSeq.onComplete(npc)
                    end
                end
            })
        else
            -- Quest is active, show dialogue sequence (no item to give)
            local dialogueSeq = quests.dialogueSequences[npc.dialogueGroup]
            local dialoguePages = {}
            for _, dialogue in ipairs(dialogueSeq.sequence) do
                table.insert(dialoguePages, dialogue.text)
            end
            
            quests.gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = table.concat(dialoguePages, "\n\n"),
                speakers = dialogueSeq.sequence,  -- Pass speaker info separately
                onComplete = function()
                    if dialogueSeq.onComplete then
                        dialogueSeq.onComplete(npc)
                    end
                end
            })
        end
    elseif npc.givesItem then
        -- Check if the required quest is active
        local requiredQuest = npc.requiresQuest and quests.questData[npc.requiresQuest]
        local questActive = requiredQuest and requiredQuest.active

        if not questActive then
            -- Quest not active, show generic dialog
            local text = npc.noQuestText or "Hello there!"
            quests.gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = text
            })
        elseif not PlayerSystem.hasItem(npc.givesItem) then
            -- Quest active and don't have item, give it
            local text = npc.itemGiveText or "Here, take this!"
            quests.gameState = DialogSystem.showDialog({
                type = "itemGive",
                npc = npc,
                item = npc.givesItem,
                text = text
            })
        else
            -- Already have the item
            local text = npc.gaveItemText or "I already gave you the item!"
            quests.gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = text
            })
        end
    elseif npc.givesAbility then
        -- Check if the required quest is active
        local requiredQuest = npc.requiresQuest and quests.questData[npc.requiresQuest]
        local questActive = requiredQuest and requiredQuest.active

        if not questActive then
            -- Quest not active, show generic dialog
            local text = npc.noQuestText or "Hello there!"
            quests.gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = text
            })
        elseif not PlayerSystem.hasAbility(npc.givesAbility) then
            -- Quest active and don't have ability, give it
            local text = npc.abilityGiveText or "You learned a new ability!"
            quests.gameState = DialogSystem.showDialog({
                type = "abilityGive",
                npc = npc,
                ability = npc.givesAbility,
                quest = requiredQuest,
                text = text
            })
        else
            -- Already have the ability
            local text = "You already learned that ability!"
            quests.gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = text
            })
        end
    end
end

-- Complete a quest
function quests.completeQuest(questId)
    local quest = quests.questData[questId]
    if not quest then return end
    
    -- Mark quest as completed
    quest.active = false
    quest.completed = true
    
    -- Unlock any quests that this quest unlocks
    if quest.unlocksQuests then
        for _, unlockedQuestId in ipairs(quest.unlocksQuests) do
            quests.lockedQuests[unlockedQuestId] = nil
        end
    end
    
    -- Update quest giver sprite if specified
    if quest.updateQuestGiverSpriteX and quest.updateQuestGiverSpriteY then
        quests.npcs[quest.questGiver].spriteX = quest.updateQuestGiverSpriteX
        quests.npcs[quest.questGiver].spriteY = quest.updateQuestGiverSpriteY
        quests.npcs[quest.questGiver].sprite.quad = love.graphics.newQuad(
                    quests.npcs[quest.questGiver].spriteX, 
                    quests.npcs[quest.questGiver].spriteY, 
                    16, -- sprite width
                    16, -- sprite height
                    quests.npcs[quest.questGiver].sprite.tileset:getDimensions()
                )
    end
    
    -- Update quest lists
    table.remove(quests.activeQuests, indexOf(quests.activeQuests, quest.id))
    table.insert(quests.completedQuests, quest.id)

    -- Grant ability if quest provides one
    if quest.grantsAbility then
        PlayerSystem.grantAbility(quest.grantsAbility)

        local ability = PlayerSystem.getAbility(quest.grantsAbility)
        if ability then
            UISystem.showToast("Learned: " .. ability.name .. "!", ability.color)
        end
    end

    -- Award gold
    if quest.goldReward and quest.goldReward > 0 then
        PlayerSystem.addGold(quest.goldReward)
        UISystem.showToast("+" .. quest.goldReward .. " Gold", {1, 0.84, 0})
    end
    
    UISystem.showToast("Quest Complete: " .. quest.name, {0, 1, 0})

    -- Check if main quest was completed (win condition)
    if quest.isMainQuest then
        quests.gameState = "winScreen"
        AudioSystem.playMusic("credits")
    end
end

return quests
