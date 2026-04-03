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
createAlias("^setpl(\\d+)$", function(matches)
    setStoredPlanet(matches[2])
    echo("Stored Planet: " .. getStoredPlanet())
end, { type = "regex" })

createAlias("^scapl$", function()
    send("sca pl " .. getStoredPlanet())
end, { type = "regex" })

createAlias("^orbpl$", function()
    send("orb " .. getStoredPlanet())
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

createAlias("chargeBank", function()
    send("buy 500 men arbor123")
    send("tra down 500 men")
end, { type = "regex" })


-- ^reset$ -> resetData()
-- Clears all stored data (use when switching ships)
createAlias("^reset$", function()
    resetData()
    echo("All data has been reset.")
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
-- repair
createAlias("^repair$", function()
    flipAwayFromPlanet()
    doMaint()
end, { type = "regex" })

createAlias("^attack", function()
    send("attack 249980 tro")
    send("imp 99 0")
end, { type = "regex" })

--
-- Assault loop
--
createAlias("^assault$", function()
    startAssault()
end, { type = "regex" })

createAlias("^assault-cancel$", function()
    cancelAssault()
end, { type = "regex" })

createAlias("^assault-status$", function()
    printStatusAssault()
end, { type = "regex" })

-- decoy.launch -> deploy_decoys()
-- Sends the decoy command five times
createAlias("^decoy\\.launch$", function(matches)
    deploy_decoys()
end, { type = "regex" })

-- missile.at <letter> -> missile_at_ship(letter)
-- Fires three missiles at the named ship (with flu between each), then raises shields
createAlias("^missile\\.at ([a-z])$", function(matches)
    local shipLetter = matches[2]
    missile_at_ship(shipLetter)
end, { type = "regex" })

-- torpedo.at <letter> -> torpedo_at_ship(letter)
-- Fires three torpedoes at the named ship, then raises shields
createAlias("^torpedo\\.at ([a-z])$", function(matches)
    local shipLetter = matches[2]
    torpedo_at_ship(shipLetter)
end, { type = "regex" })

-- fire.at <letter> -> fire_phasers_at_ship(letter)
-- Scans the named ship and fires phasers at its bearing
createAlias("^fire\\.at ([a-z])$", function(matches)
    local shipLetter = matches[2]
    fire_phasers_at_ship(shipLetter)
end, { type = "regex" })

-- warp.and.fire.at <letter> -> warp_and_fire_at_ship(letter)
-- Goes to warp 1, fires phasers at the named ship, then drops back to warp 0
createAlias("^warp\\.and\\.fire\\.at ([a-z])$", function(matches)
    local shipLetter = matches[2]
    warp_and_fire_at_ship(shipLetter)
end, { type = "regex" })

-- combat.cancel -> resets combat state machine
createAlias("^combat\\.cancel$", function()
    initCombat()
    echo("[combat] Cancelled - state reset to idle")
end, { type = "regex" })

-- ============================================================================
-- New navigation aliases (nav.to API)
-- ============================================================================

-- nav.to <N>  →  navToPlanet(N)
-- Navigate to planet N (1-9) in the current sector
createAlias("^nav\\.to ([1-9])$", function(matches)
    local planetNumber = tonumber(matches[2])
    navToPlanet(planetNumber)
end, { type = "regex" })

-- nav.to <letter>  →  navToShip(letter)
-- Scan ship <letter>, get its bearing, and move toward it
createAlias("^nav\\.to ([a-z])$", function(matches)
    local shipLetter = matches[2]
    navToShip(shipLetter)
end, { type = "regex" })

-- nav.to <X> <Y>  →  navToSector(X, Y)
-- Navigate to sector X,Y arriving at center (5000, 5000)
-- Sector range: -1000 to 1000
createAlias("^nav\\.to (-?\\d+) (-?\\d+)$", function(matches)
    local sectorX = tonumber(matches[2])
    local sectorY = tonumber(matches[3])
    navToSector(sectorX, sectorY)
end, { type = "regex" })

-- nav.to <X> <Y> <N>  →  navToSectorAndPlanet(X, Y, N)
-- Navigate to sector X,Y then orbit planet N (1-9)
createAlias("^nav\\.to (-?\\d+) (-?\\d+) ([1-9])$", function(matches)
    local sectorX      = tonumber(matches[2])
    local sectorY      = tonumber(matches[3])
    local planetNumber = tonumber(matches[4])
    navToSectorAndPlanet(sectorX, sectorY, nil, nil, planetNumber)
end, { type = "regex" })

-- nav.to <X> <Y> <posX> <posY>  →  navToSector(X, Y, posX, posY)
-- Navigate to sector X,Y arriving at in-sector position posX,posY
createAlias("^nav\\.to (-?\\d+) (-?\\d+) (\\d+) (\\d+)$", function(matches)
    local sectorX = tonumber(matches[2])
    local sectorY = tonumber(matches[3])
    local posX    = tonumber(matches[4])
    local posY    = tonumber(matches[5])
    navToSector(sectorX, sectorY, posX, posY)
end, { type = "regex" })

-- nav.to <X> <Y> <posX> <posY> <N>  →  navToSectorAndPlanet(X, Y, posX, posY, N)
-- Navigate to sector X,Y at posX,posY then orbit planet N (1-9)
createAlias("^nav\\.to (-?\\d+) (-?\\d+) (\\d+) (\\d+) ([1-9])$", function(matches)
    local sectorX      = tonumber(matches[2])
    local sectorY      = tonumber(matches[3])
    local posX         = tonumber(matches[4])
    local posY         = tonumber(matches[5])
    local planetNumber = tonumber(matches[6])
    navToSectorAndPlanet(sectorX, sectorY, posX, posY, planetNumber)
end, { type = "regex" })

-- flip.away  →  flipAwayFromPlanet()
-- Rotate so the orbited planet is at bearing 180 (directly behind)
createAlias("^flip\\.away$", function()
    flipAwayFromPlanet()
end, { type = "regex" })

-- rot.to <N>  →  rotateToHeading(N)
-- Rotate to absolute heading N
createAlias("^rot\\.to (\\d+)$", function(matches)
    local heading = tonumber(matches[2])
    rotateToHeading(heading)
end, { type = "regex" })

-- nav.cancel  →  cancelAllNavigation()
createAlias("^nav\\.cancel$", function()
    cancelAllNavigation()
end, { type = "regex" })

-- nav.status  →  getAllNavigationStatusText()
createAlias("^nav\\.status$", function()
    cecho("green", getAllNavigationStatusText())
end, { type = "regex" })