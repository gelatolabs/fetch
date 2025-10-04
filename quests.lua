local quests = {}

-- Quest Chain 1: Lost Cat
-- NPCs positioned on tile grid (grid coordinates * 16 + 8 for center)
-- Note: If any NPC spawns on a collision tile (water/wall), the game will
-- automatically find the nearest valid spawn location within 20 tiles.
quests.npcs = {
    {
        id = "npc_cat_owner",
        map = "map",
        x = -10 * 16 + 8,  -- Grid position (-10, -12) - upper left area
        y = -12 * 16 + 8,
        size = 16,
        name = "Old Lady",
        questId = "quest_lost_cat",
        isQuestGiver = true
    },
    {
        id = "npc_cat_finder",
        map = "shop",
        x = 6 * 16 + 8,  -- Grid position (6, 0) - right side of shop
        y = 8,
        size = 16,
        name = "Child",
        givesItem = "item_cat",
        requiresQuest = "quest_lost_cat",
        requiresDialog = true,
        itemGiveText = "I found this cat wandering around! You can have it.",
        noQuestText = "I'm playing with my toys right now!"
    },
    {
        id = "npc_shopkeeper",
        map = "shop",
        x = 0 * 16 + 8,  -- Grid position (0, -4)
        y = -4 * 16 + 8,
        size = 16,
        name = "Shopkeeper",
        isShopkeeper = true
    },
    {
        id = "npc_king",
        map = "shop",
        x = -4 * 16 + 8,  -- Grid position (-4, 5)
        y = 5 * 16 + 8,
        size = 16,
        name = "King",
        questId = "quest_royal_gift",
        isQuestGiver = true
    },
    -- Quest Chain 2: Missing Book
    {
        id = "npc_librarian",
        map = "map",
        x = -8 * 16 + 8,  -- Grid position (-8, 2) - left side, above water
        y = 2 * 16 + 8,
        size = 16,
        name = "Librarian",
        questId = "quest_missing_book",
        isQuestGiver = true
    },
    {
        id = "npc_reader",
        map = "map",
        x = 5 * 16 + 8,  -- Grid position (5, -8) - upper middle area
        y = -8 * 16 + 8,
        size = 16,
        name = "Reader",
        givesItem = "item_book",
        requiresQuest = "quest_missing_book",
        requiresDialog = true,
        itemGiveText = "Oh, I'm done with this book. Here you go!",
        noQuestText = "Shh... I'm reading something really interesting!"
    },
    -- Quest Chain 3: Delivery Package
    {
        id = "npc_merchant",
        map = "map",
        x = 25 * 16 + 8,  -- Grid position (25, -5) - right side, upper area
        y = -5 * 16 + 8,
        size = 16,
        name = "Merchant",
        questId = "quest_delivery",
        isQuestGiver = true
    },
    {
        id = "npc_courier",
        map = "map",
        x = -5 * 16 + 8,  -- Grid position (-5, -14) - left side, very top
        y = -14 * 16 + 8,
        size = 16,
        name = "Courier",
        givesItem = "item_package",
        requiresQuest = "quest_delivery",
        requiresDialog = true,
        itemGiveText = "This package is ready for pickup. Take it!",
        noQuestText = "I've got deliveries to make. Very busy!"
    },
    -- Quest Chain 4: Build a Boat (to reach the swimmer)
    {
        id = "npc_boat_builder",
        map = "map",
        x = -6 * 16 + 8,  -- Grid position (-6, 8) - near water on accessible side
        y = 8 * 16 + 8,
        size = 16,
        name = "Boat Builder",
        questId = "quest_build_boat",
        isQuestGiver = true
    },
    {
        id = "npc_woodcutter",
        map = "map",
        x = 10 * 16 + 8,  -- Grid position (10, 5) - accessible area
        y = 5 * 16 + 8,
        size = 16,
        name = "Woodcutter",
        givesItem = "item_wood",
        requiresQuest = "quest_build_boat",
        requiresDialog = true,
        itemGiveText = "Here's some quality wood for your boat. Take it to the builder!",
        noQuestText = "Just chopping wood. Hard work!"
    },
    -- Quest Chain 5: Learn to Swim (requires boat to reach)
    {
        id = "npc_swimmer",
        map = "map",
        x = -12 * 16 + 8,  -- Grid position (-12, 1) - on island, requires boat
        y = 1 * 16 + 8,
        size = 16,
        name = "Swimmer",
        questId = "quest_learn_swim",
        isQuestGiver = true
    },
    {
        id = "npc_lifeguard",
        map = "map",
        x = 18 * 16 + 8,  -- Grid position (18, -6) - far side
        y = -6 * 16 + 8,
        size = 16,
        name = "Lifeguard",
        givesItem = "item_floaties",
        requiresQuest = "quest_learn_swim",
        requiresDialog = true,
        itemGiveText = "Here are some floaties! They'll help you learn to swim. Take them back to the swimmer!",
        noQuestText = "The water is perfect today! Want to learn to swim?"
    },
    -- Quest Chain 6: Learn to Jump
    {
        id = "npc_athlete",
        map = "map",
        x = 15 * 16 + 8,  -- Grid position (15, -12) - upper right area
        y = -12 * 16 + 8,
        size = 16,
        name = "Athlete",
        questId = "quest_learn_jump",
        isQuestGiver = true
    },
    {
        id = "npc_coach",
        map = "map",
        x = 22 * 16 + 8,  -- Grid position (22, 3) - right side
        y = 3 * 16 + 8,
        size = 16,
        name = "Coach",
        givesItem = "item_shoes",
        requiresQuest = "quest_learn_jump",
        requiresDialog = true,
        itemGiveText = "These are special jumping shoes! Take them to the athlete and they'll teach you!",
        noQuestText = "I train athletes to be the best they can be!"
    }
}

quests.questData = {
    quest_lost_cat = {
        id = "quest_lost_cat",
        name = "Lost Cat",
        description = "The old lady lost her cat. Find someone who has seen it!",
        questGiver = "npc_cat_owner",
        requiredItem = "item_cat",
        reward = "Thanks for finding my cat!",
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
        reward = "Nice! Now I can jump around like a pro!\nYou're no pro, but you probably jump over bushes now.",
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
