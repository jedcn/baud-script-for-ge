-- Navigation tick (if function exists)
if navigationTick then
    local navStatus, navErr = pcall(navigationTick)
    if not navStatus then
        echo("\n\nCaught an error in navigationTick:\n\n" .. navErr)
    end
end
