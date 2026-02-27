function mainTick()
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

    -- Rotto tick (if function exists)
    if rottoTick then
        local rottoStatus, rottoErr = pcall(rottoTick)
        if not rottoStatus then
            echo("\n\nCaught an error in rottoTick:\n\n" .. rottoErr)
        end
    end

    -- Sector navigation tick (if function exists)
    if sectorNavTick then
        local secStatus, secErr = pcall(sectorNavTick)
        if not secStatus then
            echo("\n\nCaught an error in sectorNavTick:\n\n" .. secErr)
        end
    end
end

-- Set up recurring timer for main tick (every 1 second = 1000ms)
createTimer(1000, mainTick, { name = "mainTick", repeating = true, enabled = true })
