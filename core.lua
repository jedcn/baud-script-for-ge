--
-- This file contains lua functions that will be available for aliases.lua and triggers.lua
--
if not gePackage then
  gePackage = {}
  gePackage.debug = true
  gePackage.position = {}
  gePackage.ship = {}
  gePackage.ship.inventory = {}
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

function toggleDebug()
  gePackage.debug = not gePackage.debug
end

function log(s)
  if gePackage.debug then
    cecho("#ff00ff", s)
  end
end

function setSector(newX, newY)
  log("setSector(" .. newX .. ", " .. newY .. ")")
  gePackage.position.sectorX = tonumber(newX)
  gePackage.position.sectorY = tonumber(newY)
end

function getSector()
  return gePackage.position.sectorX, gePackage.position.sectorY
end

function setSectorPosition(newX, newY)
  log("setSectorPosition(" .. newX .. ", " .. newY .. ")")
  gePackage.position.sectorPositionX = tonumber(newX)
  gePackage.position.sectorPositionY = tonumber(newY)
end

function getSectorPosition()
  return gePackage.position.sectorPositionX, gePackage.position.sectorPositionY
end

function clearOrbitingPlanet()
  log("clearOrbitingPlanet()")
  gePackage.position.orbitingPlanet = nil
end

function setOrbitingPlanet(newPlanetNumber)
  log("setOrbitingPlanet(" .. newPlanetNumber .. ")");
  gePackage.position.orbitingPlanet = tonumber(newPlanetNumber)
end

function getOrbitingPlanet()
  return gePackage.position.orbitingPlanet
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

function setShipStatus(newStatus)
  log("setShipSatus(" .. newStatus .. ")")
  gePackage.ship.status = newStatus
end

function getShipStatus()
  return gePackage.ship.status
end

function setWarpSpeed(newWarpSpeed)
  gePackage.warpSpeed = tonumber(newWarpSpeed)
end

function getWarpSpeed()
  return gePackage.warpSpeed
end

function setShieldStatus(newStatus)
  log("setShieldStatus(" .. newStatus .. ")")
  gePackage.shieldStatus = newStatus
end

function getShieldStatus()
  return gePackage.shieldStatus
end

function setShieldCharge(newShieldCharge)
  log("setShieldCharge(" .. newShieldCharge .. ")")
  gePackage.shieldCharge = tonumber(newShieldCharge)
end

function getShieldCharge()
  return gePackage.shieldCharge
end

function setParseState(stateName, newBoolean)
  log("setParseState(" .. stateName .. ", " .. newBoolean .. ")")
  gePackage.parseState.stateName = newBoolean
end

function doMaint()
  log("doMaint()");
  send("maint arbor123")
end