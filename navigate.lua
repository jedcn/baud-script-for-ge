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
  gePackage.navigation.state = "requesting_position"
  gePackage.navigation.navigationStart = os.time()
  gePackage.navigation.lastPositionCheck = 0
  gePackage.navigation.lastPositionUpdate = 0

  navLog("Navigation started to (" .. x .. ", " .. y .. ")")
  return true
end

function cancelNavigation()
  navDebug("cancel", "cancelNavigation()")
  if not gePackage.navigation.active then
    navLog("No navigation in progress")
    return
  end

  gePackage.navigation.active = false
  gePackage.navigation.state = "aborted"
  send("warp 0")
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
  gePackage.navigation.state = "requesting_planet_scan"
  gePackage.navigation.navigationStart = os.time()
  gePackage.navigation.lastScanUpdate = 0
  gePackage.navigation.lastPositionCheck = 0
  gePackage.navigation.lastPositionUpdate = 0

  navLog("Planet navigation started to planet " .. planetNumber)
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
  local config = nav.config
  local state = nav.state

  -- State handler functions
  local actions = {
    idle = function()
      navDebug(state, "No action")
    end,

    -- ===== Planet Navigation States (Phase 2) =====
    requesting_planet_scan = function()
      local planetNumber = nav.target.planetNumber
      sendNavigationCommand("scan planet " .. planetNumber)
      nav.state = "awaiting_planet_scan"
      nav.lastCommand = os.time()
    end,

    awaiting_planet_scan = function()
      local timeSinceCommand = os.time() - nav.lastCommand
      navDebug(state, "timeSinceCommand=" .. timeSinceCommand .. ", bearing=" .. tostring(nav.planetScan.bearing) .. ", distance=" .. tostring(nav.planetScan.distance))

      -- Check timeout
      if timeSinceCommand > config.commandTimeout then
        navDebug(state, "TIMEOUT - moving to stuck state")
        nav.state = "stuck"
        return
      end

      -- Check if we have both bearing and distance from scan
      if nav.planetScan.bearing and nav.planetScan.distance then
        navDebug(state, "Scan data received, moving to requesting_position_for_planet")
        nav.state = "requesting_position_for_planet"
      end
    end,

    requesting_position_for_planet = function()
      sendNavigationCommand("rep nav")
      nav.state = "awaiting_position_for_planet"
      nav.lastPositionCheck = os.time()
    end,

    awaiting_position_for_planet = function()
      local timeSinceCheck = os.time() - nav.lastPositionCheck
      navDebug(state, "timeSinceCheck=" .. timeSinceCheck .. ", lastUpdate=" .. (nav.lastPositionUpdate - nav.navigationStart) .. ", lastCheck=" .. (nav.lastPositionCheck - nav.navigationStart))

      -- Check timeout
      if timeSinceCheck > config.commandTimeout then
        navDebug(state, "TIMEOUT - moving to stuck state")
        nav.state = "stuck"
        return
      end

      -- Check if position was updated after we requested it
      if nav.lastPositionUpdate >= nav.lastPositionCheck then
        navDebug(state, "Position updated, moving to calculating_planet_coordinates")
        nav.state = "calculating_planet_coordinates"
      end
    end,

    calculating_planet_coordinates = function()
      local currentX, currentY = getSectorPosition()
      local bearing = nav.planetScan.bearing
      local distance = nav.planetScan.distance
      navDebug(state, "current=(" .. currentX .. ", " .. currentY .. "), bearing=" .. bearing .. ", distance=" .. distance)

      -- Calculate planet coordinates
      local planetX, planetY = calculatePlanetCoordinates(currentX, currentY, bearing, distance)

      -- Store as target coordinates and switch to coordinate navigation
      nav.target.sectorPositionX = planetX
      nav.target.sectorPositionY = planetY

      navLog("Planet " .. nav.target.planetNumber .. " calculated at (" .. planetX .. ", " .. planetY .. ")")
      navDebug(state, "Transitioning to coordinate navigation (calculating_route)")
      nav.state = "calculating_route"
    end,

    -- ===== Coordinate Navigation States (Phase 1) =====
    requesting_position = function()
      sendNavigationCommand("rep nav")
      nav.state = "awaiting_position"
      nav.lastPositionCheck = os.time()
    end,

    awaiting_position = function()
      local timeSinceCheck = os.time() - nav.lastPositionCheck
      navDebug(state, "timeSinceCheck=" .. timeSinceCheck .. ", lastUpdate=" .. (nav.lastPositionUpdate - nav.navigationStart) .. ", lastCheck=" .. (nav.lastPositionCheck - nav.navigationStart))

      -- Check timeout
      if timeSinceCheck > config.commandTimeout then
        navDebug(state, "TIMEOUT - moving to stuck state")
        nav.state = "stuck"
        return
      end

      -- Check if position was updated after we requested it
      if nav.lastPositionUpdate >= nav.lastPositionCheck then
        navDebug(state, "Position updated, moving to calculating_route")
        nav.state = "calculating_route"
      end
    end,

    calculating_route = function()
      local currentX, currentY = getSectorPosition()
      local targetX = nav.target.sectorPositionX
      local targetY = nav.target.sectorPositionY
      navDebug(state, "current=(" .. currentX .. ", " .. currentY .. "), target=(" .. targetX .. ", " .. targetY .. ")")

      local distance = calculateDistance(currentX, currentY, targetX, targetY)

      if distance < config.arrivalThreshold then
        navDebug(state, "ARRIVED! distance=" .. distance .. " < threshold=" .. config.arrivalThreshold)
        nav.state = "arrived"
      else
        -- Calculate and store target heading for rotation
        nav.targetHeading = calculateHeading(currentX, currentY, targetX, targetY)
        navDebug(state, "distance=" .. distance .. ", targetHeading=" .. nav.targetHeading .. ", moving to rotating_to_heading")
        nav.state = "rotating_to_heading"
      end
    end,

    rotating_to_heading = function()
      local currentHeading = getShipHeading()
      local targetHeading = nav.targetHeading
      navDebug(state, "currentHeading=" .. currentHeading .. ", targetHeading=" .. targetHeading)

      local rotation = calculateRotation(currentHeading, targetHeading)

      -- Only rotate if rotation is significant (> 2 degrees)
      if math.abs(rotation) > 2 then
        sendNavigationCommand("rot " .. rotation)
        nav.state = "awaiting_rotation_confirmation"
      else
        navDebug(state, "Already aligned (rotation=" .. rotation .. "), moving to setting_speed")
        nav.state = "setting_speed"
      end
    end,

    awaiting_rotation_confirmation = function()
      local timeSinceCommand = os.time() - nav.lastCommand
      navDebug(state, "timeSinceCommand=" .. timeSinceCommand)

      if timeSinceCommand > config.commandTimeout then
        navDebug(state, "TIMEOUT - moving to stuck state")
        nav.state = "stuck"
        return
      end

      -- Check if rotation completed by comparing current heading to target
      local currentHeading = getShipHeading()
      local targetHeading = nav.targetHeading
      local headingDiff = math.abs(currentHeading - targetHeading)

      -- Account for wrap-around (359 vs 1 degree)
      if headingDiff > 180 then
        headingDiff = 360 - headingDiff
      end

      navDebug(state, "currentHeading=" .. currentHeading .. ", targetHeading=" .. targetHeading .. ", diff=" .. headingDiff)

      if headingDiff < 5 then  -- Within 5 degrees is good enough
        navDebug(state, "Rotation complete, moving to setting_speed")
        nav.state = "setting_speed"
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
        if speedType == "WARP" then
          sendNavigationCommand("warp " .. speedValue)
        else
          sendNavigationCommand("imp " .. speedValue)
        end
        nav.state = "awaiting_speed_confirmation"
      else
        navDebug(state, "Speed already correct, moving to traveling")
        nav.state = "traveling"
      end
    end,

    awaiting_speed_confirmation = function()
      local timeSinceCommand = os.time() - nav.lastCommand
      navDebug(state, "timeSinceCommand=" .. timeSinceCommand)

      if timeSinceCommand > config.commandTimeout then
        navDebug(state, "TIMEOUT - moving to stuck state")
        nav.state = "stuck"
        return
      end

      if timeSinceCommand > 1 then
        navDebug(state, "Speed confirmed, moving to traveling")
        nav.state = "traveling"
      end
    end,

    traveling = function()
      local timeSinceCheck = os.time() - nav.lastPositionCheck
      navDebug(state, "timeSinceCheck=" .. timeSinceCheck .. ", pollingInterval=" .. config.pollingInterval)

      if timeSinceCheck >= config.pollingInterval then
        navDebug(state, "Time to check position again, moving to requesting_position")
        nav.state = "requesting_position"
      end
    end,

    arrived = function()
      sendNavigationCommand("warp 0")
      nav.state = "stopping"
    end,

    stopping = function()
      local currentSpeed = getWarpSpeed()
      navDebug(state, "currentSpeed=" .. currentSpeed)

      if currentSpeed == 0 then
        -- For planet navigation, check if we've achieved orbit
        if nav.phase == "planet" then
          navDebug(state, "Ship stopped, checking orbit status")
          nav.state = "awaiting_orbit"
        else
          navDebug(state, "Ship stopped, moving to completed")
          nav.state = "completed"
        end
      end
    end,

    awaiting_orbit = function()
      local orbitingPlanet = getOrbitingPlanet()
      local targetPlanet = nav.target.planetNumber
      navDebug(state, "orbitingPlanet=" .. tostring(orbitingPlanet) .. ", targetPlanet=" .. targetPlanet)

      if orbitingPlanet == targetPlanet then
        navDebug(state, "Successfully orbiting planet " .. targetPlanet)
        navLog("Successfully orbiting planet " .. targetPlanet .. "!")
        nav.state = "completed"
      else
        -- Not orbiting yet - auto-orbit trigger should engage if we're close enough
        -- Wait a bit for the trigger to fire
        navDebug(state, "Waiting for orbit confirmation...")
      end
    end,

    completed = function()
      navDebug(state, "Navigation completed successfully")
      navLog("Navigation completed!")
      nav.active = false
      nav.state = "idle"
    end,

    stuck = function()
      navDebug(state, "Navigation stuck, aborting")
      navError("Navigation stuck in previous state")
      nav.state = "aborted"
    end,

    aborted = function()
      navDebug(state, "Navigation aborted")
      navError("Navigation aborted - coming to a stop")
      sendNavigationCommand("war 0 0")
      nav.active = false
      nav.state = "idle"
    end
  }

  -- Execute current state
  if actions[state] then
    actions[state]()
  end
end
