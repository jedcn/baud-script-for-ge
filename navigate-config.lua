-- navigate-config.lua
-- User-configurable navigation settings

-- Initialize navigation state structure if needed
if not gePackage.navigation then
  gePackage.navigation = {
    active = false,
    phase = nil,
    target = {},
    state = "idle",
    lastPositionCheck = 0,
    lastPositionUpdate = 0,
    lastCommand = 0,
    lastScanUpdate = 0,
    targetHeading = nil,
    planetScan = {
      bearing = nil,
      distance = nil
    },
    config = {}
  }
end

-- Distance covered per warp level per tick (confirmed via Freight Barge and Star Cruiser observation)
local DISTANCE_PER_WARP = 154

-- Returns total distance needed to stop from fromWarp at the given decelRate.
-- Each decel tick: warp drops by decelRate, ship travels new_warp * DISTANCE_PER_WARP.
local function computeStopDistance(fromWarp, decelRate)
  local dist = 0
  local w = fromWarp
  while w > 0 do
    w = math.max(0, w - decelRate)
    dist = dist + w * DISTANCE_PER_WARP
  end
  return dist
end

-- Set configuration (will be available to navigate.lua)
gePackage.navigation.config = {
  -- show debug output?
  debug = false,

  -- Distance thresholds
  arrivalThreshold = 300,           -- Stop within this distance
  planetArrivalThreshold = 250,     -- For Phase 2

  -- Timing
  scanInterval = 3,                 -- Seconds between position/scan requests to server
  commandTimeout = 30,              -- Timeout for command responses
  maxStuckTime = 60,               -- Abort if stuck this long

  -- Speed decision function (distance-based, user can customize)
  decideSpeed = function(distance, currentSpeed)
    local maxWarp = getShipMaxWarp()
    local decelRate = getShipDecelRate()

    -- Threshold for a given warp: start decelerating (or stop accelerating) when within this distance.
    -- Uses the larger of 2× computed stop distance or one tick of travel at that warp.
    -- The one-tick floor ensures we always have at least one tick to react before overshooting.
    local function threshold(warp)
      return math.max(computeStopDistance(warp, decelRate) * 2.0, warp * DISTANCE_PER_WARP)
    end

    -- Build speed tiers: the natural deceleration steps from maxWarp down to 0.
    -- e.g. FB (decelRate=2):  {15, 13, 11, 9, 7, 5, 3, 1, 0}
    --      SC (decelRate=20): {25, 5, 0}
    --      Constitution (decelRate=40): {30, 0}  -- drops straight to stop
    local tiers = {}
    local w = maxWarp
    while w > 0 do
      table.insert(tiers, w)
      w = math.max(0, w - decelRate)
    end
    table.insert(tiers, 0)

    -- Deceleration: if within threshold for current tier, drop to next tier down
    for i = 1, #tiers - 1 do
      if currentSpeed >= tiers[i] and distance < threshold(tiers[i]) then
        return "WARP", tiers[i + 1]
      end
    end

    -- Acceleration: speed up to the highest tier whose threshold we exceed
    for i = 1, #tiers - 1 do
      if distance > threshold(tiers[i]) then
        return "WARP", tiers[i]
      end
    end

    -- Short range: use impulse
    -- IMPORTANT: Can't go directly from WARP to IMPULSE — must stop at warp 0 first.
    -- If already in impulse (0 < speed < 1), no stop needed.
    if currentSpeed >= 1 then return "WARP", 0 end
    return "IMPULSE", 0.99  -- 0.99 = warp representation of imp 99
  end
}
