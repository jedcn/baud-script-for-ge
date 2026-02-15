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
  gePackage.navigation.lastCommand = os.time()
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
  gePackage.navigation.active = true
  gePackage.navigation.phase = "coordinate"
  gePackage.navigation.target.sectorPositionX = x
  gePackage.navigation.target.sectorPositionY = y
  gePackage.navigation.navigationStart = os.time()
  gePackage.navigation.lastPositionCheck = 0
  gePackage.navigation.lastPositionUpdate = 0

  navLog("Navigation started to (" .. x .. ", " .. y .. ")")
  transitionTo(gePackage.navigation, "requesting_position", "coordinate navigation initiated to (" .. x .. ", " .. y .. ")")
  return true
end

function cancelNavigation()
  navDebug("cancel", "cancelNavigation()")
  if not gePackage.navigation.active then
    navLog("No navigation in progress")
    return
  end

  gePackage.navigation.active = false
  navDecision("warp 0", "user requested navigation cancel")
  send("warp 0")
  transitionTo(gePackage.navigation, "aborted", "user cancelled navigation")
  navLog("Navigation cancelled")
end

function isNavigating()
  return gePackage.navigation.active
end

function getNavigationStatus()
  if not gePackage.navigation.active then
    return "Navigation inactive"
  end

  local state = gePackage.navigation.state
  local targetX = gePackage.navigation.target.sectorPositionX
  local targetY = gePackage.navigation.target.sectorPositionY

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
  gePackage.navigation.active = true
  gePackage.navigation.phase = "planet"
  gePackage.navigation.target.planetNumber = planetNumber
  gePackage.navigation.navigationStart = os.time()
  gePackage.navigation.lastScanUpdate = 0
  gePackage.navigation.lastPositionCheck = 0
  gePackage.navigation.lastPositionUpdate = 0

  navLog("Planet navigation started to planet " .. planetNumber)
  transitionTo(gePackage.navigation, "requesting_planet_scan", "coordinate-based planet navigation initiated to planet " .. planetNumber)
  return true
end

function setPlanetBearingAndDistance(bearing, distance)
  local phase = gePackage.navigation and gePackage.navigation.phase
  if phase == "planet" or phase == "planet_simple" then
    gePackage.navigation.planetScan.bearing = tonumber(bearing)
    gePackage.navigation.planetScan.distance = tonumber(distance)
    gePackage.navigation.lastScanUpdate = os.time()
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
  gePackage.navigation.active = true
  gePackage.navigation.phase = "planet_simple"
  gePackage.navigation.target.planetNumber = planetNumber
  gePackage.navigation.navigationStart = os.time()
  gePackage.navigation.lastScanUpdate = 0
  gePackage.navigation.lastPositionCheck = 0
  gePackage.navigation.lastPositionUpdate = 0
  gePackage.navigation.planetScan.bearing = nil
  gePackage.navigation.planetScan.distance = nil

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
        -- Store target speed for verification
        nav.targetSpeed = speedValue
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
      local timeSinceCommand = os.time() - nav.lastCommand
      navDebug(state, "timeSinceCommand=" .. timeSinceCommand)

      if timeSinceCommand > config.commandTimeout then
        transitionTo(nav, "stuck", "command timeout after " .. config.commandTimeout .. "s waiting for speed change")
        return
      end

      -- Check if speed has reached target
      local currentSpeed = getWarpSpeed() or 0
      local targetSpeed = nav.targetSpeed or 0

      navDebug(state, "currentSpeed=" .. currentSpeed .. ", targetSpeed=" .. targetSpeed)

      -- Allow some tolerance for speed matching (within 0.5)
      if math.abs(currentSpeed - targetSpeed) < 0.5 then
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

      -- If heading is unknown, keep waiting for rotation confirmation trigger
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
      local timeSinceCommand = os.time() - nav.lastCommand
      navDebug(state, "timeSinceCommand=" .. timeSinceCommand)

      if timeSinceCommand > config.commandTimeout then
        transitionTo(nav, "stuck", "command timeout after " .. config.commandTimeout .. "s waiting for speed change")
        return
      end

      if timeSinceCommand > 1 then
        transitionTo(nav, "traveling", "speed confirmed after " .. timeSinceCommand .. "s")
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
