-- navigate-nav.lua
-- New navigation API using planTrajectory for pre-planned trajectories.
--
-- Functions:
--   navToPlanet(N)                           - planet in current sector
--   navToShip(letter)                        - toward a ship (one-shot)
--   navToSector(X, Y, posX, posY)            - to a sector with ETA
--   navToSectorAndPlanet(X, Y, posX, posY, N) - sector then planet
--
-- State machine phases managed here: "nav_planet", "nav_ship"
-- Tick function: navNavTick() (called from timers.lua every second)

local function navLog(s)
  cecho("#ff00ff", "[nav] " .. s)
end

local function navError(s)
  cecho("red", "[nav] " .. s)
end

local function etaString(seconds)
  seconds = math.floor(seconds)
  if seconds < 60 then
    return string.format("%ds", seconds)
  end
  return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
end

-- ============================================================================
-- Trigger callbacks for nav_ship phase
-- ============================================================================

-- Called from trigger when a ship scan line arrives: "Bearing: X Heading: Y Dist: Z"
-- Only acts when nav_ship is active and waiting for the scan result.
function setNavShipScanFromTrigger(bearing, distance)
  if not getNavigationActive() then return end
  if getNavigationPhase() ~= "nav_ship" then return end
  if getNavigationState() ~= "navsh_awaiting_scan" then return end
  gePackage.navigation.navShipBearing = tonumber(bearing)
  gePackage.navigation.navShipDistance = tonumber(distance)
end

-- Called from trigger when the game rejects a planet scan ("That would be foolish Sir!").
-- Fails planet navigation immediately rather than waiting for a scan timeout.
function setNavPlanetNotFoundFromTrigger()
  if not getNavigationActive() then return end
  if getNavigationPhase() ~= "nav_planet" then return end
  if getNavigationState() ~= "navpl_awaiting_scan" and getNavigationState() ~= "navpl_awaiting_cruise_scan" then return end
  navError("Planet " .. tostring(gePackage.navigation.target.planetNumber) .. " does not exist in this sector")
  gePackage.navigation.state = "navpl_failed"
end

-- Called from the "Helm reports we are now heading" trigger when rotation completes.
-- Signals completion for both nav_planet and nav_ship awaiting-rotation states.
function setNavNavRotationCompleteFromTrigger()
  if not getNavigationActive() then return end
  local state = getNavigationState()
  if state == "navpl_awaiting_rotation" or state == "navsh_awaiting_rotation" then
    gePackage.navigation.rotationComplete = true
  end
end

-- ============================================================================
-- navToPlanet(N) — navigate to planet N (1-9) in the current sector
-- ============================================================================

function navToPlanet(N)
  N = tonumber(N)
  if not N or N < 1 or N > 9 then
    navError("navToPlanet: invalid planet number (must be 1-9)")
    return false
  end

  if getNavigationActive() then
    navError("Navigation already in progress — nav.cancel first")
    return false
  end

  setNavigationActive(true)
  setNavigationPhase("nav_planet")
  setNavigationTargetPlanet(N)
  setNavigationStart(os.time())
  setNavigationState("navpl_scanning")
  setNavigationLastCommand(0)
  clearNavigationPlanetScan()
  gePackage.navigation.plan = nil
  gePackage.navigation.rotationComplete = false
  gePackage.navigation.orbitAttempts = 0

  navLog("Navigating to planet " .. N .. "...")
  return true
end

-- ============================================================================
-- navToShip(letter) — scan ship, compute warp from distance, travel toward it
-- ============================================================================

function navToShip(letter)
  if getNavigationActive() then
    navError("Navigation already in progress — nav.cancel first")
    return false
  end

  setNavigationActive(true)
  setNavigationPhase("nav_ship")
  setNavigationState("navsh_scanning")
  setNavigationLastCommand(0)
  setNavigationStart(os.time())
  gePackage.navigation.navShipLetter = letter
  gePackage.navigation.navShipBearing = nil
  gePackage.navigation.navShipDistance = nil
  gePackage.navigation.plan = nil
  gePackage.navigation.rotationComplete = false
  gePackage.navigation.deadline = nil

  navLog("Scanning ship " .. letter .. "...")
  return true
end

-- ============================================================================
-- navToSector(X, Y, posX, posY)
-- Wraps the existing navigateToSector; logs ETA before handing off.
-- ============================================================================

function navToSector(X, Y, posX, posY)
  X    = tonumber(X)
  Y    = tonumber(Y)
  posX = tonumber(posX) or 5000
  posY = tonumber(posY) or 5000

  if not X or not Y then
    navError("navToSector: invalid sector coordinates")
    return false
  end

  local curSX, curSY = getSector()
  local curPX, curPY = getSectorPosition()
  if curSX and curSY and curPX and curPY then
    local absX,  absY  = calculateAbsolutePosition(curSX, curSY, curPX, curPY)
    local tAbsX, tAbsY = calculateAbsolutePosition(X, Y, posX, posY)
    local dist = calculateDistance(absX, absY, tAbsX, tAbsY)
    local plan = planTrajectory(dist, getShipMaxWarp(), getShipAccelRate(), getShipDecelRate())
    if plan then
      navLog("navToSector (" .. X .. ", " .. Y .. "): dist=" .. math.floor(dist) ..
             ", warp " .. plan.warp .. ", ETA ~" .. etaString(plan.etaSeconds))
    else
      navLog("navToSector (" .. X .. ", " .. Y .. "): very close (dist=" .. math.floor(dist) .. ")")
    end
  end

  return navigateToSector(X, Y, posX, posY)
end

-- ============================================================================
-- navToSectorAndPlanet(X, Y, posX, posY, N)
-- Wraps the existing navigateToSectorAndPlanet; logs ETA before handing off.
-- ============================================================================

function navToSectorAndPlanet(X, Y, posX, posY, N)
  X    = tonumber(X)
  Y    = tonumber(Y)
  posX = posX and tonumber(posX) or nil
  posY = posY and tonumber(posY) or nil
  N    = tonumber(N)

  if not X or not Y then
    navError("navToSectorAndPlanet: invalid sector coordinates")
    return false
  end
  if not N or N < 1 or N > 9 then
    navError("navToSectorAndPlanet: invalid planet number (must be 1-9)")
    return false
  end

  local curSX, curSY = getSector()
  local curPX, curPY = getSectorPosition()
  if curSX and curSY and curPX and curPY then
    local tPX    = posX or 5000
    local tPY    = posY or 5000
    local absX,  absY  = calculateAbsolutePosition(curSX, curSY, curPX, curPY)
    local tAbsX, tAbsY = calculateAbsolutePosition(X, Y, tPX, tPY)
    local dist = calculateDistance(absX, absY, tAbsX, tAbsY)
    local plan = planTrajectory(dist, getShipMaxWarp(), getShipAccelRate(), getShipDecelRate())
    if plan then
      navLog("navToSectorAndPlanet (" .. X .. ", " .. Y .. ") pl " .. N ..
             ": dist=" .. math.floor(dist) ..
             ", warp " .. plan.warp .. ", ETA ~" .. etaString(plan.etaSeconds) .. " to sector")
    end
  end

  return navigateToSectorAndPlanet(X, Y, posX, posY, N)
end

-- ============================================================================
-- navNavTick() — state machine for nav_planet and nav_ship phases
-- Called every second from mainTick (timers.lua).
-- ============================================================================

function navNavTick()
  if not getNavigationActive() then return end

  local phase = getNavigationPhase()
  if phase ~= "nav_planet" and phase ~= "nav_ship" then return end

  local nav    = gePackage.navigation
  local state  = nav.state
  local config = nav.config

  -- ------------------------------------------------------------------
  -- nav_planet states
  -- ------------------------------------------------------------------

  if phase == "nav_planet" then
    local targetPlanet = nav.target.planetNumber

    -- Success check: already orbiting the target
    if targetPlanet and getOrbitingPlanet() == targetPlanet then
      navLog("Successfully orbiting planet " .. targetPlanet .. "!")
      nav.active = false
      nav.state  = "idle"
      return
    end

    if state == "navpl_scanning" then
      clearNavigationPlanetScan()
      nav.lastCommand = os.time()
      send("scan planet " .. targetPlanet)
      nav.state = "navpl_awaiting_scan"

    elseif state == "navpl_awaiting_scan" then
      if os.time() - nav.lastCommand > config.commandTimeout then
        navError("Timeout waiting for planet scan")
        nav.state = "navpl_failed"
        return
      end
      local bearing  = nav.planetScan.bearing
      local distance = nav.planetScan.distance
      if bearing ~= nil and distance then
        local plan = planTrajectory(distance, getShipMaxWarp(), getShipAccelRate(), getShipDecelRate())
        nav.plan = plan
        if plan then
          navLog("Planet " .. targetPlanet .. ": dist=" .. distance ..
                 ", warp " .. plan.warp .. ", ETA ~" .. etaString(plan.etaSeconds))
        else
          navLog("Planet " .. targetPlanet .. ": very close (dist=" .. distance .. "), going to orbit")
        end
        nav.state = "navpl_rotating"
      end

    elseif state == "navpl_rotating" then
      -- bearing is relative to ship heading; rot <N> is a relative command
      local bearing = nav.planetScan.bearing
      if math.abs(bearing) > 2 then
        nav.rotationComplete = false
        nav.lastCommand = os.time()
        send("rot " .. bearing)
        nav.state = "navpl_awaiting_rotation"
      else
        nav.state = "navpl_setting_warp"
      end

    elseif state == "navpl_awaiting_rotation" then
      if os.time() - nav.lastCommand > config.commandTimeout then
        navError("Timeout waiting for rotation")
        nav.state = "navpl_failed"
        return
      end
      if nav.rotationComplete then
        nav.state = "navpl_setting_warp"
      end

    elseif state == "navpl_setting_warp" then
      local plan = nav.plan
      if plan and plan.warp >= 1 then
        send("warp " .. plan.warp)
      else
        send("imp 99")
      end
      nav.lastCommand = os.time()
      nav.state = "navpl_cruising"

    elseif state == "navpl_cruising" then
      -- Scan every tick (TICK_SECONDS) so decel detection is at most 1 tick stale.
      -- Game ticks are async so a time-based deadline is unreliable; distance is the
      -- only safe decel trigger.
      local timeSince = os.time() - nav.lastCommand
      if timeSince >= TICK_SECONDS then
        clearNavigationPlanetScan()
        nav.lastCommand = os.time()
        send("scan planet " .. targetPlanet)
        nav.state = "navpl_awaiting_cruise_scan"
      end

    elseif state == "navpl_awaiting_cruise_scan" then
      if os.time() - nav.lastCommand > config.commandTimeout then
        navError("Cruise scan timed out, continuing at current warp")
        nav.lastCommand = os.time()
        nav.state = "navpl_cruising"
        return
      end
      local distance = nav.planetScan.distance
      if distance then
        local decelAtDist = nav.plan and nav.plan.decelAtDist or 0
        navLog("Cruising to planet " .. targetPlanet ..
               ": dist=" .. distance .. ", decel at " .. decelAtDist)
        if distance < config.planetArrivalThreshold then
          send("warp 0")
          nav.lastCommand = os.time()
          nav.state = "navpl_decelerating"
        elseif decelAtDist > 0 and distance < decelAtDist then
          send("warp 0")
          nav.lastCommand = os.time()
          nav.state = "navpl_decelerating"
        else
          -- Check if course correction needed (bearing drifted significantly)
          local bearing = nav.planetScan.bearing
          if bearing ~= nil and math.abs(bearing) > 5 then
            send("warp 0")
            nav.state = "navpl_scanning"
            navLog("Course correction needed (bearing=" .. bearing .. "), rescanning")
          else
            nav.state = "navpl_cruising"
          end
        end
      end

    elseif state == "navpl_decelerating" then
      if (getWarpSpeed() or 0) == 0 then
        -- Scan to check actual distance after stopping; ship may have stopped
        -- short of orbit range, requiring an impulse close-in approach.
        clearNavigationPlanetScan()
        nav.lastCommand = os.time()
        send("scan planet " .. targetPlanet)
        nav.state = "navpl_post_stop_scan"
      end

    elseif state == "navpl_post_stop_scan" then
      if os.time() - nav.lastCommand > config.commandTimeout then
        navError("Timeout on post-stop scan, attempting orbit anyway")
        nav.state = "navpl_orbiting"
        return
      end
      local distance = nav.planetScan.distance
      if distance then
        if distance <= config.planetArrivalThreshold then
          nav.state = "navpl_orbiting"
        else
          local bearing = nav.planetScan.bearing or 0
          navLog("Stopped at dist=" .. distance .. " from planet " .. targetPlanet ..
                 " (orbit needs <" .. config.planetArrivalThreshold .. "), bearing=" .. bearing .. ", using impulse")
          send("imp 99 " .. bearing)
          nav.lastCommand = os.time()
          clearNavigationPlanetScan()
          nav.state = "navpl_impulse_approach"
        end
      end

    elseif state == "navpl_impulse_approach" then
      -- Scan every tick while creeping in at impulse
      if os.time() - nav.lastCommand >= TICK_SECONDS then
        clearNavigationPlanetScan()
        nav.lastCommand = os.time()
        send("scan planet " .. targetPlanet)
        nav.state = "navpl_awaiting_impulse_scan"
      end

    elseif state == "navpl_awaiting_impulse_scan" then
      if os.time() - nav.lastCommand > config.commandTimeout then
        navError("Timeout on impulse approach scan, attempting orbit anyway")
        send("warp 0")
        nav.lastCommand = os.time()
        nav.state = "navpl_impulse_stopping"
        return
      end
      local distance = nav.planetScan.distance
      if distance then
        local bearing = nav.planetScan.bearing or 0
        navLog("Impulse approach to planet " .. targetPlanet .. ": dist=" .. distance .. ", bearing=" .. bearing)
        if distance <= config.planetArrivalThreshold then
          send("warp 0")
          nav.lastCommand = os.time()
          nav.state = "navpl_impulse_stopping"
        else
          send("imp 99 " .. bearing)
          nav.lastCommand = os.time()
          nav.state = "navpl_impulse_approach"
        end
      end

    elseif state == "navpl_impulse_stopping" then
      if (getWarpSpeed() or 0) == 0 then
        nav.state = "navpl_orbiting"
      end

    elseif state == "navpl_orbiting" then
      local timeSince = os.time() - (nav.lastCommand or 0)
      if timeSince > 2 then
        nav.orbitAttempts = (nav.orbitAttempts or 0) + 1
        if nav.orbitAttempts > 8 then
          -- Still failing after many attempts; re-approach at impulse
          navLog("Multiple orbit failures, re-scanning for closer approach")
          nav.orbitAttempts = 0
          nav.plan = nil
          nav.decelDeadline = nil
          clearNavigationPlanetScan()
          nav.lastCommand = os.time()
          send("scan planet " .. targetPlanet)
          nav.state = "navpl_post_stop_scan"
          return
        end
        nav.lastCommand = os.time()
        send("orb " .. targetPlanet)
      end

    elseif state == "navpl_failed" then
      navError("Planet navigation failed, stopping")
      send("warp 0")
      nav.active = false
      nav.state  = "idle"
    end

    return
  end

  -- ------------------------------------------------------------------
  -- nav_ship states
  -- ------------------------------------------------------------------

  if phase == "nav_ship" then
    local letter = nav.navShipLetter

    if state == "navsh_scanning" then
      nav.navShipBearing  = nil
      nav.navShipDistance = nil
      nav.lastCommand = os.time()
      send("scan sh " .. letter)
      nav.state = "navsh_awaiting_scan"

    elseif state == "navsh_awaiting_scan" then
      if os.time() - nav.lastCommand > config.commandTimeout then
        navError("Timeout waiting for ship scan")
        nav.state = "navsh_failed"
        return
      end
      local bearing  = nav.navShipBearing
      local distance = nav.navShipDistance
      if bearing ~= nil and distance then
        local plan = planTrajectory(distance, getShipMaxWarp(), getShipAccelRate(), getShipDecelRate())
        nav.plan = plan
        if plan then
          navLog("Ship " .. letter .. ": bearing=" .. bearing ..
                 ", dist=" .. distance ..
                 ", warp " .. plan.warp ..
                 ", ETA ~" .. etaString(plan.etaSeconds))
        else
          navLog("Ship " .. letter .. ": very close (dist=" .. distance .. "), using impulse")
          nav.plan = { warp = 0, etaSeconds = 10, decelAtDist = 0, repNavEvery = 2 }
        end
        nav.state = "navsh_rotating"
      end

    elseif state == "navsh_rotating" then
      local bearing = nav.navShipBearing
      if math.abs(bearing) > 2 then
        nav.rotationComplete = false
        nav.lastCommand = os.time()
        send("rot " .. bearing)
        nav.state = "navsh_awaiting_rotation"
      else
        nav.state = "navsh_launching"
      end

    elseif state == "navsh_awaiting_rotation" then
      if os.time() - nav.lastCommand > config.commandTimeout then
        navError("Timeout waiting for rotation")
        nav.state = "navsh_failed"
        return
      end
      if nav.rotationComplete then
        nav.state = "navsh_launching"
      end

    elseif state == "navsh_launching" then
      local plan = nav.plan
      local warp = plan and plan.warp or 0
      local eta  = plan and plan.etaSeconds or 10
      if warp >= 1 then
        send("warp " .. warp)
        navLog("Launched toward ship " .. letter .. " at warp " .. warp ..
               ", ETA ~" .. etaString(eta))
      else
        send("imp 99")
        navLog("Launched toward ship " .. letter .. " at impulse, ETA ~" .. etaString(eta))
      end
      nav.active = false
      nav.state  = "idle"

    elseif state == "navsh_failed" then
      navError("Ship navigation failed, stopping")
      send("warp 0")
      nav.active = false
      nav.state  = "idle"
    end
  end
end
