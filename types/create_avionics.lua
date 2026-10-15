---@meta
--- Create: Avionics Peripheral Type Definitions & Hardware API Documentation
--- Autopilot & Avionics instruments for physics-based Sable contraptions.

---@class AltitudeSensor
---@field getHeight fun(): number Returns absolute vertical coordinate (world Y level) of the sensor in blocks.
---@field getVerticalSpeed fun(): number Returns instantaneous vertical velocity in m/s (positive for ascent, negative for descent).
---@field getAirPressure fun(): number Returns normalized atmospheric air pressure at current altitude (0.0 to 1.0).

---@class VelocitySensor
---@field getVelocity fun(): number Returns instantaneous linear velocity in m/s along sensor measurement axis.
---@field getAxis fun(): "x"|"y"|"z" Returns measurement axis name of the velocity sensor ("x", "y", or "z").

---@class GimbalSensor
---@field getAngles fun(): {pitch: number, roll: number, yaw: number} Returns attitude Euler angles in degrees (pitch [-90..90], roll [-180..180], yaw [0..360]).
---@field getAngularRates fun(): {pitch: number, roll: number, yaw: number} Returns instantaneous angular velocity rates in deg/s around vessel body axes.

---@class NavigationTable
---@field hasTarget fun(): boolean Returns true if a destination waypoint, Lodestone compass, or spawn compass is tracked.
---@field getDistanceToTarget fun(): number Returns horizontal Line-of-Sight distance to target in meters/blocks.
---@field getVerticalOffsetToTarget fun(): number Returns vertical altitude delta between target and sensor (Target Y - Sensor Y) in meters.
---@field getBearing fun(): number Returns relative bearing to target in degrees. Inverted polarity: starboard (right) is negative [-1..-180], port (left) is positive [+1..+180].
---@field getTargetMetadata fun(): table Returns metadata table for active target (e.g. {kind = "spawn", name = "Base"}).
---@field getTargetType fun(): string Returns target category string ("waypoint", "spawn", "player", etc.).

---@class GyroscopicPropellerBearing
---@field setManualTarget fun(target: {x: number, y: number, z: number}) Commands contraption-local unit 3D vector for thrust tilt within the 12-degree physical cone.
---@field clearManualTarget fun() Clears programmatic tilt vector and restores automatic gravity-aligned vertical hover mode.
---@field getTiltAngle fun(): number Returns active physical deflection angle of the bearing in degrees (0.0 to 12.0).
---@field isOverstressed fun(): boolean Returns true if the kinetic network driving this propeller bearing is overstressed.
---@field getSpeed fun(): number Returns input shaft rotational speed in RPM.
---@field getStressImpact fun(): number Returns stress impact drawn on the kinetic network in Stress Units (SU).
---@field getStressContribution fun(): number Returns stress capacity contributed to network.

---@class AnalogTransmission
---@field getSignal fun(): number Returns current redstone signal controlling gear ratio (0 to 15).
---@field setSignal fun(side_or_strength: string|number, strength?: number) Sets transmission throttle signal (0..15). Signal 0 is 100% throughput (ratio 1.0), signal 15 halts shaft (ratio 0.0).
---@field releaseSignal fun() Releases programmatic override and returns ratio control to physical redstone block input.
---@field isExternallyControlled fun(): boolean Returns true if transmission ratio is currently overridden via ComputerCraft.
---@field getRotationModifier fun(): number Returns active speed modifier ratio (0.0 to 1.0). Calculated as (15 - signal) / 15.
---@field getOutputSpeed fun(): number Returns active output shaft speed in RPM after ratio attenuation.
---@field getOutputTheoreticalSpeed fun(): number Returns theoretical output speed in RPM before torque/slip calculation.
---@field isOverstressed fun(): boolean Returns true if kinetic drive line is stalled or overstressed.
---@field isOversaturated fun(): boolean Returns true if transmission torque throughput limit is exceeded.
---@field getAxis fun(): "x"|"y"|"z" Returns shaft rotation axis name ("x", "y", or "z").
---@field getSpeed fun(): number Returns input rotational speed in RPM.
---@field getStressImpact fun(): number Returns stress impact in SU drawn on kinetic network.
---@field getStressContribution fun(): number Returns stress capacity contributed in SU.

---@class RedstoneRelay
---@field getInput fun(side: string): boolean Returns digital redstone state (true if signal > 0) on specified face ("top", "bottom", "left", "right", "back").
---@field getAnalogInput fun(side: string): number Returns analog redstone power level (0 to 15) received on specified face.
---@field setOutput fun(side: string, active: boolean) Sets digital redstone output (0 or 15) on specified face.
---@field setAnalogOutput fun(side: string, power: number) Sets analog redstone power level (0 to 15) emitted from specified face.

---@class LinkedTypewriter
---@field getPressedKeyCodes fun(): number[] Returns array of currently held GLFW keyboard scancodes from linked physical typewriter.

---@class LaserSensor
---@field getDistance fun(): number Returns measured raycast distance to target obstruction in meters/blocks.
---@field hasHit fun(): boolean Returns true if laser beam collides with a block or entity within detection range.
---@field getRange fun(): number Returns configured maximum laser range limit in blocks.
---@field setRange fun(range: number) Sets maximum detection range for laser raycast in blocks.

---@class OpticalSensor
---@field getDistance fun(): number Returns measured optical raycast distance to surface in meters/blocks.
---@field hasHit fun(): boolean Returns true if optical ray collides with a surface.
---@field getBlock fun(): string Returns Minecraft registry ID of block hit by optical sensor beam (e.g. "minecraft:stone").
---@field getRange fun(): number Returns configured maximum optical detection range in blocks.
---@field setRange fun(range: number) Sets maximum detection range for optical sensor in blocks.

---@class SwivelBearing
---@field getAngle fun(): number Returns current deflection angle of swivel bearing in degrees.
---@field isOverstressed fun(): boolean Returns true if swivel bearing kinetic drive is stalled.

---@class TorsionSpring
---@field getAngle fun(): number Returns current rotational deflection angle of torsion spring in degrees.
---@field isOverstressed fun(): boolean Returns true if torsion spring kinetic drive is stalled.

