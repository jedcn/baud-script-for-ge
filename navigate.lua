-- navigate.lua
-- Autonomous navigation system for Galactic Empire

local function navLog(s)
  cecho("#ff00ff", "[nav] " .. s)
end

local function navCmd(s)
  cecho("green", "[nav][cmd] " .. s)
end

local function navWaitingFor(s)
  cecho("green", "[nav][waiting for] " .. s)
end

local function navDebug(state, s)
  if gePackage.navigation.config.debug then
    cecho("yellow", "[nav] [" .. state .. "] " .. s)
  end
end

local function navError(s)
  cecho("red", "[nav] " .. s)
end

-- State transition logging (hot pink) - always visible
local function navTransition(fromState, toState, reason)
  cecho("#ff00ff", "[nav][state] " .. fromState .. " -> " .. toState .. " (" .. reason .. ")")
end

-- Decision logging (hot pink) - always visible
local function navDecision(action, reason)
  cecho("#ff00ff", "[nav][decision] " .. action .. " - " .. reason)
end

-- Helper to transition state with logging
local function transitionTo(nav, newState, reason)
  local oldState = nav.state
  nav.state = newState
  navTransition(oldState, newState, reason)
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

function calculateDistance(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  local distance = math.sqrt(dx * dx + dy * dy)
  navDebug("helper", "calculateDistance(" .. x1 .. ", " .. y1 .. ", " .. x2 .. ", " .. y2 .. ") = " .. distance)
  return distance
end

function calculateHeading(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  local angleRadians = math.atan(dx, -dy)
  local angleDegrees = angleRadians * 180 / math.pi

  if angleDegrees < 0 then
    angleDegrees = angleDegrees + 360
  end

  local heading = math.floor(angleDegrees + 0.5)
  navDebug("helper", "calculateHeading(" .. x1 .. ", " .. y1 .. ", " .. x2 .. ", " .. y2 .. ") = " .. heading)
  return heading
end

function calculateRotation(currentHeading, goalHeading)
  -- Based on rotateTo() from retake-ilus.lua
  -- Calculate shortest rotation to reach goal heading
  local diff = goalHeading - currentHeading

  -- Normalize to find shortest path
  if diff > 180 then
    diff = diff - 360  -- Rotate negative instead
  elseif diff < -180 then
    diff = diff + 360  -- Rotate positive instead
  end

  local rotation = math.floor(diff + 0.5)
  navDebug("helper", "calculateRotation(current: " .. currentHeading .. ", goal: " .. goalHeading .. ") = " .. rotation)
  return rotation
end

function calculatePlanetCoordinates(currentX, currentY, bearing, distance)
  -- Convert bearing to radians
  -- In navigation: 0° = North (-Y), 90° = East (+X), 180° = South (+Y), 270° = West (-X)
  local bearingRadians = bearing * math.pi / 180

  -- Calculate planet position using polar to cartesian conversion
  local planetX = currentX + distance * math.sin(bearingRadians)
  local planetY = currentY - distance * math.cos(bearingRadians)

  -- Round to nearest integer
  planetX = math.floor(planetX + 0.5)
  planetY = math.floor(planetY + 0.5)

  navDebug("helper", "calculatePlanetCoordinates(current: (" .. currentX .. ", " .. currentY .. "), bearing: " .. bearing .. "°, distance: " .. distance .. ") = (" .. planetX .. ", " .. planetY .. ")")
  return planetX, planetY
end

function sendNavigationCommand(command)
  navCmd(command)
  setNavigationLastCommand(os.time())
  send(command)
end

-- ============================================================================
-- API Functions
-- ============================================================================

function navigateToCoordinates(x, y)
  -- Convert to numbers first
  x = tonumber(x)
  y = tonumber(y)

  -- Validate coordinates (0-10000)
  if x < 0 or x > 10000 or y < 0 or y > 10000 then
    navError("ERROR: Invalid coordinates. Must be 0-10000.")
    return false
  end

  -- Initialize navigation
  setNavigationActive(true)
  setNavigationPhase("coordinate")
  setNavigationTargetCoordinates(x, y)
  setNavigationStart(os.time())
  setNavigationLastPositionCheck(0)
  setNavigationLastPositionUpdate(0)

  navLog("Navigation started to (" .. x .. ", " .. y .. ")")
  transitionTo(gePackage.navigation, "requesting_position", "coordinate navigation initiated to (" .. x .. ", " .. y .. ")")
  return true
end

function cancelNavigation()
  navDebug("cancel", "cancelNavigation()")
  if not getNavigationActive() then
    navLog("No navigation in progress")
    return
  end

  setNavigationActive(false)
  navDecision("warp 0", "user requested navigation cancel")
  send("warp 0")
  transitionTo(gePackage.navigation, "aborted", "user cancelled navigation")
  navLog("Navigation cancelled")
end

function isNavigating()
  return getNavigationActive()
end

function getNavigationStatusText()
  if not getNavigationActive() then
    return "Navigation inactive"
  end

  local state = getNavigationState()
  local target = getNavigationTarget()
  local targetX = target.sectorPositionX
  local targetY = target.sectorPositionY

  return "Navigating to (" .. targetX .. ", " .. targetY .. ") - " .. state
end

function navigateToPlanet(planetNumber)
  -- Convert to number and validate
  planetNumber = tonumber(planetNumber)
  if not planetNumber or planetNumber < 1 or planetNumber > 999 then
    navError("ERROR: Invalid planet number. Must be 1-999.")
    return false
  end

  -- Initialize navigation
  setNavigationActive(true)
  setNavigationPhase("planet")
  setNavigationTargetPlanet(planetNumber)
  setNavigationStart(os.time())
  setNavigationLastScanUpdate(0)
  setNavigationLastPositionCheck(0)
  setNavigationLastPositionUpdate(0)

  navLog("Planet navigation started to planet " .. planetNumber)
  transitionTo(gePackage.navigation, "requesting_planet_scan", "coordinate-based planet navigation initiated to planet " .. planetNumber)
  return true
end

function setPlanetBearingAndDistance(bearing, distance)
  local phase = getNavigationPhase()
  if phase == "planet" or phase == "planet_simple" then
    setNavigationPlanetScanBearing(bearing)
    setNavigationPlanetScanDistance(distance)
    setNavigationLastScanUpdate(os.time())
  end
end

function navigateToPlanetSimple(planetNumber)
  -- Bearing-following approach: repeatedly scans the planet and rotates toward it
  -- Does not calculate absolute coordinates
  planetNumber = tonumber(planetNumber)
  if not planetNumber or planetNumber < 1 or planetNumber > 999 then
    navError("ERROR: Invalid planet number. Must be 1-999.")
    return false
  end

  -- Initialize navigation
  setNavigationActive(true)
  setNavigationPhase("planet_simple")
  setNavigationTargetPlanet(planetNumber)
  setNavigationStart(os.time())
  setNavigationLastScanUpdate(0)
  setNavigationLastPositionCheck(0)
  setNavigationLastPositionUpdate(0)
  clearNavigationPlanetScan()

  navLog("Simple planet navigation started to planet " .. planetNumber)
  transitionTo(gePackage.navigation, "spl_scanning", "bearing-following navigation initiated to planet " .. planetNumber)
  return true
end

function navigateToSector(sectorX, sectorY)
  navLog("Phase 3 not yet implemented")
end

function navigateToSectorAndPlanet(sectorX, sectorY, planetNumber)
  navLog("Phase 5 not yet implemented")
end

-- ============================================================================
-- State Machine Tick Function
-- ============================================================================

function navigationTick()
  if not gePackage.navigation.active then
    return
  end

  local nav = gePackage.navigation

  -- Early exit: if we're doing planet navigation and already orbiting the target, we're done!
  if (nav.phase == "planet" or nav.phase == "planet_simple") and nav.target.planetNumber then
    local orbitingPlanet = getOrbitingPlanet()
    if orbitingPlanet == nav.target.planetNumber then
      navLog("Successfully orbiting planet " .. nav.target.planetNumber .. "!")
      nav.active = false
      transitionTo(nav, "idle", "detected orbit of target planet " .. nav.target.planetNumber .. " (auto-orbit triggered)")
      return
    end
  end
  local config = nav.config
  local state = nav.state

  -- State handler functions
  local actions = {
    idle = function()
      navDebug(state, "No action")
    end,

    -- ===== Simple Planet Navigation States (bearing-following approach) =====
    spl_scanning = function()
      -- Clear stale scan data before each scan
      nav.planetScan.bearing = nil
      nav.planetScan.distance = nil
      local planetNumber = nav.target.planetNumber
      navDecision("scan planet " .. planetNumber, "need bearing and distance to planet")
      sendNavigationCommand("scan planet " .. planetNumber)
      transitionTo(nav, "spl_awaiting_scan", "scan command sent, waiting for scan results")
    end,

    spl_awaiting_scan = function()
      local timeSinceCommand = os.time() - nav.lastCommand
      navDebug(state, "timeSinceCommand=" .. timeSinceCommand .. ", bearing=" .. tostring(nav.planetScan.bearing) .. ", distance=" .. tostring(nav.planetScan.distance))

      -- Check timeout
      if timeSinceCommand > config.commandTimeout then
        navDebug(state, "TIMEOUT - moving to stuck state")
        transitionTo(nav, "stuck", "command timeout after " .. config.commandTimeout .. "s waiting for scan")
        return
      end

      -- Wait until both bearing and distance are populated by triggers
      if nav.planetScan.bearing and nav.planetScan.distance then
        local distance = nav.planetScan.distance

        -- Check if we're close enough to orbit
        if distance < config.planetArrivalThreshold then
          transitionTo(nav, "arrived", "distance " .. distance .. " < threshold " .. config.planetArrivalThreshold .. ", close enough to orbit")
        else
          transitionTo(nav, "spl_rotating", "scan received: bearing=" .. nav.planetScan.bearing .. ", distance=" .. distance .. ", need to rotate")
        end
      end
    end,

    spl_rotating = function()
      local bearing = nav.planetScan.bearing
      local currentHeading = getShipHeading()
      navDebug(state, "bearing=" .. bearing .. ", currentHeading=" .. tostring(currentHeading))

      -- Rotate toward the planet using the relative bearing directly
      if math.abs(bearing) > 2 then
        -- Calculate and store the expected heading after rotation
        if currentHeading then
          nav.targetHeading = (currentHeading + bearing) % 360
          if nav.targetHeading < 0 then nav.targetHeading = nav.targetHeading + 360 end
        else
          nav.targetHeading = nil  -- Will need to wait for heading confirmation
        end
        navDecision("rot " .. bearing, "planet is " .. bearing .. " degrees off current heading, target heading=" .. tostring(nav.targetHeading))
        sendNavigationCommand("rot " .. bearing)
        transitionTo(nav, "spl_awaiting_rotation", "rotation command sent")
      else
        transitionTo(nav, "spl_setting_speed", "already aligned within 2 degrees (bearing=" .. bearing .. ")")
      end
    end,

    spl_awaiting_rotation = function()
      local timeSinceCommand = os.time() - nav.lastCommand
      navDebug(state, "timeSinceCommand=" .. timeSinceCommand)

      if timeSinceCommand > config.commandTimeout then
        transitionTo(nav, "stuck", "command timeout after " .. config.commandTimeout .. "s waiting for rotation")
        return
      end

      -- Check if rotation completed by comparing current heading to target
      local currentHeading = getShipHeading()
      local targetHeading = nav.targetHeading

      -- If we don't know target heading, wait for heading update then recalculate
      if not targetHeading then
        if currentHeading and timeSinceCommand > 2 then
          -- We got a heading update, assume rotation is done
          transitionTo(nav, "spl_setting_speed", "rotation complete (no target heading tracked), current heading=" .. currentHeading)
        end
        return
      end

      -- If heading is unknown, keep waiting
      if not currentHeading then
        navDebug(state, "waiting for heading update from rotation confirmation")
        return
      end

      local headingDiff = math.abs(currentHeading - targetHeading)
      -- Account for wrap-around (359 vs 1 degree)
      if headingDiff > 180 then
        headingDiff = 360 - headingDiff
      end

      navDebug(state, "currentHeading=" .. currentHeading .. ", targetHeading=" .. targetHeading .. ", diff=" .. headingDiff)

      if headingDiff < 5 then  -- Within 5 degrees is good enough
        transitionTo(nav, "spl_setting_speed", "rotation complete, heading " .. currentHeading .. " within 5 degrees of target " .. targetHeading)
      end
    end,

    spl_setting_speed = function()
      local distance = nav.planetScan.distance
      local currentSpeed = getWarpSpeed() or 0
      navDebug(state, "distance=" .. distance .. ", currentSpeed=" .. currentSpeed)

      local speedType, speedValue = config.decideSpeed(distance, currentSpeed)
      navDebug(state, "decided: " .. speedType .. " " .. speedValue)

      if math.abs(currentSpeed - speedValue) > 0.1 then
        -- Store target speed, speed type, and initial speed for tracking acceleration progress
        nav.targetSpeed = speedValue
        nav.speedType = speedType
        nav.lastObservedSpeed = currentSpeed
        nav.lastSpeedChange = os.time()
        local cmd = speedType == "WARP" and ("warp " .. speedValue) or ("imp " .. speedValue)
        navDecision(cmd, "distance=" .. distance .. ", changing from speed " .. currentSpeed .. " to " .. speedValue)
        if speedType == "WARP" then
          sendNavigationCommand("warp " .. speedValue)
        else
          sendNavigationCommand("imp " .. speedValue)
        end
        transitionTo(nav, "spl_awaiting_speed", "speed command sent, waiting for speed=" .. speedValue)
      else
        transitionTo(nav, "spl_traveling", "speed already correct at " .. currentSpeed)
      end
    end,

    spl_awaiting_speed = function()
      local currentSpeed = getWarpSpeed() or 0
      local targetSpeed = nav.targetSpeed or 0
      local speedType = nav.speedType or "WARP"
      local lastObserved = nav.lastObservedSpeed or 0

      -- Check if speed has changed since last observation
      if math.abs(currentSpeed - lastObserved) > 0.1 then
        nav.lastSpeedChange = os.time()
        nav.lastObservedSpeed = currentSpeed
      end

      local timeSinceSpeedChange = os.time() - (nav.lastSpeedChange or nav.lastCommand)
      navDebug(state, "timeSinceSpeedChange=" .. timeSinceSpeedChange .. ", currentSpeed=" .. currentSpeed .. ", targetSpeed=" .. targetSpeed .. ", speedType=" .. speedType)

      if timeSinceSpeedChange > config.commandTimeout then
        transitionTo(nav, "stuck", "command timeout after " .. config.commandTimeout .. "s with no speed progress")
        return
      end

      -- Check if speed matches target
      -- For IMPULSE, warp speed shows as ~0.xx (e.g., imp 99 -> warp 0.99)
      local speedMatches = false
      if speedType == "IMPULSE" then
        -- Impulse is active when warp speed is between 0 and 1
        speedMatches = currentSpeed > 0 and currentSpeed < 1
      else
        speedMatches = math.abs(currentSpeed - targetSpeed) < 0.5
      end

      if speedMatches then
        transitionTo(nav, "spl_traveling", "speed confirmed at " .. currentSpeed .. " (target was " .. targetSpeed .. ")")
      end
    end,

    spl_traveling = function()
      local timeSinceCommand = os.time() - nav.lastCommand
      navDebug(state, "timeSinceCommand=" .. timeSinceCommand .. ", pollingInterval=" .. config.pollingInterval)

      if timeSinceCommand >= config.pollingInterval then
        transitionTo(nav, "spl_scanning", "polling interval " .. config.pollingInterval .. "s elapsed, time to rescan")
      end
    end,

    -- ===== Planet Navigation States (Phase 2 coordinate approach) =====
    requesting_planet_scan = function()
      local planetNumber = nav.target.planetNumber
      navDecision("scan planet " .. planetNumber, "need bearing and distance to calculate planet coordinates")
      sendNavigationCommand("scan planet " .. planetNumber)
      nav.lastCommand = os.time()
      transitionTo(nav, "awaiting_planet_scan", "scan command sent, waiting for scan results")
    end,

    awaiting_planet_scan = function()
      local timeSinceCommand = os.time() - nav.lastCommand
      navDebug(state, "timeSinceCommand=" .. timeSinceCommand .. ", bearing=" .. tostring(nav.planetScan.bearing) .. ", distance=" .. tostring(nav.planetScan.distance))

      -- Check timeout
      if timeSinceCommand > config.commandTimeout then
        transitionTo(nav, "stuck", "command timeout after " .. config.commandTimeout .. "s waiting for scan")
        return
      end

      -- Check if we have both bearing and distance from scan
      if nav.planetScan.bearing and nav.planetScan.distance then
        transitionTo(nav, "requesting_position_for_planet", "scan received: bearing=" .. nav.planetScan.bearing .. ", distance=" .. nav.planetScan.distance .. ", need current position")
      end
    end,

    requesting_position_for_planet = function()
      navDecision("rep nav", "need current position to calculate planet absolute coordinates")
      sendNavigationCommand("rep nav")
      nav.lastPositionCheck = os.time()
      transitionTo(nav, "awaiting_position_for_planet", "position request sent")
    end,

    awaiting_position_for_planet = function()
      local timeSinceCheck = os.time() - nav.lastPositionCheck
      navDebug(state, "timeSinceCheck=" .. timeSinceCheck .. ", lastUpdate=" .. (nav.lastPositionUpdate - nav.navigationStart) .. ", lastCheck=" .. (nav.lastPositionCheck - nav.navigationStart))

      -- Check timeout
      if timeSinceCheck > config.commandTimeout then
        transitionTo(nav, "stuck", "command timeout after " .. config.commandTimeout .. "s waiting for position")
        return
      end

      -- Check if position was updated after we requested it
      if nav.lastPositionUpdate >= nav.lastPositionCheck then
        transitionTo(nav, "calculating_planet_coordinates", "position data received")
      end
    end,

    calculating_planet_coordinates = function()
      local currentX, currentY = getSectorPosition()
      local relativeBearing = nav.planetScan.bearing
      local distance = nav.planetScan.distance
      local shipHeading = getShipHeading()

      -- If heading is unknown, request position again to get it
      if not shipHeading then
        transitionTo(nav, "requesting_position_for_planet", "ship heading unknown, requesting position to get heading")
        return
      end

      -- Convert relative bearing to absolute bearing
      -- Scan bearing is relative to ship's heading
      local absoluteBearing = (shipHeading + relativeBearing) % 360

      navDebug(state, "current=(" .. currentX .. ", " .. currentY .. "), shipHeading=" .. shipHeading .. ", relativeBearing=" .. relativeBearing .. ", absoluteBearing=" .. absoluteBearing .. ", distance=" .. distance)

      -- Calculate planet coordinates using absolute bearing
      local planetX, planetY = calculatePlanetCoordinates(currentX, currentY, absoluteBearing, distance)

      -- Store as target coordinates and switch to coordinate navigation
      nav.target.sectorPositionX = planetX
      nav.target.sectorPositionY = planetY

      navLog("Planet " .. nav.target.planetNumber .. " calculated at (" .. planetX .. ", " .. planetY .. ")")
      transitionTo(nav, "calculating_route", "planet coordinates calculated from pos=(" .. currentX .. "," .. currentY .. "), heading=" .. shipHeading .. ", bearing=" .. relativeBearing .. " -> abs=" .. absoluteBearing .. ", dist=" .. distance)
    end,

    -- ===== Coordinate Navigation States (Phase 1) =====
    requesting_position = function()
      navDecision("rep nav", "need current position to calculate route")
      sendNavigationCommand("rep nav")
      nav.lastPositionCheck = os.time()
      transitionTo(nav, "awaiting_position", "position request sent")
    end,

    awaiting_position = function()
      local timeSinceCheck = os.time() - nav.lastPositionCheck
      navDebug(state, "timeSinceCheck=" .. timeSinceCheck .. ", lastUpdate=" .. (nav.lastPositionUpdate - nav.navigationStart) .. ", lastCheck=" .. (nav.lastPositionCheck - nav.navigationStart))

      -- Check timeout
      if timeSinceCheck > config.commandTimeout then
        transitionTo(nav, "stuck", "command timeout after " .. config.commandTimeout .. "s waiting for position")
        return
      end

      -- Check if position was updated after we requested it
      if nav.lastPositionUpdate >= nav.lastPositionCheck then
        transitionTo(nav, "calculating_route", "position data received")
      end
    end,

    calculating_route = function()
      local currentX, currentY = getSectorPosition()
      local targetX = nav.target.sectorPositionX
      local targetY = nav.target.sectorPositionY
      navDebug(state, "current=(" .. currentX .. ", " .. currentY .. "), target=(" .. targetX .. ", " .. targetY .. ")")

      local distance = calculateDistance(currentX, currentY, targetX, targetY)

      if distance < config.arrivalThreshold then
        transitionTo(nav, "arrived", "distance " .. string.format("%.1f", distance) .. " < threshold " .. config.arrivalThreshold .. ", arrived at destination")
      else
        -- Calculate and store target heading for rotation
        nav.targetHeading = calculateHeading(currentX, currentY, targetX, targetY)
        transitionTo(nav, "rotating_to_heading", "distance=" .. string.format("%.1f", distance) .. ", calculated target heading=" .. nav.targetHeading .. " degrees")
      end
    end,

    rotating_to_heading = function()
      local currentHeading = getShipHeading()
      local targetHeading = nav.targetHeading

      -- If heading is unknown, we need to get it
      if not currentHeading then
        local orbitingPlanet = getOrbitingPlanet()
        if orbitingPlanet then
          -- When orbiting, rep nav doesn't show heading. Send war 0 to leave orbit.
          navDecision("war 0", "leaving orbit to get heading (rep nav doesn't show heading while orbiting)")
          sendNavigationCommand("war 0")
          transitionTo(nav, "getting_heading", "left orbit, waiting for heading from helm report")
        else
          -- Not orbiting, request position which will include heading via rep nav
          transitionTo(nav, "requesting_position", "heading unknown, requesting nav report to get heading")
        end
        return
      end

      navDebug(state, "currentHeading=" .. currentHeading .. ", targetHeading=" .. targetHeading)

      local rotation = calculateRotation(currentHeading, targetHeading)

      -- Only rotate if rotation is significant (> 2 degrees)
      if math.abs(rotation) > 2 then
        navDecision("rot " .. rotation, "current heading " .. currentHeading .. ", need " .. targetHeading .. ", rotating " .. rotation .. " degrees")
        sendNavigationCommand("rot " .. rotation)
        -- Clear heading so we wait for fresh data from rep nav (not from "turning to" trigger)
        setShipHeading(nil)
        transitionTo(nav, "awaiting_rotation_confirmation", "rotation command sent")
      else
        transitionTo(nav, "setting_speed", "already aligned within 2 degrees (rotation=" .. rotation .. ")")
      end
    end,

    getting_heading = function()
      local timeSinceCommand = os.time() - nav.lastCommand
      navDebug(state, "timeSinceCommand=" .. timeSinceCommand)

      if timeSinceCommand > config.commandTimeout then
        transitionTo(nav, "stuck", "command timeout after " .. config.commandTimeout .. "s waiting for heading")
        return
      end

      -- Check if we now have a heading
      local currentHeading = getShipHeading()
      if currentHeading then
        transitionTo(nav, "rotating_to_heading", "heading confirmed: " .. currentHeading .. " degrees")
      end
    end,

    awaiting_rotation_confirmation = function()
      local timeSinceCommand = os.time() - nav.lastCommand
      navDebug(state, "timeSinceCommand=" .. timeSinceCommand)

      if timeSinceCommand > config.commandTimeout then
        transitionTo(nav, "stuck", "command timeout after " .. config.commandTimeout .. "s waiting for rotation")
        return
      end

      -- Check if rotation completed by comparing current heading to target
      local currentHeading = getShipHeading()
      local targetHeading = nav.targetHeading

      -- If heading is unknown, wait for "Helm reports we are now heading X degrees" trigger
      -- (The "Ship is now turning to X" trigger doesn't set heading during rotation)
      if not currentHeading then
        navDebug(state, "waiting for helm rotation complete message")
        return
      end

      local headingDiff = math.abs(currentHeading - targetHeading)

      -- Account for wrap-around (359 vs 1 degree)
      if headingDiff > 180 then
        headingDiff = 360 - headingDiff
      end

      navDebug(state, "currentHeading=" .. currentHeading .. ", targetHeading=" .. targetHeading .. ", diff=" .. headingDiff)

      if headingDiff < 5 then  -- Within 5 degrees is good enough
        transitionTo(nav, "setting_speed", "rotation complete, heading " .. currentHeading .. " within 5 degrees of target " .. targetHeading)
      end
    end,

    setting_speed = function()
      local currentX, currentY = getSectorPosition()
      local targetX = nav.target.sectorPositionX
      local targetY = nav.target.sectorPositionY
      local distance = calculateDistance(currentX, currentY, targetX, targetY)
      local currentSpeed = getWarpSpeed() or 0
      navDebug(state, "distance=" .. distance .. ", currentSpeed=" .. currentSpeed)

      local speedType, speedValue = config.decideSpeed(distance, currentSpeed)
      navDebug(state, "decided: " .. speedType .. " " .. speedValue)

      -- Only send command if speed needs to change
      if math.abs(currentSpeed - speedValue) > 0.1 then
        -- Store target speed, speed type, and initial speed for tracking acceleration progress
        nav.targetSpeed = speedValue
        nav.speedType = speedType
        nav.lastObservedSpeed = currentSpeed
        nav.lastSpeedChange = os.time()
        local cmd = speedType == "WARP" and ("warp " .. speedValue) or ("imp " .. speedValue)
        navDecision(cmd, "distance=" .. string.format("%.1f", distance) .. ", changing from speed " .. currentSpeed .. " to " .. speedValue)
        if speedType == "WARP" then
          sendNavigationCommand("warp " .. speedValue)
        else
          sendNavigationCommand("imp " .. speedValue)
        end
        transitionTo(nav, "awaiting_speed_confirmation", "speed command sent")
      else
        transitionTo(nav, "traveling", "speed already correct at " .. currentSpeed)
      end
    end,

    awaiting_speed_confirmation = function()
      local currentSpeed = getWarpSpeed() or 0
      local targetSpeed = nav.targetSpeed or 0
      local speedType = nav.speedType or "WARP"
      local lastObserved = nav.lastObservedSpeed or 0

      -- Check if speed has changed since last observation
      if math.abs(currentSpeed - lastObserved) > 0.1 then
        nav.lastSpeedChange = os.time()
        nav.lastObservedSpeed = currentSpeed
      end

      local timeSinceSpeedChange = os.time() - (nav.lastSpeedChange or nav.lastCommand)
      navDebug(state, "timeSinceSpeedChange=" .. timeSinceSpeedChange .. ", currentSpeed=" .. currentSpeed .. ", targetSpeed=" .. targetSpeed .. ", speedType=" .. speedType)

      if timeSinceSpeedChange > config.commandTimeout then
        transitionTo(nav, "stuck", "command timeout after " .. config.commandTimeout .. "s with no speed progress")
        return
      end

      -- Check if speed matches target
      -- For IMPULSE, warp speed shows as ~0.xx (e.g., imp 99 -> warp 0.99)
      local speedMatches = false
      if speedType == "IMPULSE" then
        -- Impulse is active when warp speed is between 0 and 1
        speedMatches = currentSpeed > 0 and currentSpeed < 1
      else
        speedMatches = math.abs(currentSpeed - targetSpeed) < 0.5
      end

      if speedMatches then
        transitionTo(nav, "traveling", "speed confirmed at " .. currentSpeed .. " (target was " .. targetSpeed .. ")")
      end
    end,

    traveling = function()
      local timeSinceCheck = os.time() - nav.lastPositionCheck
      navDebug(state, "timeSinceCheck=" .. timeSinceCheck .. ", pollingInterval=" .. config.pollingInterval)

      if timeSinceCheck >= config.pollingInterval then
        transitionTo(nav, "requesting_position", "polling interval " .. config.pollingInterval .. "s elapsed, checking position")
      end
    end,

    arrived = function()
      navDecision("warp 0", "arrived at destination, stopping ship")
      sendNavigationCommand("warp 0")
      transitionTo(nav, "stopping", "stop command sent")
    end,

    stopping = function()
      local currentSpeed = getWarpSpeed()
      navDebug(state, "currentSpeed=" .. currentSpeed)

      if currentSpeed == 0 then
        -- For planet navigation, check if we've achieved orbit
        if nav.phase == "planet" or nav.phase == "planet_simple" then
          transitionTo(nav, "awaiting_orbit", "ship stopped, checking if orbiting planet " .. nav.target.planetNumber)
        else
          transitionTo(nav, "completed", "ship stopped, coordinate navigation complete")
        end
      end
    end,

    awaiting_orbit = function()
      local orbitingPlanet = getOrbitingPlanet()
      local targetPlanet = nav.target.planetNumber
      navDebug(state, "orbitingPlanet=" .. tostring(orbitingPlanet) .. ", targetPlanet=" .. targetPlanet)

      if orbitingPlanet == targetPlanet then
        navLog("Successfully orbiting planet " .. targetPlanet .. "!")
        transitionTo(nav, "completed", "confirmed orbiting planet " .. targetPlanet)
      else
        -- Not orbiting yet - send orbit command
        local timeSinceCommand = os.time() - (nav.lastCommand or 0)
        if timeSinceCommand > 2 then
          navDecision("orb " .. targetPlanet, "within orbit range, sending orbit command")
          sendNavigationCommand("orb " .. targetPlanet)
        end
      end
    end,

    completed = function()
      navLog("Navigation completed!")
      nav.active = false
      transitionTo(nav, "idle", "navigation finished successfully")
    end,

    stuck = function()
      navError("Navigation stuck in previous state")
      transitionTo(nav, "aborted", "stuck state detected, aborting")
    end,

    aborted = function()
      navError("Navigation aborted - coming to a stop")
      navDecision("war 0 0", "emergency stop due to abort")
      sendNavigationCommand("war 0 0")
      nav.active = false
      transitionTo(nav, "idle", "navigation aborted, ship stopped")
    end
  }

  -- Execute current state
  if actions[state] then
    actions[state]()
  end
end

-- ============================================================================
-- Flip Away Feature
-- ============================================================================
-- Rotates the ship so that the orbited planet is directly behind (bearing 180)

local function faLog(s)
  cecho("#ff00ff", "[flipaway] " .. s)
end

local function faError(s)
  cecho("red", "[flipaway] " .. s)
end

local function faTransition(fromState, toState, reason)
  cecho("#ff00ff", "[flipaway][state] " .. fromState .. " -> " .. toState .. " (" .. reason .. ")")
end

function flipAwayFromPlanet()
  local orbitingPlanet = getOrbitingPlanet()
  if not orbitingPlanet then
    faError("Not orbiting a planet - cannot flip away")
    return false
  end

  -- Initialize flipaway state using setter
  -- No need to send "rep nav" - we already trust getOrbitingPlanet() as source of truth
  initFlipAway(orbitingPlanet)

  faLog("Starting flip away from planet " .. orbitingPlanet)
  return true
end

function setFlipAwayBearingFromTrigger(bearing)
  if getFlipAwayActive() then
    local state = getFlipAwayState()
    if state == "fa_awaiting_initial_scan" then
      setFlipAwayInitialBearing(bearing)
    elseif state == "fa_awaiting_verify_scan" then
      setFlipAwayFinalBearing(bearing)
    end
  end
end

function cancelFlipAway()
  if getFlipAwayActive() then
    clearFlipAway()
    faLog("Flip away cancelled")
  end
end

function setFlipAwayRotationCompleteFromTrigger()
  if getFlipAwayActive() then
    if getFlipAwayState() == "fa_awaiting_rotation" then
      setFlipAwayRotationComplete(true)
    end
  end
end

function flipAwayTick()
  if not gePackage.flipAway or not gePackage.flipAway.active then
    return
  end

  local fa = gePackage.flipAway
  local state = fa.state
  local commandTimeout = 60

  local actions = {
    -- fa_verifying_orbit removed - we trust getOrbitingPlanet() as source of truth

    fa_scanning_initial = function()
      fa.initialBearing = nil
      fa.lastCommand = os.time()
      send("scan planet " .. fa.planetNumber)
      fa.state = "fa_awaiting_initial_scan"
      faTransition("fa_scanning_initial", "fa_awaiting_initial_scan", "scanning planet for bearing")
    end,

    fa_awaiting_initial_scan = function()
      local timeSinceCommand = os.time() - fa.lastCommand

      if fa.initialBearing then
        fa.state = "fa_rotating"
        faTransition("fa_awaiting_initial_scan", "fa_rotating", "got bearing " .. fa.initialBearing)
      elseif timeSinceCommand > commandTimeout then
        faError("Timeout waiting for scan results")
        fa.active = false
        fa.state = "fa_failed"
      end
    end,

    fa_rotating = function()
      local bearing = fa.initialBearing
      -- When we rotate by R, planet's new bearing = bearing - R
      -- We want new bearing = 180, so: bearing - R = 180, thus R = bearing - 180
      local rotation = bearing - 180

      -- Normalize rotation to -180 to 180 range
      if rotation > 180 then
        rotation = rotation - 360
      elseif rotation < -180 then
        rotation = rotation + 360
      end

      if math.abs(rotation) <= 2 then
        faLog("Planet already at bearing " .. bearing .. ", no rotation needed")
        fa.state = "fa_completed"
        faTransition("fa_rotating", "fa_completed", "planet already behind ship")
      else
        faLog("Planet at bearing " .. bearing .. ", rotating " .. rotation .. " degrees")
        fa.lastCommand = os.time()
        fa.rotationComplete = false
        send("rot " .. rotation)
        fa.state = "fa_awaiting_rotation"
        faTransition("fa_rotating", "fa_awaiting_rotation", "rotation command sent")
      end
    end,

    fa_awaiting_rotation = function()
      local timeSinceCommand = os.time() - fa.lastCommand

      -- Wait for rotation complete signal from trigger
      if fa.rotationComplete then
        fa.state = "fa_scanning_verify"
        faTransition("fa_awaiting_rotation", "fa_scanning_verify", "rotation complete, verifying")
      elseif timeSinceCommand > commandTimeout then
        faError("Timeout waiting for rotation")
        fa.active = false
        fa.state = "fa_failed"
      end
    end,

    fa_scanning_verify = function()
      fa.finalBearing = nil
      fa.lastCommand = os.time()
      send("scan planet " .. fa.planetNumber)
      fa.state = "fa_awaiting_verify_scan"
      faTransition("fa_scanning_verify", "fa_awaiting_verify_scan", "scanning to verify planet bearing")
    end,

    fa_awaiting_verify_scan = function()
      local timeSinceCommand = os.time() - fa.lastCommand

      if fa.finalBearing then
        local diff = math.abs(fa.finalBearing - 180)
        if diff <= 5 or diff >= 355 then
          faLog("Success! Planet now at bearing " .. fa.finalBearing)
          fa.state = "fa_completed"
          faTransition("fa_awaiting_verify_scan", "fa_completed", "planet verified at bearing " .. fa.finalBearing)
        else
          faError("Planet at bearing " .. fa.finalBearing .. " (expected ~180)")
          fa.state = "fa_completed"
          faTransition("fa_awaiting_verify_scan", "fa_completed", "bearing off but accepting result")
        end
      elseif timeSinceCommand > commandTimeout then
        faError("Timeout waiting for verification scan")
        fa.active = false
        fa.state = "fa_failed"
      end
    end,

    fa_completed = function()
      faLog("Flip away complete")
      fa.active = false
    end,

    fa_failed = function()
      faError("Flip away failed")
      fa.active = false
    end
  }

  if actions[state] then
    actions[state]()
  end
end

-- ============================================================================
-- Rotate To Heading Feature (rotto)
-- ============================================================================
-- Rotates the ship to an absolute heading (only works when not orbiting)

local function rottoLog(s)
  cecho("#ff00ff", "[rotto] " .. s)
end

local function rottoError(s)
  cecho("red", "[rotto] " .. s)
end

local function rottoTransition(fromState, toState, reason)
  cecho("#ff00ff", "[rotto][state] " .. fromState .. " -> " .. toState .. " (" .. reason .. ")")
end

function rotateToHeading(targetHeading)
  targetHeading = tonumber(targetHeading)
  if not targetHeading or targetHeading < 0 or targetHeading > 359 then
    rottoError("Invalid heading. Must be 0-359.")
    return false
  end

  -- Clear heading so we know when the probe response arrives
  setShipHeading(nil)

  -- Initialize rotto state using setter
  initRotto(targetHeading)

  rottoLog("Rotating to heading " .. targetHeading .. " (probing current heading)")
  send("rot 0")
  return true
end

function setRottoRotationCompleteFromTrigger()
  if getRottoActive() then
    if getRottoState() == "rotto_awaiting_rotation" then
      setRottoRotationComplete(true)
    end
  end
end

function cancelRotto()
  if getRottoActive() then
    clearRotto()
    rottoLog("Rotate to heading cancelled")
  end
end

function rottoTick()
  if not gePackage.rotto or not gePackage.rotto.active then
    return
  end

  local rotto = gePackage.rotto
  local state = rotto.state
  local commandTimeout = 60

  local actions = {
    rotto_probing = function()
      local timeSinceCommand = os.time() - rotto.lastCommand
      local currentHeading = getShipHeading()

      if currentHeading then
        local targetHeading = rotto.targetHeading
        local rotation = targetHeading - currentHeading

        -- Normalize rotation to -180 to 180 range
        if rotation > 180 then
          rotation = rotation - 360
        elseif rotation < -180 then
          rotation = rotation + 360
        end

        if math.abs(rotation) <= 2 then
          rottoLog("Already at heading " .. currentHeading .. ", no rotation needed")
          rotto.state = "rotto_completed"
          rottoTransition("rotto_probing", "rotto_completed", "already at target heading")
        else
          rottoLog("Current heading " .. currentHeading .. ", rotating " .. rotation .. " to reach " .. targetHeading)
          rotto.lastCommand = os.time()
          rotto.rotationComplete = false
          send("rot " .. rotation)
          rotto.state = "rotto_awaiting_rotation"
          rottoTransition("rotto_probing", "rotto_awaiting_rotation", "rotation command sent")
        end
      elseif timeSinceCommand > commandTimeout then
        rottoError("Timeout waiting for heading probe response")
        rotto.active = false
        rotto.state = "rotto_failed"
      end
    end,

    rotto_awaiting_rotation = function()
      local timeSinceCommand = os.time() - rotto.lastCommand

      if rotto.rotationComplete then
        local currentHeading = getShipHeading()
        rottoLog("Rotation complete. Now heading " .. currentHeading)
        rotto.state = "rotto_completed"
        rottoTransition("rotto_awaiting_rotation", "rotto_completed", "rotation confirmed")
      elseif timeSinceCommand > commandTimeout then
        rottoError("Timeout waiting for rotation")
        rotto.active = false
        rotto.state = "rotto_failed"
      end
    end,

    rotto_completed = function()
      rottoLog("Rotate to heading complete")
      rotto.active = false
    end,

    rotto_failed = function()
      rottoError("Rotate to heading failed")
      rotto.active = false
    end
  }

  if actions[state] then
    actions[state]()
  end
end

-- ============================================================================
-- Sector Navigation Feature (navsec)
-- ============================================================================
-- Navigates the ship to a different sector, optionally to specific coordinates

local function secLog(s)
  cecho("#ff00ff", "[navsec] " .. s)
end

local function secError(s)
  cecho("red", "[navsec] " .. s)
end

local function secTransition(fromState, toState, reason)
  cecho("#ff00ff", "[navsec][state] " .. fromState .. " -> " .. toState .. " (" .. reason .. ")")
end

-- Convert sector + position to absolute galactic coordinates
function calculateAbsolutePosition(sectorX, sectorY, posX, posY)
  local absX = (sectorX * 10000) + posX
  local absY = (sectorY * 10000) + posY
  return absX, absY
end

function navigateToSector(targetSectorX, targetSectorY, targetPosX, targetPosY)
  targetSectorX = tonumber(targetSectorX)
  targetSectorY = tonumber(targetSectorY)

  if not targetSectorX or not targetSectorY then
    secError("Invalid sector coordinates")
    return false
  end

  -- Default to sector center if no position specified
  targetPosX = tonumber(targetPosX) or 5000
  targetPosY = tonumber(targetPosY) or 5000

  if targetPosX < 0 or targetPosX > 10000 or targetPosY < 0 or targetPosY > 10000 then
    secError("Invalid position. Must be 0-10000.")
    return false
  end

  -- Initialize sector navigation state using setter
  initSectorNav(targetSectorX, targetSectorY, targetPosX, targetPosY)

  secLog("Navigating to sector (" .. targetSectorX .. ", " .. targetSectorY .. ") position (" .. targetPosX .. ", " .. targetPosY .. ")")
  send("rep nav")
  return true
end

function setSectorNavRotationCompleteFromTrigger()
  if getSectorNavActive() then
    if getSectorNavState() == "sec_awaiting_rotation" then
      setSectorNavRotationComplete(true)
    end
  end
end

function cancelSectorNav()
  if getSectorNavActive() then
    clearSectorNav()
    send("warp 0")
    secLog("Sector navigation cancelled")
  end
end

function sectorNavTick()
  if not gePackage.sectorNav or not gePackage.sectorNav.active then
    return
  end

  local sec = gePackage.sectorNav
  local state = sec.state
  local config = gePackage.navigation.config
  local commandTimeout = 60

  local actions = {
    sec_requesting_position = function()
      sec.lastCommand = os.time()
      sec.lastPositionUpdate = 0
      send("rep nav")
      sec.state = "sec_awaiting_position"
      secTransition("sec_requesting_position", "sec_awaiting_position", "position request sent")
    end,

    sec_awaiting_position = function()
      local timeSinceCommand = os.time() - sec.lastCommand

      -- Check if we have fresh position data
      local currentSectorX, currentSectorY = getSector()
      local currentPosX, currentPosY = getSectorPosition()

      if currentSectorX and currentSectorY and currentPosX and currentPosY then
        sec.state = "sec_calculating_route"
        secTransition("sec_awaiting_position", "sec_calculating_route", "position received: sector (" .. currentSectorX .. ", " .. currentSectorY .. ") pos (" .. currentPosX .. ", " .. currentPosY .. ")")
      elseif timeSinceCommand > commandTimeout then
        secError("Timeout waiting for position")
        sec.active = false
        sec.state = "sec_failed"
      end
    end,

    sec_calculating_route = function()
      local currentSectorX, currentSectorY = getSector()
      local currentPosX, currentPosY = getSectorPosition()

      -- Check if we've already arrived at target sector
      if currentSectorX == sec.targetSectorX and currentSectorY == sec.targetSectorY then
        -- In target sector, check if at target position
        local distToTarget = calculateDistance(currentPosX, currentPosY, sec.targetPosX, sec.targetPosY)
        if distToTarget < config.arrivalThreshold then
          secLog("Arrived at destination!")
          sec.state = "sec_arrived"
          secTransition("sec_calculating_route", "sec_arrived", "at target position")
          return
        end
      end

      -- Calculate absolute positions
      local currentAbsX, currentAbsY = calculateAbsolutePosition(currentSectorX, currentSectorY, currentPosX, currentPosY)
      local targetAbsX, targetAbsY = calculateAbsolutePosition(sec.targetSectorX, sec.targetSectorY, sec.targetPosX, sec.targetPosY)

      -- Calculate heading to target
      sec.targetHeading = calculateHeading(currentAbsX, currentAbsY, targetAbsX, targetAbsY)
      local distance = calculateDistance(currentAbsX, currentAbsY, targetAbsX, targetAbsY)

      secLog("Current absolute: (" .. currentAbsX .. ", " .. currentAbsY .. "), Target: (" .. targetAbsX .. ", " .. targetAbsY .. ")")
      secLog("Distance: " .. string.format("%.0f", distance) .. ", Target heading: " .. sec.targetHeading)

      sec.state = "sec_rotating"
      secTransition("sec_calculating_route", "sec_rotating", "route calculated, heading " .. sec.targetHeading)
    end,

    sec_rotating = function()
      local currentHeading = getShipHeading()

      if not currentHeading then
        -- Need to get heading, leave orbit if orbiting
        local orbitingPlanet = getOrbitingPlanet()
        if orbitingPlanet then
          secLog("Leaving orbit to get heading")
          send("war 0")
          sec.lastCommand = os.time()
        end
        return
      end

      local rotation = calculateRotation(currentHeading, sec.targetHeading)

      if math.abs(rotation) <= 2 then
        secLog("Already aligned to heading " .. currentHeading)
        sec.state = "sec_setting_speed"
        secTransition("sec_rotating", "sec_setting_speed", "already aligned")
      else
        secLog("Current heading " .. currentHeading .. ", rotating " .. rotation .. " to reach " .. sec.targetHeading)
        sec.lastCommand = os.time()
        sec.rotationComplete = false
        send("rot " .. rotation)
        sec.state = "sec_awaiting_rotation"
        secTransition("sec_rotating", "sec_awaiting_rotation", "rotation command sent")
      end
    end,

    sec_awaiting_rotation = function()
      local timeSinceCommand = os.time() - sec.lastCommand

      if sec.rotationComplete then
        sec.state = "sec_setting_speed"
        secTransition("sec_awaiting_rotation", "sec_setting_speed", "rotation complete")
      elseif timeSinceCommand > commandTimeout then
        secError("Timeout waiting for rotation")
        sec.active = false
        sec.state = "sec_failed"
      end
    end,

    sec_setting_speed = function()
      local currentSectorX, currentSectorY = getSector()
      local currentPosX, currentPosY = getSectorPosition()
      local currentAbsX, currentAbsY = calculateAbsolutePosition(currentSectorX, currentSectorY, currentPosX, currentPosY)
      local targetAbsX, targetAbsY = calculateAbsolutePosition(sec.targetSectorX, sec.targetSectorY, sec.targetPosX, sec.targetPosY)
      local distance = calculateDistance(currentAbsX, currentAbsY, targetAbsX, targetAbsY)
      local currentSpeed = getWarpSpeed() or 0

      local speedType, speedValue = config.decideSpeed(distance, currentSpeed)

      if math.abs(currentSpeed - speedValue) > 0.1 then
        sec.targetSpeed = speedValue
        sec.speedType = speedType
        sec.lastObservedSpeed = currentSpeed
        sec.lastSpeedChange = os.time()
        local cmd = speedType == "WARP" and ("warp " .. speedValue) or ("imp " .. speedValue)
        secLog("Distance " .. string.format("%.0f", distance) .. ", setting " .. cmd)
        send(cmd)
        sec.state = "sec_awaiting_speed"
        secTransition("sec_setting_speed", "sec_awaiting_speed", "speed command sent")
      else
        sec.state = "sec_traveling"
        secTransition("sec_setting_speed", "sec_traveling", "speed already correct at " .. currentSpeed)
      end
    end,

    sec_awaiting_speed = function()
      local currentSpeed = getWarpSpeed() or 0
      local targetSpeed = sec.targetSpeed or 0
      local speedType = sec.speedType or "WARP"
      local lastObserved = sec.lastObservedSpeed or 0

      -- Track speed progress
      if math.abs(currentSpeed - lastObserved) > 0.1 then
        sec.lastSpeedChange = os.time()
        sec.lastObservedSpeed = currentSpeed
      end

      local timeSinceSpeedChange = os.time() - (sec.lastSpeedChange or sec.lastCommand)

      if timeSinceSpeedChange > commandTimeout then
        secError("Timeout waiting for speed change")
        sec.active = false
        sec.state = "sec_failed"
        return
      end

      -- Check if speed matches target
      -- For IMPULSE, warp speed shows as ~0.xx (e.g., imp 99 -> warp 0.99)
      local speedMatches = false
      if speedType == "IMPULSE" then
        -- Impulse is active when warp speed is between 0 and 1
        speedMatches = currentSpeed > 0 and currentSpeed < 1
      else
        speedMatches = math.abs(currentSpeed - targetSpeed) < 0.5
      end

      if speedMatches then
        sec.state = "sec_traveling"
        secTransition("sec_awaiting_speed", "sec_traveling", "speed confirmed at " .. currentSpeed)
      end
    end,

    sec_traveling = function()
      local timeSinceCommand = os.time() - sec.lastCommand

      -- Periodically check position
      if timeSinceCommand >= config.pollingInterval then
        local currentSectorX, currentSectorY = getSector()
        local currentPosX, currentPosY = getSectorPosition()

        -- Check if arrived at target sector
        if currentSectorX == sec.targetSectorX and currentSectorY == sec.targetSectorY then
          local distToTarget = calculateDistance(currentPosX, currentPosY, sec.targetPosX, sec.targetPosY)
          if distToTarget < config.arrivalThreshold then
            sec.state = "sec_arrived"
            secTransition("sec_traveling", "sec_arrived", "arrived at target position in sector")
            return
          end
        end

        -- Recalculate route (course correction)
        sec.state = "sec_requesting_position"
        secTransition("sec_traveling", "sec_requesting_position", "polling interval elapsed, rechecking position")
      end
    end,

    sec_arrived = function()
      secLog("Stopping ship")
      send("warp 0")
      sec.state = "sec_stopping"
      secTransition("sec_arrived", "sec_stopping", "stop command sent")
    end,

    sec_stopping = function()
      local currentSpeed = getWarpSpeed()
      if currentSpeed == 0 then
        sec.state = "sec_completed"
        secTransition("sec_stopping", "sec_completed", "ship stopped")
      end
    end,

    sec_completed = function()
      local currentSectorX, currentSectorY = getSector()
      secLog("Sector navigation complete! Now in sector (" .. currentSectorX .. ", " .. currentSectorY .. ")")
      sec.active = false
    end,

    sec_failed = function()
      secError("Sector navigation failed")
      sec.active = false
    end
  }

  if actions[state] then
    actions[state]()
  end
end
