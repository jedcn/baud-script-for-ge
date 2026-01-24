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
-- Core Script and Functions for Playing GE
--

if not gePackage then
  gePackage = {}
end

gePackage.constants = {
  MEN = "Men",
  MISSILES = "Missiles",
  TORPEDOES = "Torpedos",
  ION_CANNONS = "Ion cannons",
  FLUX_PODS = "Flux pods",
  FOOD_CASES = "Food cases",
  FIGHTERS = "Fighters",
  DECOYS = "Decoys",
  TROOPS = "Troops",
  ZIPPERS = "Zippers",
  JAMMERS = "Jammers",
  MINES = "Mines"
}

local debug = true;

--
--  need to better define cecho
--
function cecho(s)
    echo("todo: " .. s)
end

function log(s)
  if debug then
    cecho("\n<red>" .. s .. "<red>")
  end
end

function initializeStateIfNeeded()

  if not gePackage.position then
    gePackage.position = {}
  end
  
  if not gePackage.ship then
    gePackage.ship = {}
  end
  
  if not gePackage.ship.inventory then
    gePackage.ship.inventory = {}
  end

  if not gePackage.stateMachine then
    gePackage.stateMachine = {}
    gePackage.stateMachine.inbetweenDashes = false
    gePackage.stateMachine.scanningPlanet = false
  end
  
end

function setSectorXY(newX, newY)
  log("setSectorXY(" .. newX .. ", " .. newY .. ")")
  initializeStateIfNeeded()
  gePackage.position.xSector = tonumber(newX)
  gePackage.position.ySector = tonumber(newY)
end

function setSectorPositionXY(newX, newY)
  log("setSectorPositionXY(" .. newX .. ", " .. newY .. ")")
  initializeStateIfNeeded()
  gePackage.position.xSectorPosition = tonumber(newX)
  gePackage.position.ySectorPosition = tonumber(newY)
end

function clearOrbitingPlanet()
  log("clearOrbitingPlanet()")
  initializeStateIfNeeded()
  gePackage.position.orbitingPlanet = nil
end

function setOrbitingPlanet(newPlanetNumber)
  log("setOrbitingPlanet(" .. newPlanetNumber .. ")");
  initializeStateIfNeeded()
  gePackage.position.orbitingPlanet = tonumber(newPlanetNumber)
end

function setShipHeading(newHeading)
  log("setHeading(" .. newHeading .. ")");
  initializeStateIfNeeded()
  gePackage.ship.heading = tonumber(newHeading)
end

function getShipHeading()
  log("getShipHeading()");
  initializeStateIfNeeded()
  return gePackage.ship.heading
end

function setShipNeutronFlux(newFluxAmount)
  log("setShipNeutronFlux(" .. newFluxAmount .. ")");
  initializeStateIfNeeded()
  gePackage.ship.neutronFlux = tonumber(newFluxAmount)
end

function getShipNeutronFlux()
  log("getShipNeutronFlux()");
  initializeStateIfNeeded()
  return gePackage.ship.neutronFlux
end

function setShipInventory(itemType, itemCount)
  log("setShipInventory(" .. itemType .. ", " .. itemCount .. ")")
  initializeStateIfNeeded()
  gePackage.ship.inventory[itemType] = tonumber(itemCount)
end

function getShipInventory(itemType)
  log("getShipInventory(" .. itemType .. ")")
  initializeStateIfNeeded()
  return gePackage.ship.inventory[itemType] or 0
end

function clearShipInventory()
  log("clearShipInventory()")
  initializeStateIfNeeded()
  gePackage.ship.inventory = {}
end

function setWarpSpeed(newWarpSpeed)
  log("setWarpSpeed(" .. newWarpSpeed .. ")")
  initializeStateIfNeeded()
  gePackage.warpSpeed = tonumber(newWarpSpeed)
end

function setParseState(stateName, newBoolean)
  log("setParseState(" .. stateName .. ", " .. newBoolean .. ")")
  initializeStateIfNeeded()
  gePackage.parseState.stateName = newBoolean
end

function toggleDashes()
  --log("toggleDashes()")
  initializeStateIfNeeded()
  if gePackage.stateMachine.inbetweenDashes then
    gePackage.stateMachine.inbetweenDashes = false
    gePackage.stateMachine.reportType = nil
    setScanningPlanet(false)
  else
      gePackage.stateMachine.inbetweenDashes = true
  end  
end

function setScanningPlanet(newBoolean)
  --log("setScanningPlanet(" .. tostring(newBoolean) .. ")")
  gePackage.stateMachine.scanningPlanet = newBoolean
  if not newBoolean then
    gePackage.stateMachine.scanningPlanetNumber = nil
    gePackage.stateMachine.scanningPlanetName = nil
  end
end

function getScanningPlanet()
  --log("getScanningPlanet()")
  return gePackage.stateMachine.scanningPlanet
end

function setScanningPlanetNumber(newPlanetNumber)
  log("setScanningPlanetNumber(" .. tostring(newPlanetNumber) .. ")")
  gePackage.stateMachine.scanningPlanetNumber = newPlanetNumber
end

function setScanningPlanetName(newPlanetName)
  log("setScanningPlanetName(" .. newPlanetName .. ")")
  gePackage.stateMachine.newPlanetName = newPlanetName
end

function setReportType(newReportName)
  log("setReportType(" .. newReportName .. ")")
  initializeStateIfNeeded()
  gePackage.stateMachine.reportType = newReportName
end

function doMaint()
  log("doMaint()");
  send("maint arbor123")
end


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

--
-- auto orbit
--
createTrigger("^In gravity pull of planet (\\d+), Helm compensating, Sir!$", function(matches)
    local planetNumber = matches[2]
    send("orbit " .. planetNumber)
end, { type = "regex" })



--
-- auto shields
--
createTrigger("^HELM reports we are leaving HYPERSPACE now, Sir!$", function(matches)
    send("shi up")
end, { type = "regex" })

--
-- Storage Management
--
createTrigger("^Leaving orbit Sir!$", function(matches)
    clearOrbitingPlanet()
end, { type = "regex" })

createTrigger("^We are now in stationary orbit around planet (\\d+)$", function(matches)
    local planetNumber = matches[2]
    setOrbitingPlanet(planetNumber)
end, { type = "regex" })

createTrigger("^Galactic Pos. Xsect:(-?\\d+)\\s+Ysect:(-?\\d+)$", function(matches)
    local xSector = matches[2]
    local ySector = matches[3]
    setSectorXY(xSector, ySector)
end, { type = "regex" })

createTrigger("^Sector Pos. X:(\\d+) Y:(\\d+)$", function(matches)
    local xSectorPosition = matches[2]
    local ySectorPosition = matches[3]
    setSectorPositionXY(xSectorPosition, ySectorPosition)
end, { type = "regex" })

-- sets orbiting planet from status display
createTrigger("^Orbiting Planet........  (\\d+)$", function(matches)
    local planetNumber = matches[2]
    setOrbitingPlanet(planetNumber)
end, { type = "regex" })

-- sets ship heading from status display
createTrigger("^Galactic Heading.......  (-?\\d+)$", function(matches)
    local heading = matches[2]
    setShipHeading(heading)
end, { type = "regex" })

-- sets ship heading from helm message
createTrigger("^Helm reports we are now heading (-?\\d+) degrees.$", function(matches)
    local heading = matches[2]
    setShipHeading(heading)
end, { type = "regex" })

-- sets fighter count (only when not scanning a planet)
createTrigger("^Fighters..................\\s*(\\d+)$", function(matches)
    local fighterCount = matches[2]
    if not getScanningPlanet() then
        setShipInventory("Fighters", fighterCount)
    end
end, { type = "regex" })

-- clears ship inventory when cargo is 0
createTrigger("^Total Cargo Weight... 0 Tons$", function(matches)
    clearShipInventory()
end, { type = "regex" })

-- sets warp speed from helm message
createTrigger("^Helm reports speed is now Warp (\\d+\\.\\d+), Sir!$", function(matches)
    local warpSpeed = matches[2]
    setWarpSpeed(warpSpeed)
end, { type = "regex" })

-- sets warp speed to 0
createTrigger("^Helm reports we are at a dead stop, Sir!$", function(matches)
    setWarpSpeed(0)
end, { type = "regex" })

-- sets sector X/Y coordinates
createTrigger("^Navigating SS# (-?\\d+) (-?\\d+)$", function(matches)
    local xSector = matches[2]
    local ySector = matches[3]
    setSectorXY(xSector, ySector)
end, { type = "regex" })

-- sets warp speed from status display
createTrigger("^Speed..................Warp (\\d+\\.\\d+)$", function(matches)
    local warpSpeed = matches[2]
    setWarpSpeed(warpSpeed)
end, { type = "regex" })

-- sets flux pod count (only when not scanning a planet)
createTrigger("^Flux pods..................\\s*(\\d+)$", function(matches)
    local fluxPodCount = matches[2]
    if not getScanningPlanet() then
        setShipInventory("Flux pods", fluxPodCount)
    end
end, { type = "regex" })

-- sets neutron flux level
createTrigger("^Neutron Flux............ (\\d+)$", function(matches)
    local neutronFlux = matches[2]
    setShipNeutronFlux(neutronFlux)
end, { type = "regex" })

--
-- STATE MACHINE
-- 


-- toggles the state machine for scan parsing
createTrigger("^--------------------------------------$", function(matches)
    toggleDashes()
end, { type = "regex" })

-- sets up planet scanning state
createTrigger("^Scanning Planet (\\d+)\\s*(.*)$", function(matches)
    local planetNumber = matches[2]
    local planetName = matches[3]
    setScanningPlanet(true)
    setScanningPlanetNumber(planetNumber)
    setScanningPlanetName(planetName)
end, { type = "regex" })

-- echoes report type
createTrigger("^Systems Report$", function(matches)
    echo("Systems Report")
end, { type = "regex" })

-- echoes report type
createTrigger("^Inventory Report$", function(matches)
    echo("Inventory Report")
end, { type = "regex" })

-- echoes report type
createTrigger("^Accounting Division report$", function(matches)
    echo("Accounting Division report")
end, { type = "regex" })

-- echoes report type
createTrigger("^Navigational Report$", function(matches)
    echo("Navigational Report")
end, { type = "regex" })


echo("Finishing reading ge-main.lua")