# Navigation System - Phase 1 Implementation Progress

## Overview

Successfully implemented Phase 1 of the multi-phase navigation system for Galactic Empire MUD client. The system enables autonomous coordinate-based navigation within a sector using a tick-based state machine pattern.

## Implementation Summary

### Files Created

1. **navigate-config.lua** (56 lines)
   - User-configurable navigation settings
   - Distance thresholds (arrival: 150 units, planet: 250 units)
   - Timing configuration (polling interval: 3s, timeout: 10s)
   - Speed decision function with progressive deceleration logic
   - Interruption detection settings

2. **test/navigate_spec.lua** (160 lines)
   - 18 comprehensive tests covering:
     - Helper function tests (calculateDistance, calculateHeading, calculateRotation)
     - API function tests (navigateToCoordinates, cancelNavigation)
     - State machine transition tests
     - Arrival detection tests

### Files Modified

1. **navigate.lua** (expanded from 18 to 341 lines)
   - Added state initialization
   - Implemented helper functions:
     - `calculateDistance(x1, y1, x2, y2)` - Pythagorean distance
     - `calculateHeading(x1, y1, x2, y2)` - Bearing calculation (0°=north, 90°=east)
     - `calculateRotation(currentHeading, goalHeading)` - Shortest rotation path
     - `sendNavigationCommand(command)` - Timestamp tracking wrapper
   - Implemented API functions:
     - `navigateToCoordinates(x, y)` - Start navigation to coordinates
     - `cancelNavigation()` - Abort active navigation
     - `isNavigating()` - Check if navigation active
     - `getNavigationStatus()` - Get current status string
     - Stubs for Phase 2, 3, 5 (planet, sector, combined navigation)
   - Implemented 13-state navigation state machine in `navigationTick()`
   - Kept legacy `navigateWithinSectorTo()` for backward compatibility

2. **triggers.lua** (added 4 lines)
   - Modified "Sector Pos" trigger to update `gePackage.navigation.lastPositionUpdate` timestamp
   - Enables navigation system to detect when position data is fresh

3. **timers.lua** (added 7 lines)
   - Added `navigationTick()` call wrapped in pcall for error handling
   - Runs every tick (1 second) alongside existing retakeIlusTick

4. **aliases.lua** (added 20 lines)
   - `navto X Y` - Start navigation to coordinates (X, Y)
   - `navstatus` - Display current navigation status
   - `navcancel` - Cancel active navigation

5. **main.lua** (reordered loading)
   - Added loading of navigate-config.lua before navigate.lua
   - Ensures config is available when navigation initializes

## Key Features Implemented

### 1. Rotation Logic
- Uses `rot X` command (relative rotation) instead of `hea X` (absolute heading)
- Implements shortest-path algorithm from retake-ilus.lua
- Example: Rotating from 350° to 10° rotates +20° instead of +340°
- Only rotates if difference > 2° (avoids unnecessary micro-adjustments)

### 2. Speed Management with Deceleration
- **Acceleration logic**: Speeds up for long distances
  - Distance > 2000: WARP 5
  - Distance > 1000: WARP 3
  - Distance > 500: WARP 2
  - Distance > 200: WARP 1
  - Otherwise: IMPULSE 99

- **Deceleration logic**: Slows down before arrival to prevent overshooting
  - At WARP 5 and distance < 2000: Reduce to WARP 3
  - At WARP 3 and distance < 1000: Reduce to WARP 2
  - At WARP 2 and distance < 500: Reduce to WARP 1

### 3. State Machine Flow

```
idle → requesting_position → awaiting_position → calculating_route
    → rotating_to_heading → awaiting_rotation_confirmation → setting_speed
    → awaiting_speed_confirmation → traveling → [loop back to requesting_position]
    → arrived → stopping → completed
```

**Error states**: stuck, aborted

### 4. Interruption Detection
- Monitors heading and speed during travel
- Aborts navigation if:
  - Heading changes by > 5° unexpectedly
  - Speed changes by > 0.5 unexpectedly
- Prevents navigation conflicts with manual control or combat

### 5. Error Handling
- **Timeout detection**: 10 second timeout for command responses
- **Stuck detection**: Transitions to "stuck" state if timeout exceeded
- **Coordinate validation**: Rejects coordinates outside 0-10000 range
- **Position freshness**: Uses timestamps to verify position updates

## Test Results

### Unit Tests
```bash
busted test/navigate_spec.lua
```
**Result**: 18 successes / 0 failures / 0 errors

Tests cover:
- Distance calculations (Pythagorean theorem)
- Heading calculations (cardinal directions: N, E, S, W)
- Rotation calculations (shortest path, boundary wrapping)
- Navigation initialization
- Invalid coordinate rejection
- State machine transitions
- Arrival detection (within 150 unit threshold)
- Navigation cancellation

### Integration Tests
```bash
busted test/
```
**Result**: 49 successes / 0 failures / 0 errors
- All 31 existing tests pass (no regressions)
- All 18 new navigation tests pass

## Usage Examples

### Basic Navigation
```lua
-- Navigate to coordinates (5000, 5000)
navto 5000 5000

-- Expected output:
-- Navigation started to (5000, 5000)
-- > rep nav
-- > rot 135  (if current heading is 0, target is southeast)
-- > warp 3
-- [travels for 3 seconds]
-- > rep nav
-- [adjusts speed based on distance]
-- > warp 0
-- Navigation completed!
```

### Check Status
```lua
navstatus

-- Output examples:
-- "Navigation inactive" (when not navigating)
-- "Navigating to (5000, 5000) - traveling" (during navigation)
-- "Navigating to (5000, 5000) - rotating_to_heading" (during rotation)
```

### Cancel Navigation
```lua
navcancel

-- Output:
-- Navigation cancelled
-- > warp 0
```

## Coordinate System

- **Sector coordinates**: Can be negative (e.g., sector -25, 100)
- **Sector position**: 0-10000 range within each sector
- **Heading**: 0-360 degrees
  - 0° = North (negative Y direction)
  - 90° = East (positive X direction)
  - 180° = South (positive Y direction)
  - 270° = West (negative X direction)

## Configuration

Users can customize behavior by editing navigate-config.lua:

```lua
-- Example: More conservative navigation
gePackage.navigation.config.arrivalThreshold = 200  -- Stop farther away
gePackage.navigation.config.pollingInterval = 2      -- Check position more frequently

-- Example: Custom speed logic
gePackage.navigation.config.decideSpeed = function(distance, currentSpeed)
  if distance > 1000 then return "WARP", 2 end
  return "IMPULSE", 50
end
```

## Architecture Decisions

### Why Rotation (rot) Instead of Heading (hea)?
The game requires relative rotation commands rather than absolute heading commands. The `rot X` command rotates the ship by X degrees from its current heading, while `hea X` would set an absolute heading. We use the shortest-path algorithm to minimize rotation time.

### Why Distance-Based Speed Logic?
Progressive deceleration prevents overshooting the target. At high warp speeds, the ship has momentum and takes time to slow down. By reducing speed as distance decreases, we ensure the ship can stop within the arrival threshold (150 units).

### Why Tick-Based State Machine?
Lua 5.4 in wasmoon lacks async/await and coroutines. A tick-based approach with event-driven trigger updates provides a clean solution:
- Simple to reason about (one state per tick)
- Easy to test (synchronous execution in tests)
- Follows existing codebase pattern (retake-ilus.lua)
- Acceptable overhead (1 tick per second)

### Why Separate Config File?
Separating configuration from logic allows users to customize behavior without modifying navigation code. This makes it easier to tune thresholds, speeds, and timeouts for different play styles or ship configurations.

## Future Phases

The architecture is designed to support future phases:

### Phase 2: Planet Orbit (Planned)
- Navigate to numbered planet within sector
- Use planet bearing from sector scan
- Stop when within 250 distance units
- Send `orb X` command

### Phase 3: Inter-Sector Travel (Planned)
- Navigate between sectors using sector coordinates
- Travel at high WARP speeds (5-9)
- Monitor sector changes via `getSector()`
- Stop when entering target sector

### Phase 5: Sector + Planet Navigation (Planned)
- Chain Phase 3 (inter-sector) + Phase 2 (planet orbit)
- Navigate to different sector
- Upon arrival, locate and orbit planet
- Handle callback after sector arrival

## Known Limitations

1. **No collision avoidance**: System doesn't detect or avoid obstacles
2. **No combat handling**: Navigation doesn't pause during combat (interruption detection will abort instead)
3. **Single navigation instance**: Only one navigation can be active at a time
4. **No route planning**: Direct line navigation, doesn't plan around obstacles
5. **Fixed polling interval**: Always checks position every 3 seconds (configurable but not dynamic)

## Performance

- **Memory**: Minimal overhead (~10 fields in gePackage.navigation)
- **CPU**: One tick function execution per second when navigating
- **Network**: One "rep nav" command every 3 seconds during travel
- **Responsiveness**: Command responses typically within 1-2 seconds (network + tick latency)

## Commits

This implementation will be committed as:
```
Implement Phase 1 autonomous navigation system

- Add navigate-config.lua with user-configurable settings
- Expand navigate.lua with state machine and helper functions
- Add timestamp tracking to position triggers
- Add navigationTick() to timers
- Add navigation command aliases (navto, navstatus, navcancel)
- Add 18 comprehensive navigation tests
- All 49 tests pass (31 existing + 18 new)

Features:
- Autonomous coordinate navigation within sector
- Progressive speed deceleration to prevent overshoot
- Shortest-path rotation algorithm
- Interruption detection and abort
- Timeout and stuck detection
- Phase 2, 3, 5 architecture hooks for future development
```

## Files Summary

```
Created:
  navigate-config.lua       (56 lines)  - Configuration
  test/navigate_spec.lua   (160 lines)  - Tests

Modified:
  navigate.lua             (+323 lines) - Core navigation
  triggers.lua             (+4 lines)   - Timestamp tracking
  timers.lua               (+7 lines)   - Tick function call
  aliases.lua              (+20 lines)  - User commands
  main.lua                 (reordered)  - Load order fix

Total: +570 lines of new code
```
