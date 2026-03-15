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

    -- Deceleration: drop to next lower tier when within that tier's threshold
    if currentSpeed >= maxWarp and distance < threshold(maxWarp) then return "WARP", 5 end
    if currentSpeed >= 5      and distance < threshold(5)       then return "WARP", 3 end
    if currentSpeed >= 3      and distance < threshold(3)       then return "WARP", 2 end
    if currentSpeed >= 2      and distance < threshold(2)       then return "WARP", 1 end
    if currentSpeed >= 1      and distance < threshold(1)       then return "WARP", 0 end

    -- Acceleration: speed up when farther than that tier's threshold
    if distance > threshold(maxWarp) then return "WARP", maxWarp end
    if distance > threshold(5)       then return "WARP", 5 end
    if distance > threshold(3)       then return "WARP", 3 end
    if distance > threshold(2)       then return "WARP", 2 end
    if distance > threshold(1)       then return "WARP", 1 end

    -- Short range: use impulse
    -- IMPORTANT: Can't go directly from WARP to IMPULSE — must stop at warp 0 first.
    -- If already in impulse (0 < speed < 1), no stop needed.
    if currentSpeed >= 1 then return "WARP", 0 end
    return "IMPULSE", 0.99  -- 0.99 = warp representation of imp 99
  end
}
