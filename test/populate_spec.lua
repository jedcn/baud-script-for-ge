-- populate_spec.lua
-- Tests for populate.lua state machine

local helper = require("test.test_helper")

describe("Populate loop", function()

    before_each(function()
        helper.resetAll()
        dofile("main.lua")
    end)

    -- =========================================================================
    -- startPopulate
    -- =========================================================================

    describe("startPopulate", function()

        it("sets active and transitions to verifying_ship_type", function()
            startPopulate(11, -9, 1, 11, -9, 3)

            assert.is_true(getPopulateActive())
            assert.are.equal("verifying_ship_type", getPopulateState())
        end)

        it("stores source and destination config", function()
            startPopulate(11, -9, 1, 11, -9, 3)

            assert.are.equal(11, gePackage.populate.src.sectorX)
            assert.are.equal(-9, gePackage.populate.src.sectorY)
            assert.are.equal(1,  gePackage.populate.src.planet)
            assert.are.equal(11, gePackage.populate.dest.sectorX)
            assert.are.equal(-9, gePackage.populate.dest.sectorY)
            assert.are.equal(3,  gePackage.populate.dest.planet)
        end)

        it("does not start if already running", function()
            startPopulate(11, -9, 1, 11, -9, 3)
            helper.echoCalls = {}

            startPopulate(11, -9, 1, 11, -9, 3)

            assert.is_true(helper.wasEchoCalledWith(
                "Populate loop is already running (state: verifying_ship_type)"))
        end)

    end)

    -- =========================================================================
    -- cancelPopulate
    -- =========================================================================

    describe("printStatusPopulate", function()

        it("reports inactive when not running", function()
            printStatusPopulate()

            assert.is_true(helper.wasEchoCalledWith("[populate] inactive"))
        end)

        it("reports state and coordinates when running", function()
            startPopulate(11, -9, 1, 11, -9, 3)
            helper.echoCalls = {}

            printStatusPopulate()

            local found = false
            for _, call in ipairs(helper.echoCalls) do
                if call:find("verifying_ship_type") and call:find("11,%-9 pl1") and call:find("11,%-9 pl3") then
                    found = true
                end
            end
            assert.is_true(found)
        end)

        it("includes trip count and men delivered", function()
            startPopulate(11, -9, 1, 11, -9, 3)
            gePackage.populate.tripCount = 2
            gePackage.populate.menDelivered = 999880
            helper.echoCalls = {}

            printStatusPopulate()

            local found = false
            for _, call in ipairs(helper.echoCalls) do
                if call:find("2 trips") and call:find("999880 men delivered") then
                    found = true
                end
            end
            assert.is_true(found)
        end)

    end)

    describe("cancelPopulate", function()

        it("stops the loop and resets to idle", function()
            startPopulate(11, -9, 1, 11, -9, 3)

            local navCancelled = false
            _G.cancelAllNavigation = function() navCancelled = true end

            cancelPopulate()

            assert.is_false(getPopulateActive())
            assert.are.equal("idle", getPopulateState())
            assert.is_true(navCancelled)
        end)

        it("reports when not running", function()
            cancelPopulate()

            assert.is_true(helper.wasEchoCalledWith("Populate loop is not running."))
        end)

        it("prints summary of trips and men delivered on cancel", function()
            startPopulate(11, -9, 1, 11, -9, 3)
            gePackage.populate.tripCount = 3
            gePackage.populate.menDelivered = 1499820
            helper.echoCalls = {}

            cancelPopulate()

            local found = false
            for _, call in ipairs(helper.echoCalls) do
                if call:find("3 trips") and call:find("1499820 men delivered") then
                    found = true
                end
            end
            assert.is_true(found)
        end)

    end)

    -- =========================================================================
    -- populateTick — verifying_ship_type
    -- =========================================================================

    describe("populateTick verifying_ship_type", function()

        it("sends rep sys on first tick", function()
            startPopulate(11, -9, 1, 11, -9, 3)
            helper.sendCalls = {}

            populateTick()

            assert.is_true(helper.wasSendCalledWith("rep sys"))
        end)

        it("does not send rep sys twice", function()
            startPopulate(11, -9, 1, 11, -9, 3)

            populateTick()  -- sends rep sys
            helper.sendCalls = {}
            populateTick()  -- should NOT resend

            assert.is_false(helper.wasSendCalledWith("rep sys"))
        end)

        it("cancels if ship type is not Freight Barge", function()
            startPopulate(11, -9, 1, 11, -9, 3)
            setShipType("Battle Cruiser")

            populateTick()  -- sends rep sys
            populateTick()  -- checks ship type, cancels

            assert.is_false(getPopulateActive())
            assert.are.equal("idle", getPopulateState())
        end)

        it("advances to verifying_inventory when ship is Freight Barge", function()
            startPopulate(11, -9, 1, 11, -9, 3)
            setShipType("Freight Barge")

            populateTick()  -- sends rep sys
            populateTick()  -- checks ship type, advances

            assert.are.equal("verifying_inventory", getPopulateState())
        end)

        it("waits when ship type is not yet known", function()
            startPopulate(11, -9, 1, 11, -9, 3)
            -- do NOT set ship type (nil)

            populateTick()  -- sends rep sys
            populateTick()  -- still waiting

            assert.are.equal("verifying_ship_type", getPopulateState())
        end)

    end)

    -- =========================================================================
    -- populateTick — verifying_inventory
    -- =========================================================================

    describe("populateTick verifying_inventory", function()

        local function advanceToVerifyingInventory()
            startPopulate(11, -9, 1, 11, -9, 3)
            setShipType("Freight Barge")
            populateTick()  -- verifying_ship_type: sends rep sys
            populateTick()  -- verifying_ship_type: advances
            -- now in verifying_inventory
        end

        it("sends rep inv on first tick", function()
            advanceToVerifyingInventory()
            helper.sendCalls = {}

            populateTick()

            assert.is_true(helper.wasSendCalledWith("rep inv"))
        end)

        it("cancels if ship has men loaded", function()
            advanceToVerifyingInventory()
            setShipInventory(gePackage.constants.MEN, 100)

            populateTick()  -- sends rep inv
            populateTick()  -- checks men, cancels

            assert.is_false(getPopulateActive())
            assert.are.equal("idle", getPopulateState())
        end)

        it("advances to navigating_to_source when inventory is empty", function()
            advanceToVerifyingInventory()
            setShipInventory(gePackage.constants.MEN, 0)

            populateTick()  -- sends rep inv
            populateTick()  -- checks men, advances

            assert.are.equal("navigating_to_source", getPopulateState())
        end)

    end)

    -- =========================================================================
    -- populateTick — navigating_to_source
    -- =========================================================================

    describe("populateTick navigating_to_source", function()

        local function setInState(state)
            startPopulate(11, -9, 1, 11, -9, 3)
            gePackage.populate.state = state
            gePackage.populate.commandSent = false
        end

        it("calls navToSectorAndPlanet with source coordinates", function()
            setInState("navigating_to_source")

            local navArgs = nil
            _G.navToSectorAndPlanet = function(x, y, px, py, p)
                navArgs = {x, y, px, py, p}
            end

            populateTick()

            assert.are.equal(11, navArgs[1])
            assert.are.equal(-9, navArgs[2])
            assert.is_nil(navArgs[3])
            assert.is_nil(navArgs[4])
            assert.are.equal(1, navArgs[5])
        end)

        it("transitions to loading_men when orbiting source planet", function()
            setInState("navigating_to_source")
            setSector(11, -9)
            setOrbitingPlanet(1)

            populateTick()

            assert.are.equal("loading_men", getPopulateState())
        end)

        it("does not re-call navToSectorAndPlanet on subsequent ticks", function()
            setInState("navigating_to_source")

            local navCallCount = 0
            _G.navToSectorAndPlanet = function() navCallCount = navCallCount + 1 end

            populateTick()  -- first tick: starts nav
            populateTick()  -- second tick: waiting for orbit

            assert.are.equal(1, navCallCount)
        end)

    end)

    -- =========================================================================
    -- populateTick — loading_men
    -- =========================================================================

    describe("populateTick loading_men", function()

        local function setInState(state)
            startPopulate(11, -9, 1, 11, -9, 3)
            gePackage.populate.state = state
            gePackage.populate.commandSent = false
        end

        it("sends tra up on first tick", function()
            setInState("loading_men")
            helper.sendCalls = {}

            populateTick()

            assert.is_true(helper.wasSendCalledWith("tra up 499940 men"))
        end)

        it("waits for transferUpComplete before advancing", function()
            setInState("loading_men")

            populateTick()  -- sends tra up

            assert.are.equal("loading_men", getPopulateState())
        end)

        it("advances to checking_flux when transfer complete trigger fires", function()
            setInState("loading_men")

            populateTick()  -- sends tra up
            setPopulateTransferUpCompleteFromTrigger()
            populateTick()  -- detects flag, advances

            assert.are.equal("checking_flux", getPopulateState())
        end)

    end)

    -- =========================================================================
    -- Transfer triggers
    -- =========================================================================

    describe("transfer triggers", function()

        it("setPopulateTransferUpCompleteFromTrigger sets the flag", function()
            startPopulate(11, -9, 1, 11, -9, 3)
            gePackage.populate.transferUpComplete = false

            setPopulateTransferUpCompleteFromTrigger()

            assert.is_true(gePackage.populate.transferUpComplete)
        end)

        it("setPopulateTransferDownCompleteFromTrigger sets the flag", function()
            startPopulate(11, -9, 1, 11, -9, 3)
            gePackage.populate.transferDownComplete = false

            setPopulateTransferDownCompleteFromTrigger()

            assert.is_true(gePackage.populate.transferDownComplete)
        end)

        it("men transferred from planet trigger fires the up-complete callback", function()
            startPopulate(11, -9, 1, 11, -9, 3)
            gePackage.populate.transferUpComplete = false

            helper.simulateLine("499940 men have been transferred from the planet Sir!")

            assert.is_true(gePackage.populate.transferUpComplete)
        end)

        it("men transferred to planet trigger fires the down-complete callback", function()
            startPopulate(11, -9, 1, 11, -9, 3)
            gePackage.populate.transferDownComplete = false

            helper.simulateLine("499940 men have been transferred to the planet Sir!")

            assert.is_true(gePackage.populate.transferDownComplete)
        end)

    end)

    -- =========================================================================
    -- populateTick — checking_flux
    -- =========================================================================

    describe("populateTick checking_flux", function()

        local function setInState(state)
            startPopulate(11, -9, 1, 11, -9, 3)
            gePackage.populate.state = state
            gePackage.populate.commandSent = false
        end

        it("sends flu on first tick", function()
            setInState("checking_flux")
            helper.sendCalls = {}

            populateTick()

            assert.is_true(helper.wasSendCalledWith("flu"))
        end)

        it("advances to navigating_to_dest when flux pods >= 3", function()
            setInState("checking_flux")
            setShipInventory(gePackage.constants.FLUX_PODS, 3)

            populateTick()  -- sends flu
            populateTick()  -- checks flux, advances

            assert.are.equal("navigating_to_dest", getPopulateState())
        end)

        it("advances to loading_flux when flux pods < 3", function()
            setInState("checking_flux")
            setShipInventory(gePackage.constants.FLUX_PODS, 1)

            populateTick()  -- sends flu
            populateTick()  -- checks flux, needs more

            assert.are.equal("loading_flux", getPopulateState())
        end)

        it("advances to navigating_to_dest when flux pods are 0 but 0 < 3 check routes to loading_flux", function()
            setInState("checking_flux")
            -- no flux pods in inventory at all

            populateTick()  -- sends flu
            populateTick()  -- 0 < 3, goes to loading_flux

            assert.are.equal("loading_flux", getPopulateState())
        end)

    end)

    -- =========================================================================
    -- populateTick — unloading_men
    -- =========================================================================

    describe("populateTick unloading_men", function()

        local function setInState(state)
            startPopulate(11, -9, 1, 11, -9, 3)
            gePackage.populate.state = state
            gePackage.populate.commandSent = false
        end

        it("sends tra down on first tick", function()
            setInState("unloading_men")
            helper.sendCalls = {}

            populateTick()

            assert.is_true(helper.wasSendCalledWith("tra down 499940 men"))
        end)

        it("waits for transferDownComplete before looping", function()
            setInState("unloading_men")

            populateTick()  -- sends tra down

            assert.are.equal("unloading_men", getPopulateState())
        end)

        it("loops back to navigating_to_source when transfer complete trigger fires", function()
            setInState("unloading_men")

            populateTick()  -- sends tra down
            setPopulateTransferDownCompleteFromTrigger()
            populateTick()  -- detects flag, loops

            assert.are.equal("navigating_to_source", getPopulateState())
        end)

        it("increments tripCount and menDelivered on each completed drop-off", function()
            setInState("unloading_men")

            populateTick()
            setPopulateTransferDownCompleteFromTrigger()
            populateTick()

            assert.are.equal(1, gePackage.populate.tripCount)
            assert.are.equal(499940, gePackage.populate.menDelivered)
        end)

        it("accumulates menDelivered across multiple trips", function()
            setInState("unloading_men")
            gePackage.populate.tripCount = 2
            gePackage.populate.menDelivered = 999880

            populateTick()
            setPopulateTransferDownCompleteFromTrigger()
            populateTick()

            assert.are.equal(3, gePackage.populate.tripCount)
            assert.are.equal(1499820, gePackage.populate.menDelivered)
        end)

    end)

    -- =========================================================================
    -- Alias dispatch
    -- =========================================================================

    describe("populate.planet alias", function()

        it("calls startPopulate with correct arguments", function()
            local args = nil
            _G.startPopulate = function(sX, sY, sP, dX, dY, dP)
                args = {sX, sY, sP, dX, dY, dP}
            end

            helper.simulateAlias("populate.planet src:11 -9 1 dest:11 -9 3")

            assert.is_not_nil(args)
            assert.are.equal(11, args[1])
            assert.are.equal(-9, args[2])
            assert.are.equal(1,  args[3])
            assert.are.equal(11, args[4])
            assert.are.equal(-9, args[5])
            assert.are.equal(3,  args[6])
        end)

        it("handles negative source sector", function()
            local args = nil
            _G.startPopulate = function(sX, sY, sP, dX, dY, dP)
                args = {sX, sY, sP, dX, dY, dP}
            end

            helper.simulateAlias("populate.planet src:-5 -3 2 dest:7 8 1")

            assert.are.equal(-5, args[1])
            assert.are.equal(-3, args[2])
            assert.are.equal(2,  args[3])
        end)

    end)

    describe("populate.cancel alias", function()

        it("calls cancelPopulate", function()
            local cancelled = false
            _G.cancelPopulate = function() cancelled = true end

            helper.simulateAlias("populate.cancel")

            assert.is_true(cancelled)
        end)

    end)

end)
