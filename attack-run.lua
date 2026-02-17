--
-- attack-run.lua
-- Orchestrates attack run loop: base → target → attack → return
--
-- Usage:
--   attack-run        - Start the attack run loop
--   attack-run-cancel - Cancel and stop
--

-- Initialize state
if not gePackage.attackRun then
  gePackage.attackRun = {}
end

-- Logging helpers
local function arLog(msg)
  cecho("cyan", "[attack-run] " .. msg .. "\n")
end

local function arError(msg)
  cecho("red", "[attack-run] ERROR: " .. msg .. "\n")
end

function startAttackRun()
  arLog("Starting attack run")
  gePackage.attackRun = {
    active = true,
    state = "ar_check_prerequisites",
    lastCommand = os.time(),
    retryCount = 0,
    maxRetries = 3,
    -- Config
    baseSectorX = 11,
    baseSectorY = -10,
    basePlanet = 1,
    targetSectorX = 11,
    targetSectorY = -9,
    targetPosX = 4300,
    targetPosY = 1050,
    targetPlanet = 3,
    attackHeading = 0,
    attackFighters = 33300,
    -- Tracking flags
    maintenanceComplete = false
  }
end

function cancelAttackRun()
  if gePackage.attackRun and gePackage.attackRun.active then
    arLog("Cancelling attack run")
    gePackage.attackRun.active = false
    gePackage.attackRun.state = "ar_idle"
  end
end

function attackRunTick()
  local ar = gePackage.attackRun
  if not ar or not ar.active then return end

  local states = {
    --
    -- SETUP PHASE
    --
    ar_check_prerequisites = function()
      local sectorX, sectorY = getSector()
      local orbiting = getOrbitingPlanet()
      if sectorX == ar.baseSectorX and sectorY == ar.baseSectorY
         and orbiting == ar.basePlanet then
        arLog("Prerequisites met - at planet " .. ar.basePlanet .. " in sector " .. ar.baseSectorX .. "," .. ar.baseSectorY)
        ar.state = "ar_requesting_sys"
      else
        arError("Not at base planet - expected planet " .. ar.basePlanet .. " in sector " .. ar.baseSectorX .. "," .. ar.baseSectorY)
        ar.active = false
      end
    end,

    ar_requesting_sys = function()
      arLog("Requesting systems report")
      send("rep sys")
      ar.lastCommand = os.time()
      ar.state = "ar_awaiting_sys"
    end,

    ar_awaiting_sys = function()
      local status = getShipStatus()
      if status then
        if status == "no damage" then
          arLog("No damage detected - skipping maintenance")
          ar.state = "ar_starting_flipaway"
        else
          arLog("Damage detected: " .. status .. " - running maintenance")
          ar.state = "ar_maintenance"
        end
      elseif os.time() - ar.lastCommand > 30 then
        arError("Timeout waiting for systems report - retrying")
        ar.state = "ar_requesting_sys"
      end
    end,

    ar_maintenance = function()
      arLog("Running maintenance")
      ar.maintenanceComplete = false
      doMaint()
      ar.lastCommand = os.time()
      ar.state = "ar_awaiting_maintenance"
    end,

    ar_awaiting_maintenance = function()
      if ar.maintenanceComplete then
        arLog("Maintenance complete")
        ar.state = "ar_starting_flipaway"
      elseif os.time() - ar.lastCommand > 120 then
        arError("Timeout waiting for maintenance - retrying")
        ar.state = "ar_maintenance"
      end
    end,

    ar_starting_flipaway = function()
      arLog("Starting flipaway")
      flipAway()
      ar.lastCommand = os.time()
      ar.state = "ar_awaiting_flipaway"
    end,

    ar_awaiting_flipaway = function()
      if not gePackage.flipAway or not gePackage.flipAway.active then
        if gePackage.flipAway and gePackage.flipAway.state == "fa_completed" then
          arLog("Flipaway complete")
          ar.retryCount = 0
          ar.state = "ar_flux_transfer"
        else
          ar.retryCount = ar.retryCount + 1
          if ar.retryCount >= ar.maxRetries then
            arError("Flipaway failed after " .. ar.maxRetries .. " attempts")
            ar.active = false
          else
            arLog("Retrying flipaway (attempt " .. ar.retryCount .. ")")
            ar.state = "ar_starting_flipaway"
          end
        end
      end
    end,

    ar_flux_transfer = function()
      arLog("Transferring flux and fighters")
      send("tra up 1 flu")
      send("flu")
      send("tra up " .. ar.attackFighters .. " fig")
      ar.lastCommand = os.time()
      ar.state = "ar_starting_navsec"
    end,

    --
    -- TRANSIT TO TARGET
    --
    ar_starting_navsec = function()
      arLog("Navigating to sector " .. ar.targetSectorX .. "," .. ar.targetSectorY .. " pos " .. ar.targetPosX .. "," .. ar.targetPosY)
      navigateToSector(ar.targetSectorX, ar.targetSectorY, ar.targetPosX, ar.targetPosY)
      ar.lastCommand = os.time()
      ar.state = "ar_awaiting_navsec"
    end,

    ar_awaiting_navsec = function()
      if not gePackage.sectorNav or not gePackage.sectorNav.active then
        if gePackage.sectorNav and gePackage.sectorNav.state == "sec_completed" then
          arLog("Sector navigation complete")
          ar.retryCount = 0
          ar.state = "ar_starting_navspl"
        else
          ar.retryCount = ar.retryCount + 1
          if ar.retryCount >= ar.maxRetries then
            arError("Sector navigation failed after " .. ar.maxRetries .. " attempts")
            ar.active = false
          else
            arLog("Retrying sector navigation (attempt " .. ar.retryCount .. ")")
            ar.state = "ar_starting_navsec"
          end
        end
      end
    end,

    ar_starting_navspl = function()
      arLog("Navigating to planet " .. ar.targetPlanet)
      navigateToPlanetSimple(ar.targetPlanet)
      ar.lastCommand = os.time()
      ar.state = "ar_awaiting_orbit"
    end,

    ar_awaiting_orbit = function()
      local orbiting = getOrbitingPlanet()
      if orbiting == ar.targetPlanet then
        arLog("Now orbiting planet " .. ar.targetPlanet)
        ar.retryCount = 0
        ar.state = "ar_starting_rotto"
      elseif not gePackage.navigation or not gePackage.navigation.active then
        ar.retryCount = ar.retryCount + 1
        if ar.retryCount >= ar.maxRetries then
          arError("Planet navigation failed after " .. ar.maxRetries .. " attempts")
          ar.active = false
        else
          arLog("Retrying planet navigation (attempt " .. ar.retryCount .. ")")
          ar.state = "ar_starting_navspl"
        end
      end
    end,

    --
    -- COMBAT PREPARATION
    --
    ar_starting_rotto = function()
      arLog("Rotating to heading " .. ar.attackHeading)
      rotateToHeading(ar.attackHeading)
      ar.lastCommand = os.time()
      ar.state = "ar_awaiting_rotto"
    end,

    ar_awaiting_rotto = function()
      if not gePackage.rotto or not gePackage.rotto.active then
        if gePackage.rotto and gePackage.rotto.state == "rotto_completed" then
          arLog("Rotation complete")
          ar.retryCount = 0
          ar.state = "ar_shields_up"
        else
          ar.retryCount = ar.retryCount + 1
          if ar.retryCount >= ar.maxRetries then
            arError("Rotation failed after " .. ar.maxRetries .. " attempts")
            ar.active = false
          else
            arLog("Retrying rotation (attempt " .. ar.retryCount .. ")")
            ar.state = "ar_starting_rotto"
          end
        end
      end
    end,

    ar_shields_up = function()
      local status = getShieldStatus()
      if status ~= "UP" then
        arLog("Raising shields")
        send("shields up")
      else
        arLog("Shields already up")
      end
      ar.lastCommand = os.time()
      ar.state = "ar_awaiting_shields"
    end,

    ar_awaiting_shields = function()
      local charge = getShieldCharge()
      if charge and charge >= 100 then
        arLog("Shields at 100%")
        ar.state = "ar_attacking"
      elseif os.time() - ar.lastCommand > 60 then
        arError("Timeout waiting for shields - retrying")
        ar.state = "ar_shields_up"
      end
    end,

    --
    -- ATTACK & ESCAPE
    --
    ar_attacking = function()
      arLog("ATTACKING with " .. ar.attackFighters .. " fighters!")
      send("attack " .. ar.attackFighters .. " fig")
      ar.state = "ar_escaping"
    end,

    ar_escaping = function()
      arLog("Escaping at impulse (shields staying up)")
      send("imp 99 0")
      ar.lastCommand = os.time()
      ar.state = "ar_traveling_home"
    end,

    ar_traveling_home = function()
      local sectorX, sectorY = getSector()
      if sectorX == ar.baseSectorX and sectorY == ar.baseSectorY then
        arLog("Entered home sector " .. ar.baseSectorX .. "," .. ar.baseSectorY)
        ar.state = "ar_starting_return"
      end
      -- Stay at impulse with shields up until we enter home sector
    end,

    --
    -- RETURN TO BASE
    --
    ar_starting_return = function()
      arLog("Navigating to base planet " .. ar.basePlanet)
      navigateToPlanetSimple(ar.basePlanet)
      ar.lastCommand = os.time()
      ar.state = "ar_awaiting_return"
    end,

    ar_awaiting_return = function()
      local orbiting = getOrbitingPlanet()
      if orbiting == ar.basePlanet then
        arLog("Back at base planet " .. ar.basePlanet)
        ar.retryCount = 0
        ar.state = "ar_loop_restart"
      elseif not gePackage.navigation or not gePackage.navigation.active then
        ar.retryCount = ar.retryCount + 1
        if ar.retryCount >= ar.maxRetries then
          arError("Return navigation failed after " .. ar.maxRetries .. " attempts")
          ar.active = false
        else
          arLog("Retrying return navigation (attempt " .. ar.retryCount .. ")")
          ar.state = "ar_starting_return"
        end
      end
    end,

    ar_loop_restart = function()
      arLog("=== Attack run complete - restarting loop ===")
      ar.state = "ar_check_prerequisites"
    end
  }

  local handler = states[ar.state]
  if handler then
    handler()
  else
    arError("Unknown state: " .. tostring(ar.state))
    ar.active = false
  end
end
