if not gePackage.stateMachine then
  gePackage.stateMachine = {}
  gePackage.stateMachine.inbetweenDashes = false
  gePackage.stateMachine.scanningPlanet = false
end

function toggleDashes()
  --debugLog("toggleDashes()")
  if gePackage.stateMachine.inbetweenDashes then
    gePackage.stateMachine.inbetweenDashes = false
    gePackage.stateMachine.reportType = nil
    setScanningPlanet(false)
  else
      gePackage.stateMachine.inbetweenDashes = true
  end
end

function setScanningPlanet(newBoolean)
  --debugLog("setScanningPlanet(" .. tostring(newBoolean) .. ")")
  gePackage.stateMachine.scanningPlanet = newBoolean
  if not newBoolean then
    gePackage.stateMachine.scanningPlanetNumber = nil
    gePackage.stateMachine.scanningPlanetName = nil
  end
end

function getScanningPlanet()
  --debugLog("getScanningPlanet()")
  return gePackage.stateMachine.scanningPlanet
end

function setScanningPlanetNumber(newPlanetNumber)
  debugLog("setScanningPlanetNumber(" .. tostring(newPlanetNumber) .. ")")
  gePackage.stateMachine.scanningPlanetNumber = newPlanetNumber
end

function getScanningPlanetNumber()
  return gePackage.stateMachine.scanningPlanetNumber
end

function setScanningPlanetName(newPlanetName)
  debugLog("setScanningPlanetName(" .. newPlanetName .. ")")
  gePackage.stateMachine.scanningPlanetName = newPlanetName
end

function getScanningPlanetName()
  return gePackage.stateMachine.scanningPlanetName
end

function setReportType(newReportName)
  debugLog("setReportType(" .. newReportName .. ")")
  gePackage.stateMachine.reportType = newReportName
end

function getReportType()
  return gePackage.stateMachine.reportType
end
