--
-- This file contains Baud aliases.
--
-- They are [defined here](https://github.com/jedcn/baud?tab=readme-ov-file#createaliaspattern-callback-options)
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


--
-- ^rs$ -> rep sys
--
createAlias("^rs$", function()
    send("rep sys")
end, { type = "regex" })

-- 
-- ^ri$ -> rep inv
--
createAlias("^ri$", function()
    send("rep inv")
end, { type = "regex" })

-- 
-- ^ra$ -> rep acc
--
createAlias("^ra$", function()
    send("rep acc")
end, { type = "regex" })

-- ^maint$ ->
--   doMaint()
--
createAlias("^maint$", function()
    doMaint()
end, { type = "regex" })

--
-- ^rn$ -> rep nav
--
createAlias("^rn$", function()
    send("rep nav")
end, { type = "regex" })

--
-- ^sp$ -> scapl
--
createAlias("^sp$", function()
    send("scapl")
end, { type = "regex" })

--
-- ^ss$ -> sca se
--
createAlias("^ss$", function()
    send("sca se")
end, { type = "regex" })

--
-- ^tufg$ ->
--   send("tra up 33333 fighters")
--   send("war 4 0")
--
createAlias("^tufg$", function()
    send("tra up 33333 fighters")
    send("war 4 0")
end, { type = "regex" })

-- ^afg$ ->
--   send("attack 33333 fighters")
--   send("imp 99 0")
--
createAlias("^afg$", function()
    send("attack 33333 fighters")
    send("imp 99 0")
end, { type = "regex" })

-- ^tuff$ ->
--   send("tra up 1 flux")
--   send("flux")
--
createAlias("^tuff$", function()
    send("tra up 1 flux")
    send("flux")
end, { type = "regex" })