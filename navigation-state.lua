-- navigation-state.lua
-- State management for navigation state machines
--
-- This file provides setters and getters for:
-- 1. gePackage.navigation - Coordinate and planet navigation
-- 2. gePackage.flipAway - Flip-away maneuver from planet
-- 3. gePackage.rotto - Rotate to heading
-- 4. gePackage.sectorNav - Inter-sector navigation

-- ============================================================================
-- Navigation State (coordinate/planet navigation)
-- ============================================================================

function initNavigation()
  if not gePackage.navigation then
    gePackage.navigation = {}
  end
  gePackage.navigation.active = false
  gePackage.navigation.phase = nil
  gePackage.navigation.state = "idle"
  gePackage.navigation.target = {}
  gePackage.navigation.navigationStart = nil
  gePackage.navigation.lastPositionCheck = 0
  gePackage.navigation.lastPositionUpdate = 0
  gePackage.navigation.lastCommand = 0
  gePackage.navigation.lastScanUpdate = 0
  gePackage.navigation.targetHeading = nil
  gePackage.navigation.targetSpeed = nil
  gePackage.navigation.lastObservedSpeed = nil
  gePackage.navigation.lastSpeedChange = nil
  gePackage.navigation.planetScan = { bearing = nil, distance = nil }
end

function getNavigationActive()
  return gePackage.navigation and gePackage.navigation.active or false
end

function setNavigationActive(active)
  if gePackage.navigation then
    gePackage.navigation.active = active
  end
end

function getNavigationPhase()
  return gePackage.navigation and gePackage.navigation.phase
end

function setNavigationPhase(phase)
  if gePackage.navigation then
    gePackage.navigation.phase = phase
  end
end

function getNavigationState()
  return gePackage.navigation and gePackage.navigation.state
end

function setNavigationState(state)
  if gePackage.navigation then
    gePackage.navigation.state = state
  end
end

function getNavigationTarget()
  if gePackage.navigation and gePackage.navigation.target then
    return gePackage.navigation.target
  end
  return {}
end

function setNavigationTargetCoordinates(x, y)
  if gePackage.navigation then
    if not gePackage.navigation.target then
      gePackage.navigation.target = {}
    end
    gePackage.navigation.target.sectorPositionX = tonumber(x)
    gePackage.navigation.target.sectorPositionY = tonumber(y)
  end
end

function setNavigationTargetPlanet(planetNumber)
  if gePackage.navigation then
    if not gePackage.navigation.target then
      gePackage.navigation.target = {}
    end
    gePackage.navigation.target.planetNumber = tonumber(planetNumber)
  end
end

function getNavigationTargetPlanet()
  if gePackage.navigation and gePackage.navigation.target then
    return gePackage.navigation.target.planetNumber
  end
  return nil
end

function getNavigationLastCommand()
  return gePackage.navigation and gePackage.navigation.lastCommand or 0
end

function setNavigationLastCommand(time)
  if gePackage.navigation then
    gePackage.navigation.lastCommand = time
  end
end

function getNavigationLastPositionUpdate()
  return gePackage.navigation and gePackage.navigation.lastPositionUpdate or 0
end

function setNavigationLastPositionUpdate(time)
  if gePackage.navigation then
    gePackage.navigation.lastPositionUpdate = time
  end
end

function getNavigationLastPositionCheck()
  return gePackage.navigation and gePackage.navigation.lastPositionCheck or 0
end

function setNavigationLastPositionCheck(time)
  if gePackage.navigation then
    gePackage.navigation.lastPositionCheck = time
  end
end

function getNavigationLastScanUpdate()
  return gePackage.navigation and gePackage.navigation.lastScanUpdate or 0
end

function setNavigationLastScanUpdate(time)
  if gePackage.navigation then
    gePackage.navigation.lastScanUpdate = time
  end
end

function getNavigationStart()
  return gePackage.navigation and gePackage.navigation.navigationStart
end

function setNavigationStart(time)
  if gePackage.navigation then
    gePackage.navigation.navigationStart = time
  end
end

function getNavigationTargetHeading()
  return gePackage.navigation and gePackage.navigation.targetHeading
end

function setNavigationTargetHeading(heading)
  if gePackage.navigation then
    gePackage.navigation.targetHeading = heading
  end
end

function getNavigationTargetSpeed()
  return gePackage.navigation and gePackage.navigation.targetSpeed
end

function setNavigationTargetSpeed(speed)
  if gePackage.navigation then
    gePackage.navigation.targetSpeed = speed
  end
end

function getNavigationLastObservedSpeed()
  return gePackage.navigation and gePackage.navigation.lastObservedSpeed
end

function setNavigationLastObservedSpeed(speed)
  if gePackage.navigation then
    gePackage.navigation.lastObservedSpeed = speed
  end
end

function getNavigationLastSpeedChange()
  return gePackage.navigation and gePackage.navigation.lastSpeedChange
end

function setNavigationLastSpeedChange(time)
  if gePackage.navigation then
    gePackage.navigation.lastSpeedChange = time
  end
end

function getNavigationPlanetScan()
  if gePackage.navigation and gePackage.navigation.planetScan then
    return gePackage.navigation.planetScan.bearing, gePackage.navigation.planetScan.distance
  end
  return nil, nil
end

function setNavigationPlanetScanBearing(bearing)
  if gePackage.navigation then
    if not gePackage.navigation.planetScan then
      gePackage.navigation.planetScan = {}
    end
    gePackage.navigation.planetScan.bearing = tonumber(bearing)
  end
end

function setNavigationPlanetScanDistance(distance)
  if gePackage.navigation then
    if not gePackage.navigation.planetScan then
      gePackage.navigation.planetScan = {}
    end
    gePackage.navigation.planetScan.distance = tonumber(distance)
  end
end

function clearNavigationPlanetScan()
  if gePackage.navigation and gePackage.navigation.planetScan then
    gePackage.navigation.planetScan.bearing = nil
    gePackage.navigation.planetScan.distance = nil
  end
end

function clearNavigation()
  if gePackage.navigation then
    gePackage.navigation.active = false
    gePackage.navigation.phase = nil
    gePackage.navigation.state = "idle"
    gePackage.navigation.target = {}
    gePackage.navigation.targetHeading = nil
    gePackage.navigation.targetSpeed = nil
    gePackage.navigation.lastObservedSpeed = nil
    gePackage.navigation.lastSpeedChange = nil
    if gePackage.navigation.planetScan then
      gePackage.navigation.planetScan.bearing = nil
      gePackage.navigation.planetScan.distance = nil
    end
  end
end

-- ============================================================================
-- Flip Away State (flip-away maneuver from planet)
-- ============================================================================

function initFlipAway(planetNumber)
  gePackage.flipAway = {
    active = true,
    state = "fa_scanning_initial",  -- Skip verification since we trust getOrbitingPlanet()
    planetNumber = tonumber(planetNumber),
    initialBearing = nil,
    finalBearing = nil,
    lastCommand = os.time(),
    lastBearingUpdate = 0
  }
end

function getFlipAwayActive()
  return gePackage.flipAway and gePackage.flipAway.active or false
end

function setFlipAwayActive(active)
  if gePackage.flipAway then
    gePackage.flipAway.active = active
  end
end

function getFlipAwayState()
  return gePackage.flipAway and gePackage.flipAway.state
end

function setFlipAwayState(state)
  if gePackage.flipAway then
    gePackage.flipAway.state = state
  end
end

function getFlipAwayPlanetNumber()
  return gePackage.flipAway and gePackage.flipAway.planetNumber
end

function getFlipAwayInitialBearing()
  return gePackage.flipAway and gePackage.flipAway.initialBearing
end

function setFlipAwayInitialBearing(bearing)
  if gePackage.flipAway then
    gePackage.flipAway.initialBearing = tonumber(bearing)
    gePackage.flipAway.lastBearingUpdate = os.time()
  end
end

function getFlipAwayFinalBearing()
  return gePackage.flipAway and gePackage.flipAway.finalBearing
end

function setFlipAwayFinalBearing(bearing)
  if gePackage.flipAway then
    gePackage.flipAway.finalBearing = tonumber(bearing)
    gePackage.flipAway.lastBearingUpdate = os.time()
  end
end

function getFlipAwayLastCommand()
  return gePackage.flipAway and gePackage.flipAway.lastCommand or 0
end

function setFlipAwayLastCommand(time)
  if gePackage.flipAway then
    gePackage.flipAway.lastCommand = time
  end
end

function getFlipAwayLastBearingUpdate()
  return gePackage.flipAway and gePackage.flipAway.lastBearingUpdate or 0
end

function getFlipAwayRotationComplete()
  return gePackage.flipAway and gePackage.flipAway.rotationComplete or false
end

function setFlipAwayRotationComplete(complete)
  if gePackage.flipAway then
    gePackage.flipAway.rotationComplete = complete
  end
end

function clearFlipAway()
  if gePackage.flipAway then
    gePackage.flipAway.active = false
  end
  gePackage.flipAway = nil
end

-- ============================================================================
-- Rotto State (rotate to heading)
-- ============================================================================

function initRotto(targetHeading)
  gePackage.rotto = {
    active = true,
    state = "rotto_probing",
    targetHeading = tonumber(targetHeading),
    lastCommand = os.time(),
    rotationComplete = false
  }
end

function getRottoActive()
  return gePackage.rotto and gePackage.rotto.active or false
end

function setRottoActive(active)
  if gePackage.rotto then
    gePackage.rotto.active = active
  end
end

function getRottoState()
  return gePackage.rotto and gePackage.rotto.state
end

function setRottoState(state)
  if gePackage.rotto then
    gePackage.rotto.state = state
  end
end

function getRottoTargetHeading()
  return gePackage.rotto and gePackage.rotto.targetHeading
end

function getRottoLastCommand()
  return gePackage.rotto and gePackage.rotto.lastCommand or 0
end

function setRottoLastCommand(time)
  if gePackage.rotto then
    gePackage.rotto.lastCommand = time
  end
end

function getRottoRotationComplete()
  return gePackage.rotto and gePackage.rotto.rotationComplete or false
end

function setRottoRotationComplete(complete)
  if gePackage.rotto then
    gePackage.rotto.rotationComplete = complete
  end
end

function clearRotto()
  if gePackage.rotto then
    gePackage.rotto.active = false
  end
  gePackage.rotto = nil
end

-- ============================================================================
-- Sector Nav State (inter-sector navigation)
-- ============================================================================

function initSectorNav(targetSectorX, targetSectorY, targetPosX, targetPosY)
  gePackage.sectorNav = {
    active = true,
    state = "sec_awaiting_position",  -- Start awaiting since navigateToSector() already sends rep nav
    targetSectorX = tonumber(targetSectorX),
    targetSectorY = tonumber(targetSectorY),
    targetPosX = tonumber(targetPosX),
    targetPosY = tonumber(targetPosY),
    lastCommand = os.time(),
    lastPositionUpdate = 0,
    targetHeading = nil,
    rotationComplete = false,
    targetSpeed = nil,
    lastObservedSpeed = nil,
    lastSpeedChange = nil
  }
end

function getSectorNavActive()
  return gePackage.sectorNav and gePackage.sectorNav.active or false
end

function setSectorNavActive(active)
  if gePackage.sectorNav then
    gePackage.sectorNav.active = active
  end
end

function getSectorNavState()
  return gePackage.sectorNav and gePackage.sectorNav.state
end

function setSectorNavState(state)
  if gePackage.sectorNav then
    gePackage.sectorNav.state = state
  end
end

function getSectorNavTarget()
  if gePackage.sectorNav then
    return {
      sectorX = gePackage.sectorNav.targetSectorX,
      sectorY = gePackage.sectorNav.targetSectorY,
      posX = gePackage.sectorNav.targetPosX,
      posY = gePackage.sectorNav.targetPosY
    }
  end
  return {}
end

function getSectorNavLastCommand()
  return gePackage.sectorNav and gePackage.sectorNav.lastCommand or 0
end

function setSectorNavLastCommand(time)
  if gePackage.sectorNav then
    gePackage.sectorNav.lastCommand = time
  end
end

function getSectorNavLastPositionUpdate()
  return gePackage.sectorNav and gePackage.sectorNav.lastPositionUpdate or 0
end

function setSectorNavLastPositionUpdate(time)
  if gePackage.sectorNav then
    gePackage.sectorNav.lastPositionUpdate = time
  end
end

function getSectorNavTargetHeading()
  return gePackage.sectorNav and gePackage.sectorNav.targetHeading
end

function setSectorNavTargetHeading(heading)
  if gePackage.sectorNav then
    gePackage.sectorNav.targetHeading = heading
  end
end

function getSectorNavRotationComplete()
  return gePackage.sectorNav and gePackage.sectorNav.rotationComplete or false
end

function setSectorNavRotationComplete(complete)
  if gePackage.sectorNav then
    gePackage.sectorNav.rotationComplete = complete
  end
end

function getSectorNavTargetSpeed()
  return gePackage.sectorNav and gePackage.sectorNav.targetSpeed
end

function setSectorNavTargetSpeed(speed)
  if gePackage.sectorNav then
    gePackage.sectorNav.targetSpeed = speed
  end
end

function getSectorNavLastObservedSpeed()
  return gePackage.sectorNav and gePackage.sectorNav.lastObservedSpeed
end

function setSectorNavLastObservedSpeed(speed)
  if gePackage.sectorNav then
    gePackage.sectorNav.lastObservedSpeed = speed
  end
end

function getSectorNavLastSpeedChange()
  return gePackage.sectorNav and gePackage.sectorNav.lastSpeedChange
end

function setSectorNavLastSpeedChange(time)
  if gePackage.sectorNav then
    gePackage.sectorNav.lastSpeedChange = time
  end
end

function clearSectorNav()
  if gePackage.sectorNav then
    gePackage.sectorNav.active = false
  end
  gePackage.sectorNav = nil
end
