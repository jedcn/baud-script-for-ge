-- navigate.lua
-- Autonomous navigation system for Galactic Empire

-- Initialize navigation state
if not gePackage.navigation then
  gePackage.navigation = {
    active = false,
    phase = nil,
    target = {},
    state = "idle",
    lastPositionCheck = 0,
    lastPositionUpdate = 0,
    lastCommand = 0,
    targetHeading = nil
  }
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

function calculateDistance(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

function calculateHeading(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  local angleRadians = math.atan(dx, -dy)
  local angleDegrees = angleRadians * 180 / math.pi

  if angleDegrees < 0 then
    angleDegrees = angleDegrees + 360
  end

  return math.floor(angleDegrees + 0.5)
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

  return math.floor(diff + 0.5)
end

function sendNavigationCommand(command)
  gePackage.navigation.lastCommand = os.time()
  send(command)
end

-- ============================================================================
-- API Functions
-- ============================================================================

function navigateToCoordinates(x, y)
  -- Validate coordinates (0-10000)
  if x < 0 or x > 10000 or y < 0 or y > 10000 then
    echo("ERROR: Invalid coordinates. Must be 0-10000.")
    return false
  end

  -- Initialize navigation
  gePackage.navigation.active = true
  gePackage.navigation.phase = "coordinate"
  gePackage.navigation.target.sectorPositionX = tonumber(x)
  gePackage.navigation.target.sectorPositionY = tonumber(y)
  gePackage.navigation.state = "requesting_position"
  gePackage.navigation.lastPositionCheck = 0
  gePackage.navigation.lastPositionUpdate = 0

  echo("Navigation started to (" .. x .. ", " .. y .. ")")
  return true
end

function cancelNavigation()
  if not gePackage.navigation.active then
    echo("No navigation in progress")
    return
  end

  gePackage.navigation.active = false
  gePackage.navigation.state = "aborted"
  send("warp 0")
  echo("Navigation cancelled")
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

-- Stubs for future phases
function navigateToPlanet(planetNumber)
  echo("Phase 2 not yet implemented")
end

function navigateToSector(sectorX, sectorY)
  echo("Phase 3 not yet implemented")
end

function navigateToSectorAndPlanet(sectorX, sectorY, planetNumber)
  echo("Phase 5 not yet implemented")
end

-- ============================================================================
-- Legacy function (kept for backward compatibility)
-- ============================================================================

function navigateWithinSectorTo(destX, destY)
  local currentX, currentY = getSectorPosition()
  local heading = calculateHeading(currentX, currentY, destX, destY)
  echo("Navigate to heading: " .. heading .. " degrees")
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
    idle = function() end,

    requesting_position = function()
      sendNavigationCommand("rep nav")
      nav.state = "awaiting_position"
      nav.lastPositionCheck = os.time()
    end,

    awaiting_position = function()
      local timeSinceCheck = os.time() - nav.lastPositionCheck

      -- Check timeout
      if timeSinceCheck > config.commandTimeout then
        nav.state = "stuck"
        return
      end

      -- Check if position was updated after we requested it
      if nav.lastPositionUpdate > nav.lastPositionCheck then
        nav.state = "calculating_route"
      end
    end,

    calculating_route = function()
      local currentX, currentY = getSectorPosition()
      local targetX = nav.target.sectorPositionX
      local targetY = nav.target.sectorPositionY

      local distance = calculateDistance(currentX, currentY, targetX, targetY)

      if distance < config.arrivalThreshold then
        nav.state = "arrived"
      else
        -- Calculate and store target heading for rotation
        nav.targetHeading = calculateHeading(currentX, currentY, targetX, targetY)
        nav.state = "rotating_to_heading"
      end
    end,

    rotating_to_heading = function()
      local currentHeading = getShipHeading()
      local targetHeading = nav.targetHeading

      local rotation = calculateRotation(currentHeading, targetHeading)

      -- Only rotate if rotation is significant (> 2 degrees)
      if math.abs(rotation) > 2 then
        sendNavigationCommand("rot " .. rotation)
        nav.state = "awaiting_rotation_confirmation"
      else
        -- Already pointing in right direction
        nav.state = "setting_speed"
      end
    end,

    awaiting_rotation_confirmation = function()
      local timeSinceCommand = os.time() - nav.lastCommand

      if timeSinceCommand > config.commandTimeout then
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

      if headingDiff < 5 then  -- Within 5 degrees is good enough
        nav.state = "setting_speed"
      end
    end,

    setting_speed = function()
      local currentX, currentY = getSectorPosition()
      local targetX = nav.target.sectorPositionX
      local targetY = nav.target.sectorPositionY
      local distance = calculateDistance(currentX, currentY, targetX, targetY)
      local currentSpeed = getWarpSpeed() or 0

      local speedType, speedValue = config.decideSpeed(distance, currentSpeed)

      -- Only send command if speed needs to change
      if math.abs(currentSpeed - speedValue) > 0.1 then
        if speedType == "WARP" then
          sendNavigationCommand("warp " .. speedValue)
        else
          sendNavigationCommand("imp " .. speedValue)
        end
        nav.state = "awaiting_speed_confirmation"
      else
        -- Speed already correct, start traveling
        nav.state = "traveling"
      end
    end,

    awaiting_speed_confirmation = function()
      local timeSinceCommand = os.time() - nav.lastCommand

      if timeSinceCommand > config.commandTimeout then
        nav.state = "stuck"
        return
      end

      if timeSinceCommand > 1 then
        -- Store current heading/speed for interruption detection
        config.lastKnownHeading = getShipHeading()
        config.lastKnownSpeed = getWarpSpeed()
        nav.state = "traveling"
      end
    end,

    traveling = function()
      -- Check for interruption (unexpected heading/speed change)
      if config.detectInterruption then
        local currentHeading = getShipHeading()
        local currentSpeed = getWarpSpeed()

        if config.lastKnownHeading and math.abs(currentHeading - config.lastKnownHeading) > 5 then
          cecho("<red>Navigation interrupted - heading changed unexpectedly\n")
          nav.state = "aborted"
          return
        end

        if config.lastKnownSpeed and math.abs(currentSpeed - config.lastKnownSpeed) > 0.5 then
          cecho("<red>Navigation interrupted - speed changed unexpectedly\n")
          nav.state = "aborted"
          return
        end
      end

      local timeSinceCheck = os.time() - nav.lastPositionCheck

      if timeSinceCheck >= config.pollingInterval then
        nav.state = "requesting_position"
      end
    end,

    arrived = function()
      sendNavigationCommand("warp 0")
      nav.state = "stopping"
    end,

    stopping = function()
      local currentSpeed = getWarpSpeed()

      if currentSpeed == 0 then
        nav.state = "completed"
      end
    end,

    completed = function()
      echo("Navigation completed!")
      nav.active = false
      nav.state = "idle"
    end,

    stuck = function()
      cecho("<red>Navigation stuck in previous state\n")
      nav.state = "aborted"
    end,

    aborted = function()
      cecho("<red>Navigation aborted\n")
      nav.active = false
      nav.state = "idle"
    end
  }

  -- Execute current state
  if actions[state] then
    actions[state]()
  end
end
