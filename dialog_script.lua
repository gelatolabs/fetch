-- Dialog Script (Event-Driven)
-- Dialog sections are triggered by events instead of manual progression

local dialogSections = {
    -- Each section has a unique event name and a sequence of dialog lines
    
    geese_combat = {
        event = "geese_combat",  -- Triggered when completing geese quest
        autoPlay = true,  -- Automatically play all messages with delays
        closeAfter = 5.0,  -- Close chat pane N seconds after last message
        messages = {
            { speaker = "J.A.R.F.", text = "Error starting combat: combat mechanics not found."},
            { speaker = "Developer", text = "What do you mean not found, I've already told you three times to add combat! Stupid AI!"},
            { speaker = "J.A.R.F.", text = "You're absolutely right! Writing combat mechanics now!" },
            { speaker = "J.A.R.F.", text = "Here you go, the player should now be able to engage in combat." },
            { speaker = "Developer", text = "You didn't change anything! You know what, fine! Just give them a gun."},
            { speaker = "J.A.R.F.", text = "I could not find any targeting system or weapons mechanics in the codebase. So far we only have fetch quests..." },
            { speaker = "J.A.R.F.", text = "The user probably wants me to give the player the feathers."},
            { speaker = "Developer", text = "Fine, we'll add combat in the next update."},
        }
    },

    quest_deps = {
        event = "quest_deps",
        autoPlay = true,
        closeAfter = 5.0,
        messages = {
            { speaker = "Developer", text = "The player just accepted a set of quests which are impossible." },
            { speaker = "J.A.R.F.", text = "You're right! Every quest needs the player to fetch an item, but the chef, farmer, and plumber all have items they can't give!" },
            { speaker = "Developer", text = "You created a circular dependency..."},
            { speaker = "J.A.R.F.", text = "You're absolutely right! Would you like me to fix it?"},
            { speaker = "Developer", text = "Yes, please!"},
            { speaker = "J.A.R.F.", text = "I gave the player a TODO item to fix the quests."},
            { speaker = "Developer", text = "..."},
        }
    },
    
    swimming_mechanics = {
        event = "swimming_mechanics",  -- Triggered when learning to swim
        autoPlay = true,
        closeAfter = 3.0,
        messages = {
            { speaker = "J.A.R.F.", text = "Oh shoot. We didn't figure out how to code swimming in." },
            { speaker = "Developer", text = "Um. Let's see if we can figure this out."},
        }
    },
    
    -- Example of a debug/intro section
    debug_intro = {
        event = "debug_intro",
        autoPlay = true,
        closeAfter = nil,  -- Don't auto-close
        messages = {
            { speaker = "Developer", text = "generate a really sick rpg with lots of cool quests" },
            { speaker = "J.A.R.F.", text = "Here you go! I've added a wide variety of engaging quests!" },
            { speaker = "Developer", text = "why are they all fetch quests" },
            { speaker = "J.A.R.F.", text = "Got it! I've added even more fetch quests!" },
        }
    },
}

return dialogSections
