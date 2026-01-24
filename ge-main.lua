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
-- When you see:
--
-- ^In gravity pull of planet (\d+), Helm compensating, Sir!$
--
-- Then:
-- 
-- send("orbit " .. matches[2])
--


--
-- auto shields
--
-- When you see:
--
-- HELM reports we are leaving HYPERSPACE now, Sir!
--
-- Then:
-- 
-- send("shi up")
--

--
-- Storage Management
--
-- 
-- ^Leaving orbit Sir!$ -> clearOrbitingPlanet()

--
-- We are now in stationary orbit around planet (\d+) -> setOrbitingPlanet(matches[2])
--

--
-- ^Galactic Pos. Xsect:(-?\d+)\s+Ysect:(-?\d+)$ ->
--
-- local xSector = matches[2]
-- local ySector = matches[3]
-- setSectorXY(xSector, ySector)
--

--
-- ^Sector Pos. X:(\d+) Y:(\d+)$ ->
--
-- local xSectorPosition = matches[2]
-- local ySectorPosition = matches[3]
-- setSectorPositionXY(xSectorPosition, ySectorPosition)
--

--
--
-- Orbiting Planet........  (\d+)
--
-- setOrbitingPlanet(matches[2])

--
--  Galactic Heading.......  (-?\d+)
--
-- 
-- setShipHeading(matches[2])

-- 
-- Helm reports we are now heading (-?\d+) degrees.
-- 
-- setShipHeading(matches[2])

--
-- Fighters..................\s*(\d+)
--
-- if not getScanningPlanet() then
--   setShipInventory("Fighters", matches[2])
-- end

-- 
-- Total Cargo Weight... 0 Tons
-- 
-- clearShipInventory()

--
-- Helm reports speed is now Warp (\d+\.\d+), Sir!
--
-- setWarpSpeed(matches[2])

--
-- Helm reports we are at a dead stop, Sir!
--
-- setWarpSpeed(0)

-- 
-- Navigating SS# (-?\d+) (-?\d+)
-- 
-- local xSector = matches[2]
-- local ySector = matches[3]
-- setSectorXY(xSector, ySector)

--
-- ^Speed..................Warp (\d+\.\d+)$
--
-- setWarpSpeed(matches[2])

-- 
-- Flux pods..................\s*(\d+)
-- 
-- if not getScanningPlanet() then
--   setIShipnventory("Flux pods", matches[2])
-- end

-- 
-- Neutron Flux............ (\d+)
-- 
-- setShipNeutronFlux(matches[2])

--
-- STATE MACHINE
-- 


--
-- ^--------------------------------------$
--
-- toggleDashes() (should be called startingOrStoppingScan?)
--

--
-- Scanning Planet (\d+)\s*(.*)
--
-- local planetNumber = matches[2]
-- local planetName = matches[3]
-- setScanningPlanet(true)
-- setScanningPlanetNumber(planetNumber)
-- setScanningPlanetName(planetName)

--
-- Systems Report -> echo("Systems Report")
--

--
-- Inventory Report -> echo("Inventory Report")
--

--
-- Accounting Division report -> echo("Accounting Division report")
--

--
-- Navigational Report -> echo("Navigational Report")
--


echo("Finishing reading ge-main.lua")