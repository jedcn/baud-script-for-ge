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

function setShieldCharge(newShieldCharge)
  log("setShieldCharge(" .. newShieldCharge .. ")")
  initializeStateIfNeeded()
  gePackage.shieldCharge = tonumber(newShieldCharge)
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
