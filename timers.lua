-- Set up recurring timer for navigation tick (every 1 second = 1000ms)
createTimer(3000, function()
    -- Navigation tick (if function exists)
    if navigationTick then
        local navStatus, navErr = pcall(navigationTick)
        if not navStatus then
            echo("\n\nCaught an error in navigationTick:\n\n" .. navErr)
        end
    end
end, { name = "mainTick", repeating = true, enabled = true })