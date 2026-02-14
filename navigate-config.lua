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

-- Set configuration (will be available to navigate.lua)
gePackage.navigation.config = {
  -- show debug output?
  debug = false,

  -- Distance thresholds
  arrivalThreshold = 150,           -- Stop within this distance
  planetArrivalThreshold = 250,     -- For Phase 2

  -- Timing
  pollingInterval = 3,              -- Seconds between position checks
  commandTimeout = 18,              -- Timeout for command responses
  maxStuckTime = 60,               -- Abort if stuck this long

  -- Speed decision function (distance-based, user can customize)
  decideSpeed = function(distance, currentSpeed)
    -- Deceleration logic: slow down well before arrival
    -- Thresholds are wide to account for 3-second polling intervals
    if currentSpeed >= 5 and distance < 5000 then
      return "WARP", 3  -- Start slowing from warp 5
    end
    if currentSpeed >= 3 and distance < 3000 then
      return "WARP", 2  -- Slow from warp 3
    end
    if currentSpeed >= 2 and distance < 1500 then
      return "WARP", 1  -- Slow from warp 2
    end
    if currentSpeed >= 1 and distance < 1000 then
      return "WARP", 0  -- Drop out of warp before impulse
    end

    -- Acceleration logic: speed up for long distances
    if distance > 5000 then return "WARP", 5 end
    if distance > 3000 then return "WARP", 3 end
    if distance > 1500 then return "WARP", 2 end
    if distance > 1000 then return "WARP", 1 end

    -- For short distances (≤ 1000), use impulse
    -- IMPORTANT: Can't go directly from WARP to IMPULSE
    -- Must stop at warp 0 first, then engage impulse
    if currentSpeed > 0 then
      return "WARP", 0  -- Drop out of warp first
    end

    return "IMPULSE", 99  -- Safe to use impulse (we're stopped)
  end
}
