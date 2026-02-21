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
