--
-- ge-aliases.lua
--
-- All aliases for GE
--

--
-- Make it so that..
--
--   scapl1 -> sca pl 1
--   scapl2 -> sca pl 2
--   scapl3 -> sca pl 3
--
createAlias("^scapl(\\d+)$", function(matches)
    local planetToScan = matches[2]
    send("sca pl " .. planetToScan)
end, { type = "regex" })

--
-- Make it so that
--
-- setpl1
--
-- Stores "1" as the planet you're tracking and later on,
--
-- scapl -> sca pl 1
-- orbpl -> orb 1
--
local storedPlanet = 1
createAlias("^setpl(\\d+)$", function(matches)
    storedPlanet = tonumber(matches[2])
    echo("Stored Planet: " .. storedPlanet)
end, { type = "regex" })

createAlias("^scapl$", function()
    send("sca pl " .. storedPlanet)
end, { type = "regex" })

createAlias("^orbpl$", function()
    send("orb " .. storedPlanet)
end, { type = "regex" })
