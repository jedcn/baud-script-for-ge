-- combat_spec.lua
-- Tests for warp_and_fire_at_ship combat command

local helper = require("test.test_helper")

describe("warp_and_fire_at_ship", function()

    before_each(function()
        helper.resetAll()
        dofile("main.lua")
    end)

    it("sends warp 1 and stores pending ship", function()
        warp_and_fire_at_ship("a")

        assert.is_true(helper.wasSendCalledWith("warp 1"))
        assert.are.equal("a", gePackage.combat.warpAndFirePendingShip)
    end)

    it("does nothing if combat already active", function()
        gePackage.combat.active = true
        gePackage.combat.state = "scanning"

        warp_and_fire_at_ship("a")

        assert.is_false(helper.wasSendCalledWith("warp 1"))
    end)

    it("does nothing if warp-and-fire already pending", function()
        gePackage.combat.warpAndFirePendingShip = "b"

        warp_and_fire_at_ship("a")

        assert.is_false(helper.wasSendCalledWith("warp 1"))
        assert.are.equal("b", gePackage.combat.warpAndFirePendingShip)
    end)

    it("scans target ship when warp kicks in", function()
        warp_and_fire_at_ship("a")
        helper.sendCalls = {}

        helper.simulateLine("Helm reports WARP 1")

        assert.is_true(helper.wasSendCalledWith("scan sh a"))
        assert.is_nil(gePackage.combat.warpAndFirePendingShip)
    end)

    it("does not scan again on subsequent warp speed messages", function()
        warp_and_fire_at_ship("a")
        helper.simulateLine("Helm reports WARP 1")
        local scanCount = 0
        for _, call in ipairs(helper.sendCalls) do
            if call == "scan sh a" then scanCount = scanCount + 1 end
        end

        helper.simulateLine("Helm reports WARP 2")

        local scanCountAfter = 0
        for _, call in ipairs(helper.sendCalls) do
            if call == "scan sh a" then scanCountAfter = scanCountAfter + 1 end
        end
        assert.are.equal(scanCount, scanCountAfter)
    end)

    it("fires phasers with warp syntax and drops to warp 0 after bearing arrives", function()
        setSector(5, 5)
        warp_and_fire_at_ship("a")
        helper.simulateLine("Helm reports WARP 1")

        helper.simulateLine(" Bearing:  42 Heading: 180 Dist: 5000")

        assert.is_true(helper.wasSendCalledWith("pha 42"))
        assert.is_true(helper.wasSendCalledWith("warp 0"))
    end)

    it("resets combat state after firing", function()
        setSector(5, 5)
        warp_and_fire_at_ship("a")
        helper.simulateLine("Helm reports WARP 1")
        helper.simulateLine(" Bearing:  42 Heading: 180 Dist: 5000")

        assert.is_false(getCombatActive())
        assert.are.equal("idle", getCombatState())
        assert.is_false(gePackage.combat.dropWarpAfterFire)
    end)

end)
