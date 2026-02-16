-- Set up recurring timer for navigation tick (every 3 seconds = 3000ms)
createTimer(3000, function()
    -- Navigation tick (if function exists)
    if navigationTick then
        local navStatus, navErr = pcall(navigationTick)
        if not navStatus then
            echo("\n\nCaught an error in navigationTick:\n\n" .. navErr)
        end
    end

    -- Flip away tick (if function exists)
    if flipAwayTick then
        local faStatus, faErr = pcall(flipAwayTick)
        if not faStatus then
            echo("\n\nCaught an error in flipAwayTick:\n\n" .. faErr)
        end
    end
end, { name = "mainTick", repeating = true, enabled = true })