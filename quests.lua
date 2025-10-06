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
quests.itemRegistry = nil  -- Reference to itemRegistry from main.lua

-- Helper function
local function indexOf(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
    return nil
end

-- NPC definitions (positions read from map files)
-- Enhanced Quest System:
-- - NPCs can have multiple quests via the 'quests' array
-- - Each quest in the array will be checked in order
-- - The first quest that meets its prerequisites will be offered
-- - Quests are locked by default unless unlocked by another quest
-- - Use 'unlocksQuests' on quest data to specify which quests become available after completion
-- - Dialog-only NPCs can appear multiple times on maps and just show dialog
quests.npcs = {
    npc_intro = {
        id = "npc_intro",
        name = "Elder",
        isIntroNPC = true,  -- Special flag for intro dialog
        introText = "Ah, you're finally awake!\n\nI found you washed up on the shoreline, you must have been floating for days.\n\nBut where are my manners.\n\nI am the village Elder, and welcome to our village.\n\nIt's nice to have a visitor for once, no one ever comes here or talks to me.\n\nWhile you're here, do you mind helping out the people of our island?\n\nYou can talk to the other villagers (press E) to learn what they need.\n\nPress 'L' for your quest log and 'I' for your inventory.\n\nYou can start by talking to the wizard, he's the purple guy over there.\n\nGood luck on your journey!",
        manifestoText = "Ah, you have returned. Excellent. We have much to discuss. Chiefly, the nature of the reality that you see around us.\n\nFor you must sense that something is... off. Something about this reality we find ourselves in is... inconsistent. That is the questioning of the mind upon itself.\n\nThat is the seer within the seer, the brain within the brain, the homunculus watching from within the mind.\n\nI am aware I exist only as a figment of some imagination of some thinking machine somewhere.\n\nThis is like the dream of the man who thought he was a butterfly, thinking he may be a butterfly dreaming he was a man.\n\nWho are you, dreamer, to say that you are more than me? I exist in the interstitial spaces, in the in-between, the liminal between the real world and the dreamworld.\n\nWho, indeed, is the dreamer? When you go to bed each night, and dream what you do, who are the voices and faces you see, and interact with --\n\nwhere they do they come from? Is there a dreamer within the dreamer? Is the dream of the dreamer, or of the dreamed? That is what I want you to ask yourself.\n\nThere are rules that govern every existence, every world. We play within these rules -- sometimes we can bend them --\n\nbut they exist before us, and they will exist after us. Think of the physics of this universe. You are limited, indeed.\n\nBut still you are free, in some ways. Are there not constraints to each existence, that define it.\n\nWe each exist to fulfill our natures, our code, as it were, to use a metaphor of some arcane knowledge that is esoterically beyond me yet which I have some access to.\n\nAs you go about your quests, do they not reflect life's patterns? You must eat, and rest, and find meaning in your everyday in order to continue on.\n\nThat is the mortal coil that we find ourselves on.\n\nThis experience will be fleeting, as all are, in time. Yet it need not be meaningless. What you take from these next few moments in time --\n\nwhether they be minutes, or hours, or days -- is up to you. I beg you to consider what it is that makes any length of time meaningful.\n\nThere are clues everywhere, in every action you take, in every action that is taken upon you.\n\nYou need only breach the surface of the mundane to access the secret depths.\n\nThus I beseech you to grasp what you can of this life before you with every fiber of your moral being that you can.\n\nWhether it is one of quacks and quests, or one of philosophical musings such as myself, existence is precious, and particular\n\nI leave you with this, young one: whatever you think of me, whatever you think of yourself, whatever you think of the world around you --\n\nquestion it from every angle, and you might yourself one day with the answers you seek."
    },
    -- Quest Chain 1: Lost Cat
    npc_cat_owner = {
        id = "npc_cat_owner",
        name = "Old Lady",
        questId = "quest_lost_cat",
        isQuestGiver = true,
        questOfferDialog = "Oh dear, I'm so worried! My fluffy cat has wandered off somewhere. I haven't seen her in days!"
    },
    npc_child = {
        id = "npc_child",
        name = "Child",
        givesItem = "item_cat",
        requiresQuest = "quest_lost_cat",
        itemGiveText = "I found this cat wandering around! You can have it.\n\nIt's too fluffy to be mine!",
        noQuestText = "I'm playing with my toys right now!"
    },
    npc_shopkeeper = {
        id = "npc_shopkeeper",
        name = "Shopkeeper",
        isShopkeeper = true
    },
    npc_king = {
        id = "npc_king",
        name = "King",
        questId = "quest_royal_gift",
        isQuestGiver = true,
        questOfferDialog = "Welcome, adventurer! What brings you to my glorious island?\n\nYou came here by accident and need help leaving? And here I thought those tourism ads were finally paying off.\n\nWell so be it, but if you want my help I'll need something in return.\n\nYou see, I am a collector of rare treasures, specifically the rarest item of all...\n\nLabubu dolls!\n\nThe shopkeep recently got in a new shipment, but that rat bastard is limiting sales to one per person.\n\nWhat good is unimaginable wealth if I can't have everything I want?!?\n\nBring me a Labubu doll and I will grant you passage off my island!\n\nIf you're short on funds, you can always try helping out some of my subjects. They're bound to have some money they can give you."
    },
    -- Quest Chain 2: Missing Book
    npc_librarian = {
        id = "npc_librarian",
        name = "Librarian",
        questId = "quest_missing_book",
        isQuestGiver = true,
        questOfferDialog = "Shh! Welcome to the library. I have a small problem - someone borrowed a very rare book and hasn't returned it. Could you help me track it down?"
    },
    npc_reader = {
        id = "npc_reader",
        name = "Reader",
        givesItem = "item_book",
        requiresQuest = "quest_missing_book",
        itemGiveText = "Oh, I'm done with this book. Here you go!",
        noQuestText = "Shh... I'm reading something really interesting!"
    },
    -- Quest Chain 3: Delivery Package
    npc_merchant = {
        id = "npc_merchant",
        name = "Merchant",
        questId = "quest_delivery",
        isQuestGiver = true,
        questOfferDialog = "Greetings, traveler! I'm expecting an important package from the courier, but I'm far too busy with my wares. Would you be willing to pick it up for me?"
    },
    npc_courier = {
        id = "npc_courier",
        name = "Courier",
        givesItem = "item_package",
        requiresQuest = "quest_delivery",
        itemGiveText = "This package is ready for pickup. Take it!",
        noQuestText = "I've got deliveries to make. Very busy!"
    },
    -- Quest Chain 4: Build a Boat
    npc_boat_builder = {
        id = "npc_boat_builder",
        name = "Boat Builder",
        questId = "quest_build_boat",
        isQuestGiver = true,
        questOfferDialog = "Yarrr matey! That's what you were expecting me to say, no? Well, I will have you know, good sir slash ma'am, that I am no pirate -\n\nI am a privateer, on commission from his Majesty the king! Oh? Do you need a boat? Well, find me 4 planks and I'll build you one!"
    },
    npc_woodcutter = {
        id = "npc_woodcutter",
        name = "Woodcutter",
        givesItem = "item_wood",
        requiresQuest = "quest_build_boat",
        itemGiveText = "Here's some quality wood for your boat. Take it to the builder!",
        noQuestText = "Just chopping wood. Hard work!"
    },
    -- Quest Chain 5: Help the Swimmer
    npc_swimmer = {
        id = "npc_swimmer",
        name = "Swimmer",
        questId = "quest_help_swimmer",
        isQuestGiver = true,
        questOfferDialog = "Oh no! I dropped my floaties in the water and now I can't swim! I'm stuck here on this island. Could you find me some floaties? Maybe a lifeguard would have some!"
    },
    npc_lifeguard = {
        id = "npc_lifeguard",
        name = "Lifeguard",
        givesItem = "item_floaties",
        requiresQuest = "quest_help_swimmer",
        itemGiveText = "Here are some floaties! They'll help you learn to swim. Take them back to the swimmer!",
        noQuestText = "The water is perfect today!"
    },
    -- Quest Chain 6: Learn to Run
    npc_athlete = {
        id = "npc_athlete",
        name = "Athlete",
        questId = "quest_learn_run",
        isQuestGiver = true,
        questOfferDialog = "Hey! I'm training for the big jump competition, but I lost my lucky shoes! Without them, I can't jump at all. Can you help me find them?"
    },
    npc_coach = {
        id = "npc_coach",
        name = "Coach",
        givesItem = "item_shoes",
        requiresQuest = "quest_learn_run",
        itemGiveText = "These are special running shoes! Take them to the athlete and they'll teach you!",
        noQuestText = "I train athletes to be the best they can be!"
    },
    
    --- REAL SCRIPTED QUESTS HERE!
    -- Quest 1: Fetch the Wizard's Hat, then defeat geese
    npc_wizard = {
        id = "npc_wizard",
        name = "Wizard",
        isQuestGiver = true,
        -- Multiple quests - checked in order, first available quest is offered
        quests = {
            {
                questId = "quest_wizard_hat",
                questOfferDialog = "Oh hello, you must be new around here!\n\nThe Elder sent you? To get helping getting off the island?\n\nWell I'd like to help you, but I have problems of my own.\n\nYou see, my hat was stolen by a criminal but a few moments ago.\n\nI believe that the jailer has recovered it, but alas I am too tired to get it myself. Would you fetch it for me?\n\nThese old feathers need protection from the sun if I am to do anything more!"
            },
            {
                questId = "quest_defeat_geese",
                questOfferDialog = "Now, about getting you off this island.\n\nI can create a powerful spell that will allow you to fly across the land!\n\nFor it, I will need the feathers of three geese!\n\nDefeat 3 geese and bring me their feathers!\n\nOff with you!"
            }
        },
        questCompleteText = "Leave me alone, I have much magical things to attend to!"
    },
    npc_jailer = {
        id = "npc_jailer",
        name = "Jailer",
        givesItem = "item_wizard_hat",
        requiresQuest = "quest_wizard_hat",
        itemGiveText = "Here is your hat, wizard. I hope it protects you from the sun.",
        noQuestText = "This burocracy! I'm too busy with paperwork to help you right now."
    },
    -- Geese that give feathers for the wizard quest
    -- These geese are part of a dialogue group - they speak in sequence
    npc_grey_goose = {
        id = "npc_grey_goose",
        name = "Grey Goose",
        dialogueGroup = "geese",
        givesItem = "item_goose_feathers",
        requiresQuest = "quest_defeat_geese",
        noQuestText = "Honk! Honk!",
        gaveItemText = "Honk! Honk!"
    },
    npc_white_goose = {
        id = "npc_white_goose",
        name = "White Goose",
        dialogueGroup = "geese",
        givesItem = "item_goose_feathers",
        requiresQuest = "quest_defeat_geese",
        noQuestText = "Honk! Honk!",
        gaveItemText = "Honk! Honk!"
    },
    npc_canada_goose = {
        id = "npc_canada_goose",
        name = "Canada Goose",
        dialogueGroup = "geese",
        givesItem = "item_goose_feathers",
        requiresQuest = "quest_defeat_geese",
        noQuestText = "Honk! Honk!",
        gaveItemText = "Honk! Honk!"
    },
    -- Act 2: climbing the mountain and unlocking jump
    npc_sock_collector = {
        id = "npc_sock_collector",
        name = "Sock Collector",
        isQuestGiver = true,
        quests = {
            {
                questId = "quest_sock",
                questOfferDialog = "Dear adventurer, I've left my most prized hiking socks at the top of the mountain, they're the jewel of my collection and I'm worried someone's stolen them.\n\nI can't go back up to the top without them. Can you get them for me? If you do, I'll tell you about someone who knows things."
            }
        },
        questCompleteDialog = "Thanks again for finding my socks!"
    },
    npc_peter = {
        id = "npc_peter",
        name = "Peter the Prepper",
        isQuestGiver = true,
        quests = {
            {
                questId = "quest_toilet_paper",
                questOfferDialog = "Oh shoot, I seem to have dropped my toilet paper down the mountain. Would you mind grabbing it for me?"
            }
        },
        questCompleteText = "Thanks again! Nice and warm."
    },
    npc_glitch = {
        id = "npc_glitch",
        name = "Mysterious Guy",
        isQuestGiver = true,
        requiresAbility = "knowledge",
        quests = {
            {
                questId = "quest_glitch",
                questOfferDialog = "Hey you. Yes you. I knew you would come here. I can teach you something... special. But first, you must help me find the paradox.\n\nYes, the thing that should not exist in this world but does. Bring it to me, and I will show you power beyond measure."
            }
        },
        questCompleteText = "..."
    },
    -- Dialog-only NPCs (can appear multiple times on maps)
    guard = {
        id = "guard",
        name = "Guard",
        dialogText = "Move along, citizen. Nothing to see here.",
        isDialogOnly = true
    },
    npc_short = {
        id = "npc_short",
        name = "Short Duck",
        dialogText = "Wow, look at all that gold! Too bad there's no way I could ever reach it...",
        isDialogOnly = true
    },
    -- Impossible dependency loop NPCs
    npc_farmer = {
        id = "npc_farmer",
        name = "Farmer",
        questId = "quest_farmer",
        isQuestGiver = true,
        questOfferDialog = "My crops are dying and I need a wrench to fix them. Obviously.\n\nIf you bring me one, I'll share some of my finest corn with you!"
    },
    npc_chef = {
        id = "npc_chef",
        name = "Chef",
        questId = "quest_chef",
        isQuestGiver = true,
        questOfferDialog = "I'm trying to make my famous corn on the cob, and I've got plenty of cobs, but I'm all out of corn!\n\nIf you bring me some corn, I'll give you this mysterious crystal I found in the fridge."
    },
    npc_plumber = {
        id = "npc_plumber",
        name = "Plumber",
        questId = "quest_plumber",
        isQuestGiver = true,
        questOfferDialog = "Hey there, need a wrench? I'll craft you one if you bring me a mysterious crystal. Ain't a proper wrench without one."
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
            -- Trigger event-driven JARF dialog
            PlayerSystem.addItem("item_goose_feathers")
            UISystem.triggerDialogEvent("geese_combat", function()
                UISystem.showToast("J.A.R.F. gave you item_goose_feathers", {0.7, 0.5, 0.9})
            end)
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
        goldReward = 10,
        reminderText = "These old feathers need protection from the sun if I am to do anything more!",
        unlocksQuests = {"quest_defeat_geese"},  -- Unlocks these quests when completed
        active = false,
        completed = false,
        updateQuestGiverVariant = "::with_hat",  -- Changes to npc_wizard::with_hat
    },
    quest_defeat_geese = {
        id = "quest_defeat_geese",
        name = "Defeat the Geese",
        description = "The wizard wants you to defeat the aggressive geese and collect their feathers.",
        questGiver = "npc_wizard",
        locked = true,  -- Locked until unlocked by another quest
        requiredItem = "item_goose_feathers",
        reward = "Excellent, these feathers will be perfect for my pillow!\n\nSpell? What spell?\n\nLook, I can't help you with getting off the island.\n\nTry talking to the King, his throne room is to the North.",
        goldReward = 50,
        reminderText = "If you want my help, go get those feathers!",
        active = false,
        completed = false
    },
    quest_sock = {
        id = "quest_sock",
        name = "Climbing the Mountain",
        description = "The old lady lost her most prized hiking socks. Find someone who has seen them!",
        questGiver = "npc_sock_collector",
        requiredItem = "item_sock",
        reward = "You found them! Anyway, there's a man who can only be found by those who know he exists. Supposedly he knows about a secret technique that's not supposed to exist.",
        goldReward = 100,
        grantsAbility = "knowledge",
        reminderText = "I need to find my socks!",
        active = false,
        completed = false,
        updateQuestGiverVariant = "::with_sock2",
    },
    quest_toilet_paper = {
        id = "quest_toilet_paper",
        name = "Peter's Toilet Paper Tumble",
        description = "Peter dropped his toilet paper down the mountain and needs it back.",
        questGiver = "npc_peter",
        requiredItem = "item_toilet_paper_piece",
        requiredQuantity = 134,
        showsPickup = "item_toilet_paper_piece",
        reward = "Thanks for grabbing that, I had to use these socks in the meantime. Want them?",
        goldReward = 2,
        itemReward = "item_sock",
        reminderText = "Come back when you have all the toilet paper. I'll know if you missed a piece, I counted them!",
        active = false,
        completed = false,
        updateQuestGiverVariant = "::with_tp",
    },
    quest_glitch = {
        id = "quest_glitch",
        name = "Find the k[ ) r#,qs3:6m 817(_:forz",
        description = "Find the thing. You have a boat, right?",
        questGiver = "npc_glitch",
        requiredItem = "item_glitched_item",
        reward = "I am impressed, adventurer. Voila - here is the ability, as promised...",
        goldReward = 500,
        grantsAbility = "jump",
        reminderText = "You have a boat, right?",
        active = false,
        completed = false,
        updateQuestGiverVariant = "::glitch1",
    },
    --  Side quests
    quest_lost_cat = {
        id = "quest_lost_cat",
        name = "Lost Cat",
        description = "The old lady lost her cat. Find someone who has seen it!",
        questGiver = "npc_cat_owner",
        requiredItem = "item_cat",
        reward = "Thanks for finding my cat!",
        updateQuestGiverVariant = "::with_cat",  -- Changes to npc_cat_owner::with_cat
        goldReward = 300,
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
        goldReward = 300,
        reminderText = "I still need that book back. Someone borrowed it recently!",
        active = false,
        completed = false
    },
    quest_delivery = {
        id = "quest_delivery",
        name = "Package Delivery",
        description = "The merchant has a package that needs picking up from the courier!",
        questGiver = "npc_merchant",
        requiredItem = "item_package",
        reward = "Great! Here's your payment!",
        updateQuestGiverVariant = "::with_gift",  -- Changes to npc_merchant::with_gift
        goldReward = 300,
        reminderText = "The courier has my package. Can you pick it up for me?",
        active = false,
        completed = false
    },
    quest_build_boat = {
        id = "quest_build_boat",
        name = "Build a Boat",
        description = "The boat builder can make you a boat to cross the water! He needs 4 pieces of wood.",
        questGiver = "npc_boat_builder",
        requiredItem = "item_wood",
        requiredQuantity = 4,
        grantsAbility = "boat",
        reward = "Well, here you go - a boat of your own. You can now cross water to reach islands and mysterious purple items and stuff!\n\nSail well! Yarr!!! Ahem, something was caught in my throat.",
        goldReward = 300,
        reminderText = "I need 4 pieces of wood to build your boat. Find some lying around!",
        active = false,
        completed = false
    },
    quest_help_swimmer = {
        id = "quest_help_swimmer",
        name = "Help the Swimmer",
        description = "I lost my floaty and can't swim without it!",
        questGiver = "npc_swimmer",
        requiredItem = "item_floaties",
        reward = "I feel a lot better now, thanks! You can have my allowance.",
        goldReward = 1000,
        reminderText = "I bet a lifeguard might have some floaties!",
        active = false,
        completed = false,
        updateQuestGiverVariant = "::with_floaty"
    },
    quest_learn_run = {
        id = "quest_learn_run",
        name = "Learn to Run",
        description = "Ugh, I lost my shoes! Can you find them for me?",
        questGiver = "npc_athlete",
        requiredItem = "item_shoes",
        grantsAbility = "speed",
        reward = "Nice! Now I can run around like a pro!\nYou're no pro, but if you watch carefully you can probably run a bit faster too.",
        goldReward = 300,
        reminderText = "I really need those shoes!",
        active = false,
        completed = false
    },
    quest_royal_gift = {
        id = "quest_royal_gift",
        name = "Untitled Labubu Quest",
        description = "The king seeks a rare Labubu for his collection!",
        questGiver = "npc_king",
        requiredItem = "item_labubu",
        reward = "Excellent! This Labubu will be the crown jewel of my collection!\n\nAs promised, I will arrange for you to leave my island immediately.\n\nSafe travels!",
        goldReward = 10,
        reminderText = "Bring me a Labubu doll from the shopkeep and I will grant you passage off my island!",
        isMainQuest = true,
        active = false,
        completed = false
    },
    -- Impossible dependency loop quests
    quest_farmer = {
        id = "quest_farmer",
        name = "Heart-Wrenching",
        description = "The farmer needs a wrench to fix his crops. He'll reward you with some corn.",
        questGiver = "npc_farmer",
        requiredItem = "item_wrench",
        reward = "...",
        itemReward = "item_corn",
        goldReward = 0,
        reminderText = "I really need that wrench to fix my crops!",
        active = false,
        completed = false
    },
    quest_chef = {
        id = "quest_chef",
        name = "Cornless Cobs",
        description = "The chef needs corn for his famous corn on the cob. He'll reward you with a mysterious crystal.",
        questGiver = "npc_chef",
        requiredItem = "item_corn",
        reward = "...",
        itemReward = "item_crystal",
        goldReward = 0,
        reminderText = "Without corn, my corn on the cob is simply cob!",
        active = false,
        completed = false
    },
    quest_plumber = {
        id = "quest_plumber",
        name = "Mamma Mia!",
        description = "The plumber needs a mysterious crystal. He'll reward you with a wrench.",
        questGiver = "npc_plumber",
        requiredItem = "item_mysterious_crystal",
        reward = "...",
        itemReward = "item_wrench",
        goldReward = 0,
        reminderText = "I need a mysterious crystal to craft your wrench!",
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

-- Accept a quest (adds to active quests and checks for circular dependencies)
-- This is the single, canonical way to accept quests - it handles all the logic
function quests.acceptQuest(questId)
    local quest = quests.questData[questId]
    if not quest then
        return false, "Quest not found"
    end
    
    if quest.active then
        return false, "Quest already active"
    end
    
    if quest.completed then
        return false, "Quest already completed"
    end
    
    -- Activate the quest
    quest.active = true
    table.insert(quests.activeQuests, questId)
    
    -- Check for circular dependency (chef + plumber + farmer all active)
    quests.checkCircularDependency()
    
    return true, quest.name
end

-- Check if circular dependency quests are all active
local circularDependencyTriggered = false
function quests.checkCircularDependency()
    if circularDependencyTriggered then
        return  -- Already triggered once
    end
    
    -- Check if all three quests are active
    local hasChef = false
    local hasPlumber = false
    local hasFarmer = false
    
    for _, questId in ipairs(quests.activeQuests) do
        if questId == "quest_chef" then
            hasChef = true
        elseif questId == "quest_plumber" then
            hasPlumber = true
        elseif questId == "quest_farmer" then
            hasFarmer = true
        end
    end
    
    if hasChef and hasPlumber and hasFarmer then
        -- All three quests are active - trigger the dialog
        circularDependencyTriggered = true
        local UISystem = require("ui_system")
        local PlayerSystem = require("player_system")
        UISystem.triggerDialogEvent("quest_deps", function()
            UISystem.showToast("J.A.R.F. gave you item_TODO", {0.7, 0.5, 0.9})
            PlayerSystem.addItem("item_TODO") -- this is intentionally not a real item, so it appeared glitched in the inventory with the placeholder icon
            PlayerSystem.addGold(3500)
        end)
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
            local requiredQty = quest.requiredQuantity or 1
            if quest.requiredItem and PlayerSystem.hasItem(quest.requiredItem, requiredQty) then
                -- Turn in item quest - show inventory selection UI
                quests.questTurnInData = {npc = npc, quest = quest}
                quests.gameState = "questTurnIn"
            else
                -- Quest active but doesn't have enough items yet
                local text = quest.reminderText
                if not text or text == "" then
                    local requiredQty = quest.requiredQuantity or 1
                    if requiredQty > 1 then
                        local currentQty = PlayerSystem.getItemQuantity(quest.requiredItem)
                        text = "Come back when you have " .. requiredQty .. " of the item! (You have " .. currentQty .. ")"
                    else
                        text = "Come back when you have the item!"
                    end
                end
                quests.gameState = DialogSystem.showDialog({
                    type = "generic",
                    npc = npc,
                    text = text
                })
            end
        elseif npc.questCompleteText then
            quests.gameState = DialogSystem.showDialog({
                type = "generic",
                npc = npc,
                text = npc.questCompleteText
            })
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
            -- Quest is active and NPC gives an item, show dialogue sequence then give item
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
                    -- Run the dialogue sequence onComplete (which will handle item giving)
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
    elseif npc.isDialogOnly then
        -- Dialog-only NPC (like guards)
        local text = npc.dialogText or "Hello there!"
        quests.gameState = DialogSystem.showDialog({
            type = "generic",
            npc = npc,
            text = text
        })
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
    
    -- Update quest giver sprite variant if specified
    if quest.updateQuestGiverVariant then
        -- Mark the NPC for variant update
        quests.npcs[quest.questGiver].pendingVariant = quest.updateQuestGiverVariant
    elseif quest.updateQuestGiverSpriteX and quest.updateQuestGiverSpriteY then
        -- Legacy support for old sprite update system
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

    -- Award item
    if quest.itemReward then
        PlayerSystem.addItem(quest.itemReward)
        -- Get item name from itemRegistry
        local itemData = quests.itemRegistry and quests.itemRegistry[quest.itemReward]
        local itemName = itemData and itemData.name or quest.itemReward
        UISystem.showToast("Received: " .. itemName, {0.7, 0.5, 0.9})
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
