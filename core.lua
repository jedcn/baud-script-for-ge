--
-- This file contains lua functions that will be available for aliases.lua and triggers.lua
--
if not gePackage then
  gePackage = {}
  gePackage.debug = false
  gePackage.position = {}
  gePackage.ship = {}
  gePackage.ship.rotationInProgress = false
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

function debugLog(s)
  if gePackage.debug then
    cecho("gray", s)
  end
end

function setSector(newX, newY)
  debugLog("setSector(" .. newX .. ", " .. newY .. ")")
  gePackage.position.sectorX = tonumber(newX)
  gePackage.position.sectorY = tonumber(newY)
end

function getSector()
  return gePackage.position.sectorX, gePackage.position.sectorY
end

function setSectorPosition(newX, newY)
  debugLog("setSectorPosition(" .. newX .. ", " .. newY .. ")")
  gePackage.position.sectorPositionX = tonumber(newX)
  gePackage.position.sectorPositionY = tonumber(newY)
end

function getSectorPosition()
  return gePackage.position.sectorPositionX, gePackage.position.sectorPositionY
end

function clearOrbitingPlanet()
  debugLog("clearOrbitingPlanet()")
  gePackage.position.orbitingPlanet = nil
end

function setOrbitingPlanet(newPlanetNumber)
  debugLog("setOrbitingPlanet(" .. newPlanetNumber .. ")");
  gePackage.position.orbitingPlanet = tonumber(newPlanetNumber)
end

function getOrbitingPlanet()
  return gePackage.position.orbitingPlanet
end

function setShipHeading(newHeading)
  debugLog("setShipHeading(" .. tostring(newHeading) .. ")")
  gePackage.ship.heading = newHeading and tonumber(newHeading) or nil
end

function getShipHeading()
  return gePackage.ship.heading
end

function setRotationInProgress(inProgress)
  debugLog("setRotationInProgress(" .. tostring(inProgress) .. ")")
  gePackage.ship.rotationInProgress = inProgress
end

function getRotationInProgress()
  return gePackage.ship.rotationInProgress
end

function setShipNeutronFlux(newFluxAmount)
  debugLog("setShipNeutronFlux(" .. newFluxAmount .. ")");
  gePackage.ship.neutronFlux = tonumber(newFluxAmount)
end

function getShipNeutronFlux()
  debugLog("getShipNeutronFlux()");
  return gePackage.ship.neutronFlux
end

function setShipInventory(itemType, itemCount)
  debugLog("setShipInventory(" .. itemType .. ", " .. itemCount .. ")")
  gePackage.ship.inventory[itemType] = tonumber(itemCount)
end

function getShipInventory(itemType)
  debugLog("getShipInventory(" .. itemType .. ")")
  return gePackage.ship.inventory[itemType] or 0
end

function clearShipInventory()
  debugLog("clearShipInventory()")
  gePackage.ship.inventory = {}
end

function setShipStatus(newStatus)
  debugLog("setShipSatus(" .. newStatus .. ")")
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
  debugLog("setShieldStatus(" .. newStatus .. ")")
  gePackage.shieldStatus = newStatus
end

function getShieldStatus()
  return gePackage.shieldStatus
end

function setShieldCharge(newShieldCharge)
  debugLog("setShieldCharge(" .. newShieldCharge .. ")")
  gePackage.shieldCharge = tonumber(newShieldCharge)
end

function getShieldCharge()
  return gePackage.shieldCharge
end

function setStoredPlanet(planetNumber)
  debugLog("setStoredPlanet(" .. tostring(planetNumber) .. ")")
  gePackage.storedPlanet = tonumber(planetNumber)
end

function getStoredPlanet()
  return gePackage.storedPlanet or 1
end

function doMaint()
  debugLog("doMaint()");
  send("maint arbor123")
end

function printState()
  local sX, sY = getSector()
  local spX, spY = getSectorPosition()
  local itemTypes = {}
  for _, v in pairs(gePackage.constants) do
    table.insert(itemTypes, v)
  end
  table.sort(itemTypes)
  local inventoryRows = {}
  for _, itemType in ipairs(itemTypes) do
    table.insert(inventoryRows, {"getShipInventory[" .. itemType .. "]", tostring(getShipInventory(itemType))})
  end

  local sections = {
    {"Navigation", {
      {"getOrbitingPlanet",     tostring(getOrbitingPlanet())},
      {"getRotationInProgress", tostring(getRotationInProgress())},
      {"getSector",             tostring(sX) .. ", " .. tostring(sY)},
      {"getSectorPosition",     tostring(spX) .. ", " .. tostring(spY)},
      {"getWarpSpeed",          tostring(getWarpSpeed())},
    }},
    {"Ship", {
      {"getShieldCharge",    tostring(getShieldCharge())},
      {"getShieldStatus",    tostring(getShieldStatus())},
      {"getShipHeading",     tostring(getShipHeading())},
      {"getShipNeutronFlux", tostring(getShipNeutronFlux())},
      {"getShipStatus",      tostring(getShipStatus())},
    }},
    {"Misc", {
      {"getStoredPlanet", tostring(getStoredPlanet())},
    }},
    {"Inventory", inventoryRows},
  }

  local maxLen = 0
  for _, section in ipairs(sections) do
    for _, row in ipairs(section[2]) do
      if #row[1] > maxLen then maxLen = #row[1] end
    end
  end

  for i, section in ipairs(sections) do
    local header = i > 1 and "\n## " .. section[1] or "## " .. section[1]
    echo(header)
    for _, row in ipairs(section[2]) do
      echo(string.format("%-" .. maxLen .. "s  %s", row[1], row[2]))
    end
  end
end