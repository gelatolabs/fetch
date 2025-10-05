local AudioSystem = {}

-- Audio resources
local quackSound = nil
local currentMusic = nil
local musicTracks = {}

-- Initialize audio system
function AudioSystem.init()
    -- Load sound effects
    quackSound = love.audio.newSource("audio/quack.ogg", "static")
    
    -- Load music tracks
    musicTracks.intro = love.audio.newSource("audio/intro.ogg", "stream")
    musicTracks.theme = love.audio.newSource("audio/theme.ogg", "stream")
    musicTracks.themeFunky = love.audio.newSource("audio/theme-funky.ogg", "stream")
    musicTracks.credits = love.audio.newSource("audio/credits.ogg", "stream")
    musicTracks.boss = love.audio.newSource("audio/boss.ogg", "stream")
    musicTracks.glitch = love.audio.newSource("audio/glitch.ogg", "stream")
    musicTracks.lullaby = love.audio.newSource("audio/lullaby.ogg", "stream")
    musicTracks.sailing = love.audio.newSource("audio/sailing.ogg", "stream")
    musicTracks.spooky = love.audio.newSource("audio/spooky.ogg", "stream")
    musicTracks.throneRoom = love.audio.newSource("audio/throne-room.ogg", "stream")

    -- Set all music to loop except credits
    musicTracks.intro:setLooping(true)
    musicTracks.theme:setLooping(true)
    musicTracks.themeFunky:setLooping(true)
    musicTracks.credits:setLooping(false)
    musicTracks.boss:setLooping(true)
    musicTracks.glitch:setLooping(true)
    musicTracks.lullaby:setLooping(true)
    musicTracks.sailing:setLooping(true)
    musicTracks.spooky:setLooping(true)
    musicTracks.throneRoom:setLooping(true)
end

-- Play a music track by name
function AudioSystem.playMusic(trackName)
    local music = musicTracks[trackName]
    if not music then
        print("Warning: Music track '" .. trackName .. "' not found")
        return
    end
    
    if currentMusic == music and music:isPlaying() then
        return
    end

    if currentMusic then
        currentMusic:stop()
    end

    currentMusic = music
    music:play()
end

-- Play quack sound
function AudioSystem.playQuack()
    if quackSound then
        quackSound:play()
    end
end

-- Get music tracks
function AudioSystem.getMusicTracks()
    return musicTracks
end

-- Get current music
function AudioSystem.getCurrentMusic()
    return currentMusic
end

-- Set volume
function AudioSystem.setVolume(volume)
    love.audio.setVolume(volume)
end

return AudioSystem
