# baud-ge

Lua scripts for playing Galactic Empire (GE) via [Baud](https://github.com/jedcn/baud) MUD client.

## Commands

- Run tests: `busted test/`
- Run tests verbose: `busted test/ --verbose`

## File Structure

Update this section and README.md when files are added, removed, or renamed.

- `main.lua` - Entry point, loads other files via `dofile()`
- `core.lua` - State management functions (setSectorXY, setOrbitingPlanet, setShipHeading, etc.)
- `triggers.lua` - Pattern-matching triggers that fire on game output
- `aliases.lua` - Command aliases (shortcuts like `scapl1` -> `sca pl 1`)
- `test/test_helper.lua` - Mocks Baud framework for testing
- `test/main_spec.lua` - Trigger tests using Busted framework

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
    setSectorXY(xSector, ySector)
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
