-- navigate_physics_spec.lua
-- Tests for navigate-physics.lua pure math functions

local helper = require("test.test_helper")

describe("navigate-physics", function()

    before_each(function()
        helper.resetAll()
        dofile("main.lua")
    end)

    -- -----------------------------------------------------------------------
    describe("computeStopDistance", function()

        -- Empirically validated: FB at warp 15 stops in ~9843 units.
        -- Formula: travel at current warp first, then decel by decelRate/tick.
        -- (15+13+11+9+7+5+3+1) × 154 = 9856
        it("matches observed Freight Barge stop distance from warp 15", function()
            local dist = computeStopDistance(15, 2)
            -- Observed in-game: ~9843. Formula gives 9856.
            -- Difference (~13) is rounding/measurement.  Accept ±20.
            assert.is_true(math.abs(dist - 9843) < 20,
                "expected ~9843, got " .. dist)
        end)

        it("returns 0 for warp 0", function()
            assert.are.equal(0, computeStopDistance(0, 2))
        end)

        it("returns 0 when warp equals decelRate (stops in one step, no reaction delay)", function()
            -- warp 2, decelRate 2: single-step stop → 0
            assert.are.equal(0, computeStopDistance(2, 2))
        end)

        it("handles single warp level above decelRate (multi-step, reaction delay applies)", function()
            -- warp 3, decelRate 2: 3 > 2, multi-step → travel 3, then 1 → (3+1)×154 = 616
            assert.are.equal(616, computeStopDistance(3, 2))
        end)

        it("returns 0 for Constitution Class from warp 30 (decelRate=40 >= warp)", function()
            -- decelRate=40 >= fromWarp=30: single-step stop → 0
            assert.are.equal(0, computeStopDistance(30, 40))
        end)

        it("returns 0 for Dreadnought from warp 14 (decelRate=30 >= warp)", function()
            -- Empirically observed: ship stopped with zero distance covered.
            -- decelRate=30 >= fromWarp=14: single-step stop → 0
            assert.are.equal(0, computeStopDistance(14, 30))
        end)

        it("Star Cruiser stop distance from warp 25 (decelRate=20 < warp, multi-step)", function()
            -- decelRate=20 < 25: multi-step → 25→5→0 → (25+5)×154 = 4620
            assert.are.equal(4620, computeStopDistance(25, 20))
        end)

    end)

    -- -----------------------------------------------------------------------
    describe("computeAccelDistance", function()

        -- NOTE: Not yet empirically validated in-game. Formula: accel first
        -- then move at new speed. Needs measurement to confirm.

        it("returns 0 for target warp 0", function()
            assert.are.equal(0, computeAccelDistance(0, 1))
        end)

        it("Freight Barge 0→15 accel distance", function()
            -- accelRate=1: speeds 1,2,...,15 each one tick → (1+2+...+15)×154
            -- = 120×154 = 18480
            assert.are.equal(18480, computeAccelDistance(15, 1))
        end)

        it("Star Cruiser 0→25 accel distance", function()
            -- accelRate=10: speeds 10, 20, 25 (capped) → (10+20+25)×154 = 8470
            assert.are.equal(8470, computeAccelDistance(25, 10))
        end)

        it("Constitution 0→30 accel distance", function()
            -- accelRate=20: speeds 20, 30 (capped) → (20+30)×154 = 7700
            assert.are.equal(7700, computeAccelDistance(30, 20))
        end)

        it("reaches target warp in one tick when accelRate >= target", function()
            -- accelRate=10, target=5: one tick to speed 5 → 5×154 = 770
            assert.are.equal(770, computeAccelDistance(5, 10))
        end)

    end)

    -- -----------------------------------------------------------------------
    describe("computeRotationTicks", function()

        it("returns 0 for 0 degrees", function()
            assert.are.equal(0, computeRotationTicks(0, 100))
        end)

        it("Freight Barge takes 2 ticks for 180 degrees (rotRate=100)", function()
            -- ceil(180/100) = 2
            assert.are.equal(2, computeRotationTicks(180, 100))
        end)

        it("Freight Barge takes 1 tick for 90 degrees", function()
            assert.are.equal(1, computeRotationTicks(90, 100))
        end)

        it("Star Cruiser takes 1 tick for any angle (rotRate=1000)", function()
            assert.are.equal(1, computeRotationTicks(180, 1000))
            assert.are.equal(1, computeRotationTicks(90, 1000))
        end)

        it("uses shortest arc for angles over 180", function()
            -- 270° clockwise = 90° counter-clockwise → 1 tick at rotRate=100
            assert.are.equal(1, computeRotationTicks(270, 100))
        end)

        it("handles negative angles (rotates the shortest way)", function()
            assert.are.equal(1, computeRotationTicks(-90, 100))
        end)

    end)

    -- -----------------------------------------------------------------------
    describe("planTrajectory", function()

        it("returns nil for zero distance", function()
            assert.is_nil(planTrajectory(0, 15, 1, 2))
        end)

        it("returns nil for negative distance", function()
            assert.is_nil(planTrajectory(-100, 15, 1, 2))
        end)

        it("Freight Barge long trip uses max warp", function()
            -- 100000 >> accel+decel overhead, should use warp 15
            local plan = planTrajectory(100000, 15, 1, 2)
            assert.are.equal(15, plan.warp)
        end)

        it("plan fields are present and non-negative", function()
            local plan = planTrajectory(50000, 15, 1, 2)
            assert.is_not_nil(plan.warp)
            assert.is_true(plan.accelTicks >= 0)
            assert.is_true(plan.cruiseTicks >= 0)
            assert.is_true(plan.decelTicks >= 0)
            assert.is_true(plan.etaSeconds > 0)
            assert.is_true(plan.decelAtDist > 0)
            assert.is_true(plan.repNavEvery >= 2)
        end)

        it("etaSeconds equals total ticks times TICK_SECONDS", function()
            local plan = planTrajectory(50000, 15, 1, 2)
            local expectedEta = (plan.accelTicks + plan.cruiseTicks + plan.decelTicks) * TICK_SECONDS
            assert.are.equal(expectedEta, plan.etaSeconds)
        end)

        it("picks a lower warp when distance is too short for max warp", function()
            -- FB overhead at warp 15: 18480 + 9856 = 28336
            -- A distance of 10000 can't fit warp 15
            local plan = planTrajectory(10000, 15, 1, 2)
            assert.is_true(plan.warp < 15)
        end)

        it("decelAtDist matches computeStopDistance for the chosen warp", function()
            local plan = planTrajectory(50000, 15, 1, 2)
            assert.are.equal(computeStopDistance(plan.warp, 2), plan.decelAtDist)
        end)

        it("total distance covered equals input distance", function()
            local distance = 50000
            local plan = planTrajectory(distance, 15, 1, 2)
            local accelDist = computeAccelDistance(plan.warp, 1)
            local decelDist = computeStopDistance(plan.warp, 2)
            local cruiseDist = plan.cruiseTicks * plan.warp * DISTANCE_PER_WARP
            -- Within one tick of travel (ceiling rounding in cruiseTicks)
            local covered = accelDist + cruiseDist + decelDist
            assert.is_true(covered >= distance,
                "covered " .. covered .. " should be >= " .. distance)
            assert.is_true(covered < distance + plan.warp * DISTANCE_PER_WARP,
                "covered " .. covered .. " overshoots by more than one tick")
        end)

    end)

end)
