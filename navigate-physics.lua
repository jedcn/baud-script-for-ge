-- navigate-physics.lua
-- Pure physics calculations for trajectory planning.
--
-- Key constants (from game source GEMAIN.H / GEFUNCS.C):
--   TICK_SECONDS = 7   measured empirically: ~7s between consecutive warp speed
--                      messages during FB acceleration (game source says 3s but
--                      the MBBS server appears to run at a longer interval)
--   DISTANCE_PER_WARP = 154   in-sector position units per warp per tick
--
-- All functions are pure (no side effects, no game state access) so they
-- are easy to unit test and reuse across any navigation type.

TICK_SECONDS      = 7
DISTANCE_PER_WARP = 154

-- ---------------------------------------------------------------------------
-- computeStopDistance(fromWarp, decelRate)
--
-- Returns the distance (position units) covered from the moment "warp 0" is
-- issued until the ship reaches speed 0.
--
-- When decelRate >= fromWarp the ship drops to warp 0 in a single decel step.
-- Empirically (Dreadnought warp 14, decelRate 30) the game applies decel
-- before movement in this case — the ship stops with zero distance covered.
-- Return 0 for this case.
--
-- When decelRate < fromWarp (multiple decel ticks needed), a 1-tick reaction
-- delay applies: the ship travels at its current warp this tick, then
-- decelerates by decelRate each subsequent tick.
-- Validated: FB warp 15 → 0 covers ~9843 units.
--   Formula: (15+13+11+9+7+5+3+1) × 154 = 9856 ≈ 9843 observed.
-- ---------------------------------------------------------------------------
function computeStopDistance(fromWarp, decelRate)
  if fromWarp <= decelRate then
    return 0  -- stops in one decel step; game applies decel before movement
  end
  local dist = 0
  local w = fromWarp
  while w > 0 do
    dist = dist + w * DISTANCE_PER_WARP  -- travel at current warp first
    w = math.max(0, w - decelRate)       -- then decelerate
  end
  return dist
end

-- ---------------------------------------------------------------------------
-- computeAccelDistance(toWarp, accelRate)
--
-- Returns the distance covered while accelerating from warp 0 to toWarp.
-- Each tick: accel first (speed increases), then move at new speed.
-- This matches the order in game source (accel() runs before moveship()).
--
-- NOTE: Not yet empirically validated in-game. The stop distance formula
-- above was validated (~9843 observed). Accel distance needs measurement.
-- Formula: (1+2+...+toWarp) × 154 for accelRate=1 ships like Freight Barge.
-- ---------------------------------------------------------------------------
function computeAccelDistance(toWarp, accelRate)
  local dist = 0
  local w = 0
  while w < toWarp do
    w = math.min(toWarp, w + accelRate)
    dist = dist + w * DISTANCE_PER_WARP  -- move at new (post-accel) speed
  end
  return dist
end

-- ---------------------------------------------------------------------------
-- computeRotationTicks(degrees, rotRate)
--
-- Returns the number of ticks needed to rotate by the given angle.
-- rotRate is degrees per tick (from game source: max_accel / 10).
-- Always rotates the shortest arc (0–180°).
-- ---------------------------------------------------------------------------
function computeRotationTicks(degrees, rotRate)
  local absDeg = math.abs(degrees) % 360
  if absDeg > 180 then absDeg = 360 - absDeg end
  if rotRate <= 0 then return 0 end
  return math.ceil(absDeg / rotRate)
end

-- ---------------------------------------------------------------------------
-- planTrajectory(distance, maxWarp, accelRate, decelRate)
--
-- Given a distance to travel and ship specs, returns the optimal plan:
--   warp          - cruise warp (highest that fits accel+decel within distance)
--   accelTicks    - ticks to reach cruise warp from 0
--   cruiseTicks   - ticks spent at cruise warp
--   decelTicks    - ticks to stop from cruise warp
--   etaSeconds    - total elapsed real-world seconds
--   decelAtDist   - distance remaining when "warp 0" should be issued
--   repNavEvery   - suggested rep nav polling interval (in ticks)
--
-- Returns nil if distance is 0 or negative.
-- ---------------------------------------------------------------------------
function planTrajectory(distance, maxWarp, accelRate, decelRate)
  if distance <= 0 then return nil end

  -- Find highest cruise warp where overhead fits within distance
  local cruiseWarp = maxWarp
  while cruiseWarp > 0 do
    local accelDist = computeAccelDistance(cruiseWarp, accelRate)
    local decelDist = computeStopDistance(cruiseWarp, decelRate)
    if accelDist + decelDist <= distance then
      break
    end
    cruiseWarp = cruiseWarp - 1
  end

  local accelDist  = computeAccelDistance(cruiseWarp, accelRate)
  local decelDist  = computeStopDistance(cruiseWarp, decelRate)
  local cruiseDist = distance - accelDist - decelDist

  local accelTicks  = (cruiseWarp > 0) and math.ceil(cruiseWarp / accelRate) or 0
  local cruiseTicks = (cruiseWarp > 0) and math.ceil(cruiseDist / (cruiseWarp * DISTANCE_PER_WARP)) or 0
  local decelTicks  = (cruiseWarp > 0) and math.ceil(cruiseWarp / decelRate) or 0

  local totalTicks  = accelTicks + cruiseTicks + decelTicks
  local etaSeconds  = totalTicks * TICK_SECONDS

  -- Poll position (rep nav) roughly 5 times per trip, minimum every 10 ticks
  local repNavEvery = math.max(2, math.floor(totalTicks / 5))

  return {
    warp         = cruiseWarp,
    accelTicks   = accelTicks,
    cruiseTicks  = cruiseTicks,
    decelTicks   = decelTicks,
    etaSeconds   = etaSeconds,
    decelAtDist  = decelDist,
    repNavEvery  = repNavEvery,
  }
end
