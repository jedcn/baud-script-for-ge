-- combat.lua
-- Ship-to-ship combat commands

local function combatLog(s)
  cecho("#ff4400", "[combat] " .. s)
end

-- ============================================================================
-- State Management
-- ============================================================================

function initCombat()
  gePackage.combat = {
    active = false,
    state = "idle",
    shipBearing = nil,
    lastCommand = 0,
    warpAndFirePendingShip = nil,
    dropWarpAfterFire = false
  }
end

function getCombatActive()
  return gePackage.combat and gePackage.combat.active or false
end

function getCombatState()
  return gePackage.combat and gePackage.combat.state or "idle"
end

-- ============================================================================
-- fire_phasers_at_ship: scan target ship and fire phasers at its bearing
-- ============================================================================

function fire_phasers_at_ship(shipLetter)
  local sectorX, sectorY = getSector()
  if sectorX == 0 and sectorY == 0 then
    echo("In sector 0 0 - refusing to fire phasers (ship would be destroyed)")
    return
  end

  if getCombatActive() then
    combatLog("Already in progress (state: " .. getCombatState() .. ")")
    return
  end

  initCombat()
  gePackage.combat.active = true
  gePackage.combat.state = "scanning"
  gePackage.combat.shipLetter = shipLetter
  gePackage.combat.lastCommand = os.time()

  combatLog("Scanning ship " .. shipLetter)
  send("scan sh " .. shipLetter)
end

-- Called from trigger when ship scan bearing line is parsed
function setCombatShipBearingFromTrigger(bearing)
  if not getCombatActive() or getCombatState() ~= "scanning" then return end

  bearing = tonumber(bearing)
  gePackage.combat.shipBearing = bearing

  local warpSpeed = getWarpSpeed()

  if warpSpeed == nil then
    -- Unknown speed: send both to cover either case, then raise shields
    combatLog("Bearing " .. bearing .. ", warp unknown - sending both pha commands")
    send("pha " .. bearing)
    send("pha " .. bearing .. " 1")
    send("shi up")
  elseif warpSpeed >= 1 then
    -- In warp: no trailing 1, no shields available
    local cmd = "pha " .. bearing
    combatLog("Bearing " .. bearing .. ", warp " .. warpSpeed .. ", firing: " .. cmd)
    send(cmd)
  else
    -- Stopped or impulse: trailing 1, then raise shields
    local cmd = "pha " .. bearing .. " 1"
    combatLog("Bearing " .. bearing .. ", warp " .. warpSpeed .. ", firing: " .. cmd)
    send(cmd)
    send("shi up")
  end

  if gePackage.combat.dropWarpAfterFire then
    gePackage.combat.dropWarpAfterFire = false
    send("warp 0")
  end

  gePackage.combat.active = false
  gePackage.combat.state = "idle"
end

-- ============================================================================
-- torpedo_at_ship: fire three torpedoes at target ship, then raise shields
-- ============================================================================

function torpedo_at_ship(shipLetter)
  send("tor " .. shipLetter)
  send("tor " .. shipLetter)
  send("tor " .. shipLetter)
  send("shi up")
end

-- ============================================================================
-- missile_at_ship: fire three missiles at target ship, then raise shields
-- ============================================================================

function missile_at_ship(shipLetter)
  send("flu")
  send("missile " .. shipLetter .. " 50000")
  send("flu")
  send("missile " .. shipLetter .. " 50000")
  send("flu")
  send("missile " .. shipLetter .. " 50000")
  send("flu")
  send("shi up")
end

-- ============================================================================
-- deploy_decoys: send decoy command five times
-- ============================================================================

function deploy_decoys()
  send("decoy")
  send("decoy")
  send("decoy")
  send("decoy")
  send("decoy")
end

-- ============================================================================
-- warp_and_fire_at_ship: go to warp 1, fire phasers, then drop back to impulse
-- ============================================================================

function warp_and_fire_at_ship(shipLetter)
  if getCombatActive() then
    combatLog("Already in progress (state: " .. getCombatState() .. ")")
    return
  end
  if gePackage.combat.warpAndFirePendingShip then
    combatLog("Warp-and-fire already pending for ship " .. gePackage.combat.warpAndFirePendingShip)
    return
  end
  combatLog("Warp-and-fire: going to warp 1, then firing at " .. shipLetter)
  gePackage.combat.warpAndFirePendingShip = shipLetter
  send("warp 1")
end

-- Called from warp-speed trigger when warp speed changes
function handleWarpSpeedForCombat(warpSpeed)
  local pendingShip = gePackage.combat and gePackage.combat.warpAndFirePendingShip
  if not pendingShip then return end
  if tonumber(warpSpeed) >= 1 then
    gePackage.combat.warpAndFirePendingShip = nil
    fire_phasers_at_ship(pendingShip)
    -- fire_phasers_at_ship calls initCombat() which resets dropWarpAfterFire,
    -- so we re-set it here after that call
    gePackage.combat.dropWarpAfterFire = true
  end
end

-- Initialize on load
if not gePackage.combat then
  initCombat()
end
