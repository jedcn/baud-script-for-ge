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

    it("uses warp 15 for very long distances", function()
      local speedType, speedValue = decideSpeed(15000, 0)
      assert.equals("WARP", speedType)
      assert.equals(15, speedValue)
    end)

    it("uses warp 5 for distances over 5000", function()
      local speedType, speedValue = decideSpeed(6000, 0)
      assert.equals("WARP", speedType)
      assert.equals(5, speedValue)
    end)

    it("uses impulse when stopped at short distance", function()
      local speedType, speedValue = decideSpeed(394, 0)
      assert.equals("IMPULSE", speedType)
      assert.equals(0.99, speedValue)
    end)

    it("uses impulse when already in impulse at short distance", function()
      -- Bug fix: ship at impulse (0.99) should NOT stop before re-engaging impulse
      local speedType, speedValue = decideSpeed(394, 0.99)
      assert.equals("IMPULSE", speedType)
      assert.equals(0.99, speedValue)
    end)

    it("stops ship when in warp at short distance", function()
      -- Must drop out of warp before engaging impulse
      local speedType, speedValue = decideSpeed(394, 1)
      assert.equals("WARP", speedType)
      assert.equals(0, speedValue)
    end)

    it("decelerates from warp 15 when within 10000", function()
      local speedType, speedValue = decideSpeed(9000, 15)
      assert.equals("WARP", speedType)
      assert.equals(5, speedValue)
    end)

    it("decelerates from warp 5 when within 3000", function()
      local speedType, speedValue = decideSpeed(2000, 5)
      assert.equals("WARP", speedType)
      assert.equals(3, speedValue)
    end)
  end)

  describe("navigateToCoordinates", function()
    it("initializes navigation state", function()
      navigateToCoordinates(5000, 5000)

      assert.is_true(gePackage.navigation.active)
      assert.equals("coordinate", gePackage.navigation.phase)
      assert.equals(5000, gePackage.navigation.target.sectorPositionX)
      assert.equals(5000, gePackage.navigation.target.sectorPositionY)
      assert.equals("requesting_position", gePackage.navigation.state)
    end)

    it("rejects invalid coordinates", function()
      local result = navigateToCoordinates(-100, 5000)
      assert.is_false(result)
      assert.is_false(gePackage.navigation.active)
    end)
  end)

  describe("navigationTick state machine", function()
    it("requests position on first tick", function()
      navigateToCoordinates(5000, 5000)

      navigationTick()

      assert.is_true(helper.wasSendCalledWith("rep nav"))
      assert.equals("awaiting_position", gePackage.navigation.state)
    end)

    it("transitions to calculating_route after position update", function()
      navigateToCoordinates(5000, 5000)
      setSectorPosition(4000, 4000)

      gePackage.navigation.state = "awaiting_position"
      gePackage.navigation.lastPositionCheck = os.time() - 2
      gePackage.navigation.lastPositionUpdate = os.time()

      navigationTick()

      assert.equals("calculating_route", gePackage.navigation.state)
    end)

    it("rotates to heading after calculating route", function()
      navigateToCoordinates(5000, 5000)
      setSectorPosition(4000, 4000)
      setShipHeading(0)  -- Currently facing north
      gePackage.navigation.state = "calculating_route"

      -- Calculate route stores target heading
      -- From (4000,4000) to (5000,5000) is southeast = 135 degrees
      navigationTick()
      assert.equals("rotating_to_heading", gePackage.navigation.state)
      assert.equals(135, gePackage.navigation.targetHeading)

      -- Rotate to target heading
      navigationTick()
      assert.is_true(helper.wasSendCalledWith("rot 135"))
      assert.equals("awaiting_rotation_confirmation", gePackage.navigation.state)
    end)

    it("detects arrival when within threshold", function()
      navigateToCoordinates(5000, 5000)
      setSectorPosition(4950, 4950)  -- Distance ~71, within threshold of 100
      gePackage.navigation.state = "calculating_route"

      navigationTick()

      assert.equals("arrived", gePackage.navigation.state)
    end)
  end)

  describe("cancelNavigation", function()
    it("stops active navigation", function()
      navigateToCoordinates(5000, 5000)
      assert.is_true(gePackage.navigation.active)

      cancelNavigation()

      assert.is_false(gePackage.navigation.active)
      assert.equals("aborted", gePackage.navigation.state)
      assert.is_true(helper.wasSendCalledWith("warp 0"))
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

  describe("navigateToPlanet", function()
    it("initializes planet navigation state", function()
      navigateToPlanet(1)

      assert.is_true(gePackage.navigation.active)
      assert.equals("planet", gePackage.navigation.phase)
      assert.equals(1, gePackage.navigation.target.planetNumber)
      assert.equals("requesting_planet_scan", gePackage.navigation.state)
    end)

    it("rejects invalid planet numbers", function()
      local result1 = navigateToPlanet(0)
      assert.is_false(result1)
      assert.is_false(gePackage.navigation.active)

      local result2 = navigateToPlanet(1000)
      assert.is_false(result2)
      assert.is_false(gePackage.navigation.active)
    end)
  end)

  describe("planet navigation state machine", function()
    it("requests planet scan on first tick", function()
      navigateToPlanet(3)

      navigationTick()

      assert.is_true(helper.wasSendCalledWith("scan planet 3"))
      assert.equals("awaiting_planet_scan", gePackage.navigation.state)
    end)

    it("transitions to requesting position after scan data received", function()
      navigateToPlanet(1)
      gePackage.navigation.state = "awaiting_planet_scan"
      gePackage.navigation.lastCommand = os.time() - 2

      -- Simulate scan results
      gePackage.navigation.planetScan.bearing = 45
      gePackage.navigation.planetScan.distance = 1000
      gePackage.navigation.lastScanUpdate = os.time()

      navigationTick()

      assert.equals("requesting_position_for_planet", gePackage.navigation.state)
    end)

    it("calculates planet coordinates after position update", function()
      navigateToPlanet(1)
      setSectorPosition(5000, 5000)
      setShipHeading(0)  -- Heading north

      -- Simulate having scan data (relative to ship heading)
      -- Relative bearing 90 + ship heading 0 = absolute bearing 90 (due east)
      gePackage.navigation.planetScan.bearing = 90
      gePackage.navigation.planetScan.distance = 1000
      gePackage.navigation.lastScanUpdate = os.time()

      -- Move to awaiting position state
      gePackage.navigation.state = "awaiting_position_for_planet"
      gePackage.navigation.lastPositionCheck = os.time() - 2
      gePackage.navigation.lastPositionUpdate = os.time()

      navigationTick()

      -- Should transition to calculating_planet_coordinates
      assert.equals("calculating_planet_coordinates", gePackage.navigation.state)

      -- Next tick calculates coordinates
      navigationTick()

      -- Should have calculated planet at (6000, 5000) and transitioned to coordinate navigation
      assert.equals(6000, gePackage.navigation.target.sectorPositionX)
      assert.equals(5000, gePackage.navigation.target.sectorPositionY)
      assert.equals("calculating_route", gePackage.navigation.state)
    end)

    it("detects orbit early and completes navigation", function()
      navigateToPlanet(2)
      setOrbitingPlanet(2)

      gePackage.navigation.state = "awaiting_orbit"

      navigationTick()

      -- Early orbit detection now goes directly to idle
      assert.equals("idle", gePackage.navigation.state)
      assert.equals(false, gePackage.navigation.active)
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
