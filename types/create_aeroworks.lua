---@meta
--- Create: Aeroworks Peripheral Type Definitions & Hardware API Documentation
--- Heavy stabilization flywheel and momentum reaction wheels for Aeronautics contraptions.

---@class AeroworksGyroscope
---@field getSpeed fun(): number Returns input shaft drive speed in RPM (target nominal speed: 256 RPM).
---@field getStressImpact fun(): number Returns kinetic stress drawn in SU (typically 16 SU per RPM, 4096 SU at 256 RPM).
---@field getStressContribution fun(): number Returns kinetic network capacity contribution.
---@field isOverstressed fun(): boolean Returns true if kinetic drive line is stalled or overstressed.
---@field getKind fun(): string Returns kinetic network role string (e.g. "consumer").
---@field getSelfId fun(): string Returns unique kinetic network identifier of the gyroscope block.

