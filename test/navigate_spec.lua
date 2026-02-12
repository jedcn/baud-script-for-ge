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
      setSectorPosition(4900, 4900)  -- Distance ~141, within threshold of 150
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

    it("checks orbit status after arriving at planet", function()
      navigateToPlanet(2)
      setOrbitingPlanet(2)

      gePackage.navigation.state = "awaiting_orbit"

      navigationTick()

      assert.equals("completed", gePackage.navigation.state)
    end)
  end)
end)
