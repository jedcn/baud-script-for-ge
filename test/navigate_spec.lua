-- navigate_spec.lua
-- Tests for navigation system

local helper = require("test.test_helper")

describe("Navigation System", function()
  before_each(function()
    helper.resetAll()
    dofile("main.lua")
  end)

  describe("calculateDistance", function()
    it("calculates distance between two points", function()
      local dist = calculateDistance(0, 0, 300, 400)
      assert.equals(500, dist)
    end)

    it("calculates distance for same point", function()
      local dist = calculateDistance(100, 100, 100, 100)
      assert.equals(0, dist)
    end)
  end)

  describe("calculateHeading", function()
    it("calculates 0 degrees for due north", function()
      assert.equals(0, calculateHeading(5000, 5000, 5000, 0))
    end)

    it("calculates 90 degrees for due east", function()
      assert.equals(90, calculateHeading(5000, 5000, 10000, 5000))
    end)

    it("calculates 180 degrees for due south", function()
      assert.equals(180, calculateHeading(5000, 5000, 5000, 10000))
    end)

    it("calculates 270 degrees for due west", function()
      assert.equals(270, calculateHeading(5000, 5000, 0, 5000))
    end)
  end)

  describe("calculateRotation", function()
    it("calculates positive rotation for clockwise turn", function()
      assert.equals(45, calculateRotation(0, 45))
    end)

    it("calculates negative rotation for counter-clockwise turn", function()
      assert.equals(-45, calculateRotation(45, 0))
    end)

    it("chooses shorter path when crossing 0/360 boundary", function()
      -- Going from 350 to 10 degrees: shorter to rotate +20 than -340
      assert.equals(20, calculateRotation(350, 10))
    end)

    it("chooses shorter negative path when crossing boundary", function()
      -- Going from 10 to 350 degrees: shorter to rotate -20 than +340
      assert.equals(-20, calculateRotation(10, 350))
    end)

    it("returns 0 when already at target heading", function()
      assert.equals(0, calculateRotation(90, 90))
    end)
  end)

  describe("decideSpeed", function()
    local decideSpeed
    before_each(function()
      decideSpeed = gePackage.navigation.config.decideSpeed
    end)

    -- Default ship: maxWarp=10, decelRate=10
    -- threshold(10) = max(computeStopDistance(10,10)*2=0, 10*154=1540) = 1540
    -- threshold(1)  = max(0, 1*154=154) = 154

    it("uses max warp for distances beyond computed threshold", function()
      -- 15000 > threshold(maxWarp=10)=1540 → max warp
      local speedType, speedValue = decideSpeed(15000, 0)
      assert.equals("WARP", speedType)
      assert.equals(10, speedValue)
    end)

    it("uses max warp once past the computed threshold (not just 10000)", function()
      -- 6000 > threshold(10)=1540 → max warp (not warp 5)
      local speedType, speedValue = decideSpeed(6000, 0)
      assert.equals("WARP", speedType)
      assert.equals(10, speedValue)
    end)

    it("uses impulse when stopped within threshold(1)", function()
      -- 100 < threshold(1)=154, all accel checks fail → impulse
      local speedType, speedValue = decideSpeed(100, 0)
      assert.equals("IMPULSE", speedType)
      assert.equals(0.99, speedValue)
    end)

    it("uses impulse when already in impulse within threshold(1)", function()
      -- Bug fix: ship at impulse (0.99) should NOT stop before re-engaging impulse
      local speedType, speedValue = decideSpeed(100, 0.99)
      assert.equals("IMPULSE", speedType)
      assert.equals(0.99, speedValue)
    end)

    it("stops ship when in warp within threshold(1)", function()
      -- Must drop out of warp before engaging impulse
      -- 100 < threshold(1)=154 and currentSpeed(1) >= 1 → WARP 0
      local speedType, speedValue = decideSpeed(100, 1)
      assert.equals("WARP", speedType)
      assert.equals(0, speedValue)
    end)

    -- Freight Barge: decelRate=2, tiers={15,13,11,...,1,0}, threshold(15)=15092
    it("decelerates Freight Barge from max warp by one decel step", function()
      setShipType("Freight Barge")
      -- drops to next tier (13), not a hardcoded value like 5
      local speedType, speedValue = decideSpeed(12000, 15)
      assert.equals("WARP", speedType)
      assert.equals(13, speedValue)
    end)

    it("does not decelerate Freight Barge from max warp outside computed threshold", function()
      setShipType("Freight Barge")
      -- 16000 > decelThreshold (15092), so no decel — falls through to accel ladder
      local speedType, speedValue = decideSpeed(16000, 15)
      assert.equals("WARP", speedType)
      assert.equals(15, speedValue)  -- maxWarp
    end)

    -- Star Cruiser: decelRate=20, stopDist(25,20)=154*5=770, threshold=1540
    it("decelerates Star Cruiser from max warp when within computed threshold", function()
      setShipType("Star Cruiser")
      local speedType, speedValue = decideSpeed(1000, 25)
      assert.equals("WARP", speedType)
      assert.equals(5, speedValue)
    end)

    it("does not decelerate Star Cruiser from max warp outside computed threshold", function()
      setShipType("Star Cruiser")
      -- threshold(25) = max(770*2=1540, 25*154=3850) = 3850
      -- 5000 > 3850 → accelerate to max warp
      local speedType, speedValue = decideSpeed(5000, 25)
      assert.equals("WARP", speedType)
      assert.equals(25, speedValue)
    end)

    -- Freight Barge: threshold(5) = max(computeStopDistance(5,2)*2=1232, 5*154=770) = 1232
    it("decelerates Freight Barge from warp 5 by one decel step", function()
      setShipType("Freight Barge")
      -- next tier after 5 is 3 (decelRate=2: 5-2=3)
      local speedType, speedValue = decideSpeed(1000, 5)
      assert.equals("WARP", speedType)
      assert.equals(3, speedValue)
    end)

    -- Constitution Class: decelRate=40, tiers={30,0} — drops straight to stop
    it("decelerates Constitution Class directly to warp 0 from max warp", function()
      setShipType("Constitution Class Starship")
      -- threshold(30) = max(0, 30*154=4620) = 4620; next tier is 0
      local speedType, speedValue = decideSpeed(3000, 30)
      assert.equals("WARP", speedType)
      assert.equals(0, speedValue)
    end)
  end)

  -- ===== Phase 2: Planet Navigation Tests =====
  describe("calculatePlanetCoordinates", function()
    it("calculates planet position due north", function()
      -- Current position (5000, 5000), bearing 0° (north), distance 1000
      -- Should be at (5000, 4000) - same X, Y reduced by 1000
      local planetX, planetY = calculatePlanetCoordinates(5000, 5000, 0, 1000)
      assert.equals(5000, planetX)
      assert.equals(4000, planetY)
    end)

    it("calculates planet position due east", function()
      -- Current position (5000, 5000), bearing 90° (east), distance 1000
      -- Should be at (6000, 5000) - X increased by 1000, same Y
      local planetX, planetY = calculatePlanetCoordinates(5000, 5000, 90, 1000)
      assert.equals(6000, planetX)
      assert.equals(5000, planetY)
    end)

    it("calculates planet position due south", function()
      -- Current position (5000, 5000), bearing 180° (south), distance 1000
      -- Should be at (5000, 6000) - same X, Y increased by 1000
      local planetX, planetY = calculatePlanetCoordinates(5000, 5000, 180, 1000)
      assert.equals(5000, planetX)
      assert.equals(6000, planetY)
    end)

    it("calculates planet position due west", function()
      -- Current position (5000, 5000), bearing 270° (west), distance 1000
      -- Should be at (4000, 5000) - X reduced by 1000, same Y
      local planetX, planetY = calculatePlanetCoordinates(5000, 5000, 270, 1000)
      assert.equals(4000, planetX)
      assert.equals(5000, planetY)
    end)

    it("calculates planet position at 45 degrees", function()
      -- Current position (5000, 5000), bearing 45° (northeast), distance ~1414
      -- Should be at approximately (6000, 4000)
      local planetX, planetY = calculatePlanetCoordinates(5000, 5000, 45, 1414)
      assert.equals(6000, planetX)
      assert.equals(4000, planetY)
    end)

    it("handles negative bearings", function()
      -- Current position (5000, 5000), bearing -20° (slightly west of north), distance 1000
      local planetX, planetY = calculatePlanetCoordinates(5000, 5000, -20, 1000)
      -- -20 degrees = 340 degrees, should be northwest
      assert.is_true(planetX < 5000)  -- West of current position
      assert.is_true(planetY < 5000)  -- North of current position
    end)
  end)

  -- ===== Simple Planet Navigation Tests (bearing-following) =====
  describe("navigateToPlanetSimple", function()
    it("initializes simple planet navigation state", function()
      navigateToPlanetSimple(1)

      assert.is_true(gePackage.navigation.active)
      assert.equals("planet_simple", gePackage.navigation.phase)
      assert.equals(1, gePackage.navigation.target.planetNumber)
      assert.equals("spl_scanning", gePackage.navigation.state)
    end)

    it("rejects invalid planet numbers", function()
      local result = navigateToPlanetSimple(0)
      assert.is_false(result)
      assert.is_false(gePackage.navigation.active)
    end)
  end)

  describe("simple planet navigation state machine", function()
    it("scans planet on first tick", function()
      navigateToPlanetSimple(5)

      navigationTick()

      assert.is_true(helper.wasSendCalledWith("scan planet 5"))
      assert.equals("spl_awaiting_scan", gePackage.navigation.state)
    end)

    it("clears stale scan data before each scan", function()
      navigateToPlanetSimple(1)
      gePackage.navigation.planetScan.bearing = 99
      gePackage.navigation.planetScan.distance = 9999

      navigationTick()

      assert.is_nil(gePackage.navigation.planetScan.bearing)
      assert.is_nil(gePackage.navigation.planetScan.distance)
    end)

    it("rotates toward planet after scan", function()
      navigateToPlanetSimple(1)
      gePackage.navigation.state = "spl_awaiting_scan"
      gePackage.navigation.lastCommand = os.time() - 2
      gePackage.navigation.planetScan.bearing = 45
      gePackage.navigation.planetScan.distance = 3000

      navigationTick()

      -- Should transition to spl_rotating
      assert.equals("spl_rotating", gePackage.navigation.state)

      -- Next tick should send rotation command
      navigationTick()
      assert.is_true(helper.wasSendCalledWith("rot 45"))
      assert.equals("spl_awaiting_rotation", gePackage.navigation.state)
    end)

    it("skips rotation when already aligned", function()
      navigateToPlanetSimple(1)
      gePackage.navigation.state = "spl_rotating"
      gePackage.navigation.planetScan.bearing = 1  -- within 2 degree tolerance
      gePackage.navigation.planetScan.distance = 3000

      navigationTick()

      assert.equals("spl_setting_speed", gePackage.navigation.state)
    end)

    it("transitions to arrived when within 250 distance", function()
      navigateToPlanetSimple(1)
      gePackage.navigation.state = "spl_awaiting_scan"
      gePackage.navigation.lastCommand = os.time() - 2
      gePackage.navigation.planetScan.bearing = 5
      gePackage.navigation.planetScan.distance = 200  -- within threshold

      navigationTick()

      -- Goes to arrived first to stop the ship, then stopping -> awaiting_orbit
      assert.equals("arrived", gePackage.navigation.state)
    end)

    it("rescans after traveling", function()
      navigateToPlanetSimple(1)
      gePackage.navigation.state = "spl_traveling"
      gePackage.navigation.lastCommand = os.time() - 4  -- past scanInterval of 3s

      navigationTick()

      assert.equals("spl_scanning", gePackage.navigation.state)
    end)

    it("stays in spl_traveling if not enough time has passed", function()
      navigateToPlanetSimple(1)
      gePackage.navigation.state = "spl_traveling"
      gePackage.navigation.lastCommand = os.time() - 1  -- not past scanInterval

      navigationTick()

      assert.equals("spl_traveling", gePackage.navigation.state)
    end)
  end)

  -- ===== navigateToSectorAndPlanet Tests =====
  describe("navigateToSectorAndPlanet", function()
    it("rejects planet number 0", function()
      local result = navigateToSectorAndPlanet(11, -9, 4300, 1050, 0)
      assert.is_false(result)
      assert.is_false(getSectorNavActive())
    end)

    it("rejects planet number 1000", function()
      local result = navigateToSectorAndPlanet(11, -9, 4300, 1050, 1000)
      assert.is_false(result)
      assert.is_false(getSectorNavActive())
    end)

    it("rejects nil planet number", function()
      local result = navigateToSectorAndPlanet(11, -9, 4300, 1050, nil)
      assert.is_false(result)
      assert.is_false(getSectorNavActive())
    end)

    it("starts sector nav for valid inputs", function()
      local result = navigateToSectorAndPlanet(11, -9, 4300, 1050, 3)
      assert.is_true(result)
      assert.is_true(getSectorNavActive())
      assert.is_true(helper.wasSendCalledWith("rep nav"))
    end)

    it("stores followUpPlanet on sectorNav", function()
      navigateToSectorAndPlanet(11, -9, 4300, 1050, 3)
      assert.equals(3, gePackage.sectorNav.followUpPlanet)
    end)

    it("accepts planet number 1 and 999 as boundary values", function()
      local result1 = navigateToSectorAndPlanet(11, -9, 4300, 1050, 1)
      assert.is_true(result1)
      helper.resetAll()
      dofile("main.lua")
      local result2 = navigateToSectorAndPlanet(11, -9, 4300, 1050, 999)
      assert.is_true(result2)
    end)
  end)

  -- ===== sec_completed follow-up planet Tests =====
  describe("sec_completed with followUpPlanet", function()
    before_each(function()
      -- Set up current position so sector nav has something to work with
      setSector(11, -9)
      setSectorPosition(4300, 1050)
    end)

    it("starts planet nav when followUpPlanet is set", function()
      navigateToSectorAndPlanet(11, -9, 4300, 1050, 3)
      gePackage.sectorNav.state = "sec_completed"

      sectorNavTick()

      assert.is_false(getSectorNavActive())
      assert.is_true(gePackage.navigation.active)
      assert.equals("planet_simple", gePackage.navigation.phase)
      assert.equals(3, gePackage.navigation.target.planetNumber)
    end)

    it("clears stale orbitingPlanet before starting planet nav", function()
      -- Ship was orbiting planet 3 in origin sector; state carries over
      setOrbitingPlanet(3)
      navigateToSectorAndPlanet(11, -9, 4300, 1050, 3)
      gePackage.sectorNav.state = "sec_completed"

      sectorNavTick()

      -- orbit state must be cleared so the early-exit in navigationTick doesn't
      -- falsely declare arrival before any scan happens
      assert.is_nil(getOrbitingPlanet())  -- clearOrbitingPlanet() was called
      -- planet nav should be scanning, not already complete
      assert.equals("spl_scanning", gePackage.navigation.state)
    end)

    it("does not start planet nav when followUpPlanet is absent", function()
      navigateToSector(11, -9, 4300, 1050)
      gePackage.sectorNav.state = "sec_completed"

      sectorNavTick()

      assert.is_false(getSectorNavActive())
      assert.is_false(gePackage.navigation.active)
    end)
  end)
end)
