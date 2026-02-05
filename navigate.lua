function navigateWithinSectorTo(destX, destY)
  local currentX, currentY = getSectorPosition()

  local dx = destX - currentX
  local dy = destY - currentY

  local angleRadians = math.atan(dx, -dy)
  local angleDegrees = angleRadians * 180 / math.pi

  if angleDegrees < 0 then
    angleDegrees = angleDegrees + 360
  end

  angleDegrees = math.floor(angleDegrees + 0.5)

  echo("Navigate to heading: " .. angleDegrees .. " degrees")
end
