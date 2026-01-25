--
-- This script will be read by [baud](https://github.com/jedcn/baud).
--
-- Details [here](https://github.com/jedcn/baud?tab=readme-ov-file#loading-scripts)
--
echo("Starting to read main.lua")

-- Load state management functions
dofile("core.lua")

-- Load aliases
dofile("aliases.lua")

-- Load triggers
dofile("triggers.lua")

echo("Finishing reading main.lua")
