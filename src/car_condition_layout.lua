-- Compact portrait design space for the independent car-condition window.
-- The renderer fits it uniformly, keeping the car and tyre proportions intact.
return {
  width = 320,
  height = 280,

  carCenterX = 160,
  frontWheelY = 68,
  rearWheelY = 178,
  leftWheelX = 96,
  rightWheelX = 224,
  tyreWidth = 22,
  tyreHeight = 54,

  -- Temperature offsets from the selected compound/profile working window.
  tyreDarkBlueOffset = 25,
  tyreBlueOffset = 10,
  tyreYellowOffset = 3,
  tyreOrangeOffset = 5,
  tyreRedOffset = 10,
  gt3TyreOptimumMin = 75,
  gt3TyreOptimumMax = 85,
  -- Used only when the car does not provide its tyre optimum temperature.
  tyreFallbackOptimumTemperature = 85,
  tyreGeneralCoreWeight = 0.80,

  conditionWarn = 0.35,
  conditionDanger = 0.72,
  punctureBlinkPeriod = 0.18
}
