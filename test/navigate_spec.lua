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
end)
