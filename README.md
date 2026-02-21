# Baud Lua Script for Playing Galactic Empire

Lua scripts for playing Galactic Empire via [baud](https://github.com/jedcn/baud).

These scripts have tests. Run tests with `busted test`

## Project Structure

```
baud-scripts-for-ge/
├── README.md                 -- This file
├── main.lua                  -- Entry point, loads other files via dofile()
├── core.lua                  -- Ship state management (setSector, setShipHeading, etc.)
├── state-machine-core.lua    -- Parsing state for multi-line output
├── navigation-state.lua      -- Navigation state machines (coordinate nav, flip-away, rotto, sector nav)
├── navigate.lua              -- Autonomous navigation system
├── navigate-config.lua       -- User-configurable navigation settings
├── status.lua                -- Status bar display function
├── triggers.lua              -- Pattern-matching triggers on game output
├── aliases.lua               -- Command aliases (shortcuts like scapl1 -> sca pl 1)
├── timers.lua                -- Recurring timers (navigation tick, etc.)
├── plan/
│   ├── navigation.md         -- Navigation system implementation plan
│   └── testing-plan.md       -- Implementation plan for tests
└── test/
    ├── test_helper.lua       -- Mocks for Baud framework functions
    ├── core_spec.lua         -- Core function tests
    ├── main_spec.lua         -- Trigger tests
    └── navigate_spec.lua     -- Navigation system tests
```

## Prerequisites for Running Tests

   ```bash
   brew install lua
   brew install luarocks
   luarocks install busted
   ```
