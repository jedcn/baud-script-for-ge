-- main_spec.lua
-- Comprehensive tests for all triggers in main.lua

local helper = require("test.test_helper")

describe("GE Triggers", function()

    before_each(function()
        helper.resetAll()
        -- Load the main file (this registers all triggers)
        dofile("main.lua")
    end)

    -- =========================================================================
    -- Auto-response triggers (3)
    -- =========================================================================

    describe("Auto-response triggers", function()

        it("sends 'n' when prompted with (N)onstop, (Q)uit, or (C)ontinue?", function()
            helper.simulateLine("(N)onstop, (Q)uit, or (C)ontinue?")
            assert.is_true(helper.wasSendCalledWith("n"))
        end)

        it("sends orbit command when in gravity pull of planet", function()
            helper.simulateLine("In gravity pull of planet 42, Helm compensating, Sir!")
            assert.is_true(helper.wasSendCalledWith("orbit 42"))
        end)

        it("sends 'shi up' when leaving hyperspace", function()
            helper.simulateLine("HELM reports we are leaving HYPERSPACE now, Sir!")
            assert.is_true(helper.wasSendCalledWith("shi up"))
        end)

    end)

    -- =========================================================================
    -- Storage Management triggers (4)
    -- =========================================================================

    describe("Storage Management triggers", function()

        it("calls clearOrbitingPlanet when leaving orbit", function()
            local called = false
            local original = clearOrbitingPlanet
            _G.clearOrbitingPlanet = function() called = true end

            helper.simulateLine("Leaving orbit Sir!")

            assert.is_true(called)
            _G.clearOrbitingPlanet = original
        end)

        it("calls setOrbitingPlanet with planet number when entering orbit", function()
            local called_with = nil
            local original = setOrbitingPlanet
            _G.setOrbitingPlanet = function(num) called_with = num end

            helper.simulateLine("We are now in stationary orbit around planet 42")

            assert.equal("42", called_with)
            _G.setOrbitingPlanet = original
        end)

        it("calls setSectorXY with coordinates from Galactic Pos", function()
            local x, y = nil, nil
            local original = setSectorXY
            _G.setSectorXY = function(newX, newY) x, y = newX, newY end

            helper.simulateLine("Galactic Pos. Xsect:-25  Ysect:100")

            assert.equal("-25", x)
            assert.equal("100", y)
            _G.setSectorXY = original
        end)

        it("calls setSectorPositionXY with coordinates from Sector Pos", function()
            local x, y = nil, nil
            local original = setSectorPositionXY
            _G.setSectorPositionXY = function(newX, newY) x, y = newX, newY end

            helper.simulateLine("Sector Pos. X:50 Y:75")

            assert.equal("50", x)
            assert.equal("75", y)
            _G.setSectorPositionXY = original
        end)

    end)

    -- =========================================================================
    -- Status Display triggers (4)
    -- =========================================================================

    describe("Status Display triggers", function()

        it("calls setOrbitingPlanet from Orbiting Planet status line", function()
            local called_with = nil
            local original = setOrbitingPlanet
            _G.setOrbitingPlanet = function(num) called_with = num end

            helper.simulateLine("Orbiting Planet........  42")

            assert.equal("42", called_with)
            _G.setOrbitingPlanet = original
        end)

        it("calls setShipHeading from Galactic Heading status line", function()
            local called_with = nil
            local original = setShipHeading
            _G.setShipHeading = function(heading) called_with = heading end

            helper.simulateLine("Galactic Heading.......  180")

            assert.equal("180", called_with)
            _G.setShipHeading = original
        end)

        it("calls setWarpSpeed from Speed status line", function()
            local called_with = nil
            local original = setWarpSpeed
            _G.setWarpSpeed = function(speed) called_with = speed end

            helper.simulateLine("Speed..................Warp 5.50")

            assert.equal("5.50", called_with)
            _G.setWarpSpeed = original
        end)

        it("calls setShipNeutronFlux from Neutron Flux status line", function()
            local called_with = nil
            local original = setShipNeutronFlux
            _G.setShipNeutronFlux = function(flux) called_with = flux end

            helper.simulateLine("Neutron Flux............ 1000")

            assert.equal("1000", called_with)
            _G.setShipNeutronFlux = original
        end)

    end)

    -- =========================================================================
    -- Helm Message triggers (4)
    -- =========================================================================

    describe("Helm Message triggers", function()

        it("calls setShipHeading from helm heading message", function()
            local called_with = nil
            local original = setShipHeading
            _G.setShipHeading = function(heading) called_with = heading end

            helper.simulateLine("Helm reports we are now heading -45 degrees.")

            assert.equal("-45", called_with)
            _G.setShipHeading = original
        end)

        it("calls setWarpSpeed from helm speed message", function()
            local called_with = nil
            local original = setWarpSpeed
            _G.setWarpSpeed = function(speed) called_with = speed end

            helper.simulateLine("Helm reports speed is now Warp 3.25, Sir!")

            assert.equal("3.25", called_with)
            _G.setWarpSpeed = original
        end)

        it("calls setWarpSpeed with 0 when at dead stop", function()
            local called_with = nil
            local original = setWarpSpeed
            _G.setWarpSpeed = function(speed) called_with = speed end

            helper.simulateLine("Helm reports we are at a dead stop, Sir!")

            assert.equal(0, called_with)
            _G.setWarpSpeed = original
        end)

        it("calls setSectorXY from Navigating SS# message", function()
            local x, y = nil, nil
            local original = setSectorXY
            _G.setSectorXY = function(newX, newY) x, y = newX, newY end

            helper.simulateLine("Navigating SS# -10 20")

            assert.equal("-10", x)
            assert.equal("20", y)
            _G.setSectorXY = original
        end)

    end)

    -- =========================================================================
    -- Inventory triggers (3)
    -- =========================================================================

    describe("Inventory triggers", function()

        it("calls setShipInventory for Fighters when not scanning planet", function()
            local itemType, itemCount = nil, nil
            local original = setShipInventory
            _G.setShipInventory = function(t, c) itemType = t; itemCount = c end

            -- Ensure we're not scanning a planet
            initializeStateIfNeeded()
            setScanningPlanet(false)

            helper.simulateLine("Fighters..................   15")

            assert.equal("Fighters", itemType)
            assert.equal("15", itemCount)
            _G.setShipInventory = original
        end)

        it("does NOT call setShipInventory for Fighters when scanning planet", function()
            local called = false
            local original = setShipInventory
            _G.setShipInventory = function() called = true end

            -- Set scanning state to true
            initializeStateIfNeeded()
            setScanningPlanet(true)

            helper.simulateLine("Fighters..................   15")

            assert.is_false(called)
            _G.setShipInventory = original
        end)

        it("calls setShipInventory for Flux pods when not scanning planet", function()
            local itemType, itemCount = nil, nil
            local original = setShipInventory
            _G.setShipInventory = function(t, c) itemType = t; itemCount = c end

            -- Ensure we're not scanning a planet
            initializeStateIfNeeded()
            setScanningPlanet(false)

            helper.simulateLine("Flux pods..................    8")

            assert.equal("Flux pods", itemType)
            assert.equal("8", itemCount)
            _G.setShipInventory = original
        end)

        it("calls clearShipInventory when Total Cargo Weight is 0", function()
            local called = false
            local original = clearShipInventory
            _G.clearShipInventory = function() called = true end

            helper.simulateLine("Total Cargo Weight... 0 Tons")

            assert.is_true(called)
            _G.clearShipInventory = original
        end)

    end)

    -- =========================================================================
    -- State Machine triggers (2)
    -- =========================================================================

    describe("State Machine triggers", function()

        it("calls toggleDashes when dashes line is encountered", function()
            local called = false
            local original = toggleDashes
            _G.toggleDashes = function() called = true end

            helper.simulateLine("--------------------------------------")

            assert.is_true(called)
            _G.toggleDashes = original
        end)

        it("sets up planet scanning state when Scanning Planet is encountered", function()
            local scanningSet = false
            local planetNumber = nil
            local planetName = nil

            local origSetScanning = setScanningPlanet
            local origSetNumber = setScanningPlanetNumber
            local origSetName = setScanningPlanetName

            _G.setScanningPlanet = function(val) scanningSet = val end
            _G.setScanningPlanetNumber = function(num) planetNumber = num end
            _G.setScanningPlanetName = function(name) planetName = name end

            helper.simulateLine("Scanning Planet 7  New Terra")

            assert.is_true(scanningSet)
            assert.equal("7", planetNumber)
            assert.equal("New Terra", planetName)

            _G.setScanningPlanet = origSetScanning
            _G.setScanningPlanetNumber = origSetNumber
            _G.setScanningPlanetName = origSetName
        end)

    end)

    -- =========================================================================
    -- Report Type triggers (4)
    -- =========================================================================

    describe("Report Type triggers", function()

        it("echoes 'Systems Report' when Systems Report is encountered", function()
            helper.simulateLine("Systems Report")
            assert.is_true(helper.wasEchoCalledWith("Systems Report"))
        end)

        it("echoes 'Inventory Report' when Inventory Report is encountered", function()
            helper.simulateLine("Inventory Report")
            assert.is_true(helper.wasEchoCalledWith("Inventory Report"))
        end)

        it("echoes 'Accounting Division report' when encountered", function()
            helper.simulateLine("Accounting Division report")
            assert.is_true(helper.wasEchoCalledWith("Accounting Division report"))
        end)

        it("echoes 'Navigational Report' when Navigational Report is encountered", function()
            helper.simulateLine("Navigational Report")
            assert.is_true(helper.wasEchoCalledWith("Navigational Report"))
        end)

    end)

    -- =========================================================================
    -- Shield triggers (1)
    -- =========================================================================

    describe("Shield triggers", function()

        it("calls setShieldCharge with shield percentage", function()
            local called_with = nil
            local original = setShieldCharge
            _G.setShieldCharge = function(charge) called_with = charge end

            helper.simulateLine("Shields are at 75 percent charge, Sir!")

            assert.equal("75", called_with)
            _G.setShieldCharge = original
        end)

    end)

end)
