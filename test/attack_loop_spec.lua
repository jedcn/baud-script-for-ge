-- attack_loop_spec.lua
-- Tests for attack-loop.lua state machine

local helper = require("test.test_helper")

describe("Attack loop", function()

    before_each(function()
        helper.resetAll()
        dofile("main.lua")
    end)

    describe("startAssault", function()

        it("sets state to going_home", function()
            startAssault()

            assert.is_true(getAttackLoopActive())
            assert.are.equal("going_home", getAttackLoopState())
        end)

        it("starts in rotating state when at target planet", function()
            setSector(11, -9)
            setOrbitingPlanet(3)

            local rottoArg = nil
            _G.rotateToHeading = function(heading) rottoArg = heading end

            startAssault()

            assert.is_true(getAttackLoopActive())
            assert.are.equal("rotating", getAttackLoopState())
            assert.are.equal(0, rottoArg)
        end)

        it("does not start if already running", function()
            startAssault()
            helper.echoCalls = {}

            startAssault()

            assert.is_true(helper.wasEchoCalledWith("Assault loop is already running (state: going_home)"))
        end)

    end)

    describe("cancelAssault", function()

        it("stops the loop", function()
            startAssault()

            cancelAssault()

            assert.is_false(getAttackLoopActive())
            assert.are.equal("idle", getAttackLoopState())
        end)

        it("reports if not running", function()
            cancelAssault()

            assert.is_true(helper.wasEchoCalledWith("Assault loop is not running."))
        end)

    end)

    describe("printStatusAssault", function()

        it("reports inactive when not running", function()
            printStatusAssault()

            assert.is_true(helper.wasEchoCalledWith("Assault loop: inactive"))
        end)

        it("reports state when running", function()
            startAssault()
            helper.echoCalls = {}

            printStatusAssault()

            -- Should contain the current state
            local found = false
            for _, call in ipairs(helper.echoCalls) do
                if call:find("going_home") then
                    found = true
                end
            end
            assert.is_true(found)
        end)

    end)

    describe("attackLoopTick", function()

        it("does nothing when not active", function()
            helper.sendCalls = {}

            attackLoopTick()

            assert.are.equal(0, #helper.sendCalls)
        end)

        describe("going_home -> repairing", function()

            it("transitions immediately when already orbiting supply planet", function()
                setSector(9, -11)
                setOrbitingPlanet(3)
                startAssault()

                -- Mock doMaint
                local maintCalled = false
                _G.doMaint = function() maintCalled = true end

                -- First tick: going_home detects orbit, transitions to repairing
                attackLoopTick()
                assert.are.equal("repairing", getAttackLoopState())

                -- Second tick: repairing sends repair commands (stays in orbit)
                attackLoopTick()
                assert.is_true(maintCalled)
            end)

            it("does not match supply planet when orbiting same planet number in wrong sector", function()
                setSector(11, -9)  -- target sector, not supply
                setOrbitingPlanet(3)

                -- startAssault detects target planet, goes to rotating
                _G.rotateToHeading = function() end
                startAssault()

                -- Should NOT be in repairing (that would mean it confused target for supply)
                assert.are_not.equal("repairing", getAttackLoopState())
            end)

            it("starts navigation when not at supply planet", function()
                startAssault()

                _G.getNavigationActive = function() return false end
                _G.getSectorNavActive = function() return false end

                local navArgs = {}
                _G.navigateToSectorAndPlanet = function(sX, sY, pX, pY, planet)
                    navArgs = {sX, sY, pX, pY, planet}
                end

                attackLoopTick()

                assert.are.equal("going_home", getAttackLoopState())
                assert.are.equal(9, navArgs[1])
                assert.are.equal(-11, navArgs[2])
            end)

            it("does not start nav while nav is still active", function()
                startAssault()

                _G.getNavigationActive = function() return true end
                _G.getSectorNavActive = function() return false end

                local navCalled = false
                _G.navigateToSectorAndPlanet = function() navCalled = true end

                attackLoopTick()

                assert.are.equal("going_home", getAttackLoopState())
                assert.is_false(navCalled)
            end)

        end)

        describe("repairing -> loading", function()

            it("transitions when ship has no damage", function()
                startAssault()
                setAttackLoopState("repairing")

                setShipStatus("no damage")

                -- Mock navigateToSectorAndPlanet
                local navArgs = {}
                _G.navigateToSectorAndPlanet = function(sX, sY, pX, pY, planet)
                    navArgs = {sX, sY, pX, pY, planet}
                end

                attackLoopTick()

                assert.are.equal("loading", getAttackLoopState())
                -- Should have sent trade commands
                assert.is_true(helper.wasSendCalledWith("tra up 1 flu"))
                assert.is_true(helper.wasSendCalledWith("flu"))
                assert.is_true(helper.wasSendCalledWith("tra up 249980 tro"))
                -- Should navigate to target
                assert.are.equal(11, navArgs[1])
                assert.are.equal(-9, navArgs[2])
            end)

            it("does not transition while ship has damage", function()
                startAssault()
                setAttackLoopState("repairing")

                setShipStatus("Light damage")

                attackLoopTick()

                assert.are.equal("repairing", getAttackLoopState())
            end)

        end)

        describe("loading -> rotating", function()

            it("transitions when already orbiting target planet", function()
                startAssault()
                setAttackLoopState("loading")
                setSector(11, -9)
                setOrbitingPlanet(3)

                -- Mock rotateToHeading
                local rottoArg = nil
                _G.rotateToHeading = function(heading) rottoArg = heading end

                attackLoopTick()

                assert.are.equal("rotating", getAttackLoopState())
                assert.are.equal(0, rottoArg)
            end)

            it("starts navigation when not at target planet", function()
                startAssault()
                setAttackLoopState("loading")

                _G.getNavigationActive = function() return false end
                _G.getSectorNavActive = function() return false end

                local navArgs = {}
                _G.navigateToSectorAndPlanet = function(sX, sY, pX, pY, planet)
                    navArgs = {sX, sY, pX, pY, planet}
                end

                attackLoopTick()

                assert.are.equal("loading", getAttackLoopState())
                assert.are.equal(11, navArgs[1])
                assert.are.equal(-9, navArgs[2])
            end)

        end)

        describe("rotating -> checking_shields", function()

            it("transitions when rotto is done and heading matches", function()
                startAssault()
                setAttackLoopState("rotating")

                _G.getRottoActive = function() return false end
                setShipHeading(0)

                attackLoopTick()

                assert.are.equal("checking_shields", getAttackLoopState())
                assert.is_true(helper.wasSendCalledWith("shi up"))
                assert.is_true(helper.wasSendCalledWith("rep sys"))
            end)

            it("does not transition while rotto is active", function()
                startAssault()
                setAttackLoopState("rotating")

                _G.getRottoActive = function() return true end
                setShipHeading(0)

                attackLoopTick()

                assert.are.equal("rotating", getAttackLoopState())
            end)

        end)

        describe("checking_shields -> attacking", function()

            it("transitions when shields are at 100%", function()
                startAssault()
                setAttackLoopState("checking_shields")

                setShieldCharge(100)

                attackLoopTick()

                assert.are.equal("attacking", getAttackLoopState())
                assert.is_true(helper.wasSendCalledWith("attack 249980 tro"))
                assert.is_true(helper.wasSendCalledWith("imp 99 0"))
            end)

            it("does not transition when shields are below 100%", function()
                startAssault()
                setAttackLoopState("checking_shields")

                setShieldCharge(80)

                attackLoopTick()

                assert.are.equal("checking_shields", getAttackLoopState())
            end)

        end)

        describe("attacking -> escaping", function()

            it("transitions immediately", function()
                startAssault()
                setAttackLoopState("attacking")

                attackLoopTick()

                assert.are.equal("escaping", getAttackLoopState())
            end)

        end)

        describe("escaping -> going_home", function()

            it("transitions when sector changes from target", function()
                startAssault()
                setAttackLoopState("escaping")

                -- Simulate being in a different sector than the target (11, -9)
                setSector(12, -9)

                attackLoopTick()

                assert.are.equal("going_home", getAttackLoopState())
            end)

            it("does not transition while still in target sector", function()
                startAssault()
                setAttackLoopState("escaping")

                setSector(11, -9)

                attackLoopTick()

                assert.are.equal("escaping", getAttackLoopState())
            end)

        end)

    end)

end)
