if not gePackage.stateMachine then
  gePackage.stateMachine = {}
  gePackage.stateMachine.inbetweenDashes = false
  gePackage.stateMachine.scanningPlanet = false
end

function toggleDashes()
  --log("toggleDashes()")
  if gePackage.stateMachine.inbetweenDashes then
    gePackage.stateMachine.inbetweenDashes = false
    gePackage.stateMachine.reportType = nil
    setScanningPlanet(false)
  else
      gePackage.stateMachine.inbetweenDashes = true
  end
end

function setScanningPlanet(newBoolean)
  --log("setScanningPlanet(" .. tostring(newBoolean) .. ")")
  gePackage.stateMachine.scanningPlanet = newBoolean
  if not newBoolean then
    gePackage.stateMachine.scanningPlanetNumber = nil
    gePackage.stateMachine.scanningPlanetName = nil
  end
end

function getScanningPlanet()
  --log("getScanningPlanet()")
  return gePackage.stateMachine.scanningPlanet
end

function setScanningPlanetNumber(newPlanetNumber)
  log("setScanningPlanetNumber(" .. tostring(newPlanetNumber) .. ")")
  gePackage.stateMachine.scanningPlanetNumber = newPlanetNumber
end

function setScanningPlanetName(newPlanetName)
  log("setScanningPlanetName(" .. newPlanetName .. ")")
  gePackage.stateMachine.newPlanetName = newPlanetName
end

function setReportType(newReportName)
  log("setReportType(" .. newReportName .. ")")
  gePackage.stateMachine.reportType = newReportName
end
