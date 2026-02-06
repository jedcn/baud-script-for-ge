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
  local distance = math.sqrt(dx * dx + dy * dy)
  log("calculateDistance(" .. x1 .. ", " .. y1 .. ", " .. x2 .. ", " .. y2 .. ") = " .. distance)
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
  log("calculateHeading(" .. x1 .. ", " .. y1 .. ", " .. x2 .. ", " .. y2 .. ") = " .. heading)
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
  log("calculateRotation(current: " .. currentHeading .. ", goal: " .. goalHeading .. ") = " .. rotation)
  return rotation
end

function sendNavigationCommand(command)
  log("sendNavigationCommand: " .. command)
  gePackage.navigation.lastCommand = os.time()
  send(command)
end

-- ============================================================================
-- API Functions
-- ============================================================================

function navigateToCoordinates(x, y)
  log("navigateToCoordinates(" .. tostring(x) .. ", " .. tostring(y) .. ")")

  -- Convert to numbers first
  x = tonumber(x)
  y = tonumber(y)

  -- Validate coordinates (0-10000)
  if x < 0 or x > 10000 or y < 0 or y > 10000 then
    echo("ERROR: Invalid coordinates. Must be 0-10000.")
    return false
  end

  -- Initialize navigation
  gePackage.navigation.active = true
  gePackage.navigation.phase = "coordinate"
  gePackage.navigation.target.sectorPositionX = x
  gePackage.navigation.target.sectorPositionY = y
  gePackage.navigation.state = "requesting_position"
  gePackage.navigation.lastPositionCheck = 0
  gePackage.navigation.lastPositionUpdate = 0

  log("Navigation initialized: target=(" .. x .. ", " .. y .. "), state=" .. gePackage.navigation.state)
  echo("Navigation started to (" .. x .. ", " .. y .. ")")
  return true
end

function cancelNavigation()
  log("cancelNavigation()")
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

  log("navigationTick: state=" .. state)

  -- State handler functions
  local actions = {
    idle = function()
      log("  [idle] No action")
    end,

    requesting_position = function()
      log("  [requesting_position] Sending 'rep nav'")
      sendNavigationCommand("rep nav")
      nav.state = "awaiting_position"
      nav.lastPositionCheck = os.time()
    end,

    awaiting_position = function()
      local timeSinceCheck = os.time() - nav.lastPositionCheck
      log("  [awaiting_position] timeSinceCheck=" .. timeSinceCheck .. ", lastUpdate=" .. nav.lastPositionUpdate .. ", lastCheck=" .. nav.lastPositionCheck)

      -- Check timeout
      if timeSinceCheck > config.commandTimeout then
        log("  [awaiting_position] TIMEOUT - moving to stuck state")
        nav.state = "stuck"
        return
      end

      -- Check if position was updated after we requested it
      if nav.lastPositionUpdate > nav.lastPositionCheck then
        log("  [awaiting_position] Position updated, moving to calculating_route")
        nav.state = "calculating_route"
      end
    end,

    calculating_route = function()
      local currentX, currentY = getSectorPosition()
      local targetX = nav.target.sectorPositionX
      local targetY = nav.target.sectorPositionY
      log("  [calculating_route] current=(" .. currentX .. ", " .. currentY .. "), target=(" .. targetX .. ", " .. targetY .. ")")

      local distance = calculateDistance(currentX, currentY, targetX, targetY)

      if distance < config.arrivalThreshold then
        log("  [calculating_route] ARRIVED! distance=" .. distance .. " < threshold=" .. config.arrivalThreshold)
        nav.state = "arrived"
      else
        -- Calculate and store target heading for rotation
        nav.targetHeading = calculateHeading(currentX, currentY, targetX, targetY)
        log("  [calculating_route] distance=" .. distance .. ", targetHeading=" .. nav.targetHeading .. ", moving to rotating_to_heading")
        nav.state = "rotating_to_heading"
      end
    end,

    rotating_to_heading = function()
      local currentHeading = getShipHeading()
      local targetHeading = nav.targetHeading
      log("  [rotating_to_heading] currentHeading=" .. currentHeading .. ", targetHeading=" .. targetHeading)

      local rotation = calculateRotation(currentHeading, targetHeading)

      -- Only rotate if rotation is significant (> 2 degrees)
      if math.abs(rotation) > 2 then
        log("  [rotating_to_heading] Rotating by " .. rotation .. " degrees")
        sendNavigationCommand("rot " .. rotation)
        nav.state = "awaiting_rotation_confirmation"
      else
        log("  [rotating_to_heading] Already aligned (rotation=" .. rotation .. "), moving to setting_speed")
        nav.state = "setting_speed"
      end
    end,

    awaiting_rotation_confirmation = function()
      local timeSinceCommand = os.time() - nav.lastCommand
      log("  [awaiting_rotation_confirmation] timeSinceCommand=" .. timeSinceCommand)

      if timeSinceCommand > config.commandTimeout then
        log("  [awaiting_rotation_confirmation] TIMEOUT - moving to stuck state")
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

      log("  [awaiting_rotation_confirmation] currentHeading=" .. currentHeading .. ", targetHeading=" .. targetHeading .. ", diff=" .. headingDiff)

      if headingDiff < 5 then  -- Within 5 degrees is good enough
        log("  [awaiting_rotation_confirmation] Rotation complete, moving to setting_speed")
        nav.state = "setting_speed"
      end
    end,

    setting_speed = function()
      local currentX, currentY = getSectorPosition()
      local targetX = nav.target.sectorPositionX
      local targetY = nav.target.sectorPositionY
      local distance = calculateDistance(currentX, currentY, targetX, targetY)
      local currentSpeed = getWarpSpeed() or 0
      log("  [setting_speed] distance=" .. distance .. ", currentSpeed=" .. currentSpeed)

      local speedType, speedValue = config.decideSpeed(distance, currentSpeed)
      log("  [setting_speed] decided: " .. speedType .. " " .. speedValue)

      -- Only send command if speed needs to change
      if math.abs(currentSpeed - speedValue) > 0.1 then
        log("  [setting_speed] Changing speed to " .. speedType .. " " .. speedValue)
        if speedType == "WARP" then
          sendNavigationCommand("warp " .. speedValue)
        else
          sendNavigationCommand("imp " .. speedValue)
        end
        nav.state = "awaiting_speed_confirmation"
      else
        log("  [setting_speed] Speed already correct, moving to traveling")
        nav.state = "traveling"
      end
    end,

    awaiting_speed_confirmation = function()
      local timeSinceCommand = os.time() - nav.lastCommand
      log("  [awaiting_speed_confirmation] timeSinceCommand=" .. timeSinceCommand)

      if timeSinceCommand > config.commandTimeout then
        log("  [awaiting_speed_confirmation] TIMEOUT - moving to stuck state")
        nav.state = "stuck"
        return
      end

      if timeSinceCommand > 1 then
        -- Store current heading/speed for interruption detection
        config.lastKnownHeading = getShipHeading()
        config.lastKnownSpeed = getWarpSpeed()
        log("  [awaiting_speed_confirmation] Speed confirmed, moving to traveling")
        nav.state = "traveling"
      end
    end,

    traveling = function()
      log("  [traveling] Checking interruption and polling interval")

      -- Check for interruption (unexpected heading/speed change)
      if config.detectInterruption then
        local currentHeading = getShipHeading()
        local currentSpeed = getWarpSpeed()

        -- if config.lastKnownHeading and math.abs(currentHeading - config.lastKnownHeading) > 5 then
        --   log("  [traveling] INTERRUPTED - heading changed from " .. config.lastKnownHeading .. " to " .. currentHeading)
        --   cecho("<red>Navigation interrupted - heading changed unexpectedly\n")
        --   nav.state = "aborted"
        --   return
        -- end

        -- if config.lastKnownSpeed and math.abs(currentSpeed - config.lastKnownSpeed) > 0.5 then
        --   log("  [traveling] INTERRUPTED - speed changed from " .. config.lastKnownSpeed .. " to " .. currentSpeed)
        --   cecho("<red>Navigation interrupted - speed changed unexpectedly\n")
        --   nav.state = "aborted"
        --   return
        -- end
      end

      local timeSinceCheck = os.time() - nav.lastPositionCheck
      log("  [traveling] timeSinceCheck=" .. timeSinceCheck .. ", pollingInterval=" .. config.pollingInterval)

      if timeSinceCheck >= config.pollingInterval then
        log("  [traveling] Time to check position again, moving to requesting_position")
        nav.state = "requesting_position"
      end
    end,

    arrived = function()
      log("  [arrived] Stopping ship")
      sendNavigationCommand("warp 0")
      nav.state = "stopping"
    end,

    stopping = function()
      local currentSpeed = getWarpSpeed()
      log("  [stopping] currentSpeed=" .. currentSpeed)

      if currentSpeed == 0 then
        log("  [stopping] Ship stopped, moving to completed")
        nav.state = "completed"
      end
    end,

    completed = function()
      log("  [completed] Navigation completed successfully")
      echo("Navigation completed!")
      nav.active = false
      nav.state = "idle"
    end,

    stuck = function()
      log("  [stuck] Navigation stuck, aborting")
      cecho("<red>Navigation stuck in previous state\n")
      nav.state = "aborted"
    end,

    aborted = function()
      log("  [aborted] Navigation aborted")
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
