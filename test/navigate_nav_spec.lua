-- navigate_nav_spec.lua
-- Tests for navigate-nav.lua: navToPlanet, navToShip, navToSector, navToSectorAndPlanet
-- and the navNavTick state machine.

local helper = require("test.test_helper")

describe("navigate-nav", function()

  before_each(function()
    helper.resetAll()
    dofile("main.lua")
    -- Default ship: no type set → maxWarp=10, decelRate=10, accelRate=5
  end)

  -- =========================================================================
  describe("navToPlanet", function()

    it("rejects invalid planet numbers", function()
      assert.is_false(navToPlanet(0))
      assert.is_false(navToPlanet(10))
    end)

    it("rejects if navigation already active", function()
      navToPlanet(3)
      assert.is_false(navToPlanet(3))
    end)

    it("sets navigation active with nav_planet phase", function()
      navToPlanet(3)
      assert.is_true(getNavigationActive())
      assert.are.equal("nav_planet", getNavigationPhase())
    end)

    it("sets correct planet number", function()
      navToPlanet(5)
      assert.are.equal(5, getNavigationTargetPlanet())
    end)

    it("starts in navpl_scanning state", function()
      navToPlanet(3)
      assert.are.equal("navpl_scanning", getNavigationState())
    end)

    it("returns true on success", function()
      assert.is_true(navToPlanet(1))
    end)

  end)

  -- =========================================================================
  describe("navNavTick nav_planet phase", function()

    it("navpl_scanning: sends scan planet command and transitions to awaiting_scan", function()
      navToPlanet(3)
      navNavTick()
      assert.is_true(helper.wasSendCalledWith("scan planet 3"))
      assert.are.equal("navpl_awaiting_scan", getNavigationState())
    end)

    it("navpl_awaiting_scan: waits when no scan data", function()
      navToPlanet(3)
      navNavTick()  -- scanning → awaiting_scan
      helper.sendCalls = {}
      navNavTick()  -- awaiting_scan: no data yet → stays
      assert.are.equal("navpl_awaiting_scan", getNavigationState())
      assert.are.equal(0, #helper.sendCalls)
    end)

    it("navpl_awaiting_scan: transitions to rotating when scan data arrives", function()
      navToPlanet(3)
      navNavTick()  -- navpl_scanning → navpl_awaiting_scan + sends scan
      -- Simulate scan result (bearing=45, distance=5000)
      setNavigationPlanetScanBearing(45)
      setNavigationPlanetScanDistance(5000)
      navNavTick()  -- navpl_awaiting_scan → navpl_rotating (has data)
      assert.are.equal("navpl_rotating", getNavigationState())
    end)

    it("navpl_awaiting_scan: plan is set when scan data arrives", function()
      navToPlanet(3)
      navNavTick()
      setNavigationPlanetScanBearing(45)
      setNavigationPlanetScanDistance(5000)
      navNavTick()
      assert.is_not_nil(gePackage.navigation.plan)
      assert.is_not_nil(gePackage.navigation.plan.warp)
    end)

    it("navpl_rotating: sends rot command when bearing is significant", function()
      navToPlanet(3)
      navNavTick()
      setNavigationPlanetScanBearing(45)
      setNavigationPlanetScanDistance(5000)
      navNavTick()  -- → navpl_rotating
      helper.sendCalls = {}
      navNavTick()  -- navpl_rotating → sends rot 45
      assert.is_true(helper.wasSendCalledWith("rot 45"))
      assert.are.equal("navpl_awaiting_rotation", getNavigationState())
    end)

    it("navpl_rotating: skips rotation when bearing is within 2 degrees", function()
      navToPlanet(3)
      navNavTick()
      setNavigationPlanetScanBearing(1)  -- within 2 degrees
      setNavigationPlanetScanDistance(5000)
      navNavTick()  -- → navpl_rotating
      navNavTick()  -- navpl_rotating: bearing=1, skip rot → navpl_setting_warp
      assert.are.equal("navpl_setting_warp", getNavigationState())
    end)

    it("navpl_awaiting_rotation: waits for rotationComplete flag", function()
      navToPlanet(3)
      navNavTick()
      setNavigationPlanetScanBearing(45)
      setNavigationPlanetScanDistance(5000)
      navNavTick()  -- → navpl_rotating
      navNavTick()  -- → navpl_awaiting_rotation
      navNavTick()  -- still awaiting
      assert.are.equal("navpl_awaiting_rotation", getNavigationState())
    end)

    it("navpl_awaiting_rotation: transitions when rotationComplete is set", function()
      navToPlanet(3)
      navNavTick()
      setNavigationPlanetScanBearing(45)
      setNavigationPlanetScanDistance(5000)
      navNavTick()  -- → navpl_rotating
      navNavTick()  -- → navpl_awaiting_rotation
      -- Simulate rotation complete trigger
      gePackage.navigation.rotationComplete = true
      navNavTick()  -- → navpl_setting_warp
      assert.are.equal("navpl_setting_warp", getNavigationState())
    end)

    it("navpl_setting_warp: sends warp command and transitions to cruising", function()
      navToPlanet(3)
      navNavTick()
      setNavigationPlanetScanBearing(1)
      setNavigationPlanetScanDistance(5000)
      navNavTick()  -- → navpl_rotating
      navNavTick()  -- bearing=1 → navpl_setting_warp
      helper.sendCalls = {}
      navNavTick()  -- navpl_setting_warp → sends warp N
      assert.are.equal("navpl_cruising", getNavigationState())
      -- At distance 5000 with default ship (maxWarp=10, decelRate=10, accelRate=5)
      -- planTrajectory picks some warp > 0
      assert.is_true(#helper.sendCalls > 0)
    end)

    it("navpl_setting_warp: sends warp and transitions to cruising", function()
      navToPlanet(3)
      navNavTick()
      setNavigationPlanetScanBearing(1)
      setNavigationPlanetScanDistance(5000)
      navNavTick()  -- → navpl_rotating
      navNavTick()  -- → navpl_setting_warp
      helper.sendCalls = {}
      navNavTick()  -- → sends warp, state = navpl_cruising
      assert.are.equal("navpl_cruising", getNavigationState())
      assert.is_true(#helper.sendCalls > 0)
    end)

    it("navpl_cruising: scans every TICK_SECONDS regardless of trip length", function()
      navToPlanet(3)
      navNavTick()
      setNavigationPlanetScanBearing(1)
      setNavigationPlanetScanDistance(5000)
      navNavTick()  -- → navpl_rotating
      navNavTick()  -- → navpl_setting_warp
      navNavTick()  -- → navpl_cruising, lastCommand=now
      -- Force lastCommand to be TICK_SECONDS ago
      gePackage.navigation.lastCommand = os.time() - TICK_SECONDS
      helper.sendCalls = {}
      navNavTick()  -- scan fires
      assert.is_true(helper.wasSendCalledWith("scan planet 3"))
      assert.are.equal("navpl_awaiting_cruise_scan", getNavigationState())
    end)

    it("navpl_decelerating: scans planet when speed reaches 0", function()
      navToPlanet(3)
      gePackage.navigation.state = "navpl_decelerating"
      setWarpSpeed(0)
      navNavTick()
      assert.is_true(helper.wasSendCalledWith("scan planet 3"))
      assert.are.equal("navpl_post_stop_scan", getNavigationState())
    end)

    it("navpl_post_stop_scan: transitions to orbiting when within threshold", function()
      navToPlanet(3)
      gePackage.navigation.state = "navpl_post_stop_scan"
      gePackage.navigation.lastCommand = os.time()
      setNavigationPlanetScanBearing(0)
      setNavigationPlanetScanDistance(200)  -- within 250 threshold
      navNavTick()
      assert.are.equal("navpl_orbiting", getNavigationState())
    end)

    it("navpl_post_stop_scan: starts impulse approach when too far", function()
      navToPlanet(3)
      gePackage.navigation.state = "navpl_post_stop_scan"
      gePackage.navigation.lastCommand = os.time()
      setNavigationPlanetScanBearing(0)
      setNavigationPlanetScanDistance(495)  -- beyond 250 threshold
      navNavTick()
      assert.is_true(helper.wasSendCalledWith("imp 99"))
      assert.are.equal("navpl_impulse_approach", getNavigationState())
    end)

    it("navpl_impulse_approach: scans planet each tick", function()
      navToPlanet(3)
      gePackage.navigation.state = "navpl_impulse_approach"
      gePackage.navigation.lastCommand = 0  -- force immediate scan
      navNavTick()
      assert.is_true(helper.wasSendCalledWith("scan planet 3"))
      assert.are.equal("navpl_awaiting_impulse_scan", getNavigationState())
    end)

    it("navpl_awaiting_impulse_scan: stops and moves to orbiting when close enough", function()
      navToPlanet(3)
      gePackage.navigation.state = "navpl_awaiting_impulse_scan"
      gePackage.navigation.lastCommand = os.time()
      setNavigationPlanetScanBearing(0)
      setNavigationPlanetScanDistance(100)  -- within threshold
      navNavTick()
      assert.is_true(helper.wasSendCalledWith("warp 0"))
      assert.are.equal("navpl_impulse_stopping", getNavigationState())
    end)

    it("navpl_awaiting_impulse_scan: continues approach when still too far", function()
      navToPlanet(3)
      gePackage.navigation.state = "navpl_awaiting_impulse_scan"
      gePackage.navigation.lastCommand = os.time()
      setNavigationPlanetScanBearing(0)
      setNavigationPlanetScanDistance(400)  -- still too far
      navNavTick()
      assert.are.equal("navpl_impulse_approach", getNavigationState())
    end)

    it("navpl_impulse_stopping: transitions to orbiting when stopped", function()
      navToPlanet(3)
      gePackage.navigation.state = "navpl_impulse_stopping"
      setWarpSpeed(0)
      navNavTick()
      assert.are.equal("navpl_orbiting", getNavigationState())
    end)

    it("navpl_orbiting: sends orb command and completes when orbit confirmed", function()
      navToPlanet(3)
      -- Jump straight to orbiting state
      gePackage.navigation.state = "navpl_orbiting"
      gePackage.navigation.lastCommand = 0  -- force immediate send
      navNavTick()  -- sends orb 3
      assert.is_true(helper.wasSendCalledWith("orb 3"))
    end)

    it("navpl_orbiting: re-approaches after too many failures", function()
      navToPlanet(3)
      gePackage.navigation.state = "navpl_orbiting"
      gePackage.navigation.lastCommand = 0
      gePackage.navigation.orbitAttempts = 8  -- one more will trigger re-approach
      navNavTick()
      assert.is_true(helper.wasSendCalledWith("scan planet 3"))
      assert.are.equal("navpl_post_stop_scan", getNavigationState())
    end)

    it("completes when orbit is confirmed mid-tick", function()
      navToPlanet(3)
      gePackage.navigation.state = "navpl_orbiting"
      -- Simulate already orbiting the target
      setOrbitingPlanet(3)
      navNavTick()  -- detects orbit, sets active = false
      assert.is_false(getNavigationActive())
      assert.are.equal("idle", getNavigationState())
    end)

  end)

  -- =========================================================================
  describe("navToShip", function()

    it("rejects if navigation already active", function()
      navToPlanet(3)
      assert.is_false(navToShip("a"))
    end)

    it("sets navigation active with nav_ship phase", function()
      navToShip("b")
      assert.is_true(getNavigationActive())
      assert.are.equal("nav_ship", getNavigationPhase())
    end)

    it("starts in navsh_scanning state", function()
      navToShip("c")
      assert.are.equal("navsh_scanning", getNavigationState())
    end)

    it("stores the ship letter", function()
      navToShip("z")
      assert.are.equal("z", gePackage.navigation.navShipLetter)
    end)

    it("returns true on success", function()
      assert.is_true(navToShip("a"))
    end)

  end)

  -- =========================================================================
  describe("navNavTick nav_ship phase", function()

    it("navsh_scanning: sends scan sh command and transitions to awaiting_scan", function()
      navToShip("a")
      navNavTick()
      assert.is_true(helper.wasSendCalledWith("scan sh a"))
      assert.are.equal("navsh_awaiting_scan", getNavigationState())
    end)

    it("navsh_awaiting_scan: waits when no scan data", function()
      navToShip("a")
      navNavTick()  -- → navsh_awaiting_scan
      helper.sendCalls = {}
      navNavTick()  -- no data → stays
      assert.are.equal("navsh_awaiting_scan", getNavigationState())
    end)

    it("navsh_awaiting_scan: transitions to rotating when bearing and distance arrive", function()
      navToShip("a")
      navNavTick()  -- → navsh_awaiting_scan
      -- Simulate trigger setting scan data
      setNavShipScanFromTrigger(-30, 50000)
      navNavTick()  -- → navsh_rotating
      assert.are.equal("navsh_rotating", getNavigationState())
    end)

    it("navsh_rotating: sends rot command when bearing is significant", function()
      navToShip("a")
      navNavTick()
      setNavShipScanFromTrigger(-45, 50000)
      navNavTick()  -- → navsh_rotating
      helper.sendCalls = {}
      navNavTick()  -- sends rot -45
      assert.is_true(helper.wasSendCalledWith("rot -45"))
      assert.are.equal("navsh_awaiting_rotation", getNavigationState())
    end)

    it("navsh_rotating: skips rotation when bearing is within 2 degrees", function()
      navToShip("a")
      navNavTick()
      setNavShipScanFromTrigger(0, 50000)
      navNavTick()  -- → navsh_rotating
      navNavTick()  -- bearing=0 → navsh_launching
      assert.are.equal("navsh_launching", getNavigationState())
    end)

    it("navsh_launching: sends warp command and transitions to traveling", function()
      navToShip("a")
      navNavTick()
      setNavShipScanFromTrigger(0, 50000)
      navNavTick()  -- → navsh_rotating
      navNavTick()  -- → navsh_launching
      helper.sendCalls = {}
      navNavTick()  -- sends warp N → navsh_traveling
      assert.are.equal("navsh_traveling", getNavigationState())
      assert.is_true(#helper.sendCalls > 0)
    end)

    it("navsh_launching: sets a deadline for stopping", function()
      navToShip("a")
      navNavTick()
      setNavShipScanFromTrigger(0, 50000)
      navNavTick()  -- → navsh_rotating
      navNavTick()  -- → navsh_launching
      navNavTick()  -- → navsh_traveling, sets deadline
      assert.is_not_nil(gePackage.navigation.deadline)
      assert.is_true(gePackage.navigation.deadline > os.time())
    end)

    it("navsh_traveling: stops when deadline is reached", function()
      navToShip("a")
      navNavTick()
      setNavShipScanFromTrigger(0, 50000)
      navNavTick()  -- → navsh_rotating
      navNavTick()  -- → navsh_launching
      navNavTick()  -- → navsh_traveling
      -- Force deadline to be in the past
      gePackage.navigation.deadline = os.time() - 1
      helper.sendCalls = {}
      navNavTick()  -- deadline reached → warp 0, done
      assert.is_true(helper.wasSendCalledWith("warp 0"))
      assert.is_false(getNavigationActive())
    end)

  end)

  -- =========================================================================
  describe("setNavShipScanFromTrigger", function()

    it("sets bearing and distance when in navsh_awaiting_scan state", function()
      navToShip("a")
      navNavTick()  -- → navsh_awaiting_scan
      setNavShipScanFromTrigger(-30, 141793)
      assert.are.equal(-30, gePackage.navigation.navShipBearing)
      assert.are.equal(141793, gePackage.navigation.navShipDistance)
    end)

    it("ignores the call when not in nav_ship phase", function()
      navToPlanet(3)
      setNavShipScanFromTrigger(-30, 141793)
      assert.is_nil(gePackage.navigation.navShipBearing)
    end)

    it("ignores the call when not in awaiting_scan state", function()
      navToShip("a")
      -- Still in navsh_scanning (haven't ticked yet)
      setNavShipScanFromTrigger(-30, 141793)
      assert.is_nil(gePackage.navigation.navShipBearing)
    end)

  end)

  -- =========================================================================
  describe("setNavNavRotationCompleteFromTrigger", function()

    it("sets rotationComplete for navpl_awaiting_rotation", function()
      navToPlanet(3)
      navNavTick()  -- → navpl_awaiting_scan
      setNavigationPlanetScanBearing(45)
      setNavigationPlanetScanDistance(5000)
      navNavTick()  -- → navpl_rotating
      navNavTick()  -- → navpl_awaiting_rotation
      gePackage.navigation.rotationComplete = false
      setNavNavRotationCompleteFromTrigger()
      assert.is_true(gePackage.navigation.rotationComplete)
    end)

    it("sets rotationComplete for navsh_awaiting_rotation", function()
      navToShip("a")
      navNavTick()  -- → navsh_awaiting_scan
      setNavShipScanFromTrigger(45, 50000)
      navNavTick()  -- → navsh_rotating
      navNavTick()  -- → navsh_awaiting_rotation
      gePackage.navigation.rotationComplete = false
      setNavNavRotationCompleteFromTrigger()
      assert.is_true(gePackage.navigation.rotationComplete)
    end)

    it("does nothing when navigation is not active", function()
      -- Should not error when nav is inactive
      setNavNavRotationCompleteFromTrigger()
    end)

  end)

  -- =========================================================================
  describe("navToSector", function()

    it("rejects invalid sector coordinates", function()
      assert.is_false(navToSector(nil, 3))
      assert.is_false(navToSector(5, nil))
    end)

    it("calls navigateToSector (delegates to existing sector nav)", function()
      local calls = {}
      _G.navigateToSector = function(x, y, posX, posY)
        table.insert(calls, { x = x, y = y, posX = posX, posY = posY })
        return true
      end
      navToSector(5, -3)
      assert.are.equal(1, #calls)
      assert.are.equal(5,    calls[1].x)
      assert.are.equal(-3,   calls[1].y)
      assert.are.equal(5000, calls[1].posX)
      assert.are.equal(5000, calls[1].posY)
    end)

    it("passes explicit position through to navigateToSector", function()
      local calls = {}
      _G.navigateToSector = function(x, y, posX, posY)
        table.insert(calls, { x = x, y = y, posX = posX, posY = posY })
        return true
      end
      navToSector(5, -3, 2000, 8000)
      assert.are.equal(2000, calls[1].posX)
      assert.are.equal(8000, calls[1].posY)
    end)

  end)

  -- =========================================================================
  describe("navToSectorAndPlanet", function()

    it("rejects invalid planet number", function()
      assert.is_false(navToSectorAndPlanet(5, -3, nil, nil, 0))
      assert.is_false(navToSectorAndPlanet(5, -3, nil, nil, 10))
    end)

    it("calls navigateToSectorAndPlanet", function()
      local calls = {}
      _G.navigateToSectorAndPlanet = function(x, y, posX, posY, n)
        table.insert(calls, { x = x, y = y, posX = posX, posY = posY, n = n })
        return true
      end
      navToSectorAndPlanet(5, -3, nil, nil, 2)
      assert.are.equal(1, #calls)
      assert.are.equal(5,  calls[1].x)
      assert.are.equal(-3, calls[1].y)
      assert.are.equal(2,  calls[1].n)
    end)

    it("passes position args through", function()
      local calls = {}
      _G.navigateToSectorAndPlanet = function(x, y, posX, posY, n)
        table.insert(calls, { posX = posX, posY = posY })
        return true
      end
      navToSectorAndPlanet(5, -3, 2000, 8000, 2)
      assert.are.equal(2000, calls[1].posX)
      assert.are.equal(8000, calls[1].posY)
    end)

  end)

  -- =========================================================================
  describe("nav_planet: navigationTick skips new phases", function()

    it("navigationTick does not process nav_planet phase", function()
      navToPlanet(3)
      -- navNavTick hasn't been called yet, state is navpl_scanning
      -- navigationTick should NOT touch nav_planet phase
      navigationTick()
      -- State should still be navpl_scanning (not modified by old tick)
      assert.are.equal("navpl_scanning", getNavigationState())
    end)

  end)

end)
