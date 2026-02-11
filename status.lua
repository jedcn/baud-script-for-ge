function status()
--   debug("status()")
  local sectorX, sectorY = getSector()
  sectorX = sectorX or 0
  sectorY = sectorY or 0

  local sectorPositionX, sectorPositionY = getSectorPosition()
  sectorPositionX = sectorPositionX or 0
  sectorPositionY = sectorPositionY or 0

  local shipHeading = getShipHeading() or "?"
  local warpSpeed = getWarpSpeed() or "?"
  local shieldStatus = getShieldStatus() or "?"
  local shieldCharge = getShieldCharge() or "?"
  local shieldState = shieldStatus .. ":" .. shieldCharge
  local shipStatus = getShipStatus() or "?"
  local segments = {
    { text = "Sector"},
    { text = sectorX .. "," .. sectorY, fg = "white" },
    { text = "(x,y)" },
    { text = "(" .. sectorPositionX .. ", " .. sectorPositionY .. ")", fg="white" },
    { text = "Heading" },
    { text = shipHeading, fg="white" },
    { text = "Warp" },
    { text = warpSpeed, fg="white" },
    { text = "Shields" },
    { text = shieldState, fg="white" },
    { text = "Damage:" },
    { text = shipStatus, fg="white" },
  }
  return segments
end

setStatus(status)