-- aliases_spec.lua
-- Tests for the nav.to alias patterns and their dispatch

local helper = require("test.test_helper")

describe("nav.to aliases", function()

    local calls = {}

    before_each(function()
        helper.resetAll()
        dofile("main.lua")
        calls = {}
        -- Stub functions defined by navigate.lua / navigate-nav.lua (set AFTER dofile
        -- so we override the real implementations for these dispatch tests)
        _G.navToPlanet = function(n)
            table.insert(calls, { fn = "navToPlanet", n = n })
        end
        _G.navToShip = function(letter)
            table.insert(calls, { fn = "navToShip", letter = letter })
        end
        _G.navToSector = function(x, y, posX, posY)
            table.insert(calls, { fn = "navToSector", x = x, y = y, posX = posX, posY = posY })
        end
        _G.navToSectorAndPlanet = function(x, y, posX, posY, n)
            table.insert(calls, { fn = "navToSectorAndPlanet", x = x, y = y, posX = posX, posY = posY, n = n })
        end
        _G.flipAwayFromPlanet = function()
            table.insert(calls, { fn = "flipAwayFromPlanet" })
        end
        _G.rotateToHeading = function(h)
            table.insert(calls, { fn = "rotateToHeading", h = h })
        end
        _G.cancelAllNavigation = function()
            table.insert(calls, { fn = "cancelAllNavigation" })
        end
        _G.getAllNavigationStatusText = function()
            return "No navigation active"
        end
    end)

    -- -----------------------------------------------------------------------
    describe("nav.to <N> (planet in current sector)", function()

        it("dispatches navToPlanet with the planet number", function()
            helper.simulateAlias("nav.to 3")
            assert.are.equal(1, #calls)
            assert.are.equal("navToPlanet", calls[1].fn)
            assert.are.equal(3, calls[1].n)
        end)

        it("works for planet 1", function()
            helper.simulateAlias("nav.to 1")
            assert.are.equal("navToPlanet", calls[1].fn)
            assert.are.equal(1, calls[1].n)
        end)

        it("works for planet 9 (maximum)", function()
            helper.simulateAlias("nav.to 9")
            assert.are.equal("navToPlanet", calls[1].fn)
            assert.are.equal(9, calls[1].n)
        end)

        it("does not match planet 0", function()
            local matched = helper.simulateAlias("nav.to 0")
            assert.is_false(matched)
        end)

    end)

    -- -----------------------------------------------------------------------
    describe("nav.to <letter> (ship)", function()

        it("dispatches navToShip with the letter", function()
            helper.simulateAlias("nav.to a")
            assert.are.equal(1, #calls)
            assert.are.equal("navToShip", calls[1].fn)
            assert.are.equal("a", calls[1].letter)
        end)

        it("works for any lowercase letter", function()
            helper.simulateAlias("nav.to z")
            assert.are.equal("navToShip", calls[1].fn)
            assert.are.equal("z", calls[1].letter)
        end)

    end)

    -- -----------------------------------------------------------------------
    describe("nav.to <X> <Y> (sector, center)", function()

        it("dispatches navToSector with sector coords and no position", function()
            helper.simulateAlias("nav.to 5 -3")
            assert.are.equal(1, #calls)
            assert.are.equal("navToSector", calls[1].fn)
            assert.are.equal(5, calls[1].x)
            assert.are.equal(-3, calls[1].y)
            assert.is_nil(calls[1].posX)
            assert.is_nil(calls[1].posY)
        end)

        it("handles negative X and Y", function()
            helper.simulateAlias("nav.to -10 -10")
            assert.are.equal("navToSector", calls[1].fn)
            assert.are.equal(-10, calls[1].x)
            assert.are.equal(-10, calls[1].y)
        end)

        it("handles large sector values", function()
            helper.simulateAlias("nav.to 1000 -1000")
            assert.are.equal("navToSector", calls[1].fn)
            assert.are.equal(1000, calls[1].x)
            assert.are.equal(-1000, calls[1].y)
        end)

    end)

    -- -----------------------------------------------------------------------
    describe("nav.to <X> <Y> <N> (sector then planet)", function()

        it("dispatches navToSectorAndPlanet with no position", function()
            helper.simulateAlias("nav.to 5 -3 2")
            assert.are.equal(1, #calls)
            assert.are.equal("navToSectorAndPlanet", calls[1].fn)
            assert.are.equal(5, calls[1].x)
            assert.are.equal(-3, calls[1].y)
            assert.is_nil(calls[1].posX)
            assert.is_nil(calls[1].posY)
            assert.are.equal(2, calls[1].n)
        end)

        it("does not match planet 0 (planet numbers are 1-9 only)", function()
            -- "nav.to 5 -3 0" has three numbers but 0 is not [1-9],
            -- so no alias pattern matches
            local matched = helper.simulateAlias("nav.to 5 -3 0")
            assert.is_false(matched)
        end)

    end)

    -- -----------------------------------------------------------------------
    describe("nav.to <X> <Y> <posX> <posY> (sector with position)", function()

        it("dispatches navToSector with sector and in-sector position", function()
            helper.simulateAlias("nav.to 5 -3 2000 8000")
            assert.are.equal(1, #calls)
            assert.are.equal("navToSector", calls[1].fn)
            assert.are.equal(5, calls[1].x)
            assert.are.equal(-3, calls[1].y)
            assert.are.equal(2000, calls[1].posX)
            assert.are.equal(8000, calls[1].posY)
        end)

    end)

    -- -----------------------------------------------------------------------
    describe("nav.to <X> <Y> <posX> <posY> <N> (sector, position, planet)", function()

        it("dispatches navToSectorAndPlanet with all args", function()
            helper.simulateAlias("nav.to 5 -3 2000 8000 3")
            assert.are.equal(1, #calls)
            assert.are.equal("navToSectorAndPlanet", calls[1].fn)
            assert.are.equal(5, calls[1].x)
            assert.are.equal(-3, calls[1].y)
            assert.are.equal(2000, calls[1].posX)
            assert.are.equal(8000, calls[1].posY)
            assert.are.equal(3, calls[1].n)
        end)

    end)

    -- -----------------------------------------------------------------------
    describe("flip.away", function()

        it("calls flipAwayFromPlanet", function()
            helper.simulateAlias("flip.away")
            assert.are.equal(1, #calls)
            assert.are.equal("flipAwayFromPlanet", calls[1].fn)
        end)

    end)

    -- -----------------------------------------------------------------------
    describe("rot.to <N>", function()

        it("calls rotateToHeading with the heading", function()
            helper.simulateAlias("rot.to 180")
            assert.are.equal(1, #calls)
            assert.are.equal("rotateToHeading", calls[1].fn)
            assert.are.equal(180, calls[1].h)
        end)

        it("works for heading 0", function()
            helper.simulateAlias("rot.to 0")
            assert.are.equal(1, #calls)
            assert.are.equal("rotateToHeading", calls[1].fn)
            assert.are.equal(0, calls[1].h)
        end)

    end)

    -- -----------------------------------------------------------------------
    describe("nav.cancel", function()

        it("calls cancelAllNavigation", function()
            helper.simulateAlias("nav.cancel")
            assert.are.equal(1, #calls)
            assert.are.equal("cancelAllNavigation", calls[1].fn)
        end)

    end)

    -- -----------------------------------------------------------------------
    describe("nav.status", function()

        it("echoes navigation status text", function()
            helper.simulateAlias("nav.status")
            assert.is_true(#helper.echoCalls > 0)
        end)

    end)

end)
