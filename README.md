# Baud Lua Script for Playing Galactic Empire

Lua scripts for playing Galactic Empire via [baud](https://github.com/jedcn/baud).

## Development Setup

### Prerequisites

1. **Lua** (5.1 or later)
   ```bash
   # macOS
   brew install lua

   # Ubuntu/Debian
   sudo apt-get install lua5.4
   ```

2. **LuaRocks** (Lua package manager)
   ```bash
   # macOS
   brew install luarocks

   # Ubuntu/Debian
   sudo apt-get install luarocks
   ```

3. **Busted** (testing framework)
   ```bash
   luarocks install busted
   ```

## Running Tests

Run all tests:
```bash
busted test/
```

Run tests with verbose output:
```bash
busted test/ --verbose
```

Run a specific test file:
```bash
busted test/ge_triggers_spec.lua
```

## Project Structure

```
baud-ge/
├── README.md                 -- This file
├── ge-main.lua               -- Main GE triggers and functions
├── examples.lua              -- Example triggers and aliases
├── plan/
│   └── testing-plan.md       -- Implementation plan for tests
└── test/
    ├── test_helper.lua       -- Mocks for Baud framework functions
    └── ge_triggers_spec.lua  -- Trigger tests
```
