function status()
--   log("status()")
  local sectorX, sectorY = getSector()
  local sectorPositionX, sectorPositionY = getSectorPosition()
  local shipHeading = getShipHeading() or "?"
  local warpSpeed = getWarpSpeed() or "?"
  local shieldCharge = getShieldCharge() or "?"

  local segments = {
    { text = "Sector: " .. sectorX .. "," .. sectorY},
    { text = "(x,y):(" .. sectorPositionX .. ", " .. sectorPositionY .. ")"},
    { text = "Heading: " .. shipHeading },
    { text = "Warp: " .. warpSpeed },
    { text = "Shields: " .. shieldCharge },
  }
  return segments
end

setStatus(status)