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

createAlias("^scapl(\\d+)$", function(matches)
    local planetToScan = matches[2]
    send("sca pl " .. planetToScan)
end, { type = "regex" })

echo("Finishing reading ge-main.lua")