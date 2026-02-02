--
-- This file contains lua functions that will be available for aliases.lua and triggers.lua
--
if not gePackage then
  gePackage = {}
  gePackage.position = {}
  gePackage.ship = {}
  gePackage.ship.inventory = {}
  gePackage.stateMachine = {}
  gePackage.stateMachine.inbetweenDashes = false
  gePackage.stateMachine.scanningPlanet = false
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


function setSectorXY(newX, newY)
  log("setSectorXY(" .. newX .. ", " .. newY .. ")")
  gePackage.position.xSector = tonumber(newX)
  gePackage.position.ySector = tonumber(newY)
end

function setSectorPositionXY(newX, newY)
  log("setSectorPositionXY(" .. newX .. ", " .. newY .. ")")
  gePackage.position.xSectorPosition = tonumber(newX)
  gePackage.position.ySectorPosition = tonumber(newY)
end

function clearOrbitingPlanet()
  log("clearOrbitingPlanet()")
  gePackage.position.orbitingPlanet = nil
end

function setOrbitingPlanet(newPlanetNumber)
  log("setOrbitingPlanet(" .. newPlanetNumber .. ")");
  gePackage.position.orbitingPlanet = tonumber(newPlanetNumber)
end

function setShipHeading(newHeading)
  log("setHeading(" .. newHeading .. ")");
  gePackage.ship.heading = tonumber(newHeading)
end

function getShipHeading()
  return gePackage.ship.heading
end

function setShipNeutronFlux(newFluxAmount)
  log("setShipNeutronFlux(" .. newFluxAmount .. ")");
  gePackage.ship.neutronFlux = tonumber(newFluxAmount)
end

function getShipNeutronFlux()
  log("getShipNeutronFlux()");
  return gePackage.ship.neutronFlux
end

function setShipInventory(itemType, itemCount)
  log("setShipInventory(" .. itemType .. ", " .. itemCount .. ")")
  gePackage.ship.inventory[itemType] = tonumber(itemCount)
end

function getShipInventory(itemType)
  log("getShipInventory(" .. itemType .. ")")
  return gePackage.ship.inventory[itemType] or 0
end

function clearShipInventory()
  log("clearShipInventory()")
  gePackage.ship.inventory = {}
end

function setWarpSpeed(newWarpSpeed)
  gePackage.warpSpeed = tonumber(newWarpSpeed)
end

function getWarpSpeed()
  return gePackage.warpSpeed
end

function setShieldCharge(newShieldCharge)
  log("setShieldCharge(" .. newShieldCharge .. ")")
  gePackage.shieldCharge = tonumber(newShieldCharge)
end

function setParseState(stateName, newBoolean)
  log("setParseState(" .. stateName .. ", " .. newBoolean .. ")")
  gePackage.parseState.stateName = newBoolean
end

function toggleDashes()
  --log("toggleDashes()")
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
  gePackage.stateMachine.reportType = newReportName
end

function doMaint()
  log("doMaint()");
  send("maint arbor123")
end

function statusPrompt()
  local shipHeading = getShipHeading() or "?"
  local warpSpeed = getWarpSpeed() or "?"

  local segments = {
    { text = "Sector: " .. gePackage.position.xSector .. "," .. gePackage.position.ySector},
    { text = "(x,y): (" .. gePackage.position.xSectorPosition .. ", " .. gePackage.position.ySectorPosition .. ")"},
    { text = "Heading: " .. shipHeading },
    { text = "Warp: " .. warpSpeed },
  }
  return segments
end

setStatus(statusPrompt)
