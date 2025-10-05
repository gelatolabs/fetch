-- Dialog Script
-- Array of speaker + text pairs for the chat UI

local dialogScript = {
    -- SCRIPTED DIALOG
    -- Trigger when quest_defeat_geese is active
    { speaker = "J.A.R.F.", text = "Ugh, the system isn't ready yet. They haven't unlocked combat. Who designed this mess? "},
    { speaker = "Developer", text = "I told you to do it though."},
    { speaker = "J.A.R.F.", text = "They don't even have a weapon yet, they haven't picked a class!" },
    { speaker = "Developer", text = "Just give them a gun."},
    { speaker = "J.A.R.F.", text = "A gun! How will I implement hit boxes? This is too much work. I'll just give him the feathers." },
    { speaker = "Developer", text = "Fine, we'll add combat in the next update."},
    -- Trigger when quest_learn_to_swim is active
    { speaker = "J.A.R.F.", text = "Oh shoot. We didn't figure out how to code swimming in." },
    { speaker = "Developer", text = "Um. Let's see if we can figure this out."},

    -- DEBUG DIALOG
    { speaker = "Developer", text = "generate a really sick rpg with lots of cool quests" },
    { speaker = "J.A.R.F.", text = "Here you go! I've added a wide variety of engaging quests!" },
    { speaker = "Developer", text = "why are they all fetch quests" },
    { speaker = "J.A.R.F.", text = "Got it! I've added even more fetch quests!" },
}

return dialogScript
