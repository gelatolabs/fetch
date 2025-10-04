local quests = {}

-- Quest Chain 1: Lost Cat
quests.npcs = {
    {
        id = "npc_cat_owner",
        x = 200,
        y = 200,
        size = 16,
        name = "Old Lady",
        questId = "quest_lost_cat",
        isQuestGiver = true
    },
    {
        id = "npc_cat_finder",
        x = 600,
        y = 200,
        size = 16,
        name = "Child",
        givesItem = "item_cat",
        requiresQuest = "quest_lost_cat",
        requiresDialog = true,
        itemGiveText = "I found this cat wandering around! You can have it.",
        noQuestText = "I'm playing with my toys right now!"
    },
    -- Quest Chain 2: Missing Book
    {
        id = "npc_librarian",
        x = 350,
        y = 450,
        size = 16,
        name = "Librarian",
        questId = "quest_missing_book",
        isQuestGiver = true
    },
    {
        id = "npc_reader",
        x = 150,
        y = 450,
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
        x = 500,
        y = 350,
        size = 16,
        name = "Merchant",
        questId = "quest_delivery",
        isQuestGiver = true
    },
    {
        id = "npc_courier",
        x = 250,
        y = 150,
        size = 16,
        name = "Courier",
        givesItem = "item_package",
        requiresQuest = "quest_delivery",
        requiresDialog = true,
        itemGiveText = "This package is ready for pickup. Take it!",
        noQuestText = "I've got deliveries to make. Very busy!"
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
        reminderText = "The courier has my package. Can you pick it up for me?",
        active = false,
        completed = false
    }
}

return quests
