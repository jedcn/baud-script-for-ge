--
-- This script will be read by [baud](https://github.com/jedcn/baud).
--
-- Details [here](https://github.com/jedcn/baud?tab=readme-ov-file#loading-scripts)
--
echo("Starting to read main.lua")

-- SCRIPT_DIR is set by Baud to the directory containing this script
local scriptDir = SCRIPT_DIR
if not scriptDir then
  error("SCRIPT_DIR not set - are you running this through Baud?")
end

-- Load state management functions
dofile(scriptDir .. "core.lua")

-- Load aliases
dofile(scriptDir .. "aliases.lua")

-- Load triggers
dofile(scriptDir .. "triggers.lua")

echo("Finishing reading main.lua")
