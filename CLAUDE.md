# baud-ge

Lua scripts for playing Galactic Empire (GE) via [Baud](https://github.com/jedcn/baud) MUD client.

## Commands

- Run tests: `busted test/`
- Run tests verbose: `busted test/ --verbose`

## File Structure

Update this section and README.md when files are added, removed, or renamed.

- `main.lua` - Entry point, loads other files via `dofile()`
- `core.lua` - Ship state management (setSector, setOrbitingPlanet, setShipHeading, etc.)
- `state-machine-core.lua` - Parsing state for multi-line output (scanning planets, reports)
- `navigation-state.lua` - Navigation state machines (coordinate nav, flip-away, rotto, sector nav)
- `navigate.lua` - Autonomous navigation system
- `navigate-config.lua` - User-configurable navigation settings
- `status.lua` - Status bar display function
- `triggers.lua` - Pattern-matching triggers that fire on game output
- `aliases.lua` - Command aliases (shortcuts like `scapl1` -> `sca pl 1`)
- `timers.lua` - Recurring timers (navigation tick, etc.)
- `test/test_helper.lua` - Mocks Baud framework for testing
- `test/core_spec.lua` - Core function tests (resetData, etc.)
- `test/main_spec.lua` - Trigger tests using Busted framework
- `test/navigate_spec.lua` - Navigation system tests

## Conventions

### Triggers and Aliases
- Use `createTrigger(pattern, callback, { type = "regex" })` for regex patterns
- Use `createAlias(pattern, callback, { type = "regex" })` for command shortcuts
- Patterns require double-escaped backslashes: `\\d+` not `\d+`
- Baud provides global functions: `send()`, `echo()`, `createTrigger()`, `createAlias()`

### Explaining Variables
Use named variables for regex captures to clarify what each capture group represents:
```lua
createTrigger("^Galactic Pos. Xsect:(-?\\d+)\\s+Ysect:(-?\\d+)$", function(matches)
    local xSector = matches[2]
    local ySector = matches[3]
    setSector(xSector, ySector)
end, { type = "regex" })
```

### Testing
- Tests use Busted framework with BDD-style `describe`/`it` blocks
- Override globals with `_G.functionName = ...` to intercept calls
- Always restore original functions after test
- `helper.simulateLine(text)` fires matching triggers against test input

## Game Domain

Galactic Empire is a space trading/combat MUD. Key concepts:
- **Sectors**: Galaxy divided into sectors with X/Y coordinates
- **Sector Position**: Position within a sector (also X/Y)
- **Planets**: Numbered planets that can be orbited and scanned
- **Ship State**: Heading, warp speed, shields, neutron flux, inventory
- **Reports**: Systems Report, Inventory Report, Navigational Report, etc.

## State Management

All game state stored in global `gePackage` table:
- `gePackage.position` - Sector coordinates, sector position, orbiting planet
- `gePackage.ship` - Heading, neutron flux, inventory
- `gePackage.stateMachine` - Parsing state for multi-line output (scanning planets, reports)

### State Access Paradigm

**Single Source of Truth**: All state lives in `gePackage`, accessed exclusively through setters and getters.

1. **Triggers** parse game output and call **setters** (in `core.lua` or `navigation-state.lua`)
2. **Aliases, state machines, and other scripts** read state via **getters only**
3. **Never access `gePackage` directly** outside of core.lua, state-machine-core.lua, or navigation-state.lua

This prevents duplication of state and ensures consistency. When a new game mechanic is discovered:
1. Add a trigger that parses the output
2. Add a setter/getter pair in the appropriate core file
3. Any feature can then use the getter immediately

### State Files

- `core.lua` - Ship state (heading, position, shields, inventory, etc.)
- `state-machine-core.lua` - Parsing state for multi-line output
- `navigation-state.lua` - Navigation state machines (coordinate nav, flip-away, rotto, sector nav)
