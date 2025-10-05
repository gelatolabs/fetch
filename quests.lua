local quests = {}

-- NPCs positioned on tile grid (grid coordinates * 16 + 8 for center)
-- Note: If any NPC spawns on a collision tile (water/wall), the game will
-- automatically find the nearest valid spawn location within 20 tiles.
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
        introText = "Hey you! You're finally awake!\n\nWe're in a bit of a jam here, aren't we?\n\nHere's what you should know.\n\nTalk to villagers (press E) to learn what they need.\n\nPress L for your quest log and I for your inventory.\n\nGood luck on your journey!",
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
        questOfferDialog = "Oh dear, I'm so worried! My precious cat has wandered off somewhere. I haven't seen her in days!"
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
        itemGiveText = "I found this cat wandering around! You can have it.",
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
    -- Quest 1: Fetch  the Wizard's Hat.
    npc_wizard = {
        id = "npc_wizard",
        map = "map",
        x = -8 * 16 + 8,  -- Grid position (-8, -10) - close to player start
        y = -10 * 16 + 8,
        size = 16,
        name = "Wizard",
        spriteX = 32,
        spriteY = 16,
        questId = "quest_wizard_hat",
        isQuestGiver = true,
        questOfferDialog = "Oh hello! My hat was stolen by a criminal, a few moments ago.\n\nI just received word that the jailer has recovered it, but alas I am too tired. Would fetch it for me?\n\nThese old feathers need protection from the sun if I am to do anything more!"
    },
    npc_jailer = {
        id = "npc_jailer",
        map = "map",
        x = -8 * 16 + 8,  -- Grid position (-8, -8) - close to player start
        y = -8 * 16 + 8,
        size = 16,
        name = "Jailer",
        givesItem = "item_wizard_hat",
        requiresQuest = "quest_wizard_hat",
        itemGiveText = "Here is your hat, wizard. I hope it protects you from the sun.",
        noQuestText = "This burocracy! I'm too busy with paperwork to help you right now."
    },
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
        active = false,
        completed = false,
        updateQuestGiverSpriteX = 48,
        updateQuestGiverSpriteY = 16,
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

return quests
