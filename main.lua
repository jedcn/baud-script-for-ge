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

dofile(scriptDir .. "core.lua")

dofile(scriptDir .. "aliases.lua")

dofile(scriptDir .. "triggers.lua")

dofile(scriptDir .. "status.lua")

echo("Finishing reading main.lua")
