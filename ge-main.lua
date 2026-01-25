--
-- ge-main.lua
--

--
-- This script will be read by [baud](https://github.com/jedcn/baud).
--
-- It defines Aliases, Triggers, and lua functions that can be invoked
-- via /lua inside a running session of baud.
--
echo("Starting to read ge-main.lua")

-- Load state management functions
dofile("ge-functions.lua")

-- Load aliases
dofile("ge-aliases.lua")

-- Load triggers
dofile("ge-triggers.lua")

echo("Finishing reading ge-main.lua")
