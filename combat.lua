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
    lastCommand = 0
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
    -- Unknown speed: send both to cover either case
    combatLog("Bearing " .. bearing .. ", warp unknown - sending both pha commands")
    send("pha " .. bearing)
    send("pha " .. bearing .. " 1")
  elseif warpSpeed >= 1 then
    -- In warp: no trailing 1
    local cmd = "pha " .. bearing
    combatLog("Bearing " .. bearing .. ", warp " .. warpSpeed .. ", firing: " .. cmd)
    send(cmd)
  else
    -- Stopped or impulse: trailing 1
    local cmd = "pha " .. bearing .. " 1"
    combatLog("Bearing " .. bearing .. ", warp " .. warpSpeed .. ", firing: " .. cmd)
    send(cmd)
  end

  gePackage.combat.active = false
  gePackage.combat.state = "idle"
end

-- Initialize on load
if not gePackage.combat then
  initCombat()
end
