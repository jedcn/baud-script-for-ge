-- core_spec.lua
-- Tests for core.lua functions

local helper = require("test.test_helper")

describe("Core functions", function()

    before_each(function()
        helper.resetAll()
        dofile("main.lua")
    end)

    describe("resetData", function()

        it("clears position data", function()
            setSector(10, 20)
            setSectorPosition(100, 200)
            setOrbitingPlanet(3)

            resetData()

            local sX, sY = getSector()
            local spX, spY = getSectorPosition()
            assert.is_nil(sX)
            assert.is_nil(sY)
            assert.is_nil(spX)
            assert.is_nil(spY)
            assert.is_nil(getOrbitingPlanet())
        end)

        it("clears ship data", function()
            setShipHeading(180)
            setShipNeutronFlux(500)
            setShipStatus("OK")
            setShipInventory(gePackage.constants.MEN, 50)

            resetData()

            assert.is_nil(getShipHeading())
            assert.is_nil(getShipNeutronFlux())
            assert.is_nil(getShipStatus())
            assert.are.equal(0, getShipInventory(gePackage.constants.MEN))
            assert.is_false(getRotationInProgress())
        end)

        it("clears shield and warp data", function()
            setWarpSpeed(5)
            setShieldStatus("Up")
            setShieldCharge(100)

            resetData()

            assert.is_nil(getWarpSpeed())
            assert.is_nil(getShieldStatus())
            assert.is_nil(getShieldCharge())
        end)

        it("clears stored planet", function()
            setStoredPlanet(7)

            resetData()

            -- getStoredPlanet returns 1 as default when nil
            assert.are.equal(1, getStoredPlanet())
        end)

        it("clears state machine data", function()
            setReportType("Systems Report")
            setScanningPlanet(true)
            setScanningPlanetNumber(3)

            resetData()

            assert.is_nil(getReportType())
            assert.is_false(getScanningPlanet())
            assert.is_nil(getScanningPlanetNumber())
        end)

        it("clears navigation state machines", function()
            initNavigation()
            setNavigationActive(true)
            initRotto(180)
            initFlipAway(3)
            initSectorNav(5, 5, 100, 100)

            resetData()

            assert.is_false(getNavigationActive())
            assert.is_false(getRottoActive())
            assert.is_false(getFlipAwayActive())
            assert.is_false(getSectorNavActive())
        end)

    end)

end)

describe("Ship type and specs", function()

    before_each(function()
        helper.resetAll()
        dofile("main.lua")
    end)

    describe("setShipType / getShipType", function()

        it("stores and retrieves ship type", function()
            setShipType("Star Cruiser")
            assert.are.equal("Star Cruiser", getShipType())
        end)

        it("returns nil when not set", function()
            assert.is_nil(getShipType())
        end)

    end)

    describe("setShipName / getShipName", function()

        it("stores and retrieves ship name", function()
            setShipName("The Arbitrage")
            assert.are.equal("The Arbitrage", getShipName())
        end)

        it("returns nil when not set", function()
            assert.is_nil(getShipName())
        end)

    end)

    describe("getShipMaxWarp", function()

        it("returns correct max warp for known ship types", function()
            setShipType("Star Cruiser")
            assert.are.equal(25, getShipMaxWarp())

            setShipType("Heavy Freighter")
            assert.are.equal(8, getShipMaxWarp())

            setShipType("Dreadnought")
            assert.are.equal(50, getShipMaxWarp())
        end)

        it("returns 10 as default for unknown ship type", function()
            setShipType("Unknown Ship")
            assert.are.equal(10, getShipMaxWarp())
        end)

        it("returns 10 as default when ship type is not set", function()
            assert.are.equal(10, getShipMaxWarp())
        end)

    end)

    describe("getShipAcceleration", function()

        it("returns correct acceleration for known ship types", function()
            setShipType("Star Cruiser")
            assert.are.equal(10000, getShipAcceleration())

            setShipType("Freight Barge")
            assert.are.equal(1000, getShipAcceleration())
        end)

        it("returns 5000 as default for unknown ship type", function()
            setShipType("Unknown Ship")
            assert.are.equal(5000, getShipAcceleration())
        end)

    end)

    describe("getShipDecelRate", function()

        it("returns confirmed decel rate for Freight Barge", function()
            setShipType("Freight Barge")
            assert.are.equal(2, getShipDecelRate())
        end)

        it("returns confirmed decel rate for Star Cruiser", function()
            setShipType("Star Cruiser")
            assert.are.equal(20, getShipDecelRate())
        end)

        it("returns 10 as default for unknown ship type", function()
            setShipType("Unknown Ship")
            assert.are.equal(10, getShipDecelRate())
        end)

        it("returns 10 as default when ship type is not set", function()
            assert.are.equal(10, getShipDecelRate())
        end)

    end)

    describe("getShipAccelRate", function()

        it("is half the decel rate for Freight Barge", function()
            setShipType("Freight Barge")
            assert.are.equal(1, getShipAccelRate())
        end)

        it("is half the decel rate for Star Cruiser", function()
            setShipType("Star Cruiser")
            assert.are.equal(10, getShipAccelRate())
        end)

        it("is half the decel rate for Constitution Class Starship", function()
            setShipType("Constitution Class Starship")
            assert.are.equal(20, getShipAccelRate())
        end)

        it("returns 5 as default for unknown ship type", function()
            setShipType("Unknown Ship")
            assert.are.equal(5, getShipAccelRate())
        end)

    end)

    describe("getShipRotRate", function()

        -- rotRate = max_accel / 10 (degrees per 3-second tick, from game source)
        it("returns 100 degrees/tick for Freight Barge", function()
            setShipType("Freight Barge")
            assert.are.equal(100, getShipRotRate())
        end)

        it("returns 1000 degrees/tick for Star Cruiser", function()
            setShipType("Star Cruiser")
            assert.are.equal(1000, getShipRotRate())
        end)

        it("returns 2000 degrees/tick for Constitution Class Starship", function()
            setShipType("Constitution Class Starship")
            assert.are.equal(2000, getShipRotRate())
        end)

        it("returns 500 as default for unknown ship type", function()
            setShipType("Unknown Ship")
            assert.are.equal(500, getShipRotRate())
        end)

    end)

end)
