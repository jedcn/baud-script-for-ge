# Plan: Testing Framework for GE Triggers

## Overview

Set up a testing framework to verify that triggers in `ge-main.lua` correctly match patterns and call the appropriate functions with correct arguments.

## Key Challenge

`createTrigger` is provided by the Baud framework (not defined in this codebase). To test our trigger logic without the full Baud runtime, we need to:
1. Mock `createTrigger` to capture the patterns and callbacks
2. Simulate text streams and verify the correct functions are called

## Recommended Approach: Busted + Mocks

**Busted** is the recommended Lua testing framework because:
- Built-in spy/mock support (perfect for verifying function calls)
- Readable BDD-style syntax (`describe`, `it`)
- Easy to install via `luarocks install busted`

## Implementation Plan

### 1. Create test helper that mocks Baud functions

Create `test/test_helper.lua`:
```lua
-- Mock Baud framework functions
local triggers = {}
local aliases = {}

function createTrigger(pattern, callback, options)
    table.insert(triggers, {
        pattern = pattern,
        callback = callback,
        options = options or {}
    })
end

function createAlias(pattern, callback, options)
    table.insert(aliases, {
        pattern = pattern,
        callback = callback,
        options = options or {}
    })
end

function send(text) end  -- no-op for testing
function echo(text) end  -- no-op for testing

-- Test utility: simulate a line of text and fire matching triggers
function simulateLine(text)
    for _, trigger in ipairs(triggers) do
        local matches = {string.match(text, trigger.pattern)}
        if #matches > 0 then
            -- Lua's string.match returns captures, not full match first
            -- We need to prepend the full match for compatibility
            table.insert(matches, 1, text)
            trigger.callback(matches)
        end
    end
end

-- Reset triggers between tests
function resetTriggers()
    triggers = {}
    aliases = {}
end

return {
    triggers = triggers,
    simulateLine = simulateLine,
    resetTriggers = resetTriggers
}
```

### 2. Create test file for triggers

See `test/ge_triggers_spec.lua` for the full implementation.

### 3. Running tests

```bash
# Install busted (one time)
luarocks install busted

# Run all tests
busted test/

# Run with verbose output
busted test/ --verbose
```

## Complete Trigger Test List (24 triggers)

### Auto-response triggers (3)
| Pattern | Action | Test Verification |
|---------|--------|-------------------|
| `(N)onstop, (Q)uit, or (C)ontinue?` | send("n") | verify send called with "n" |
| `In gravity pull of planet (\d+)...` | send("orbit " .. planetNumber) | verify send called with "orbit 42" |
| `HELM reports we are leaving HYPERSPACE...` | send("shi up") | verify send called with "shi up" |

### Storage Management triggers (4)
| Pattern | Action | Test Verification |
|---------|--------|-------------------|
| `Leaving orbit Sir!` | clearOrbitingPlanet() | verify function called |
| `We are now in stationary orbit around planet (\d+)` | setOrbitingPlanet(planetNumber) | verify called with "42" |
| `Galactic Pos. Xsect:(-?\d+)\s+Ysect:(-?\d+)` | setSectorXY(x, y) | verify called with "-25", "100" |
| `Sector Pos. X:(\d+) Y:(\d+)` | setSectorPositionXY(x, y) | verify called with "50", "75" |

### Status Display triggers (4)
| Pattern | Action | Test Verification |
|---------|--------|-------------------|
| `Orbiting Planet........  (\d+)` | setOrbitingPlanet(planetNumber) | verify called with "42" |
| `Galactic Heading.......  (-?\d+)` | setShipHeading(heading) | verify called with "180" |
| `Speed..................Warp (\d+\.\d+)` | setWarpSpeed(warpSpeed) | verify called with "5.50" |
| `Neutron Flux............ (\d+)` | setShipNeutronFlux(flux) | verify called with "1000" |

### Helm Message triggers (4)
| Pattern | Action | Test Verification |
|---------|--------|-------------------|
| `Helm reports we are now heading (-?\d+) degrees.` | setShipHeading(heading) | verify called with "-45" |
| `Helm reports speed is now Warp (\d+\.\d+), Sir!` | setWarpSpeed(warpSpeed) | verify called with "3.25" |
| `Helm reports we are at a dead stop, Sir!` | setWarpSpeed(0) | verify called with 0 |
| `Navigating SS# (-?\d+) (-?\d+)` | setSectorXY(x, y) | verify called with "-10", "20" |

### Inventory triggers (3)
| Pattern | Action | Test Verification |
|---------|--------|-------------------|
| `Fighters..................\s*(\d+)` | setShipInventory("Fighters", count) | verify called with "Fighters", "15" (when not scanning) |
| `Flux pods..................\s*(\d+)` | setShipInventory("Flux pods", count) | verify called with "Flux pods", "8" (when not scanning) |
| `Total Cargo Weight... 0 Tons` | clearShipInventory() | verify function called |

### State Machine triggers (2)
| Pattern | Action | Test Verification |
|---------|--------|-------------------|
| `--------------------------------------` | toggleDashes() | verify function called |
| `Scanning Planet (\d+)\s*(.*)` | setScanningPlanet(true), setScanningPlanetNumber, setScanningPlanetName | verify all three called correctly |

### Report Type triggers (4)
| Pattern | Action | Test Verification |
|---------|--------|-------------------|
| `Systems Report` | echo("Systems Report") | verify echo called |
| `Inventory Report` | echo("Inventory Report") | verify echo called |
| `Accounting Division report` | echo("Accounting Division report") | verify echo called |
| `Navigational Report` | echo("Navigational Report") | verify echo called |

## Verification

After implementation:
1. Run `busted test/` - all tests should pass
2. Intentionally break a pattern in ge-main.lua - relevant test should fail
3. Fix the pattern - test should pass again

## Decisions

- **Framework**: Use Busted via luarocks
- **Scope**: Test all 20+ triggers for comprehensive coverage
