local status, err = pcall(retakeIlusTick)

if not status then
    echo("\n\nCaught an error in retakeIlusTick:\n\n" .. err)
end

-- Navigation tick
local navStatus, navErr = pcall(navigationTick)

if not navStatus then
    echo("\n\nCaught an error in navigationTick:\n\n" .. navErr)
end
