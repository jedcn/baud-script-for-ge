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
    targetHeading = nil,
    config = {}
  }
end

-- Set configuration (will be available to navigate.lua)
gePackage.navigation.config = {
  -- Distance thresholds
  arrivalThreshold = 150,           -- Stop within this distance
  planetArrivalThreshold = 250,     -- For Phase 2

  -- Timing
  pollingInterval = 3,              -- Seconds between position checks
  commandTimeout = 18,              -- Timeout for command responses
  maxStuckTime = 60,               -- Abort if stuck this long

  -- Speed decision function (distance-based, user can customize)
  decideSpeed = function(distance, currentSpeed)
    -- Deceleration logic: slow down before arrival
    if currentSpeed >= 5 and distance < 2000 then
      return "WARP", 3  -- Start slowing from warp 5
    end
    if currentSpeed >= 3 and distance < 1000 then
      return "WARP", 2  -- Slow from warp 3
    end
    if currentSpeed >= 2 and distance < 500 then
      return "WARP", 1  -- Slow from warp 2
    end

    -- Acceleration logic: speed up for long distances
    if distance > 2000 then return "WARP", 5 end
    if distance > 1000 then return "WARP", 3 end
    if distance > 500 then return "WARP", 2 end
    if distance > 200 then return "WARP", 1 end
    return "IMPULSE", 99
  end,

  -- Interruption detection
  detectInterruption = true,        -- Abort if heading/speed changes unexpectedly
  lastKnownHeading = nil,
  lastKnownSpeed = nil
}
