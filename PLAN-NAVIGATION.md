# Multi-Phase Navigation System Implementation Plan

## Overview

Build an autonomous navigation system for Galactic Empire MUD client that can navigate to coordinates within a sector (Phase 1), with architecture to support planet orbit (Phase 2), inter-sector travel (Phase 3), and combined navigation (Phase 5) in future.

The system uses a tick-based state machine pattern (following `retake-ilus.lua`) that sends commands, waits for trigger responses, and makes decisions based on updated game state.

## Architecture

### State Storage
Store navigation state separately from existing `gePackage.stateMachine` (which handles report parsing) to avoid conflicts:

```lua
gePackage.navigation = {
  active = false,              -- Is navigation running?
  phase = "coordinate",        -- "coordinate", "planet", "sector", "sector_then_planet"

  target = {
    sectorPositionX = nil,     -- Target coordinates within sector
    sectorPositionY = nil,
    planetNumber = nil,        -- For future Phase 2
    sectorX = nil,             -- For future Phase 3
    sectorY = nil
  },

  state = "idle",              -- Current state machine state
  lastPositionCheck = 0,       -- os.time() when we sent "rep nav"
  lastPositionUpdate = 0,      -- os.time() when triggers updated position
  lastCommand = 0,             -- os.time() when we sent any command

  config = { ... }             -- Configuration (from navigate-config.lua)
}
```

### State Machine Flow (Phase 1)

```
idle
  → User calls navigateToCoordinates(x, y)
  → state = "requesting_position"

requesting_position
  → Send "rep nav"
  → state = "awaiting_position"

awaiting_position
  → Wait for triggers to update getSectorPosition()
  → Timeout check (10s)
  → state = "calculating_route"

calculating_route
  → Calculate distance to target
  → Calculate target heading angle
  → Calculate rotation needed (shortest path)
  → If arrived (< 150 units): state = "arrived"
  → Else: state = "rotating_to_heading"

rotating_to_heading
  → Send "rot X" (relative rotation)
  → state = "awaiting_rotation_confirmation"

awaiting_rotation_confirmation
  → Wait for trigger to update getShipHeading()
  → Timeout check (10s)
  → Verify heading matches target
  → state = "setting_speed"

awaiting_heading_confirmation
  → Wait for trigger to update getShipHeading()
  → Timeout check (10s)
  → state = "setting_speed"

setting_speed
  → Decide WARP vs IMPULSE based on distance
  → Send "warp X" or "imp X"
  → state = "awaiting_speed_confirmation"

awaiting_speed_confirmation
  → Wait for trigger to update getWarpSpeed()
  → Timeout check (10s)
  → state = "traveling"

traveling
  → Wait pollingInterval (3s)
  → state = "requesting_position"
  → Loop to check if arrived

arrived
  → Send "warp 0" to stop
  → state = "stopping"

stopping
  → Wait for getWarpSpeed() == 0
  → state = "completed"

completed
  → Log success
  → active = false
  → state = "idle"

stuck
  → Check total stuck time
  → Retry if < maxStuckTime (60s)
  → Abort if >= maxStuckTime

aborted
  → Log error
  → active = false
  → state = "idle"
```

### Async Command-Response Pattern

Commands → Triggers → State Updates → Tick Function Reads State → Next Command

Example:
1. `navigationTick()` sends "rep nav"
2. MUD responds: "Sector Pos. X:4000 Y:4000"
3. Trigger fires: `setSectorPosition(4000, 4000)` and updates `lastPositionUpdate`
4. Next tick: `navigationTick()` reads position, calculates target heading (45°), calculates rotation needed
5. Next tick: sends "rot 45" (rotate 45 degrees from current heading)
6. MUD responds: "Helm reports we are now heading 45 degrees"
7. Trigger fires: `setShipHeading(45)`
8. Next tick: verifies heading matches target, sends "warp 3"
9. MUD responds: "Helm reports speed is now Warp 3.00, Sir!"
10. System travels for 3 seconds, then requests position again
11. Loop continues, adjusting speed as distance decreases (warp 5 → 3 → 2 → 1 → stop)

## Implementation Steps

### 1. Create navigate-config.lua

New file with user-configurable settings:

```lua
if not gePackage.navigation then
  gePackage.navigation = {}
end

gePackage.navigation.config = {
  -- Distance thresholds
  arrivalThreshold = 150,           -- Stop within this distance
  planetArrivalThreshold = 250,     -- For Phase 2

  -- Timing
  pollingInterval = 3,              -- Seconds between position checks
  commandTimeout = 10,              -- Timeout for command responses
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
```

### 2. Expand navigate.lua

#### Initialize navigation state
```lua
if not gePackage.navigation then
  gePackage.navigation = {
    active = false,
    phase = nil,
    target = {},
    state = "idle",
    lastPositionCheck = 0,
    lastPositionUpdate = 0,
    lastCommand = 0
  }
end
```

#### Add helper functions
```lua
function calculateDistance(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

function calculateHeading(x1, y1, x2, y2)
  -- Extract from existing navigateWithinSectorTo()
  local dx = x2 - x1
  local dy = y2 - y1
  local angleRadians = math.atan(dx, -dy)
  local angleDegrees = angleRadians * 180 / math.pi
  if angleDegrees < 0 then
    angleDegrees = angleDegrees + 360
  end
  return math.floor(angleDegrees + 0.5)
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

  return math.floor(diff + 0.5)
end

function sendNavigationCommand(command)
  gePackage.navigation.lastCommand = os.time()
  send(command)
end
```

#### API functions
```lua
function navigateToCoordinates(x, y)
  -- Validate coordinates (0-10000)
  if x < 0 or x > 10000 or y < 0 or y > 10000 then
    echo("ERROR: Invalid coordinates. Must be 0-10000.")
    return false
  end

  -- Initialize navigation
  gePackage.navigation.active = true
  gePackage.navigation.phase = "coordinate"
  gePackage.navigation.target.sectorPositionX = tonumber(x)
  gePackage.navigation.target.sectorPositionY = tonumber(y)
  gePackage.navigation.state = "requesting_position"
  gePackage.navigation.lastPositionCheck = 0
  gePackage.navigation.lastPositionUpdate = 0

  echo("Navigation started to (" .. x .. ", " .. y .. ")")
  return true
end

function cancelNavigation()
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
```

#### State machine tick function
Follow `retakeIlusTick()` pattern:

```lua
function navigationTick()
  if not gePackage.navigation.active then
    return
  end

  local nav = gePackage.navigation
  local config = nav.config
  local state = nav.state

  -- State handler functions
  local actions = {
    idle = function() end,

    requesting_position = function()
      sendNavigationCommand("rep nav")
      nav.state = "awaiting_position"
      nav.lastPositionCheck = os.time()
    end,

    awaiting_position = function()
      local timeSinceCheck = os.time() - nav.lastPositionCheck

      -- Check timeout
      if timeSinceCheck > config.commandTimeout then
        nav.state = "stuck"
        return
      end

      -- Check if position was updated after we requested it
      if nav.lastPositionUpdate > nav.lastPositionCheck then
        nav.state = "calculating_route"
      end
    end,

    calculating_route = function()
      local currentX, currentY = getSectorPosition()
      local targetX = nav.target.sectorPositionX
      local targetY = nav.target.sectorPositionY

      local distance = calculateDistance(currentX, currentY, targetX, targetY)

      if distance < config.arrivalThreshold then
        nav.state = "arrived"
      else
        -- Calculate and store target heading for rotation
        nav.targetHeading = calculateHeading(currentX, currentY, targetX, targetY)
        nav.state = "rotating_to_heading"
      end
    end,

    rotating_to_heading = function()
      local currentHeading = getShipHeading()
      local targetHeading = nav.targetHeading

      local rotation = calculateRotation(currentHeading, targetHeading)

      -- Only rotate if rotation is significant (> 2 degrees)
      if math.abs(rotation) > 2 then
        sendNavigationCommand("rot " .. rotation)
        nav.state = "awaiting_rotation_confirmation"
      else
        -- Already pointing in right direction
        nav.state = "setting_speed"
      end
    end,

    awaiting_rotation_confirmation = function()
      local timeSinceCommand = os.time() - nav.lastCommand

      if timeSinceCommand > config.commandTimeout then
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

      if headingDiff < 5 then  -- Within 5 degrees is good enough
        nav.state = "setting_speed"
      end
    end,

    setting_speed = function()
      local currentX, currentY = getSectorPosition()
      local targetX = nav.target.sectorPositionX
      local targetY = nav.target.sectorPositionY
      local distance = calculateDistance(currentX, currentY, targetX, targetY)
      local currentSpeed = getWarpSpeed() or 0

      local speedType, speedValue = config.decideSpeed(distance, currentSpeed)

      -- Only send command if speed needs to change
      if math.abs(currentSpeed - speedValue) > 0.1 then
        if speedType == "WARP" then
          sendNavigationCommand("warp " .. speedValue)
        else
          sendNavigationCommand("imp " .. speedValue)
        end
        nav.state = "awaiting_speed_confirmation"
      else
        -- Speed already correct, start traveling
        nav.state = "traveling"
      end
    end,

    awaiting_speed_confirmation = function()
      local timeSinceCommand = os.time() - nav.lastCommand

      if timeSinceCommand > config.commandTimeout then
        nav.state = "stuck"
        return
      end

      if timeSinceCommand > 1 then
        -- Store current heading/speed for interruption detection
        config.lastKnownHeading = getShipHeading()
        config.lastKnownSpeed = getWarpSpeed()
        nav.state = "traveling"
      end
    end,

    traveling = function()
      -- Check for interruption (unexpected heading/speed change)
      if config.detectInterruption then
        local currentHeading = getShipHeading()
        local currentSpeed = getWarpSpeed()

        if config.lastKnownHeading and math.abs(currentHeading - config.lastKnownHeading) > 5 then
          cecho("<red>Navigation interrupted - heading changed unexpectedly\n")
          nav.state = "aborted"
          return
        end

        if config.lastKnownSpeed and math.abs(currentSpeed - config.lastKnownSpeed) > 0.5 then
          cecho("<red>Navigation interrupted - speed changed unexpectedly\n")
          nav.state = "aborted"
          return
        end
      end

      local timeSinceCheck = os.time() - nav.lastPositionCheck

      if timeSinceCheck >= config.pollingInterval then
        nav.state = "requesting_position"
      end
    end,

    arrived = function()
      sendNavigationCommand("warp 0")
      nav.state = "stopping"
    end,

    stopping = function()
      local currentSpeed = getWarpSpeed()

      if currentSpeed == 0 then
        nav.state = "completed"
      end
    end,

    completed = function()
      echo("Navigation completed!")
      nav.active = false
      nav.state = "idle"
    end,

    stuck = function()
      cecho("<red>Navigation stuck in previous state\n")
      nav.state = "aborted"
    end,

    aborted = function()
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
```

### 3. Modify triggers.lua

Add timestamp updates when position/heading/speed change:

```lua
-- Existing trigger for Sector Pos, add timestamp update:
createTrigger("^Sector Pos. X:(\\d+) Y:(\\d+)$", function(matches)
    local xSectorPosition = matches[2]
    local ySectorPosition = matches[3]
    setSectorPosition(xSectorPosition, ySectorPosition)

    -- NEW: Update navigation timestamp
    if gePackage.navigation then
      gePackage.navigation.lastPositionUpdate = os.time()
    end
end, { type = "regex" })

-- Similar updates for heading and speed triggers
-- (Add timestamp updates to existing triggers around lines 83-133)
```

### 4. Modify timers.lua

Add navigationTick call:

```lua
local status, err = pcall(retakeIlusTick)
if not status then
    echo("\n\nCaught an error in retakeIlusTick:\n\n" .. err)
end

-- NEW: Add navigation tick
local navStatus, navErr = pcall(navigationTick)
if not navStatus then
    echo("\n\nCaught an error in navigationTick:\n\n" .. navErr)
end
```

### 5. Modify aliases.lua

Add navigation command aliases:

```lua
-- Navigate to coordinates
createAlias("^navto (\\d+) (\\d+)$", function(matches)
    local x = matches[2]
    local y = matches[3]
    navigateToCoordinates(x, y)
end, { type = "regex" })

-- Navigation status
createAlias("^navstatus$", function()
    echo(getNavigationStatus())
end, { type = "regex" })

-- Cancel navigation
createAlias("^navcancel$", function()
    cancelNavigation()
end, { type = "regex" })
```

### 6. Modify main.lua

Load navigate-config.lua before navigate.lua:

```lua
dofile(scriptDir .. "core.lua")
dofile(scriptDir .. "aliases.lua")
dofile(scriptDir .. "triggers.lua")
dofile(scriptDir .. "state-machine-core.lua")
dofile(scriptDir .. "navigate-config.lua")  -- NEW
dofile(scriptDir .. "navigate.lua")
dofile(scriptDir .. "status.lua")
```

### 7. Create test/navigate_spec.lua

```lua
local helper = require("test.test_helper")

describe("Navigation System", function()
  before_each(function()
    helper.resetAll()
    dofile("main.lua")
  end)

  describe("calculateDistance", function()
    it("calculates distance between two points", function()
      local dist = calculateDistance(0, 0, 300, 400)
      assert.equals(500, dist)
    end)

    it("calculates distance for same point", function()
      local dist = calculateDistance(100, 100, 100, 100)
      assert.equals(0, dist)
    end)
  end)

  describe("calculateHeading", function()
    it("calculates 0 degrees for due north", function()
      assert.equals(0, calculateHeading(5000, 5000, 5000, 0))
    end)

    it("calculates 90 degrees for due east", function()
      assert.equals(90, calculateHeading(5000, 5000, 10000, 5000))
    end)

    it("calculates 180 degrees for due south", function()
      assert.equals(180, calculateHeading(5000, 5000, 5000, 10000))
    end)

    it("calculates 270 degrees for due west", function()
      assert.equals(270, calculateHeading(5000, 5000, 0, 5000))
    end)
  end)

  describe("calculateRotation", function()
    it("calculates positive rotation for clockwise turn", function()
      assert.equals(45, calculateRotation(0, 45))
    end)

    it("calculates negative rotation for counter-clockwise turn", function()
      assert.equals(-45, calculateRotation(45, 0))
    end)

    it("chooses shorter path when crossing 0/360 boundary", function()
      -- Going from 350 to 10 degrees: shorter to rotate +20 than -340
      assert.equals(20, calculateRotation(350, 10))
    end)

    it("chooses shorter negative path when crossing boundary", function()
      -- Going from 10 to 350 degrees: shorter to rotate -20 than +340
      assert.equals(-20, calculateRotation(10, 350))
    end)

    it("returns 0 when already at target heading", function()
      assert.equals(0, calculateRotation(90, 90))
    end)
  end)

  describe("navigateToCoordinates", function()
    it("initializes navigation state", function()
      navigateToCoordinates(5000, 5000)

      assert.is_true(gePackage.navigation.active)
      assert.equals("coordinate", gePackage.navigation.phase)
      assert.equals(5000, gePackage.navigation.target.sectorPositionX)
      assert.equals(5000, gePackage.navigation.target.sectorPositionY)
      assert.equals("requesting_position", gePackage.navigation.state)
    end)

    it("rejects invalid coordinates", function()
      local result = navigateToCoordinates(-100, 5000)
      assert.is_false(result)
      assert.is_false(gePackage.navigation.active)
    end)
  end)

  describe("navigationTick state machine", function()
    it("requests position on first tick", function()
      navigateToCoordinates(5000, 5000)

      navigationTick()

      assert.is_true(helper.wasSendCalledWith("rep nav"))
      assert.equals("awaiting_position", gePackage.navigation.state)
    end)

    it("transitions to calculating_route after position update", function()
      navigateToCoordinates(5000, 5000)
      setSectorPosition(4000, 4000)

      gePackage.navigation.state = "awaiting_position"
      gePackage.navigation.lastPositionCheck = os.time() - 2
      gePackage.navigation.lastPositionUpdate = os.time()

      navigationTick()

      assert.equals("calculating_route", gePackage.navigation.state)
    end)

    it("rotates to heading after calculating route", function()
      navigateToCoordinates(5000, 5000)
      setSectorPosition(4000, 4000)
      setShipHeading(0)  -- Currently facing north
      gePackage.navigation.state = "calculating_route"

      -- Calculate route stores target heading
      navigationTick()
      assert.equals("rotating_to_heading", gePackage.navigation.state)
      assert.equals(45, gePackage.navigation.targetHeading)

      -- Rotate to target heading
      navigationTick()
      assert.is_true(helper.wasSendCalledWith("rot 45"))
      assert.equals("awaiting_rotation_confirmation", gePackage.navigation.state)
    end)

    it("detects arrival when within threshold", function()
      navigateToCoordinates(5000, 5000)
      setSectorPosition(4900, 4900)  -- Distance ~141, within threshold of 150
      gePackage.navigation.state = "calculating_route"

      navigationTick()

      assert.equals("arrived", gePackage.navigation.state)
    end)
  end)

  describe("cancelNavigation", function()
    it("stops active navigation", function()
      navigateToCoordinates(5000, 5000)
      assert.is_true(gePackage.navigation.active)

      cancelNavigation()

      assert.is_false(gePackage.navigation.active)
      assert.equals("aborted", gePackage.navigation.state)
      assert.is_true(helper.wasSendCalledWith("warp 0"))
    end)
  end)
end)
```

## Critical Files

- **navigate-config.lua** (NEW) - Configuration settings
- **navigate.lua** (MODIFY) - Core navigation logic, state machine
- **triggers.lua** (MODIFY) - Add timestamp updates to position/heading/speed triggers
- **timers.lua** (MODIFY) - Add navigationTick() call
- **aliases.lua** (MODIFY) - Add navto/navstatus/navcancel aliases
- **main.lua** (MODIFY) - Load navigate-config.lua
- **test/navigate_spec.lua** (NEW) - Navigation tests

## Verification

### Manual Testing in Game
1. Connect to GE MUD
2. Type `navto 5000 5000`
3. Observe:
   - "Navigation started to (5000, 5000)"
   - Ship requests position with "rep nav"
   - Ship sets heading
   - Ship sets warp speed
   - Ship periodically checks position
   - Ship stops when arrived
   - "Navigation completed!"

4. Test cancellation:
   - `navto 8000 8000`
   - `navcancel`
   - Observe: "Navigation cancelled" and ship stops

5. Test status:
   - `navto 3000 3000`
   - `navstatus`
   - Observe: "Navigating to (3000, 3000) - traveling"

### Unit Tests
```bash
busted test/navigate_spec.lua
```

Should see all tests pass for:
- calculateDistance
- calculateHeading
- navigateToCoordinates initialization
- State machine transitions
- Arrival detection
- Cancellation

### Integration Test
Run full test suite:
```bash
busted test/
```

All existing tests should still pass (no regressions).

## Future Phases (Hooks)

### Phase 2: Planet Orbit
- Add states: `approaching_planet`, `awaiting_orbit_confirmation`
- Requires planet position data (from sector scan or stored database)
- Use 250 distance threshold instead of 150

### Phase 3: Inter-Sector Travel
- Add states: `traveling_intersector`, `awaiting_sector_change`
- Use `getSector()` instead of `getSectorPosition()`
- Higher WARP speeds (5-9)
- Stop when sector coordinates match target

### Phase 5: Sector + Planet
- Chain Phase 3 → Phase 2
- Store callback function for after sector arrival
- Switch navigation phase mid-execution

## Configuration Examples

Users can customize behavior by editing navigate-config.lua:

```lua
-- Conservative navigation (slow down earlier)
gePackage.navigation.config.decideSpeed = function(distance)
  if distance > 1000 then return "WARP", 2 end
  if distance > 500 then return "WARP", 1 end
  return "IMPULSE", 50
end

-- Larger arrival threshold
gePackage.navigation.config.arrivalThreshold = 200

-- Faster polling
gePackage.navigation.config.pollingInterval = 2
```
