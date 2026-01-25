# Baud Lua Script for Playing Galactic Empire

Lua scripts for playing Galactic Empire via [baud](https://github.com/jedcn/baud).

This scripts have tests. Run them with `busted test`

## Project Structure

```
baud-scripts-for-ge/
├── README.md                 -- This file
├── main.lua                  -- Entry point, loads other files
├── core.lua                  -- Core functions
├── aliases.lua               -- Command aliases
├── triggers.lua              -- Pattern-matching triggers
├── examples.lua              -- Example triggers and aliases
├── plan/
│   └── testing-plan.md       -- Implementation plan for tests
└── test/
    ├── test_helper.lua       -- Mocks for Baud framework functions
    └── ge_triggers_spec.lua  -- Trigger tests
```

## Prerequisites for Running Tests

   ```bash
   brew install lua
   brew install luarocks
   luarocks install busted
   ```
