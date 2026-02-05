--
-- This file contains Baud triggers.
--
-- They are [defined here](https://github.com/jedcn/baud?tab=readme-ov-file#createtriggerpattern-callback-options)
--

--
-- auto orbit
--
createTrigger("^In gravity pull of planet (\\d+), Helm compensating, Sir!$", function(matches)
    local planetNumber = matches[2]
    send("orbit " .. planetNumber)
end, { type = "regex" })

--
-- auto shields
--
createTrigger("^HELM reports we are leaving HYPERSPACE now, Sir!$", function(matches)
    send("shi up")
end, { type = "regex" })

--
-- Storage Management
--
createTrigger("^Leaving orbit Sir!$", function(matches)
    clearOrbitingPlanet()
end, { type = "regex" })

createTrigger("^We are now in stationary orbit around planet (\\d+)$", function(matches)
    local planetNumber = matches[2]
    setOrbitingPlanet(planetNumber)
end, { type = "regex" })

createTrigger("^Galactic Pos. Xsect:(-?\\d+)\\s+Ysect:(-?\\d+)$", function(matches)
    local xSector = matches[2]
    local ySector = matches[3]
    setSector(xSector, ySector)
end, { type = "regex" })

createTrigger("Range Scan Dist:\\d+ \\(s:(-?\\d+) (-?\\d+)\\)$", function(matches)
    local xSector = matches[2]
    local ySector = matches[3]
    setSector(xSector, ySector)
end, { type = "regex" })

createTrigger("Sector Scan mag:1x \\(s:(-?\\d+) (-?\\d+)\\)$", function(matches)
    local xSector = matches[2]
    local ySector = matches[3]
    setSector(xSector, ySector)
end, { type = "regex" })

createTrigger("^Sector Pos. X:(\\d+) Y:(\\d+)$", function(matches)
    local xSectorPosition = matches[2]
    local ySectorPosition = matches[3]
    setSectorPosition(xSectorPosition, ySectorPosition)
end, { type = "regex" })

-- sets orbiting planet from status display
createTrigger("^Orbiting Planet........  (\\d+)$", function(matches)
    local planetNumber = matches[2]
    setOrbitingPlanet(planetNumber)
end, { type = "regex" })

-- sets ship heading from status display
createTrigger("^Galactic Heading.......  (-?\\d+)$", function(matches)
    local heading = matches[2]
    setShipHeading(heading)
end, { type = "regex" })

createTrigger("^Heading.................... (-?\\d+)$", function(matches)
    local heading = matches[2]
    setShipHeading(heading)
end, { type = "regex" })

-- sets ship heading from helm message
createTrigger("^Helm reports we are now heading (-?\\d+) degrees.$", function(matches)
    local heading = matches[2]
    setShipHeading(heading)
end, { type = "regex" })

-- sets fighter count (only when not scanning a planet)
createTrigger("^Fighters..................\\s*(\\d+)$", function(matches)
    local fighterCount = matches[2]
    if not getScanningPlanet() then
        setShipInventory("Fighters", fighterCount)
    end
end, { type = "regex" })

-- clears ship inventory when cargo is 0
createTrigger("^Total Cargo Weight... 0 Tons$", function(matches)
    clearShipInventory()
end, { type = "regex" })

-- sets warp speed from interim helm message
createTrigger("^Helm reports WARP (\\d+)$", function(matches)
    local warpSpeed = matches[2]
    setWarpSpeed(warpSpeed)
end, { type = "regex" })


-- sets warp speed from helm message
createTrigger("^Helm reports speed is now Warp (\\d+\\.\\d+), Sir!$", function(matches)
    local warpSpeed = matches[2]
    setWarpSpeed(warpSpeed)
end, { type = "regex" })

createTrigger("^Speed..................Warp (\\d+\\.\\d+)$", function(matches)
    local warpSpeed = matches[2]
    setWarpSpeed(warpSpeed)
end, { type = "regex" })

-- sets warp speed to 0
createTrigger("^Helm reports we are at a dead stop, Sir!$", function(matches)
    setWarpSpeed(0)
end, { type = "regex" })

-- sets sector X/Y coordinates
createTrigger("^Navigating SS# (-?\\d+) (-?\\d+)$", function(matches)
    local xSector = matches[2]
    local ySector = matches[3]
    setSector(xSector, ySector)
end, { type = "regex" })

-- sets warp speed from status display
createTrigger("^Speed..................Warp (\\d+\\.\\d+)$", function(matches)
    local warpSpeed = matches[2]
    setWarpSpeed(warpSpeed)
end, { type = "regex" })

-- sets flux pod count (only when not scanning a planet)
createTrigger("^Flux pods..................\\s*(\\d+)$", function(matches)
    local fluxPodCount = matches[2]
    if not getScanningPlanet() then
        setShipInventory("Flux pods", fluxPodCount)
    end
end, { type = "regex" })

-- sets neutron flux level
createTrigger("^Neutron Flux............ (\\d+)$", function(matches)
    local neutronFlux = matches[2]
    setShipNeutronFlux(neutronFlux)
end, { type = "regex" })

--
-- STATE MACHINE
--


-- toggles the state machine for scan parsing
createTrigger("^--------------------------------------$", function(matches)
    toggleDashes()
end, { type = "regex" })

-- sets up planet scanning state
createTrigger("^Scanning Planet (\\d+)\\s*(.*)$", function(matches)
    local planetNumber = matches[2]
    local planetName = matches[3]
    setScanningPlanet(true)
    setScanningPlanetNumber(planetNumber)
    setScanningPlanetName(planetName)
end, { type = "regex" })

-- set shield strength
createTrigger("^Shields are at (\\d+) percent charge, Sir!", function(matches)
    local shieldCharge = matches[2]
    setShieldCharge(shieldCharge)
end, { type="regex" })

-- set shield strength
createTrigger("^Shield Bank Charge .... (\\d+)", function(matches)
    local shieldCharge = matches[2]
    setShieldCharge(shieldCharge)
end, { type="regex" })

createTrigger("^Shields energizing, Sir!", function()
    setShieldStatus("UP");
end, { type="regex" })

createTrigger("^Shields are now down, Sir!", function()
    setShieldStatus("DOWN");
end, { type="regex" })

createTrigger("^Shields \\(Mark-\\d+\\)...... (\\w+)$", function(matches)
    local status = matches[2]
    setShieldStatus(status)
end, { type="regex" })

createTrigger("^DCO reports............ (.+)$", function(matches)
    local shipStatus = matches[2]
    setShipStatus(shipStatus)
end, { type="regex" })