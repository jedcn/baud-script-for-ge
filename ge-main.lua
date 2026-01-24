--
-- ge-main.lua
--

--
-- This script will be read by [baud](https://github.com/jedcn/baud).
--
-- It defines Aliases, Triggers, and lua functions that can be invoked
-- via /lua inside a running session of baud.
--
echo("Starting to read ge-main.lua")

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

--
-- When you see:
--
-- (N)onstop, (Q)uit, or (C)ontinue
--
-- You should send "N" and gag it?
--
-- This is not working right now.
--
createTrigger("^\\(N\\)onstop, \\(Q\\)uit, or \\(C\\)ontinue\\?$", function(matches)
    send("n")
end, { type = "regex" })

echo("Finishing reading ge-main.lua")