-- populate.lua
-- Automated population transfer loop: source planet -> destination planet -> repeat
-- Usage: populate.planet src:X Y P dest:X Y P
-- Cancel: populate.cancel

local TRANSFER_COUNT = 499940
local MIN_FLUX_PODS = 3

-- ============================================================================
-- Helpers
-- ============================================================================

local function isOrbitingPlanetInSector(planet, sectorX, sectorY)
  local orbiting = getOrbitingPlanet()
  if orbiting ~= planet then return false end
  local sX, sY = getSector()
  return sX == sectorX and sY == sectorY
end

-- ============================================================================
-- State Management
-- ============================================================================

function initPopulate()
  gePackage.populate = {
    active = false,
    state = "idle",
    lastStateChange = nil,
    commandSent = false,
    transferUpComplete = false,
    transferDownComplete = false,
    src  = { sectorX = nil, sectorY = nil, planet = nil },
    dest = { sectorX = nil, sectorY = nil, planet = nil }
  }
end

function getPopulateActive()
  return gePackage.populate and gePackage.populate.active or false
end

function getPopulateState()
  return gePackage.populate and gePackage.populate.state or "idle"
end

function setPopulateState(newState)
  if gePackage.populate then
    local oldState = gePackage.populate.state
    gePackage.populate.state = newState
    gePackage.populate.lastStateChange = os.time()
    gePackage.populate.commandSent = false
    cecho("#00ffff", "[populate][state] " .. oldState .. " -> " .. newState)
  end
end

-- Called by triggers.lua when transfer-up confirmation is received
function setPopulateTransferUpCompleteFromTrigger()
  if gePackage.populate then
    gePackage.populate.transferUpComplete = true
  end
end

-- Called by triggers.lua when transfer-down confirmation is received
function setPopulateTransferDownCompleteFromTrigger()
  if gePackage.populate then
    gePackage.populate.transferDownComplete = true
  end
end

-- ============================================================================
-- Start / Cancel
-- ============================================================================

function startPopulate(srcX, srcY, srcPlanet, destX, destY, destPlanet)
  if getPopulateActive() then
    echo("Populate loop is already running (state: " .. getPopulateState() .. ")")
    return
  end

  initPopulate()
  gePackage.populate.active = true
  gePackage.populate.startedAt = os.time()
  gePackage.populate.src  = { sectorX = srcX,  sectorY = srcY,  planet = srcPlanet  }
  gePackage.populate.dest = { sectorX = destX, sectorY = destY, planet = destPlanet }

  cecho("#00ffff", "[populate] Starting: src=" .. srcX .. "," .. srcY .. " pl" .. srcPlanet ..
        " dest=" .. destX .. "," .. destY .. " pl" .. destPlanet)

  setPopulateState("verifying_ship_type")
end

function cancelPopulate()
  if not getPopulateActive() then
    echo("Populate loop is not running.")
    return
  end

  cancelAllNavigation()
  cecho("#00ffff", "[populate] Cancelled by user")
  gePackage.populate.active = false
  gePackage.populate.state = "idle"
end

function printStatusPopulate()
  if not getPopulateActive() then
    echo("[populate] inactive")
    return
  end

  local cfg     = gePackage.populate
  local state   = cfg.state
  local elapsed = os.time() - (cfg.startedAt or os.time())
  local stateElapsed = os.time() - (cfg.lastStateChange or os.time())

  local src  = cfg.src.sectorX  .. "," .. cfg.src.sectorY  .. " pl" .. cfg.src.planet
  local dest = cfg.dest.sectorX .. "," .. cfg.dest.sectorY .. " pl" .. cfg.dest.planet

  echo("[populate] " .. state ..
       " | src=" .. src .. " dest=" .. dest ..
       " | running " .. elapsed .. "s, in state " .. stateElapsed .. "s")
end

-- ============================================================================
-- Tick Function
-- ============================================================================

function populateTick()
  if not getPopulateActive() then return end

  local state = gePackage.populate.state
  local cfg   = gePackage.populate

  if state == "verifying_ship_type" then
    if not cfg.commandSent then
      cfg.commandSent = true
      send("rep sys")
      return
    end

    local shipType = getShipType()
    if shipType == nil then return end  -- waiting for rep sys response

    if shipType ~= "Freight Barge" then
      cecho("#ff0000", "[populate] ERROR: ship type is '" .. shipType .. "', must be Freight Barge")
      cancelPopulate()
      return
    end

    setPopulateState("verifying_inventory")

  elseif state == "verifying_inventory" then
    if not cfg.commandSent then
      cfg.commandSent = true
      send("rep inv")
      return
    end

    local menCount = getShipInventory(gePackage.constants.MEN)
    if menCount == nil then return end  -- waiting for rep inv response

    if menCount > 0 then
      cecho("#ff0000", "[populate] ERROR: ship already has " .. menCount .. " men loaded, aborting")
      cancelPopulate()
      return
    end

    setPopulateState("navigating_to_source")

  elseif state == "navigating_to_source" then
    local src = cfg.src
    if isOrbitingPlanetInSector(src.planet, src.sectorX, src.sectorY) then
      setPopulateState("loading_men")
      return
    end

    if not cfg.commandSent then
      cfg.commandSent = true
      navToSectorAndPlanet(src.sectorX, src.sectorY, nil, nil, src.planet)
    end

  elseif state == "loading_men" then
    if not cfg.commandSent then
      cfg.commandSent = true
      cfg.transferUpComplete = false
      send("tra up " .. TRANSFER_COUNT .. " men")
      return
    end

    if cfg.transferUpComplete then
      cfg.transferUpComplete = false
      setPopulateState("checking_flux")
    end

  elseif state == "checking_flux" then
    if not cfg.commandSent then
      cfg.commandSent = true
      send("flu")
      return
    end

    local fluxPods = getShipInventory(gePackage.constants.FLUX_PODS)
    if fluxPods == nil then fluxPods = 0 end

    if fluxPods >= MIN_FLUX_PODS then
      setPopulateState("navigating_to_dest")
    else
      setPopulateState("loading_flux")
    end

  elseif state == "loading_flux" then
    if not cfg.commandSent then
      cfg.commandSent = true
      local fluxPods = getShipInventory(gePackage.constants.FLUX_PODS) or 0
      local needed = MIN_FLUX_PODS - fluxPods
      cecho("#00ffff", "[populate] Loading " .. needed .. " flux pods")
      send("tra up " .. needed .. " flu")
      cfg.fluxLoadedAt = os.time()
      return
    end

    -- Wait 5 seconds for the transfer to complete (no game ACK for flux transfers)
    local elapsed = os.time() - (cfg.fluxLoadedAt or 0)
    if elapsed >= 5 then
      setPopulateState("navigating_to_dest")
    end

  elseif state == "navigating_to_dest" then
    local dest = cfg.dest
    if isOrbitingPlanetInSector(dest.planet, dest.sectorX, dest.sectorY) then
      setPopulateState("unloading_men")
      return
    end

    if not cfg.commandSent then
      cfg.commandSent = true
      navToSectorAndPlanet(dest.sectorX, dest.sectorY, nil, nil, dest.planet)
    end

  elseif state == "unloading_men" then
    if not cfg.commandSent then
      cfg.commandSent = true
      cfg.transferDownComplete = false
      send("tra down " .. TRANSFER_COUNT .. " men")
      return
    end

    if cfg.transferDownComplete then
      cfg.transferDownComplete = false
      setPopulateState("navigating_to_source")
    end
  end
end

-- Initialize on load
if not gePackage.populate then
  initPopulate()
end
