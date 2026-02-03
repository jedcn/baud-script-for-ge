function status()
  local shipHeading = getShipHeading() or "?"
  local warpSpeed = getWarpSpeed() or "?"
  local shieldCharge = getShieldCharge() or "?"

  local segments = {
    { text = "Sector: " .. gePackage.position.xSector .. "," .. gePackage.position.ySector},
    { text = "(x,y):(" .. gePackage.position.xSectorPosition .. ", " .. gePackage.position.ySectorPosition .. ")"},
    { text = "Heading: " .. shipHeading },
    { text = "Warp: " .. warpSpeed },
    { text = "Shields: " .. shieldCharge },
  }
  return segments
end

setStatus(status)