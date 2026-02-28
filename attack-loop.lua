-- attack-loop.lua
-- Automated assault loop: supply → attack → escape → repeat

-- ============================================================================
-- Configuration (change these for different planet assaults)
-- ============================================================================

local assaultConfig = {
  supply = {
    sectorX = 9,
    sectorY = -11,
    posX = 5000,
    posY = 8000,
    planet = 3
  },
  target = {
    sectorX = 11,
    sectorY = -9,
    posX = 3000,
    posY = 1000,
    planet = 3
  },
  escapeHeading = 0,
  troopCount = 249980
}

-- ============================================================================
-- State Management
-- ============================================================================

function initAttackLoop()
  gePackage.attackLoop = {
    active = false,
    state = "idle",
    startedAt = nil,
    lastStateChange = nil
  }
end

function getAttackLoopActive()
  return gePackage.attackLoop and gePackage.attackLoop.active or false
end

function getAttackLoopState()
  return gePackage.attackLoop and gePackage.attackLoop.state or "idle"
end

function setAttackLoopState(newState)
  if gePackage.attackLoop then
    local oldState = gePackage.attackLoop.state
    gePackage.attackLoop.state = newState
    gePackage.attackLoop.lastStateChange = os.time()
    cecho("#ff00ff", "[assault][state] " .. oldState .. " -> " .. newState)
  end
end

-- ============================================================================
-- Start / Cancel / Status
-- ============================================================================

function startAssault()
  if getAttackLoopActive() then
    echo("Assault loop is already running (state: " .. getAttackLoopState() .. ")")
    return
  end

  initAttackLoop()
  gePackage.attackLoop.active = true
  gePackage.attackLoop.startedAt = os.time()

  cecho("#ff00ff", "[assault] Starting assault loop")
  setAttackLoopState("going_home")
  local cfg = assaultConfig.supply
  navigateToSectorAndPlanet(cfg.sectorX, cfg.sectorY, cfg.posX, cfg.posY, cfg.planet)
end

function cancelAssault()
  if not getAttackLoopActive() then
    echo("Assault loop is not running.")
    return
  end

  cecho("#ff00ff", "[assault] Cancelled by user")
  gePackage.attackLoop.active = false
  gePackage.attackLoop.state = "idle"
end

function assaultStatus()
  if not getAttackLoopActive() then
    echo("Assault loop: inactive")
    return
  end

  local state = getAttackLoopState()
  local elapsed = os.time() - (gePackage.attackLoop.startedAt or os.time())
  local stateElapsed = os.time() - (gePackage.attackLoop.lastStateChange or os.time())
  echo("Assault loop: " .. state .. " (running " .. elapsed .. "s, in state " .. stateElapsed .. "s)")
end

-- ============================================================================
-- Tick Function
-- ============================================================================

function attackLoopTick()
  if not getAttackLoopActive() then return end

  local state = getAttackLoopState()
  local cfg = assaultConfig

  if state == "going_home" then
    -- Wait for navigation to complete and orbit supply planet
    if not getNavigationActive() and not getSectorNavActive() then
      local orbiting = getOrbitingPlanet()
      if orbiting == cfg.supply.planet then
        setAttackLoopState("repairing")
        flipAwayFromPlanet()
        doMaint()
      end
    end

  elseif state == "repairing" then
    -- Wait for ship to be fully repaired
    if getShipStatus() == "No damage" then
      setAttackLoopState("loading")
      send("tra up 1 flu")
      send("flu")
      send("tra up " .. cfg.troopCount .. " tro")
      navigateToSectorAndPlanet(cfg.target.sectorX, cfg.target.sectorY, cfg.target.posX, cfg.target.posY, cfg.target.planet)
    end

  elseif state == "loading" then
    -- Wait for navigation to complete and orbit target planet
    if not getNavigationActive() and not getSectorNavActive() then
      local orbiting = getOrbitingPlanet()
      if orbiting == cfg.target.planet then
        setAttackLoopState("rotating")
        rotateToHeading(cfg.escapeHeading)
      end
    end

  elseif state == "rotating" then
    -- Wait for rotto to complete
    if not getRottoActive() then
      local heading = getShipHeading()
      if heading and math.abs(heading - cfg.escapeHeading) <= 2 then
        setAttackLoopState("checking_shields")
        send("shi up")
        send("rep sys")
      end
    end

  elseif state == "checking_shields" then
    -- Wait for shields to reach 100%
    local charge = getShieldCharge()
    if charge and charge >= 100 then
      setAttackLoopState("attacking")
      send("attack " .. cfg.troopCount .. " tro")
      send("imp 99 " .. cfg.escapeHeading)
    end

  elseif state == "attacking" then
    -- Transition immediately to escaping
    setAttackLoopState("escaping")

  elseif state == "escaping" then
    -- Wait until we leave the target sector
    local sX, sY = getSector()
    if sX and sY then
      if sX ~= cfg.target.sectorX or sY ~= cfg.target.sectorY then
        setAttackLoopState("going_home")
        navigateToSectorAndPlanet(cfg.supply.sectorX, cfg.supply.sectorY, cfg.supply.posX, cfg.supply.posY, cfg.supply.planet)
      end
    end
  end
end

-- Initialize on load
if not gePackage.attackLoop then
  initAttackLoop()
end
