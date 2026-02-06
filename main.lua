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

dofile(scriptDir .. "state-machine-core.lua")

dofile(scriptDir .. "navigate-config.lua")

dofile(scriptDir .. "navigate.lua")

dofile(scriptDir .. "status.lua")

-- Set up recurring timer for navigation tick (every 1 second = 1000ms)
createTimer(1000, function()
    -- Navigation tick (if function exists)
    if navigationTick then
        local navStatus, navErr = pcall(navigationTick)
        if not navStatus then
            echo("\n\nCaught an error in navigationTick:\n\n" .. navErr)
        end
    end

    -- Retake Ilus tick (if function exists)
    if retakeIlusTick then
        local status, err = pcall(retakeIlusTick)
        if not status then
            echo("\n\nCaught an error in retakeIlusTick:\n\n" .. err)
        end
    end
end, { name = "mainTick", repeating = true, enabled = true })

echo("Finishing reading main.lua")
