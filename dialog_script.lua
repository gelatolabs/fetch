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
            { speaker = "Developer", text = "... At least give them some gold."},
            { speaker = "J.A.R.F.", text = "That seems like a good idea! I gave the player 3500 gold."},
        }
    },

    talk_to_glitch = {
        event = "talk_to_glitch",  -- Triggered when learning to jump
        autoPlay = true,
        closeAfter = 5.0,
        messages = {
            {speaker = "Developer", text = "What happened to Fred?"},
            { speaker = "J.A.R.F.", text = "The “#%$Hu34”dfhsjidf9 character is functioning at slightly below normal levels." },
            { speaker = "Developer", text = "I think this is a lot worse than normal."},
            {speaker = "J.A.R.F.", text="He's not an important character so his parameters for functioning are pretty wide."},
            { speaker = "Developer", text = "Whatever, as long as he can still give his quest I guess it's good enough."},
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
    
    mapwest_entry = {
        event = "mapwest_entry",  -- Triggered when entering mapwest
        autoPlay = true,
        closeAfter = 3.0,
        messages = {
            { speaker = "J.A.R.F.", text = "Welcome to the western region!" },
            { speaker = "Developer", text = "Why are there so many trees here?" },
            { speaker = "J.A.R.F.", text = "You're right! There are a lot of trees here! You asked me to put a forest here, so I did." },
            { speaker = "Developer", text = "But the player character clips into one when they enter the map." },
            { speaker = "J.A.R.F.", text = "Didn't you tell me you were a tree hugger?" },
            { speaker = "Developer", text = "Hey player, you should just leave while I fix this mess. (Press 'E')" },
        }
    },

    talk_to_glitch = {
        event = "talk_to_glitch",
        autoPlay = true,
        closeAfter = 3.0,
        messages = {
            { speaker = "Developer", text = "What happened to Fred" },
            { speaker = "J.A.R.F.", text = "The \"#%$Hu34\"dfhsjidf9 character is functioning at slightly below normal levels." },
            { speaker = "Developer", text = "I think this is a lot worse than normal."},
            { speaker = "J.A.R.F.", text=" He's not an important character so his parameters for functioning are pretty wide."},
            { speaker = "Developer", text = "This game is buggy as hell."},
            { speaker = "J.A.R.F.", text = "You're right! The display is acting up a bit. I've fixed it now so it scans more."},
            { speaker = "Developer", text = "Whatever, this entire thing is a mess. Player, try checking the bottom left of the first map. That should be where the item you need is."},
        }
    },
}

return dialogSections
