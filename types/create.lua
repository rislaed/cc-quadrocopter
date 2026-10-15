---@meta
--- Create Mod Peripheral Type Definitions & Hardware API Documentation
--- Mechanical and kinetic blocks from base Create mod.

---@class CreateNixieTube
---@field setText fun(text: string) Sets text string displayed across the Nixie Tube (or connected multi-tube line). Passing "" clears display.
---@field setTextColor fun(color: number) Sets glowing character color using ComputerCraft color bitmask (e.g. colors.orange, colors.yellow, colors.green).
---@field setTextColour fun(colour: number) British English alias for setTextColor.
---@field setSignal fun(strength: number) Displays numeric analog redstone level (0 to 15) on the indicator.

---@class CreateDeployer
---@field deploy fun(): boolean Triggers simulated player click/use action with held item. Returns true if action succeeded.
---@field getSpeed fun(): number Returns input shaft rotational speed in RPM.
---@field isOverstressed fun(): boolean Returns true if kinetic drive line is stalled or overstressed.
---@field getStressImpact fun(): number Returns stress impact in SU drawn on kinetic network.

---@class CreateInvertedClutch
---@field getSpeed fun(): number Returns output shaft rotational speed in RPM.
---@field isOverstressed fun(): boolean Returns true if kinetic drive line is stalled or overstressed.
---@field getStressImpact fun(): number Returns stress impact in SU drawn on kinetic network.

