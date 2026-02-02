# Baud Lua Script for Playing Galactic Empire

Lua scripts for playing Galactic Empire via [baud](https://github.com/jedcn/baud).

These scripts have tests. Run tests with `busted test`

## Project Structure

Keep this section up to date when files are renamed, added, or deleted.

```
baud-scripts-for-ge/
├── README.md                 -- This file
├── main.lua                  -- Entry point, loads other files
├── core.lua                  -- Core functions
├── aliases.lua               -- Command aliases
├── triggers.lua              -- Pattern-matching triggers
├── plan/
│   └── testing-plan.md       -- Implementation plan for tests
└── test/
    ├── test_helper.lua       -- Mocks for Baud framework functions
    └── main_spec.lua         -- Trigger tests
```

## Prerequisites for Running Tests

   ```bash
   brew install lua
   brew install luarocks
   luarocks install busted
   ```
