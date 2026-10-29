local CONFIG = {
	SIDES = {
		MODEM = "bottom",
		LANDING_MODE = "top",
		LEVER_ALT = "front",
		GYRO_STIFF_X = "left",
		GYRO_STIFF_Z = "right"
	},

	WORLD_SPAWN = {
		x = 0,
		y = 66,
		z = 0
	},

	LIMITS = {
		MAX_CONE_ANGLE = 12.0,
		MIN_CRUISE_ALT = 64.0,
		MAX_CRUISE_ALT = 320.0,
		MAX_CLIMB_SPEED = 3.5,
		MAX_DESCENT_SPEED = 1.5,
		APPROACH_MIN_DISTANCE = 45.0,
		APPROACH_MAX_TILT = 2.5,
		APPROACH_TERMINAL_TILT = 1.0,
		APPROACH_THROTTLE_CAP = 0.15,
		BRAKE_ACCEL = 0.50,
		NOMINAL_HOVER = 0.025,
		HOVER_RADIUS = 5.0,
		ALT_DEADBAND = 0.5,
		MIN_THROTTLE = 0.0,
		MIN_AIRBORNE_THROTTLE = 0.015,
		MAX_THROTTLE = 0.42,
		MIN_SAFE_PRESSURE = 0.45,
		THROTTLE_SLEW_NORMAL = 0.35,
		THROTTLE_SLEW_TAKEOFF = 0.40,
		VECTOR_SLEW_RATE = 25.0,
		MAX_LANDING_TILT_DEV = 18.0,
		MAX_RESTING_TILT = 25.0,
		MAX_IDLE_TILT = 10.0,
		TOUCHDOWN_TIMEOUT = 1.5,
		TOUCHDOWN_MAX_SPEED = 0.12,
		MAX_COORD = 99999.0
	},

	PID = {
		VERTICAL = { kp = 0.040, ki = 0.006, kd = 0.035, max_i = 0.025, max_out = 0.060 },
		VELOCITY = { kp = 1.6, ki = 0.02, kd = 0.40, max_i = 1.5, max_out = 12.0 },
		HEADING  = { kp = 0.30, ki = 0.01, kd = 0.18, max_i = 2.0, max_out = 5.0 },
		LEVELING = { kp = 0.50, ki = 0.0, kd = 0.25, max_i = 0.0, max_out = 6.0 }
	},

	JOYSTICK = {
		LOCKOUT_TIME = 5.0,
		HOLD_OFFSET_TIME = 5.0,
		NEUTRAL_TIMEOUT = 5.0,
		RATE_FINE = 2.0,
		RATE_FAST = 3500.0,
		CYCLE_INTERVAL = 1.5
	},

	TICK_RATE = 0.05,
	NIXIE_WIDTH = 10,

	LOG = {
		ENABLED = true,
		INTERVAL = 1.0,
		MAX_SIZE = 250000
	}
}

local MathUtil = {}

function MathUtil.clamp(value, minValue, maxValue)
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end

function MathUtil.wrapAngle180(angle)
	while angle > 180 do angle = angle - 360 end
	while angle < -180 do angle = angle + 360 end
	return angle
end

function MathUtil.wrapAngle360(angle)
	while angle >= 360 do angle = angle - 360 end
	while angle < 0 do angle = angle + 360 end
	return angle
end

function MathUtil.normalize2D(x, z)
	local length = math.sqrt(x * x + z * z)
	if length < 0.00001 then
		return 0, 0, 0
	end
	return x / length, z / length, length
end

function MathUtil.round(value, decimals)
	local multiplier = 10 ^ (decimals or 0)
	return math.floor(value * multiplier + 0.5) / multiplier
end

function MathUtil.formatCoordNumber(value)
	value = MathUtil.round(value or 0, 0)
	local absValue = math.abs(value)
	if absValue <= 9999 then
		return string.format("%d", value)
	end
	local sign = (value < 0) and "-" or ""
	local kiloValue = MathUtil.round(absValue / 1000.0, 1)
	if kiloValue == math.floor(kiloValue) then
		return string.format("%s%dk", sign, math.floor(kiloValue))
	else
		return string.format("%s%.1fk", sign, kiloValue)
	end
end

function MathUtil.formatCoordinatesDisplay(x, z, width)
	width = width or (CONFIG.NIXIE_WIDTH or 10)
	local numX = MathUtil.round(x or 0, 0)
	local numZ = MathUtil.round(z or 0, 0)

	local sX = string.format("%d", numX)
	local sZ = string.format("%d", numZ)
	local combined = sX .. " " .. sZ
	if #combined <= width then
		return combined, 0
	end

	if numZ < 0 and #(sX .. sZ) <= width then
		return sX .. sZ, 0
	end

	local function toK(val, decimals)
		local sign = (val < 0) and "-" or ""
		local absVal = math.abs(val)
		local kVal = absVal / 1000.0
		if decimals == 0 then
			return string.format("%s%dk", sign, math.floor(kVal + 0.5))
		else
			local r = MathUtil.round(kVal, 1)
			if r == math.floor(r) then
				return string.format("%s%dk", sign, math.floor(r))
			else
				return string.format("%s%.1fk", sign, r)
			end
		end
	end

	local kX1 = (math.abs(numX) >= 1000) and toK(numX, 1) or sX
	local kZ1 = (math.abs(numZ) >= 1000) and toK(numZ, 1) or sZ
	if #(kX1 .. " " .. kZ1) <= width then
		return kX1 .. " " .. kZ1, 0
	end
	if numZ < 0 and #(kX1 .. kZ1) <= width then
		return kX1 .. kZ1, 0
	end

	local kX0 = (math.abs(numX) >= 1000) and toK(numX, 0) or sX
	local kZ0 = (math.abs(numZ) >= 1000) and toK(numZ, 0) or sZ
	if #(kX0 .. " " .. kZ0) <= width then
		return kX0 .. " " .. kZ0, 0
	end
	if numZ < 0 and #(kX0 .. kZ0) <= width then
		return kX0 .. kZ0, 0
	end

	local res = kX0 .. (numZ < 0 and "" or " ") .. kZ0
	if #res > width then
		res = string.sub(res, 1, width)
	end
	return res, 0
end

function MathUtil.computeJoystickRate(signal)
	local magnitude = math.abs(signal or 0)
	if magnitude == 0 then return 0 end
	local sign = (signal > 0) and 1 or -1

	local joyConfig = CONFIG.JOYSTICK or {}
	local fineRate = magnitude * (joyConfig.RATE_FINE or 2.0)
	local normalized = magnitude / 15.0
	local fastRate = (normalized ^ 2.5) * (joyConfig.RATE_FAST or 3500.0)

	return sign * (fineRate + fastRate)
end

function MathUtil.computeBrakingDistance(horizontalSpeed)
	local brakeAcceleration = CONFIG.LIMITS.BRAKE_ACCEL or 0.80
	local safetyMargin = 15.0
	local minDistance = CONFIG.LIMITS.APPROACH_MIN_DISTANCE or 65.0
	local distance = (horizontalSpeed * horizontalSpeed) / (2.0 * brakeAcceleration) + safetyMargin
	return math.max(distance, minDistance)
end

local SPEED_LUT = {}

local function initSpeedLUT(numTransmissions)
	SPEED_LUT = {}
	local activeCount = math.min(numTransmissions or 2, 3)
	local seen = {}

	if activeCount <= 1 then
		for signal1 = 0, 15 do
			local ratio1 = (15 - signal1) / 15.0
			local ratio = MathUtil.round(ratio1, 5)
			if not seen[ratio] then
				seen[ratio] = true
				table.insert(SPEED_LUT, { ratio = ratio, signals = { signal1 } })
			end
		end
	elseif activeCount == 2 then
		for signal1 = 0, 15 do
			for signal2 = 0, 15 do
				local ratioValue = ((15 - signal1) / 15.0) * ((15 - signal2) / 15.0)
				local ratio = MathUtil.round(ratioValue, 5)
				if not seen[ratio] then
					seen[ratio] = true
					table.insert(SPEED_LUT, { ratio = ratio, signals = { signal1, signal2 } })
				end
			end
		end
	else
		for signal1 = 0, 15 do
			for signal2 = 0, 15 do
				for signal3 = 0, 15 do
					local ratioValue = ((15 - signal1) / 15.0) * ((15 - signal2) / 15.0) * ((15 - signal3) / 15.0)
					local ratio = MathUtil.round(ratioValue, 6)
					if not seen[ratio] then
						seen[ratio] = true
						table.insert(SPEED_LUT, { ratio = ratio, signals = { signal1, signal2, signal3 } })
					end
				end
			end
		end
	end

	table.sort(SPEED_LUT, function(a, b) return a.ratio < b.ratio end)
end

initSpeedLUT(2)

local function findBestSpeedSignals(targetRatio, totalCount)
	targetRatio = MathUtil.clamp(targetRatio, 0.0, 1.0)
	totalCount = totalCount or 2
	local activeCount = math.min(totalCount, 3)

	if targetRatio <= 0.0001 then
		local cutSignals = {}
		for i = 1, totalCount do
			cutSignals[i] = 15
		end
		return cutSignals, 0.0
	end

	if #SPEED_LUT == 0 then
		initSpeedLUT(totalCount)
	end

	local best = SPEED_LUT[1]
	local bestDifference = math.abs(best.ratio - targetRatio)

	for i = 2, #SPEED_LUT do
		local entry = SPEED_LUT[i]
		local difference = math.abs(entry.ratio - targetRatio)
		if difference < bestDifference then
			bestDifference = difference
			best = entry
		elseif entry.ratio > targetRatio and difference > bestDifference then
			break
		end
	end

	local resultSignals = {}
	for i = 1, activeCount do
		resultSignals[i] = (best.signals and best.signals[i]) or 0
	end
	for i = activeCount + 1, totalCount do
		resultSignals[i] = 0
	end

	return resultSignals, best.ratio
end

local PID = {}
PID.__index = PID

function PID.new(gains)
	local self = setmetatable({}, PID)
	self.kp = gains.kp or 1.0
	self.ki = gains.ki or 0.0
	self.kd = gains.kd or 0.0
	self.max_i = gains.max_i or 10.0
	self.max_out = gains.max_out or 15.0
	self.integral = 0.0
	self.last_error = 0.0
	self.has_run = false
	return self
end

function PID:reset()
	self.integral = 0.0
	self.last_error = 0.0
	self.has_run = false
end

function PID:compute(errorValue, dt, currentRate)
	dt = dt or CONFIG.TICK_RATE
	if dt <= 0 then dt = CONFIG.TICK_RATE end

	if (errorValue > 0.1 and self.integral < 0) or (errorValue < -0.1 and self.integral > 0) then
		self.integral = self.integral * 0.85
	end

	if math.abs(errorValue) < 4.0 then
		self.integral = self.integral + errorValue * dt
		self.integral = MathUtil.clamp(self.integral, -self.max_i, self.max_i)
	end

	local derivative = 0.0
	if currentRate ~= nil then
		derivative = -currentRate
	elseif self.has_run then
		derivative = (errorValue - self.last_error) / dt
	end

	self.last_error = errorValue
	self.has_run = true

	local output = (self.kp * errorValue) + (self.ki * self.integral) + (self.kd * derivative)
	return MathUtil.clamp(output, -self.max_out, self.max_out)
end

local function centerText(text, width)
	width = width or (CONFIG.NIXIE_WIDTH or 10)
	text = tostring(text or "")
	if #text > width then
		text = string.sub(text, 1, width)
	end
	local padLeft = math.floor((width - #text) / 2)
	local padRight = width - #text - padLeft
	return string.rep(" ", padLeft) .. text .. string.rep(" ", padRight)
end

local ConfigFile = {
	path = "quadrocopter.cfg",
	data = {
		landing_memory = {},
		cabin_bindings = {},
		joystick_bindings = {},
		security = {},
		last_controls = {},
		saved_target = nil,
		axis_inversion = nil,
		spawn_offset = { x = 0, z = 0 }
	}
}

function ConfigFile.load()
	if fs.exists(ConfigFile.path) then
		local file = fs.open(ConfigFile.path, "r")
		if file then
			local content = file.readAll()
			file.close()
			local loaded = textutils.unserialize(content)
			if type(loaded) == "table" then
				for key, value in pairs(loaded) do
					ConfigFile.data[key] = value
				end
			end
		end
	end
	if ConfigFile.data.spawn_offset == nil then
		ConfigFile.data.spawn_offset = { x = 0, z = 0 }
	end
	return ConfigFile.data
end

function ConfigFile.save()
	local file = fs.open(ConfigFile.path, "w")
	if file then
		file.write(textutils.serialize(ConfigFile.data))
		file.close()
	end
end

ConfigFile.load()

local Hardware
local CabinControl
local Security
local JoystickNav
local NavSystem
local FlightManager

local FlightLogger = {
	timer = 0.0,
	path = "flight.log"
}

function FlightLogger.init()
	if not (CONFIG.LOG and CONFIG.LOG.ENABLED) then return end
	local bakPath = FlightLogger.path .. ".bak"
	if fs.exists(bakPath) then
		fs.delete(bakPath)
	end
	if fs.exists(FlightLogger.path) then
		fs.move(FlightLogger.path, bakPath)
	end
	local file = fs.open(FlightLogger.path, "w")
	if file then
		file.close()
	end
end

function FlightLogger.write(line)
	local maxSize = (CONFIG.LOG and CONFIG.LOG.MAX_SIZE) or 250000
	if fs.exists(FlightLogger.path) and fs.getSize(FlightLogger.path) > maxSize then
		local oldPath = FlightLogger.path .. ".bak"
		if fs.exists(oldPath) then
			fs.delete(oldPath)
		end
		fs.move(FlightLogger.path, oldPath)
	end
	local file = fs.open(FlightLogger.path, "a")
	if file then
		file.writeLine(line)
		file.close()
	end
end

function FlightLogger.update(dt, targetVerticalSpeed)
	if not (CONFIG.LOG and CONFIG.LOG.ENABLED) then return end
	FlightLogger.timer = FlightLogger.timer + (dt or CONFIG.TICK_RATE)
	local interval = (CONFIG.LOG and CONFIG.LOG.INTERVAL) or 1.0
	if FlightLogger.timer < interval then return end
	FlightLogger.timer = 0.0

	local nowStr = "00:00:00"
	local okDate, resDate = pcall(os.date, "%H:%M:%S")
	if okDate and type(resDate) == "string" then
		nowStr = resDate
	else
		local okTime, resTime = pcall(textutils.formatTime, os.time(), true)
		if okTime and type(resTime) == "string" then
			nowStr = resTime
		end
	end

	local y = (NavSystem and NavSystem.pos and NavSystem.pos.y) or 0
	local targetY = (FlightManager and FlightManager.target_alt) or 0
	local errY = targetY - y
	local vy = (NavSystem and NavSystem.vel and NavSystem.vel.y) or 0
	local tgtVy = targetVerticalSpeed or 0

	local thrCmd = (Hardware and Hardware.throttle_norm) or 0
	local thrAct = (Hardware and (Hardware.actual_ratio or Hardware.throttle_actual)) or 0
	local sigList = {}
	if Hardware and Hardware.cached_signals then
		for _, s in ipairs(Hardware.cached_signals) do
			table.insert(sigList, tostring(s))
		end
	end
	local sigStr = table.concat(sigList, ",")

	local vx = (NavSystem and NavSystem.vel and NavSystem.vel.x) or 0
	local vz = (NavSystem and NavSystem.vel and NavSystem.vel.z) or 0
	local hSpeed = math.sqrt(vx * vx + vz * vz)

	local pitch = (NavSystem and NavSystem.attitude and NavSystem.attitude.pitch) or 0
	local roll = (NavSystem and NavSystem.attitude and NavSystem.attitude.roll) or 0

	local currentVec = (Hardware and Hardware.current_vector) or { 0, 1, 0 }
	local nx = currentVec[1] or 0
	local ny = currentVec[2] or 1
	local nz = currentVec[3] or 0
	local tiltDeg = math.deg(math.acos(MathUtil.clamp(ny, -1.0, 1.0)))

	local distStr = "--"
	if NavSystem and NavSystem.is_target_loaded and NavSystem.target_dHoriz then
		distStr = string.format("%.0fm", NavSystem.target_dHoriz)
	end

	local line = string.format(
		"[%s] ST:%-7s | Y:%6.1f->%5.0f(err:%+5.1f) | Vy:%+5.2f/%+4.1f | Thr:%.3f(act:%.3f,[%s]) | Vxz:%4.2f(X:%+5.2f,Z:%+5.2f) | Att(P:%+4.1f*,R:%+4.1f*) | Vec:%4.1f*(%+5.2f,%+4.2f,%+5.2f) | Dist:%s",
		nowStr,
		tostring((FlightManager and FlightManager.state) or "PARKED"),
		y,
		targetY,
		errY,
		vy,
		tgtVy,
		thrCmd,
		thrAct,
		sigStr,
		hSpeed,
		vx,
		vz,
		pitch,
		roll,
		tiltDeg,
		nx,
		ny,
		nz,
		distStr
	)
	FlightLogger.write(line)
end

local Crypto = {}

function Crypto.hash(message)
	message = tostring(message or "")
	local bxor = (bit32 and bit32.bxor) or (bit and bit.bxor) or function(a, b)
		local result, bitVal = 0, 1
		while a > 0 or b > 0 do
			local bitA, bitB = a % 2, b % 2
			if bitA ~= bitB then
				result = result + bitVal
			end
			a = math.floor(a / 2)
			b = math.floor(b / 2)
			bitVal = bitVal * 2
		end
		return result
	end
	local hash1 = 0x811c9dc5
	local hash2 = 0x53c54179

	for i = 1, #message do
		local byte = string.byte(message, i)
		hash1 = (bxor(hash1, byte) * 0x01000193) % 0x100000000
		hash2 = (bxor(hash2, byte) * 0x04593293 + hash1) % 0x100000000
	end

	return string.format("%08x%08x", hash1, hash2)
end

Security = {
	is_locked = (ConfigFile.data.security and ConfigFile.data.security.hash ~= nil) and true or false,
	is_switch_on = false,
	pin_buffer = {},
	blink_timer = 0.0,
	blink_state = false,
	status_msg = nil,
	status_timer = 0.0,
	last_button_state = false,
	last_input_time = 0.0
}

function Security.hashSecret(secretString, salt)
	salt = salt or "quad_sec_s4lt_0x42"
	return Crypto.hash(salt .. ":" .. tostring(secretString or ""))
end

function Security.serializePin(buffer)
	local parts = {}
	for _, point in ipairs(buffer or {}) do
		table.insert(parts, string.format("%d,%d", point.forward or 0, point.right or 0))
	end
	return table.concat(parts, ";")
end

function Security.verifyPassword(buffer)
	local securityConfig = ConfigFile.data.security or {}
	if not securityConfig.hash then
		return true
	end
	local serialized = Security.serializePin(buffer)
	local computed = Security.hashSecret(serialized, securityConfig.salt)
	return computed == securityConfig.hash
end

function Security.update(dt, isLockSwitch, deltaForward, deltaRight, buttonPressed)
	Security.is_switch_on = isLockSwitch

	if Security.status_timer > 0 then
		Security.status_timer = Security.status_timer - dt
		if Security.status_timer <= 0 then
			Security.status_msg = nil
		end
	end

	local securityConfig = ConfigFile.data.security or {}
	if not securityConfig.hash then
		Security.is_locked = isLockSwitch or false
		Security.last_button_state = buttonPressed
		return
	end

	if isLockSwitch then
		Security.is_locked = true
		Security.pin_buffer = {}
		Security.status_msg = nil
		Security.last_button_state = buttonPressed
		return
	end

	if Security.is_locked then
		Security.blink_timer = Security.blink_timer + dt
		if Security.blink_timer >= 0.45 then
			Security.blink_timer = 0.0
			Security.blink_state = not Security.blink_state
		end

		local buttonJustPressed = buttonPressed and not Security.last_button_state
		Security.last_button_state = buttonPressed

		if #Security.pin_buffer > 0 then
			Security.last_input_time = Security.last_input_time + dt
			if Security.last_input_time > 10.0 then
				Security.pin_buffer = {}
				Security.status_msg = "TIMEOUT"
				Security.status_timer = 1.0
			end
		end

		if buttonJustPressed then
			Security.last_input_time = 0.0
			table.insert(Security.pin_buffer, { forward = deltaForward, right = deltaRight })

			local securityConfig = ConfigFile.data.security or {}
			local targetSteps = securityConfig.steps or 1

			if Security.verifyPassword(Security.pin_buffer) then
				Security.is_locked = false
				Security.status_msg = nil
				Security.status_timer = 0.0
				Security.pin_buffer = {}
				JoystickNav.lockout_timer = (CONFIG.JOYSTICK and CONFIG.JOYSTICK.LOCKOUT_TIME) or 5.0
			elseif #Security.pin_buffer >= targetSteps then
				Security.status_msg = "DENIED"
				Security.status_timer = 1.0
				Security.pin_buffer = {}
			end
		end
	else
		Security.last_button_state = buttonPressed
	end
end

function Security.setupInteractive()
	local width = CONFIG.NIXIE_WIDTH or 10
	local function showNixie(displayText)
		local formatted = centerText(displayText or "", width)
		if Hardware and Hardware.nixie_tube and Hardware.nixie_tube.setText then
			pcall(Hardware.nixie_tube.setText, formatted)
		end
	end

	term.clear()
	term.setCursorPos(1, 1)
	print("===[ SECURITY GESTURE SETUP ]===")
	print("Deflect stick and CLICK center button to record each step.")
	print("To FINISH and save, release stick to center (0,0) and CLICK center button.\n")

	local steps = {}
	local lastButton = true
	local isFinished = false

	while not isFinished do
		local deltaForward, deltaRight, buttonPressed = Hardware.readJoystick()
		local buttonJustPressed = buttonPressed and not lastButton
		lastButton = buttonPressed

		local isNeutral = (deltaForward == 0 and deltaRight == 0)
		local currentStepNum = #steps + 1

		local promptText = ""
		if isNeutral and #steps >= 1 then
			promptText = "ACCEPT"
		else
			promptText = string.format("PIN %d", currentStepNum)
		end

		local blink = (math.floor(os.epoch("utc") / 400) % 2) == 0
		showNixie(blink and promptText or "")

		if buttonJustPressed then
			if isNeutral then
				if #steps >= 1 then
					isFinished = true
				end
			else
				table.insert(steps, { forward = deltaForward, right = deltaRight })
				print(string.format("   Recorded Step %d: Forward=%d, Right=%d", #steps, deltaForward, deltaRight))
				print(string.format("   [Center stick + click to FINISH (%d step(s)), or deflect for Step %d]", #steps, #steps + 1))
			end
		end
		os.sleep(0.05)
	end

	local serialized = Security.serializePin(steps)
	local salt = string.format("quad_salt_%d", os.epoch("utc") or 12345)
	local hashed = Security.hashSecret(serialized, salt)

	ConfigFile.data.security = {
		salt = salt,
		hash = hashed,
		steps = #steps
	}
	ConfigFile.save()

	print(string.format("\nSecurity PIN (%d step(s)) successfully saved to quadrocopter.cfg!", #steps))
	showNixie("CALIBRATED")
	os.sleep(1.2)
end

local LandingMemory = {}

function LandingMemory.get(key)
	if not key then return nil end
	local memory = ConfigFile.data.landing_memory or {}
	local storedAltitude = memory[key]
	if storedAltitude and (storedAltitude < -64 or storedAltitude > 320) then
		memory[key] = nil
		ConfigFile.save()
		return nil
	end
	return storedAltitude
end

function LandingMemory.set(key, altitudeY)
	if not key or not altitudeY then return end
	if not ConfigFile.data.landing_memory then
		ConfigFile.data.landing_memory = {}
	end
	ConfigFile.data.landing_memory[key] = MathUtil.round(altitudeY, 1)
	ConfigFile.save()
end

function LandingMemory.delete(key)
	if not key or not ConfigFile.data.landing_memory then return end
	ConfigFile.data.landing_memory[key] = nil
	ConfigFile.save()
end

function LandingMemory.clear()
	ConfigFile.data.landing_memory = {}
	ConfigFile.save()
end

local lastControls = ConfigFile.data.last_controls or {}
local initialSpeed = lastControls.speed or 15

CabinControl = {
	bindings = ConfigFile.data.cabin_bindings or {},
	frozen_altitude = lastControls.altitude or 64.0,
	frozen_landing = (lastControls.landing ~= nil) and lastControls.landing or false,
	frozen_hover = (lastControls.hover ~= nil) and lastControls.hover or false,
	frozen_speed = initialSpeed,
	frozen_tilt = math.max(1.0, (initialSpeed / 15.0) * (CONFIG.LIMITS.MAX_CONE_ANGLE or 12.0)),
	frozen_flat_deck = (lastControls.flat_deck ~= nil) and lastControls.flat_deck or false
}

function CabinControl.hasBindings()
	local bindings = CabinControl.bindings
	local joystickBindings = ConfigFile.data.joystick_bindings
	local securityConfig = ConfigFile.data.security
	local axisInversion = ConfigFile.data.axis_inversion
	return bindings and bindings.landing and bindings.hover and bindings.altitude and bindings.speed and bindings.flat_deck and bindings.lock
		and joystickBindings and joystickBindings.relay and joystickBindings.forward and joystickBindings.backward and joystickBindings.left and joystickBindings.right and joystickBindings.button
		and securityConfig and securityConfig.hash and securityConfig.salt
		and axisInversion and axisInversion.x and axisInversion.z
end

function CabinControl.calibrateInteractive(forceFull)
	local width = CONFIG.NIXIE_WIDTH or 10
	local function showNixie(displayText)
		local formatted = centerText(displayText or "", width)
		if Hardware and Hardware.nixie_tube and Hardware.nixie_tube.setText then
			pcall(Hardware.nixie_tube.setText, formatted)
		end
	end

	local relays = {}
	for _, name in ipairs(peripheral.getNames()) do
		if peripheral.getType(name) == "redstone_relay" then
			table.insert(relays, { name = name, device = peripheral.wrap(name) })
		end
	end

	if #relays == 0 then
		print("No redstone_relay peripherals detected on network. Using direct computer sides.")
		showNixie("NO RELAYS")
		os.sleep(1.5)
		return
	end

	local validSides = { "top", "bottom", "left", "right", "back" }
	local currentBindings = CabinControl.bindings or {}

	term.clear()
	term.setCursorPos(1, 1)
	print("===[ COCKPIT CONTROLS CALIBRATION ]===")
	print(string.format("Detected %d redstone_relay block(s).", #relays))
	print("Follow prompts on Nixie tubes or terminal.\n")

	local newBindings = {}
	if not forceFull and currentBindings.landing and currentBindings.hover and currentBindings.altitude and currentBindings.speed then
		newBindings.landing = currentBindings.landing
		newBindings.hover = currentBindings.hover
		newBindings.altitude = currentBindings.altitude
		newBindings.speed = currentBindings.speed
		newBindings.gyro_x = currentBindings.gyro_x
		newBindings.gyro_z = currentBindings.gyro_z
		if currentBindings.flat_deck then
			newBindings.flat_deck = currentBindings.flat_deck
		end
		if currentBindings.lock then
			newBindings.lock = currentBindings.lock
		end
	end

	local joyBindings = { sides = {} }

	local function isBound(relayName, sideName)
		for _, bound in pairs(newBindings) do
			if bound.relay == relayName and bound.side == sideName then
				return true
			end
		end
		if joyBindings.relay == relayName then
			for _, side in ipairs(joyBindings.sides or {}) do
				if side == sideName then
					return true
				end
			end
		end
		return false
	end

	local baselineSignals = {}
	for _, relay in ipairs(relays) do
		baselineSignals[relay.name] = {}
		for _, side in ipairs(validSides) do
			local ok, signal = pcall(relay.device.getAnalogInput, side)
			baselineSignals[relay.name][side] = ok and signal or 0
		end
	end
	print(string.format("Captured baseline redstone signals across all %d relay(s).", #relays))

	local function waitForSignalChange(promptText, label, minDelta, targetRelay)
		minDelta = minDelta or 1
		print(">> Step: " .. label .. " (flashing on Nixie: " .. promptText .. ")")

		local blinkState = true
		local blinkTimer = 0.0
		while true do
			blinkTimer = blinkTimer + 0.1
			if blinkTimer >= 0.4 then
				blinkTimer = 0.0
				blinkState = not blinkState
				showNixie(blinkState and promptText or "")
			end

			for _, relay in ipairs(relays) do
				if (not targetRelay) or (relay.name == targetRelay) then
					for _, side in ipairs(validSides) do
						if not isBound(relay.name, side) then
							local ok, signalValue = pcall(relay.device.getAnalogInput, side)
							if ok and signalValue then
								local previousSignalValue = (baselineSignals[relay.name] and baselineSignals[relay.name][side]) or 0
								local signalDelta = math.abs(signalValue - previousSignalValue)
								if signalDelta >= minDelta then
									print(string.format("   Bound [%s] -> %s (side: %s, signal: %d -> %d, delta: %d)", label, relay.name, side, previousSignalValue, signalValue, signalDelta))

									for _, relay2 in ipairs(relays) do
										for _, side2 in ipairs(validSides) do
											if not isBound(relay2.name, side2) and not (relay2.name == relay.name and side2 == side) then
												local ok2, signalValue2 = pcall(relay2.device.getAnalogInput, side2)
												if baselineSignals[relay2.name] then
													baselineSignals[relay2.name][side2] = (ok2 and signalValue2) or 0
												end
											end
										end
									end

									return { relay = relay.name, side = side }
								end
							end
						end
					end
				end
			end
			os.sleep(0.05)
		end
	end

	if not newBindings.altitude then
		newBindings.altitude = waitForSignalChange("ALTITUDE", "Cruise Altitude Lever", 1)
	end

	if not newBindings.speed then
		newBindings.speed = waitForSignalChange("SPEED", "Cruise Speed Limiter Lever", 1)
		newBindings.gyro_x = { relay = newBindings.speed.relay, side = "left" }
		newBindings.gyro_z = { relay = newBindings.speed.relay, side = "right" }
		print(string.format("   Auto-assigned Gyro X (Blue) -> %s (side: left)", newBindings.speed.relay))
		print(string.format("   Auto-assigned Gyro Z (Cyan) -> %s (side: right)", newBindings.speed.relay))
	end

	if not newBindings.hover then
		newBindings.hover = waitForSignalChange("HOVER", "Hover Station Switch", 1)
	end

	if not newBindings.landing then
		newBindings.landing = waitForSignalChange("LAND", "Landing Switch", 1)
	end

	if not newBindings.flat_deck then
		newBindings.flat_deck = waitForSignalChange("HORIZON", "Horizon Lock Switch", 1)
	end

	if not newBindings.lock then
		newBindings.lock = waitForSignalChange("LOCK", "Master Security Lock Switch", 1)
	end

	ConfigFile.data.cabin_bindings = newBindings
	ConfigFile.save()
	CabinControl.bindings = newBindings

	local currentJoystick = ConfigFile.data.joystick_bindings or {}
	if forceFull or (not currentJoystick.relay) or (not currentJoystick.forward) or (not currentJoystick.right) or (not currentJoystick.backward) or (not currentJoystick.left) or (not currentJoystick.button) then
		print("\n>> Calibrating Wireless 2D Joystick (All 5 channels on 1 relay)...")

		local joystickForward = waitForSignalChange("FORWARD", "Joystick FORWARD (Green Link)", 1)
		joyBindings.relay = joystickForward.relay
		table.insert(joyBindings.sides, joystickForward.side)

		local joystickRight = waitForSignalChange("RIGHT", "Joystick RIGHT (Purple Link)", 1, joyBindings.relay)
		table.insert(joyBindings.sides, joystickRight.side)

		local joystickBack = waitForSignalChange("BACKWARD", "Joystick BACKWARD (Blue Link)", 1, joyBindings.relay)
		table.insert(joyBindings.sides, joystickBack.side)

		local joystickLeft = waitForSignalChange("LEFT", "Joystick LEFT (Red Link)", 1, joyBindings.relay)
		table.insert(joyBindings.sides, joystickLeft.side)

		local joystickButton = waitForSignalChange("ACCEPT", "Joystick ACCEPT Button (Torch Link)", 1, joyBindings.relay)
		table.insert(joyBindings.sides, joystickButton.side)

		ConfigFile.data.joystick_bindings = {
			relay = joyBindings.relay,
			forward = joystickForward.side,
			right = joystickRight.side,
			backward = joystickBack.side,
			left = joystickLeft.side,
			button = joystickButton.side
		}
		ConfigFile.save()
		print(string.format("   Joystick successfully bound to %s (all 5 channels distinct)!", joyBindings.relay))
	end

	local currentSecurity = ConfigFile.data.security or {}
	if forceFull or (not currentSecurity.hash) then
		Security.setupInteractive()
	end

	local currentInversion = ConfigFile.data.axis_inversion
	if forceFull or not currentInversion or not currentInversion.x or not currentInversion.z then
		if not Hardware or not Hardware.nav_spawn then
			if Hardware and Hardware.init then
				Hardware.init()
			end
		end

		term.clear()
		term.setCursorPos(1, 1)
		print("===[ GPS AXIS INVERSION & SPAWN OFFSET ]===")
		print("Tilt joystick to toggle +/- axis signs (Up->Z+, Right->X+).")
		print("Hold joystick >5s in any direction to tune spawn offset.")
		print("Return joystick to (0,0) to verify resulting coordinates.")
		print("Press ACCEPT button on joystick to save.\n")

		local invX = (currentInversion and currentInversion.x) or 1
		local invZ = (currentInversion and currentInversion.z) or 1
		local currentOffset = ConfigFile.data.spawn_offset or { x = 0, z = 0 }
		local offsetX = (currentOffset and currentOffset.x) or 0.0
		local offsetZ = (currentOffset and currentOffset.z) or 0.0

		local holdTimer = 0.0
		local isAdjustingOffset = false
		local lastButtonState = false

		while true do
			local deltaForward, deltaRight, buttonPressed = Hardware.readJoystick()
			local buttonJustPressed = buttonPressed and not lastButtonState
			lastButtonState = buttonPressed

			if buttonJustPressed then
				ConfigFile.data.axis_inversion = { x = invX, z = invZ }
				ConfigFile.data.spawn_offset = { x = MathUtil.round(offsetX, 1), z = MathUtil.round(offsetZ, 1) }
				ConfigFile.save()
				print(string.format("\nSaved: Inversion X:%+d Z:%+d | Offset X:%+.1f Z:%+.1f", invX, invZ, offsetX, offsetZ))
				os.sleep(0.8)
				break
			end

			local isDisplaced = (deltaForward ~= 0 or deltaRight ~= 0)
			local holdThreshold = (CONFIG.JOYSTICK and CONFIG.JOYSTICK.HOLD_OFFSET_TIME) or 5.0
			local dt = CONFIG.TICK_RATE or 0.05
			if isDisplaced then
				holdTimer = holdTimer + dt
				if not isAdjustingOffset then
					if deltaRight > 0 then invX = 1 elseif deltaRight < 0 then invX = -1 end
					if deltaForward > 0 then invZ = 1 elseif deltaForward < 0 then invZ = -1 end
					if holdTimer >= holdThreshold then
						isAdjustingOffset = true
					end
				else
					local maxCoord = CONFIG.LIMITS.MAX_COORD or 99999.0
					local rateX = MathUtil.computeJoystickRate(deltaRight)
					local rateZ = MathUtil.computeJoystickRate(deltaForward)
					offsetX = MathUtil.clamp(offsetX + rateX * dt, -maxCoord, maxCoord)
					offsetZ = MathUtil.clamp(offsetZ + rateZ * dt, -maxCoord, maxCoord)
				end
			else
				holdTimer = 0.0
				isAdjustingOffset = false
			end

			local calcX = (CONFIG.WORLD_SPAWN.x or 0) + offsetX
			local calcZ = (CONFIG.WORLD_SPAWN.z or 0) + offsetZ
			local dHoriz = 0
			if Hardware.nav_spawn and Hardware.nav_spawn.hasTarget and Hardware.nav_spawn.hasTarget() then
				local dist = Hardware.nav_spawn.getDistanceToTarget() or 0
				local dY = Hardware.nav_spawn.getVerticalOffsetToTarget() or 0
				local brg = Hardware.nav_spawn.getBearing() or 0
				local dHorizSq = dist * dist - dY * dY
				dHoriz = dHorizSq > 0 and math.sqrt(dHorizSq) or 0
				local navRef = Hardware.nav_target or Hardware.nav_spawn
				local hdg = (navRef and navRef.getHeading and navRef.getHeading()) or 0
				local worldAngle = MathUtil.wrapAngle360(hdg - brg)
				local rad = math.rad(worldAngle)
				calcX = calcX - invX * dHoriz * math.sin(rad)
				calcZ = calcZ - invZ * dHoriz * math.cos(rad)
			end

			term.setCursorPos(1, 7)
			if isAdjustingOffset then
				term.clearLine()
				print(string.format("[OFFSET TUNING]  X:%+8.1f   Z:%+8.1f       ", offsetX, offsetZ))
				term.clearLine()
				print(string.format("Deflection:      Forward:%+2d   Right:%+2d       ", deltaForward, deltaRight))
				term.clearLine()
				print("Status: Tuning spawn offset... Release to neutral (0,0) to view GPS.")
				term.clearLine()
				print("Press ACCEPT button on joystick to save.                           ")
				local dispText = MathUtil.formatCoordinatesDisplay(offsetX, offsetZ, width)
				showNixie(dispText)
			else
				term.clearLine()
				print(string.format("GPS POS:         X:%+8.1f   Z:%+8.1f (Dist:%.0fm) ", calcX, calcZ, dHoriz))
				term.clearLine()
				print(string.format("Axis Signs:      X:[%+d]          Z:[%+d]        ", invX, invZ))
				term.clearLine()
				print(string.format("Spawn Offset:    X:%+8.1f   Z:%+8.1f       ", offsetX, offsetZ))
				term.clearLine()
				if holdTimer > 0 then
					print(string.format("Holding: %.1f / %.1fs (Keep holding to tune offset)       ", holdTimer, holdThreshold))
				else
					print("Tilt joystick to flip signs. Hold >5s to tune offset.      ")
				end
				term.clearLine()
				print("Press ACCEPT button on joystick to save.                           ")
				local dispText = MathUtil.formatCoordinatesDisplay(calcX, calcZ, width)
				showNixie(dispText)
			end

			os.sleep(dt)
		end
	end

	showNixie("CALIBRATED")
	print("\nCalibration successfully saved to quadrocopter.cfg!")
	os.sleep(1.2)
end

Hardware = {
	bearings = {},
	transmissions = {},
	cached_signals = {},
	wired_modems = {},
	altitude_sensor = nil,
	velocity_x = nil,
	velocity_z = nil,
	gimbal_sensor = nil,
	nav_tables = {},
	nav_target = nil,
	nav_spawn = nil,
	typewriter = nil,
	nixie_tube = nil,
	last_nixie_text = "",
	throttle_norm = 0.0,
	throttle_actual = 0.0,
	throttle_ceiling = 0.42,
	actual_ratio = 0.0,
	inversion = false,
	current_vector = { 0, 1, 0 },
	last_dispatched_vec = nil,
	vector_cleared = true,
	typewriter_keys = {},
	active_keys = {},
	bearing_names = {},
	bearing_method_name = nil,
	bearing_payload_type = nil,
	bearing_methods_summary = nil,
	last_bearing_err = nil
}

function Hardware.init()
	Hardware.bearings = {}
	Hardware.bearing_names = {}
	Hardware.bearing_method_name = nil
	Hardware.bearing_payload_type = nil
	Hardware.bearing_methods_summary = nil
	Hardware.last_bearing_err = nil
	Hardware.transmissions = {}
	Hardware.cached_signals = {}
	Hardware.wired_modems = {}
	Hardware.altitude_sensor = nil
	Hardware.velocity_x = nil
	Hardware.velocity_z = nil
	Hardware.gimbal_sensor = nil
	Hardware.nav_tables = {}
	Hardware.nav_target = nil
	Hardware.nav_spawn = nil
	Hardware.typewriter = nil
	Hardware.nixie_tube = nil
	Hardware.last_nixie_text = ""
	Hardware.throttle_norm = 0.0
	Hardware.throttle_actual = 0.0
	Hardware.throttle_ceiling = CONFIG.LIMITS.MAX_THROTTLE
	Hardware.actual_ratio = 0.0
	Hardware.inversion = false
	Hardware.current_vector = { 0, 1, 0 }
	Hardware.last_dispatched_vec = nil
	Hardware.vector_cleared = true
	Hardware.typewriter_keys = {}
	Hardware.active_keys = {}

	local names = peripheral.getNames()
	for _, name in ipairs(names) do
		local peripheralType = peripheral.getType(name)
		if peripheralType == "gyroscopic_propeller_bearing" then
			table.insert(Hardware.bearings, peripheral.wrap(name))
			table.insert(Hardware.bearing_names, name)
		elseif peripheralType == "analog_transmission" then
			table.insert(Hardware.transmissions, peripheral.wrap(name))
		elseif peripheralType == "altitude_sensor" then
			Hardware.altitude_sensor = peripheral.wrap(name)
		elseif peripheralType == "velocity_sensor" then
			local device = peripheral.wrap(name)
			local axis = string.lower(device.getAxis() or "")
			if string.find(axis, "x") or axis == "east" or axis == "west" then
				Hardware.velocity_x = device
			else
				Hardware.velocity_z = device
			end
		elseif peripheralType == "gimbal_sensor" then
			Hardware.gimbal_sensor = peripheral.wrap(name)
		elseif peripheralType == "navigation_table" then
			table.insert(Hardware.nav_tables, peripheral.wrap(name))
		elseif peripheralType == "linked_typewriter" then
			Hardware.typewriter = peripheral.wrap(name)
		elseif string.find(string.lower(peripheralType or ""), "nixie") or peripheralType == "Create_NixieTube" then
			Hardware.nixie_tube = peripheral.wrap(name)
			if Hardware.nixie_tube and Hardware.nixie_tube.setTextColor then
				pcall(Hardware.nixie_tube.setTextColor, colors.orange)
			end
		elseif peripheralType == "modem" then
			local ok, isWireless = pcall(peripheral.call, name, "isWireless")
			if ok and isWireless == false then
				table.insert(Hardware.wired_modems, peripheral.wrap(name))
			end
		end
	end

	table.sort(Hardware.bearings, function(a, b) return (a.getSelfId() or "") < (b.getSelfId() or "") end)
	table.sort(Hardware.transmissions, function(a, b) return (a.getSelfId() or "") < (b.getSelfId() or "") end)

	if #Hardware.bearings > 0 then
		local b1 = Hardware.bearings[1]
		local b1Name = Hardware.bearing_names[1]
		local methodsList = {}
		if b1Name and peripheral.getMethods then
			for _, m in ipairs(peripheral.getMethods(b1Name) or {}) do
				table.insert(methodsList, m)
			end
		end
		if #methodsList == 0 and type(b1) == "table" then
			for k, v in pairs(b1) do
				if type(v) == "function" then table.insert(methodsList, tostring(k)) end
			end
		end
		table.sort(methodsList)
		Hardware.bearing_methods_summary = table.concat(methodsList, " ")

		local candidates = {
			"setManualTarget", "setTarget", "setVector", "setTiltVector",
			"setManualVector", "setTilt", "setAngle", "setTargetVector",
			"setDirection", "setTargetDirection", "setOrientation",
			"setPitchRoll", "setTiltAngle"
		}
		for _, m in ipairs(candidates) do
			if (b1 and type(b1[m]) == "function") or (b1Name and peripheral.hasType) then
				for _, cand in ipairs(methodsList) do
					if cand == m then
						Hardware.bearing_method_name = m
						break
					end
				end
				if Hardware.bearing_method_name then break end
			end
		end
		if not Hardware.bearing_method_name then
			for _, m in ipairs(methodsList) do
				local lm = string.lower(m)
				if string.find(lm, "target") or string.find(lm, "tilt") or string.find(lm, "vector") or string.find(lm, "manual") then
					Hardware.bearing_method_name = m
					break
				end
			end
		end
	end

	initSpeedLUT(#Hardware.transmissions)
	Hardware.assignNavTables()

	local ok = true
	local missing = {}
	if #Hardware.bearings < 4 then ok = false; table.insert(missing, string.format("bearings (%d/4)", #Hardware.bearings)) end
	if #Hardware.transmissions < 1 then ok = false; table.insert(missing, "analog_transmission (at least 1 required)") end
	if not Hardware.altitude_sensor then ok = false; table.insert(missing, "altitude_sensor") end
	if not Hardware.velocity_x then ok = false; table.insert(missing, "velocity_sensor (X)") end
	if not Hardware.velocity_z then ok = false; table.insert(missing, "velocity_sensor (Z)") end
	if not Hardware.gimbal_sensor then ok = false; table.insert(missing, "gimbal_sensor") end
	if #Hardware.nav_tables < 1 then ok = false; table.insert(missing, "navigation_table (at least 1 required)") end

	return ok, missing
end

function Hardware.assignNavTables()
	Hardware.nav_target = nil
	Hardware.nav_spawn = nil

	for _, tbl in ipairs(Hardware.nav_tables) do
		local okMeta, meta = pcall(tbl.getTargetMetadata)
		local hasTarget = pcall(tbl.hasTarget) and tbl.hasTarget()

		local kind = (okMeta and type(meta) == "table") and meta.kind or nil

		if kind == "spawn" then
			Hardware.nav_spawn = tbl
		elseif hasTarget then
			Hardware.nav_target = tbl
		end
	end

	if #Hardware.nav_tables == 1 then
		local tbl = Hardware.nav_tables[1]
		local okMeta, meta = pcall(tbl.getTargetMetadata)
		local kind = (okMeta and type(meta) == "table") and meta.kind or nil
		if kind == "spawn" then
			Hardware.nav_spawn = tbl
		else
			Hardware.nav_target = tbl
		end
	elseif #Hardware.nav_tables >= 2 and not Hardware.nav_target and not Hardware.nav_spawn then
		Hardware.nav_target = Hardware.nav_tables[1]
		Hardware.nav_spawn = Hardware.nav_tables[2]
	end
end

function Hardware.setVector(nx, ny, nz)
	local length = math.sqrt(nx * nx + ny * ny + nz * nz)
	if length > 0.00001 then
		nx, ny, nz = nx / length, ny / length, nz / length
	else
		nx, ny, nz = 0, 1, 0
	end

	if Hardware.last_dispatched_vec and
	   math.abs(nx - Hardware.last_dispatched_vec[1]) < 0.015 and
	   math.abs(ny - Hardware.last_dispatched_vec[2]) < 0.015 and
	   math.abs(nz - Hardware.last_dispatched_vec[3]) < 0.015 then
		return
	end

	Hardware.vector_cleared = false

	if #Hardware.bearings == 0 then return end

	local mName = Hardware.bearing_method_name
	if not mName then
		local b1 = Hardware.bearings[1]
		local b1Name = Hardware.bearing_names and Hardware.bearing_names[1]
		local methodsList = {}
		if b1Name and peripheral.getMethods then
			for _, m in ipairs(peripheral.getMethods(b1Name) or {}) do
				table.insert(methodsList, m)
			end
		end
		if #methodsList == 0 and type(b1) == "table" then
			for k, v in pairs(b1) do
				if type(v) == "function" then table.insert(methodsList, tostring(k)) end
			end
		end
		table.sort(methodsList)
		Hardware.bearing_methods_summary = table.concat(methodsList, " ")

		local candidates = {
			"setManualTarget", "setTarget", "setVector", "setTiltVector",
			"setManualVector", "setTilt", "setAngle", "setTargetVector",
			"setDirection", "setTargetDirection", "setOrientation",
			"setPitchRoll", "setTiltAngle"
		}
		for _, m in ipairs(candidates) do
			if (b1 and type(b1[m]) == "function") or (b1Name and peripheral.hasType) then
				for _, cand in ipairs(methodsList) do
					if cand == m then
						mName = m
						Hardware.bearing_method_name = m
						break
					end
				end
				if mName then break end
			end
		end
		if not mName then
			for _, m in ipairs(methodsList) do
				local lm = string.lower(m)
				if string.find(lm, "target") or string.find(lm, "tilt") or string.find(lm, "vector") or string.find(lm, "manual") then
					mName = m
					Hardware.bearing_method_name = m
					break
				end
			end
		end
	end

	if not mName then
		Hardware.last_bearing_err = "No vector method on bearing"
		return
	end

	local callBearing = function(idx, pt)
		local bObj = Hardware.bearings[idx]
		local bName = Hardware.bearing_names and Hardware.bearing_names[idx]
		local invoke = function(...)
			if bObj and type(bObj[mName]) == "function" then
				return bObj[mName](...)
			elseif bName and peripheral.call then
				return peripheral.call(bName, mName, ...)
			else
				error("Method " .. tostring(mName) .. " not callable")
			end
		end

		if pt == "map" then
			return pcall(invoke, { x = nx, y = ny, z = nz })
		elseif pt == "array" then
			return pcall(invoke, { nx, ny, nz })
		elseif pt == "scalars_3" then
			return pcall(invoke, nx, ny, nz)
		elseif pt == "scalars_2" then
			return pcall(invoke, nx, nz)
		elseif pt == "vector_obj" and vector and vector.new then
			return pcall(invoke, vector.new(nx, ny, nz))
		end
		return false, "unknown payload"
	end

	local pTypes = {}
	if Hardware.bearing_payload_type then
		table.insert(pTypes, Hardware.bearing_payload_type)
	end
	for _, pt in ipairs({ "map", "array", "scalars_3", "scalars_2", "vector_obj" }) do
		if pt ~= Hardware.bearing_payload_type then
			table.insert(pTypes, pt)
		end
	end

	local successPayload = nil
	local lastErr = nil

	for _, pt in ipairs(pTypes) do
		local ok, err = callBearing(1, pt)
		if ok then
			successPayload = pt
			Hardware.bearing_payload_type = pt
			lastErr = nil
			break
		else
			lastErr = err
		end
	end

	if successPayload then
		Hardware.last_bearing_err = nil
		Hardware.last_dispatched_vec = { nx, ny, nz }
		for i = 2, #Hardware.bearings do
			callBearing(i, successPayload)
		end
	else
		Hardware.last_bearing_err = tostring(mName) .. ": " .. tostring(lastErr)
		Hardware.last_dispatched_vec = nil
	end
end

function Hardware.clearVector()
	if Hardware.vector_cleared then return end
	Hardware.vector_cleared = true
	Hardware.last_dispatched_vec = nil
	Hardware.current_vector = { 0, 1, 0 }
	for i, bearing in ipairs(Hardware.bearings) do
		local bName = Hardware.bearing_names and Hardware.bearing_names[i]
		if bearing and type(bearing.clearManualTarget) == "function" then
			pcall(bearing.clearManualTarget)
		elseif bearing and type(bearing.clearTarget) == "function" then
			pcall(bearing.clearTarget)
		elseif bearing and type(bearing.resetTarget) == "function" then
			pcall(bearing.resetTarget)
		elseif bName and peripheral.call then
			pcall(peripheral.call, bName, "clearManualTarget")
		end
	end
end

function Hardware.setVectorSoft(targetNx, targetNy, targetNz, dt)
	dt = dt or CONFIG.TICK_RATE
	local maxAngleRadPerSec = math.rad(CONFIG.LIMITS.VECTOR_SLEW_RATE or 10.0)
	local maxStep = math.sin(maxAngleRadPerSec * dt)

	local currentX = Hardware.current_vector[1] or 0
	local currentY = Hardware.current_vector[2] or 1
	local currentZ = Hardware.current_vector[3] or 0

	local differenceX = targetNx - currentX
	local differenceY = targetNy - currentY
	local differenceZ = targetNz - currentZ
	local distance = math.sqrt(differenceX * differenceX + differenceY * differenceY + differenceZ * differenceZ)

	if distance > maxStep and distance > 0.0001 then
		local factor = maxStep / distance
		currentX = currentX + differenceX * factor
		currentY = currentY + differenceY * factor
		currentZ = currentZ + differenceZ * factor
	else
		currentX, currentY, currentZ = targetNx, targetNy, targetNz
	end

	local length = math.sqrt(currentX * currentX + currentY * currentY + currentZ * currentZ)
	if length > 0.0001 then
		currentX, currentY, currentZ = currentX / length, currentY / length, currentZ / length
	else
		currentX, currentY, currentZ = 0, 1, 0
	end
	Hardware.current_vector = { currentX, currentY, currentZ }

	local horizMag = math.sqrt(currentX * currentX + currentZ * currentZ)
	local targetHorizMag = math.sqrt(targetNx * targetNx + targetNz * targetNz)

	if targetHorizMag < 0.001 and horizMag < 0.008 then
		Hardware.clearVector()
	else
		Hardware.setVector(currentX, currentY, currentZ)
	end
end

function Hardware.setTiltVector(tiltX, tiltZ, maxAllowedTilt, dt)
	local totalTilt = math.sqrt(tiltX * tiltX + tiltZ * tiltZ)
	if totalTilt > maxAllowedTilt and totalTilt > 0.001 then
		local scale = maxAllowedTilt / totalTilt
		tiltX = tiltX * scale
		tiltZ = tiltZ * scale
		totalTilt = maxAllowedTilt
	end

	local radiansTilt = math.rad(totalTilt)
	local normalY = math.cos(radiansTilt)
	local normalX = (totalTilt > 0.001) and (math.sin(radiansTilt) * (tiltX / totalTilt)) or 0
	local normalZ = (totalTilt > 0.001) and (math.sin(radiansTilt) * (tiltZ / totalTilt)) or 0
	Hardware.setVectorSoft(normalX, normalY, normalZ, dt)
	return totalTilt, normalY
end

function Hardware.applyThrottle(rawThrottle, dt, fastRamp)
	local ceiling = Hardware.throttle_ceiling or CONFIG.LIMITS.MAX_THROTTLE
	rawThrottle = MathUtil.clamp(rawThrottle or 0.0, CONFIG.LIMITS.MIN_THROTTLE, ceiling)
	local transmissionCount = #Hardware.transmissions

	if rawThrottle == 0.0 then
		Hardware.throttle_norm = 0.0
		Hardware.throttle_actual = 0.0
		Hardware.actual_ratio = 0.0
		for i, trans in ipairs(Hardware.transmissions) do
			if Hardware.cached_signals[i] ~= 15 then
				Hardware.cached_signals[i] = 15
				pcall(trans.setSignal, 15)
			end
		end
		return
	end

	Hardware.throttle_norm = rawThrottle

	local diff = rawThrottle - Hardware.throttle_actual
	local slew = fastRamp and CONFIG.LIMITS.THROTTLE_SLEW_TAKEOFF or CONFIG.LIMITS.THROTTLE_SLEW_NORMAL
	local maxDelta = slew * (dt or CONFIG.TICK_RATE)

	if math.abs(diff) > maxDelta then
		Hardware.throttle_actual = Hardware.throttle_actual + (diff > 0 and maxDelta or -maxDelta)
	else
		Hardware.throttle_actual = rawThrottle
	end
	Hardware.throttle_actual = MathUtil.clamp(Hardware.throttle_actual, 0.0, ceiling)

	local targetRatio = Hardware.throttle_actual

	local deadband = (transmissionCount >= 3) and 0.0005 or 0.003
	if targetRatio > 0 and Hardware.actual_ratio > 0 and math.abs(targetRatio - Hardware.actual_ratio) < deadband then
		return
	end

	local signals, actualRatio = findBestSpeedSignals(targetRatio, transmissionCount)
	Hardware.actual_ratio = actualRatio

	for i, trans in ipairs(Hardware.transmissions) do
		local signal = signals[i] or 0
		if Hardware.cached_signals[i] ~= signal then
			Hardware.cached_signals[i] = signal
			pcall(trans.setSignal, signal)
		end
	end
end

function Hardware.setInversion(enable)
	Hardware.inversion = enable
	redstone.setOutput("back", enable)
end

function Hardware.setGyroStiffness(stiffnessX, stiffnessZ)
	local bindings = CabinControl.bindings
	local valueX = MathUtil.clamp(stiffnessX, 0, 15)
	local valueZ = MathUtil.clamp(stiffnessZ, 0, 15)

	if bindings and bindings.gyro_x and bindings.gyro_z and peripheral.isPresent(bindings.gyro_x.relay) and peripheral.isPresent(bindings.gyro_z.relay) then
		local peripheralX = peripheral.wrap(bindings.gyro_x.relay)
		local peripheralZ = peripheral.wrap(bindings.gyro_z.relay)
		if peripheralX and peripheralX.setAnalogOutput then
			pcall(peripheralX.setAnalogOutput, bindings.gyro_x.side, valueX)
		end
		if peripheralZ and peripheralZ.setAnalogOutput then
			pcall(peripheralZ.setAnalogOutput, bindings.gyro_z.side, valueZ)
		end
	else
		redstone.setAnalogOutput(CONFIG.SIDES.GYRO_STIFF_X, valueX)
		redstone.setAnalogOutput(CONFIG.SIDES.GYRO_STIFF_Z, valueZ)
	end
end

function Hardware.readRelayChannel(binding)
	if not binding or not binding.relay or not peripheral.isPresent(binding.relay) then
		return 0, false
	end
	local device = peripheral.wrap(binding.relay)
	local analogSignal = (device and device.getAnalogInput and device.getAnalogInput(binding.side)) or 0
	local digitalSignal = (device and device.getInput and device.getInput(binding.side)) or false
	return analogSignal, (analogSignal > 0) or digitalSignal
end

function Hardware.readLevers()
	local bindings = CabinControl.bindings
	local targetAlt = 64.0
	local isLandingMode = false
	local isHoverMode = false
	local speedLevel = 15
	local allowedTiltLimit = 12.0

	local altAnalog = 0
	if bindings and bindings.altitude and peripheral.isPresent(bindings.altitude.relay) then
		altAnalog, _ = Hardware.readRelayChannel(bindings.altitude)
	else
		altAnalog = redstone.getAnalogInput(CONFIG.SIDES.LEVER_ALT) or 0
	end
	targetAlt = CONFIG.LIMITS.MIN_CRUISE_ALT + (altAnalog / 15.0) * (CONFIG.LIMITS.MAX_CRUISE_ALT - CONFIG.LIMITS.MIN_CRUISE_ALT)

	if bindings and bindings.landing and peripheral.isPresent(bindings.landing.relay) then
		local _, isLanding = Hardware.readRelayChannel(bindings.landing)
		isLandingMode = isLanding
	else
		isLandingMode = redstone.getInput(CONFIG.SIDES.LANDING_MODE) or false
	end

	local _, isHover = Hardware.readRelayChannel(bindings and bindings.hover)
	isHoverMode = isHover

	if bindings and bindings.speed and peripheral.isPresent(bindings.speed.relay) then
		speedLevel, _ = Hardware.readRelayChannel(bindings.speed)
	end
	allowedTiltLimit = math.max(1.0, (speedLevel / 15.0) * (CONFIG.LIMITS.MAX_CONE_ANGLE or 12.0))

	local _, isFlatDeck = Hardware.readRelayChannel(bindings and bindings.flat_deck)
	local _, isLockSwitch = Hardware.readRelayChannel(bindings and bindings.lock)

	if Security.is_locked then
		targetAlt = CabinControl.frozen_altitude or targetAlt
		isLandingMode = (CabinControl.frozen_landing ~= nil) and CabinControl.frozen_landing or false
		isHoverMode = (CabinControl.frozen_hover ~= nil) and CabinControl.frozen_hover or false
		speedLevel = CabinControl.frozen_speed or 15
		allowedTiltLimit = CabinControl.frozen_tilt or 12.0
		isFlatDeck = (CabinControl.frozen_flat_deck ~= nil) and CabinControl.frozen_flat_deck or false
	else
		local last = ConfigFile.data.last_controls or {}
		local changed = (last.altitude ~= MathUtil.round(targetAlt, 1))
			or (last.landing ~= isLandingMode)
			or (last.hover ~= isHoverMode)
			or (last.speed ~= speedLevel)
			or (last.flat_deck ~= isFlatDeck)

		CabinControl.frozen_altitude = targetAlt
		CabinControl.frozen_landing = isLandingMode
		CabinControl.frozen_hover = isHoverMode
		CabinControl.frozen_speed = speedLevel
		CabinControl.frozen_tilt = allowedTiltLimit
		CabinControl.frozen_flat_deck = isFlatDeck

		if changed then
			ConfigFile.data.last_controls = {
				altitude = MathUtil.round(targetAlt, 1),
				landing = isLandingMode,
				hover = isHoverMode,
				speed = speedLevel,
				flat_deck = isFlatDeck
			}
			ConfigFile.save()
		end
	end

	return targetAlt, isLandingMode, isHoverMode, speedLevel, isFlatDeck, isLockSwitch, allowedTiltLimit
end

function Hardware.readJoystick()
	local joystickBindings = ConfigFile.data.joystick_bindings
	if not joystickBindings or not joystickBindings.relay or not peripheral.isPresent(joystickBindings.relay) then
		return 0, 0, false
	end
	local device = peripheral.wrap(joystickBindings.relay)
	if not device or not device.getAnalogInput then
		return 0, 0, false
	end

	local signalForward = (joystickBindings.forward and device.getAnalogInput(joystickBindings.forward)) or 0
	local signalBack = (joystickBindings.backward and device.getAnalogInput(joystickBindings.backward)) or 0
	local signalLeft = (joystickBindings.left and device.getAnalogInput(joystickBindings.left)) or 0
	local signalRight = (joystickBindings.right and device.getAnalogInput(joystickBindings.right)) or 0

	local buttonSignal = (joystickBindings.button and device.getAnalogInput(joystickBindings.button)) or 0
	local buttonDigital = (joystickBindings.button and device.getInput and device.getInput(joystickBindings.button)) or false
	local buttonPressed = (buttonSignal > 0) or buttonDigital

	local deltaForward = signalForward - signalBack
	local deltaRight = signalRight - signalLeft

	return deltaForward, deltaRight, buttonPressed
end

JoystickNav = {
	is_dialing = false,
	dial_x = 0.0,
	dial_z = 0.0,
	neutral_timer = 0.0,
	last_button_state = false,
	cycle_timer = 0.0,
	lockout_timer = 0.0
}

function JoystickNav.dispatch(targetX, targetZ)
	FlightManager.divergence_alarm = false
	FlightManager.divergence_timer = 0.0
	FlightManager.override_hover_alt = nil
	FlightManager.landing_aborted = false
	FlightManager.waypoint_reached = false

	NavSystem.setManualCoordinates(targetX, targetZ)
	NavSystem.update()

	FlightManager.planToTarget()
end

function JoystickNav.update(dt, deltaForward, deltaRight, buttonPressed)
	if JoystickNav.lockout_timer and JoystickNav.lockout_timer > 0 then
		JoystickNav.lockout_timer = JoystickNav.lockout_timer - dt
	end

	if Security.is_locked or (Security.status_timer and Security.status_timer > 0) then
		JoystickNav.is_dialing = false
		JoystickNav.last_button_state = buttonPressed
		return
	end

	if JoystickNav.lockout_timer and JoystickNav.lockout_timer > 0 then
		JoystickNav.is_dialing = false
		JoystickNav.last_button_state = buttonPressed
		return
	end

	local buttonJustPressed = buttonPressed and not JoystickNav.last_button_state
	JoystickNav.last_button_state = buttonPressed
	local joyConfig = CONFIG.JOYSTICK or {}

	if not JoystickNav.is_dialing then
		if deltaForward ~= 0 or deltaRight ~= 0 or buttonJustPressed then
			JoystickNav.is_dialing = true
			JoystickNav.dial_x = 0.0
			JoystickNav.dial_z = 0.0
			JoystickNav.neutral_timer = joyConfig.NEUTRAL_TIMEOUT or 5.0
			JoystickNav.cycle_timer = 0.0
			FlightManager.status_msg = "Dialing coordinates (Joystick)..."
		end
		return
	end

	if buttonJustPressed then
		local targetX = MathUtil.round(JoystickNav.dial_x, 0)
		local targetZ = MathUtil.round(JoystickNav.dial_z, 0)

		if targetX == 0 and targetZ == 0 then
			NavSystem.clearTarget()
			if FlightManager.state == "CRUISE" or FlightManager.state == "APPROACH" or FlightManager.state == "MANUAL" then
				FlightManager.state = "HOVER"
				FlightManager.hover_anchor = { x = NavSystem.pos.x, z = NavSystem.pos.z }
				FlightManager.pid_vel_x:reset()
				FlightManager.pid_vel_z:reset()
				FlightManager.divergence_alarm = false
				FlightManager.divergence_timer = 0.0
				Hardware.clearVector()
				FlightManager.status_msg = "Target cleared (0,0 ACCEPT): Holding station in HOVER."
			else
				FlightManager.status_msg = "Target cleared (0,0 ACCEPT)."
			end
			JoystickNav.is_dialing = false
			return
		else
			JoystickNav.dispatch(targetX, targetZ)
			JoystickNav.is_dialing = false
			return
		end
	end

	if deltaForward ~= 0 or deltaRight ~= 0 then
		JoystickNav.neutral_timer = joyConfig.NEUTRAL_TIMEOUT or 5.0

		local rateX = MathUtil.computeJoystickRate(deltaRight)
		local rateZ = MathUtil.computeJoystickRate(deltaForward)

		local maxCoord = CONFIG.LIMITS.MAX_COORD or 99999.0
		JoystickNav.dial_x = MathUtil.clamp(JoystickNav.dial_x + rateX * dt, -maxCoord, maxCoord)
		JoystickNav.dial_z = MathUtil.clamp(JoystickNav.dial_z + rateZ * dt, -maxCoord, maxCoord)
	else
		JoystickNav.neutral_timer = JoystickNav.neutral_timer - dt
		if JoystickNav.neutral_timer <= 0 then
			JoystickNav.is_dialing = false
			FlightManager.status_msg = "Coordinate dialing timed out."
		end
	end
end

NavSystem = {
	pos = { x = 0, y = 66, z = 0 },
	vel = { x = 0, y = 0, z = 0 },
	attitude = { pitch = 0, roll = 0 },
	rates = { x = 0, y = 0, z = 0 },
	heading = 0.0,
	pressure = 1.0,
	is_target_loaded = false,
	target_source = "NONE",
	target_distance = 0,
	target_dHoriz = 0,
	target_dY = 0,
	target_bearing = 0,
	target_local_x = 0,
	target_local_z = 0,
	manual_coord = (ConfigFile.data.saved_target and ConfigFile.data.saved_target.x and ConfigFile.data.saved_target.z) and { x = ConfigFile.data.saved_target.x, z = ConfigFile.data.saved_target.z } or nil,
	has_spawn_gps = false
}

function NavSystem.update()
	Hardware.assignNavTables()

	if Hardware.altitude_sensor then
		NavSystem.pos.y = Hardware.altitude_sensor.getHeight() or NavSystem.pos.y
		NavSystem.vel.y = Hardware.altitude_sensor.getVerticalSpeed() or 0
		if Hardware.altitude_sensor.getAirPressure then
			NavSystem.pressure = Hardware.altitude_sensor.getAirPressure() or 1.0
		end
	end

	local localVelocityX = 0
	local localVelocityZ = 0
	if Hardware.velocity_x then
		local raw = Hardware.velocity_x.getVelocity() or 0
		local axis = string.lower(Hardware.velocity_x.getAxis() or "")
		if axis == "west" or axis == "-x" then raw = -raw end
		localVelocityX = raw
	end
	if Hardware.velocity_z then
		local raw = Hardware.velocity_z.getVelocity() or 0
		local axis = string.lower(Hardware.velocity_z.getAxis() or "")
		if axis == "north" or axis == "-z" then raw = -raw end
		localVelocityZ = raw
	end
	NavSystem.vel.x = localVelocityX
	NavSystem.vel.z = localVelocityZ

	if Hardware.gimbal_sensor then
		local angles = Hardware.gimbal_sensor.getAngles()
		if angles and angles[1] and angles[2] then
			NavSystem.attitude.pitch = angles[1]
			NavSystem.attitude.roll = angles[2]
		end
		local rates = Hardware.gimbal_sensor.getAngularRates()
		if rates and rates[1] and rates[2] and rates[3] then
			NavSystem.rates.x = rates[1]
			NavSystem.rates.y = rates[2]
			NavSystem.rates.z = rates[3]
		end
	end

	local navigationReference = Hardware.nav_target or Hardware.nav_spawn or (Hardware.nav_tables[1])
	if navigationReference and navigationReference.getHeading then
		NavSystem.heading = navigationReference.getHeading() or NavSystem.heading
	end

	NavSystem.has_spawn_gps = false
	if Hardware.nav_spawn and Hardware.nav_spawn.hasTarget and Hardware.nav_spawn.hasTarget() then
		local distanceSpawn = Hardware.nav_spawn.getDistanceToTarget() or 0
		local deltaYSpawn = Hardware.nav_spawn.getVerticalOffsetToTarget() or 0
		local bearingSpawn = Hardware.nav_spawn.getBearing() or 0

		local distanceHorizSquare = distanceSpawn * distanceSpawn - deltaYSpawn * deltaYSpawn
		local distanceHorizSpawn = distanceHorizSquare > 0 and math.sqrt(distanceHorizSquare) or 0

		local worldAngle = MathUtil.wrapAngle360(NavSystem.heading - bearingSpawn)
		local radiansAzimuth = math.rad(worldAngle)

		local spawnOffset = ConfigFile.data.spawn_offset or {}
		local axisInversion = ConfigFile.data.axis_inversion or {}
		local spawnX = (CONFIG.WORLD_SPAWN.x or 0) + (spawnOffset.x or 0)
		local spawnZ = (CONFIG.WORLD_SPAWN.z or 0) + (spawnOffset.z or 0)
		local invX = (axisInversion.x ~= nil) and axisInversion.x or 1
		local invZ = (axisInversion.z ~= nil) and axisInversion.z or 1

		NavSystem.pos.x = MathUtil.round(spawnX - invX * distanceHorizSpawn * math.sin(radiansAzimuth), 1)
		NavSystem.pos.z = MathUtil.round(spawnZ - invZ * distanceHorizSpawn * math.cos(radiansAzimuth), 1)
		NavSystem.has_spawn_gps = true
	end

	if Hardware.nav_target and Hardware.nav_target.hasTarget and Hardware.nav_target.hasTarget() and not NavSystem.manual_coord then
		local distanceTarget = Hardware.nav_target.getDistanceToTarget() or 0
		local deltaYTarget = Hardware.nav_target.getVerticalOffsetToTarget() or 0
		local bearingTarget = Hardware.nav_target.getBearing() or 0

		local distanceHorizSquare = distanceTarget * distanceTarget - deltaYTarget * deltaYTarget
		local distanceHoriz = 0.0
		if (distanceTarget - math.abs(deltaYTarget)) > 0.15 and distanceHorizSquare > 0 then
			distanceHoriz = math.sqrt(distanceHorizSquare)
		end

		NavSystem.target_distance = distanceTarget
		NavSystem.target_dHoriz = distanceHoriz
		NavSystem.target_dY = deltaYTarget
		NavSystem.target_bearing = bearingTarget

		local bearingRadians = math.rad(bearingTarget)
		NavSystem.target_local_x = -distanceHoriz * math.sin(bearingRadians)
		NavSystem.target_local_z = distanceHoriz * math.cos(bearingRadians)
		NavSystem.target_bearing = MathUtil.round(math.deg(math.atan2(NavSystem.target_local_x, NavSystem.target_local_z)), 1)

		if NavSystem.has_spawn_gps then
			local worldAngleTarget = MathUtil.wrapAngle360(NavSystem.heading - bearingTarget)
			local radTarget = math.rad(worldAngleTarget)
			local axisInversion = ConfigFile.data.axis_inversion or {}
			local invX = (axisInversion.x ~= nil) and axisInversion.x or 1
			local invZ = (axisInversion.z ~= nil) and axisInversion.z or 1
			NavSystem.target_world_x = MathUtil.round(NavSystem.pos.x + invX * distanceHoriz * math.sin(radTarget), 1)
			NavSystem.target_world_z = MathUtil.round(NavSystem.pos.z + invZ * distanceHoriz * math.cos(radTarget), 1)
		end

		NavSystem.is_target_loaded = true
		NavSystem.target_source = "LODESTONE"

	elseif NavSystem.manual_coord and NavSystem.has_spawn_gps then
		local deltaX = NavSystem.manual_coord.x - NavSystem.pos.x
		local deltaZ = NavSystem.manual_coord.z - NavSystem.pos.z
		local distanceHoriz = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)

		local axisInversion = ConfigFile.data.axis_inversion or {}
		local invX = (axisInversion.x ~= nil) and axisInversion.x or 1
		local invZ = (axisInversion.z ~= nil) and axisInversion.z or 1

		if distanceHoriz > 0.001 then
			local worldAngleTarget = math.deg(math.atan2(deltaX / invX, deltaZ / invZ))
			local targetBearing = MathUtil.wrapAngle180(NavSystem.heading - worldAngleTarget)
			local bearingRadians = math.rad(targetBearing)

			NavSystem.target_local_x = -distanceHoriz * math.sin(bearingRadians)
			NavSystem.target_local_z = distanceHoriz * math.cos(bearingRadians)
			NavSystem.target_bearing = MathUtil.round(targetBearing, 1)
		else
			NavSystem.target_local_x = 0
			NavSystem.target_local_z = 0
			NavSystem.target_bearing = 0
		end
		NavSystem.target_distance = distanceHoriz
		NavSystem.target_dHoriz = distanceHoriz
		NavSystem.target_dY = nil

		NavSystem.target_world_x = NavSystem.manual_coord.x
		NavSystem.target_world_z = NavSystem.manual_coord.z

		NavSystem.is_target_loaded = true
		NavSystem.target_source = "MANUAL_COORD"

	else
		NavSystem.target_world_x = nil
		NavSystem.target_world_z = nil
		NavSystem.is_target_loaded = false
		NavSystem.target_source = "NONE"
		NavSystem.target_distance = 0
		NavSystem.target_dHoriz = 0
		NavSystem.target_dY = nil
		NavSystem.target_bearing = 0
		NavSystem.target_local_x = 0
		NavSystem.target_local_z = 0
	end
end

function NavSystem.setManualCoordinates(x, z)
	local maxCoord = CONFIG.LIMITS.MAX_COORD or 99999.0
	local numberX = MathUtil.clamp(tonumber(x) or 0, -maxCoord, maxCoord)
	local numberZ = MathUtil.clamp(tonumber(z) or 0, -maxCoord, maxCoord)
	NavSystem.manual_coord = { x = numberX, z = numberZ }
	ConfigFile.data.saved_target = { x = numberX, z = numberZ }
	ConfigFile.save()
	if FlightManager then
		FlightManager.waypoint_reached = false
	end
end

function NavSystem.clearTarget()
	NavSystem.manual_coord = nil
	NavSystem.is_target_loaded = false
	NavSystem.target_source = "NONE"
	NavSystem.locked_target_key = nil
	if FlightManager then
		FlightManager.waypoint_reached = false
	end
	ConfigFile.data.saved_target = nil
	ConfigFile.save()
end

function NavSystem.getTargetName()
	if Hardware.nav_target and Hardware.nav_target.hasTarget and Hardware.nav_target.hasTarget() then
		local okMeta, meta = pcall(Hardware.nav_target.getTargetMetadata)
		if okMeta and type(meta) == "table" then
			if meta.name and meta.name ~= "" then return tostring(meta.name) end
			if meta.custom_name and meta.custom_name ~= "" then return tostring(meta.custom_name) end
			if meta.title and meta.title ~= "" then return tostring(meta.title) end
		end
	end
	return nil
end

function NavSystem.getTargetKey()
	if Hardware.nav_target and Hardware.nav_target.hasTarget and Hardware.nav_target.hasTarget() then
		if NavSystem.locked_target_key then
			return NavSystem.locked_target_key
		end
		local okMeta, meta = pcall(Hardware.nav_target.getTargetMetadata)
		local key = nil
		if okMeta and type(meta) == "table" then
			if meta.sublevel_id then key = "lodestone_" .. tostring(meta.sublevel_id)
			elseif meta.map_id then key = "map_" .. tostring(meta.map_id)
			elseif meta.placer_uuid then key = "recovery_" .. tostring(meta.placer_uuid)
			elseif meta.name and meta.name ~= "" then key = "named_" .. tostring(meta.name)
			elseif meta.title and meta.title ~= "" then key = "titled_" .. tostring(meta.title)
			end
		end
		if not key then
			if NavSystem.target_world_x and NavSystem.target_world_z then
				key = string.format("target_pos_%.0f_%.0f", MathUtil.round(NavSystem.target_world_x, 0), MathUtil.round(NavSystem.target_world_z, 0))
			else
				key = "compass_target"
			end
		end
		NavSystem.locked_target_key = key
		return key
	elseif NavSystem.manual_coord then
		NavSystem.locked_target_key = nil
		return string.format("manual_%.0f_%.0f", NavSystem.manual_coord.x, NavSystem.manual_coord.z)
	else
		NavSystem.locked_target_key = nil
		return nil
	end
end

function NavSystem.getTargetPadAltitude()
	local knownPadY = nil
	if NavSystem.is_target_loaded and not NavSystem.manual_coord and NavSystem.target_dY then
		knownPadY = NavSystem.pos.y + NavSystem.target_dY
	end
	if not knownPadY then
		local targetKey = NavSystem.getTargetKey()
		knownPadY = targetKey and LandingMemory.get(targetKey) or nil
	end
	return knownPadY
end

FlightManager = {
	state = "PARKED",
	is_airborne = false,
	liftoff_start_y = nil,
	pid_vel_x = PID.new(CONFIG.PID.VELOCITY),
	pid_vel_z = PID.new(CONFIG.PID.VELOCITY),
	pid_heading = PID.new(CONFIG.PID.HEADING),
	pid_vertical = PID.new(CONFIG.PID.VERTICAL),
	overstress_timer = 0.0,
	touchdown_timer = 0.0,
	landing_tilt_timer = 0.0,
	landing_time_in_state = 0.0,
	baseline_pitch = 0.0,
	baseline_roll = 0.0,
	landing_start_y = nil,
	landing_has_descended = false,
	override_hover_alt = nil,
	last_alt_floor = nil,
	is_grounded = false,
	divergence_timer = 0.0,
	divergence_alarm = false,
	last_target_key = nil,
	hover_stable_timer = nil,
	approach_land_timer = nil,
	status_msg = "Ready. Insert Lodestone Compass or enter coords."
}

function FlightManager.getEstimatedHover(pressure)
	pressure = MathUtil.clamp(pressure or (NavSystem and NavSystem.pressure) or 1.0, 0.15, 1.0)
	local seaLevelHover = CONFIG.LIMITS.NOMINAL_HOVER or 0.025
	return seaLevelHover / pressure
end

function FlightManager.reset(isInitialBoot)
	FlightManager.pid_vel_x:reset()
	FlightManager.pid_vel_z:reset()
	FlightManager.pid_heading:reset()
	FlightManager.pid_vertical:reset()
	FlightManager.touchdown_timer = 0.0
	FlightManager.landing_tilt_timer = 0.0
	FlightManager.landing_time_in_state = 0.0
	FlightManager.overstress_timer = 0.0
	FlightManager.override_hover_alt = nil
	FlightManager.baseline_pitch = 0.0
	FlightManager.baseline_roll = 0.0
	FlightManager.divergence_timer = 0.0
	FlightManager.divergence_alarm = false
	FlightManager.last_target_key = NavSystem.getTargetKey()
	FlightManager.dispatched_target_key = nil
	FlightManager.hover_stable_timer = nil
	FlightManager.approach_land_timer = nil
	FlightManager.waypoint_reached = false
	FlightManager.manual_landing = false
	Hardware.throttle_ceiling = CONFIG.LIMITS.MAX_THROTTLE
	Hardware.clearVector()
	Hardware.setInversion(false)
	Hardware.setGyroStiffness(0, 0)

	local altFloorSetting, isLandingMode, isHoverMode = Hardware.readLevers()
	FlightManager.last_landing_mode = isLandingMode
	FlightManager.last_hover_mode = isHoverMode
	FlightManager.last_alt_floor = altFloorSetting

	if isInitialBoot then
		local currentPitch = NavSystem.attitude.pitch or 0
		local currentRoll = NavSystem.attitude.roll or 0
		local tiltMagnitude = math.max(math.abs(currentPitch), math.abs(currentRoll))
		local currentY = NavSystem.pos.y or 0
		local horizontalSpeed = math.sqrt((NavSystem.vel.x or 0)^2 + (NavSystem.vel.z or 0)^2)
		local verticalSpeed = math.abs(NavSystem.vel.y or 0)
		local currentVy = NavSystem.vel.y or 0
		local isMovingInAir = (horizontalSpeed > 0.35) or (verticalSpeed > 0.35) or (currentVy < -0.30)

		if tiltMagnitude > (CONFIG.LIMITS.MAX_IDLE_TILT or 45.0) then
			FlightManager.is_grounded = false
			FlightManager.is_airborne = true
			local estHover = FlightManager.getEstimatedHover(NavSystem.pressure)
			FlightManager.hover_throttle = estHover
			Hardware.applyThrottle(estHover, CONFIG.TICK_RATE, true)
			FlightManager.override_hover_alt = currentY + 2.0
			FlightManager.state = "HOVER"
			FlightManager.status_msg = string.format("ROLLOVER DANGER (%.1f* > %.1f*). Recovering to hover.", tiltMagnitude, CONFIG.LIMITS.MAX_IDLE_TILT or 45.0)

		elseif isMovingInAir then
			FlightManager.is_grounded = false
			FlightManager.is_airborne = true
			FlightManager.liftoff_start_y = currentY
			local estHover = FlightManager.getEstimatedHover(NavSystem.pressure)
			FlightManager.hover_throttle = estHover
			Hardware.applyThrottle(estHover, CONFIG.TICK_RATE, true)
			FlightManager.planToTarget()

		elseif (not isLandingMode) and (altFloorSetting > (currentY + 2.5) or isHoverMode) then
			FlightManager.is_grounded = false
			FlightManager.is_airborne = false
			FlightManager.liftoff_start_y = currentY
			FlightManager.touchdown_timer = 0.0
			FlightManager.hover_stable_timer = 0.0
			FlightManager.planToTarget()

		else
			FlightManager.is_grounded = true
			FlightManager.is_airborne = false
			FlightManager.liftoff_start_y = currentY
			FlightManager.state = "PARKED"
			FlightManager.status_msg = string.format("PARKED on base (Y:%.1f, Tilt:%.1f*). Ready for departure.", currentY, tiltMagnitude)
			Hardware.applyThrottle(0, CONFIG.TICK_RATE, true)
		end
	else
		FlightManager.is_grounded = false
		Hardware.applyThrottle(0, CONFIG.TICK_RATE, true)
		FlightManager.planToTarget()
	end
end

function FlightManager.isStationary(threshold)
	local maxSpeedThreshold = threshold or CONFIG.LIMITS.TOUCHDOWN_MAX_SPEED or 0.12
	local velocityX = NavSystem.vel.x or 0
	local velocityY = NavSystem.vel.y or 0
	local velocityZ = NavSystem.vel.z or 0
	local totalSpeed = math.sqrt(velocityX * velocityX + velocityY * velocityY + velocityZ * velocityZ)
	return totalSpeed <= maxSpeedThreshold and math.abs(velocityX) <= maxSpeedThreshold and math.abs(velocityY) <= maxSpeedThreshold and math.abs(velocityZ) <= maxSpeedThreshold
end

function FlightManager.planToTarget()
	local currentY = NavSystem.pos.y or 0
	local targetDistance = NavSystem.target_dHoriz or 0
	local altFloorSetting, isLandingMode, isHoverMode = Hardware.readLevers()
	local effectiveTargetAlt = FlightManager.override_hover_alt or altFloorSetting
	local altitudeDeficit = effectiveTargetAlt - currentY

	if isHoverMode then
		FlightManager.state = "FREEZED"
		FlightManager.target_alt = currentY
		Hardware.clearVector()
		Hardware.setGyroStiffness(15, 15)
		FlightManager.status_msg = "Hover switch active. Holding position in FREEZED."
		return
	end

	if not FlightManager.is_airborne or FlightManager.is_grounded then
		if isLandingMode then
			FlightManager.state = "PARKED"
			FlightManager.is_grounded = true
			FlightManager.is_airborne = false
			Hardware.applyThrottle(0, CONFIG.TICK_RATE, true)
			Hardware.clearVector()
			Hardware.setGyroStiffness(0, 0)
			FlightManager.status_msg = string.format("PARKED on ground (Y:%.1f). Flip landing switch OFF to launch.", currentY)
			return
		end

		FlightManager.state = "CLIMB"
		FlightManager.is_airborne = false
		FlightManager.is_grounded = false
		FlightManager.liftoff_start_y = currentY
		Hardware.clearVector()
		Hardware.setGyroStiffness(15, 15)
		FlightManager.status_msg = string.format("TAKEOFF & CLIMB to altitude (Y:%.1f -> %.0fm). Pure vertical ascent.", currentY, effectiveTargetAlt)
		return
	end

	if not NavSystem.is_target_loaded then
		FlightManager.state = "HOVER"
		FlightManager.target_alt = effectiveTargetAlt
		Hardware.clearVector()
		Hardware.setGyroStiffness(15, 15)
		FlightManager.status_msg = "No target loaded. Holding altitude in HOVER."
		return
	end

	local hoverRadius = CONFIG.LIMITS.HOVER_RADIUS or 5.0
	if targetDistance <= hoverRadius then
		if isLandingMode and not FlightManager.landing_aborted then
			FlightManager.state = "LANDING"
			FlightManager.touchdown_timer = 0.0
			FlightManager.landing_time_in_state = 0.0
			FlightManager.landing_start_y = currentY
			FlightManager.landing_has_descended = false
			FlightManager.landing_retry_count = 0
			FlightManager.status_msg = "Arrived at target: Commencing descent to land."
		else
			FlightManager.state = "HOVER"
			FlightManager.target_alt = effectiveTargetAlt
			Hardware.clearVector()
			Hardware.setGyroStiffness(15, 15)
			FlightManager.status_msg = "Target reached. Holding position in HOVER."
		end
		return
	end

	local altDeadband = CONFIG.LIMITS.ALT_DEADBAND or 0.5
	if altitudeDeficit > altDeadband then
		FlightManager.state = "CLIMB"
		Hardware.clearVector()
		Hardware.setGyroStiffness(15, 15)
		FlightManager.status_msg = string.format("CLIMB to target altitude (Y:%.1f -> %.0fm). Pure vertical ascent.", currentY, effectiveTargetAlt)
		return
	end

	local currentVx = NavSystem.vel.x or 0
	local currentVz = NavSystem.vel.z or 0
	local horizontalSpeed = math.sqrt(currentVx * currentVx + currentVz * currentVz)
	local brakingDistance = MathUtil.computeBrakingDistance(horizontalSpeed)

	if targetDistance <= brakingDistance then
		FlightManager.state = "APPROACH"
		Hardware.setGyroStiffness(15, 15)
		FlightManager.pid_vel_x:reset()
		FlightManager.pid_vel_z:reset()
		FlightManager.status_msg = string.format("Target nearby (Dist:%.1fm <= SBrake:%.1fm). Entering APPROACH.", targetDistance, brakingDistance)
		return
	end

	FlightManager.state = "CRUISE"
	FlightManager.status_msg = string.format("Altitude reached (Y:%.1f). Cruising to target (Dist:%.1fm).", currentY, targetDistance)
end

function FlightManager.processTouchdown(dt, isGrounded, restingTilt, targetKey, targetDistance)
	if isGrounded then
		FlightManager.touchdown_timer = (FlightManager.touchdown_timer or 0) + dt
		local requiredTimeout = CONFIG.LIMITS.TOUCHDOWN_TIMEOUT or 1.5
		if FlightManager.touchdown_timer >= requiredTimeout then
			FlightManager.state = "PARKED"
			FlightManager.is_grounded = true
			FlightManager.is_airborne = false
			FlightManager.touchdown_timer = 0.0
			FlightManager.override_hover_alt = nil
			FlightManager.landing_aborted = false
			Hardware.applyThrottle(0, dt, true)
			Hardware.clearVector()
			if targetKey and targetDistance and targetDistance <= 6.0 then
				LandingMemory.set(targetKey, NavSystem.pos.y)
			end
			FlightManager.status_msg = string.format("TOUCHDOWN on base (Y:%.1f, Tilt:%.1f*). Engines cut.", NavSystem.pos.y, restingTilt)
			return true
		end
	else
		FlightManager.touchdown_timer = 0.0
	end
	return false
end

function FlightManager.computeThrottle(targetVerticalSpeed, dt, normalY, isTakeoff, customCeiling)
	dt = dt or CONFIG.TICK_RATE
	local currentVy = NavSystem.vel.y or 0
	local currentPressure = NavSystem.pressure or 1.0

	local rawAcceleration = (currentVy - (FlightManager.last_vy or currentVy)) / math.max(0.01, dt)
	FlightManager.last_vy = currentVy
	FlightManager.filtered_acc_vy = (FlightManager.filtered_acc_vy or 0) * 0.6 + rawAcceleration * 0.4
	local accelerationVerticalSpeed = FlightManager.filtered_acc_vy

	local errorVerticalSpeed = targetVerticalSpeed - currentVy

	local baseHoverConstant = CONFIG.LIMITS.NOMINAL_HOVER or 0.025
	local pressureScale = MathUtil.clamp(1.0 / math.max(0.15, currentPressure), 1.0, 5.0)
	local learnedBias = 1.0
	if FlightManager.hover_throttle and FlightManager.hover_throttle > 0 then
		learnedBias = MathUtil.clamp(FlightManager.hover_throttle / baseHoverConstant, 0.75, 1.6)
	end
	local nominalHover = baseHoverConstant * pressureScale * learnedBias

	if FlightManager.state ~= "PARKED" and not FlightManager.is_grounded and FlightManager.state ~= "LANDING" then
		if math.abs(errorVerticalSpeed) < 0.4 and math.abs(currentVy) < 0.25 and math.abs(targetVerticalSpeed) < 0.2 then
			FlightManager.hover_throttle = MathUtil.clamp(
				(FlightManager.hover_throttle or baseHoverConstant) + errorVerticalSpeed * 0.005 * dt,
				baseHoverConstant * 0.70,
				baseHoverConstant * 1.60
			)
		end
	end

	if targetVerticalSpeed < -0.1 and not isTakeoff then
		if FlightManager.pid_vertical.integral > 0.005 then
			FlightManager.pid_vertical.integral = 0.005
		end
	end

	local maxAllowedCeiling = Hardware.throttle_ceiling or CONFIG.LIMITS.MAX_THROTTLE
	local isClimbingState = isTakeoff or (FlightManager.state == "CLIMB")

	local pidCorrection = FlightManager.pid_vertical:compute(errorVerticalSpeed, dt, accelerationVerticalSpeed)
	local effectiveCorrection = pidCorrection
	if isClimbingState and errorVerticalSpeed > 0 then
		local climbBoost = math.min(0.080, errorVerticalSpeed * 0.030)
		effectiveCorrection = math.max(effectiveCorrection, climbBoost)
	end
	local baseThrottle = nominalHover + effectiveCorrection

	normalY = math.max(0.85, normalY or 1.0)
	local finalThrottle = baseThrottle / normalY

	local minThrottle = CONFIG.LIMITS.MIN_THROTTLE or 0.0
	if FlightManager.state ~= "LANDING" and FlightManager.state ~= "PARKED" and not FlightManager.is_grounded then
		minThrottle = MathUtil.clamp(nominalHover * 0.60, CONFIG.LIMITS.MIN_AIRBORNE_THROTTLE or 0.015, 0.120)
	end

	local dynamicCeiling = isClimbingState and math.min(nominalHover * 2.5, maxAllowedCeiling) or MathUtil.clamp(nominalHover * 1.80, 0.080, maxAllowedCeiling)
	local effectiveCeiling = customCeiling and math.min(customCeiling, dynamicCeiling) or dynamicCeiling

	finalThrottle = MathUtil.clamp(finalThrottle, minThrottle, effectiveCeiling)
	return finalThrottle, currentVy
end

function FlightManager.updateParked(dt, effectiveTargetAlt, isLandingMode, isHoverMode, targetJustChanged)
	local currentVy = NavSystem.vel.y or 0
	local currentVx = NavSystem.vel.x or 0
	local currentVz = NavSystem.vel.z or 0
	local linearSpeed = math.sqrt(currentVx * currentVx + currentVy * currentVy + currentVz * currentVz)
	local currentPitch = NavSystem.attitude.pitch or 0
	local currentRoll = NavSystem.attitude.roll or 0
	local idleTilt = math.max(math.abs(currentPitch), math.abs(currentRoll))
	local maxIdleTilt = CONFIG.LIMITS.MAX_IDLE_TILT or 10.0

	if currentVy < -0.15 or linearSpeed > 0.40 or idleTilt > maxIdleTilt then
		FlightManager.state = "CLIMB"
		FlightManager.is_grounded = false
		FlightManager.is_airborne = true
		FlightManager.override_hover_alt = math.max(NavSystem.pos.y + 15.0, effectiveTargetAlt or 0)
		FlightManager.touchdown_timer = 0.0
		Hardware.setGyroStiffness(15, 15)
		local recoveryThrottle = math.min(Hardware.throttle_ceiling or CONFIG.LIMITS.MAX_THROTTLE, 0.35)
		Hardware.applyThrottle(recoveryThrottle, dt, true)
		if currentVy < -0.15 or linearSpeed > 0.40 then
			FlightManager.status_msg = string.format("FALL DETECTED IN PARK (Vy:%.2f m/s, Spd:%.2f m/s): Emergency CLIMB!", currentVy, linearSpeed)
		else
			FlightManager.status_msg = string.format("STEEP TILT (%.1f* > %.1f*): Emergency CLIMB from PARKED!", idleTilt, maxIdleTilt)
		end
		return
	end

	local wasLandingMode = (FlightManager.last_landing_mode ~= nil) and FlightManager.last_landing_mode or isLandingMode
	local landingJustReleased = wasLandingMode and (not isLandingMode)
	FlightManager.last_landing_mode = isLandingMode
	FlightManager.last_hover_mode = isHoverMode

	if landingJustReleased or (not isLandingMode and targetJustChanged) then
		FlightManager.landing_aborted = false
		FlightManager.is_grounded = false
		FlightManager.is_airborne = false
		FlightManager.liftoff_start_y = NavSystem.pos.y
		FlightManager.touchdown_timer = 0.0
		FlightManager.hover_stable_timer = 0.0
		FlightManager.pid_vertical:reset()
		FlightManager.planToTarget()
		return
	end

	Hardware.clearVector()
	Hardware.applyThrottle(0, dt, true)
	Hardware.setInversion(false)
	Hardware.setGyroStiffness(0, 0)

	FlightManager.is_grounded = true
	FlightManager.is_airborne = false
	FlightManager.liftoff_start_y = NavSystem.pos.y
	if NavSystem.is_target_loaded then
		FlightManager.status_msg = string.format("PARKED at waypoint (Y:%.1f). Turn off landing switch to launch.", NavSystem.pos.y)
	else
		FlightManager.status_msg = string.format("PARKED on base (Y:%.1f, Tilt:%.1f*). Turn off landing switch to launch.", NavSystem.pos.y, idleTilt)
	end
end

function FlightManager.updateClimb(dt, effectiveTargetAlt, cruiseTargetVerticalSpeed, isLandingMode, isHoverMode)
	if isHoverMode then
		FlightManager.state = "FREEZED"
		FlightManager.target_alt = NavSystem.pos.y
		FlightManager.pid_vel_x:reset()
		FlightManager.pid_vel_z:reset()
		Hardware.clearVector()
		Hardware.setGyroStiffness(15, 15)
		FlightManager.status_msg = "Hover switch ON: Freezing climb at current altitude."
		return
	end

	local currentY = NavSystem.pos.y or 0
	local startY = FlightManager.liftoff_start_y or currentY

	if isLandingMode then
		FlightManager.state = "LANDING"
		FlightManager.landing_start_y = currentY
		FlightManager.touchdown_timer = 0.0
		FlightManager.landing_time_in_state = 0.0
		FlightManager.landing_has_descended = false
		FlightManager.status_msg = "Landing switch ON: Aborting climb to land."
		return
	end

	Hardware.clearVector()
	Hardware.setGyroStiffness(15, 15)

	if currentY >= (startY + 1.2) then
		FlightManager.is_airborne = true
		FlightManager.is_grounded = false
	end

	local computedThrottle, currentVy = FlightManager.computeThrottle(cruiseTargetVerticalSpeed, dt, 1.0, true)
	Hardware.applyThrottle(computedThrottle, dt, true)

	local deadband = CONFIG.LIMITS.ALT_DEADBAND or 0.5
	if currentY >= (effectiveTargetAlt - deadband) and math.abs(currentVy) < 1.0 then
		local targetDistance = NavSystem.target_dHoriz or 0
		local currentVx = NavSystem.vel.x or 0
		local currentVz = NavSystem.vel.z or 0
		local horizontalSpeed = math.sqrt(currentVx * currentVx + currentVz * currentVz)
		local brakingDistance = MathUtil.computeBrakingDistance(horizontalSpeed)

		if not NavSystem.is_target_loaded then
			FlightManager.state = "HOVER"
			FlightManager.status_msg = string.format("Target altitude reached (Y:%.1f). Holding HOVER.", currentY)
		elseif targetDistance <= brakingDistance then
			FlightManager.state = "APPROACH"
			FlightManager.pid_vel_x:reset()
			FlightManager.pid_vel_z:reset()
			FlightManager.status_msg = string.format("Target altitude reached (Y:%.1f). Entering APPROACH (Dist:%.1fm).", currentY, targetDistance)
		else
			FlightManager.state = "CRUISE"
			FlightManager.status_msg = string.format("Target altitude reached (Y:%.1f). Transitioning to CRUISE.", currentY)
		end
		return
	end

	FlightManager.status_msg = string.format("CLIMB TO CRUISE: Y=%.1f/%.0fm (+%.1fm) Vy=%.1f m/s", currentY, effectiveTargetAlt, effectiveTargetAlt - currentY, currentVy)
end

function FlightManager.updateFreezed(dt, isHoverMode)
	if not isHoverMode then
		FlightManager.status_msg = "Hover switch released: Resuming target planning."
		FlightManager.planToTarget()
		return
	end

	local currentVx = NavSystem.vel.x or 0
	local currentVz = NavSystem.vel.z or 0
	local horizontalSpeed = math.sqrt(currentVx * currentVx + currentVz * currentVz)

	if horizontalSpeed > 0.05 then
		local brakeTiltX = MathUtil.clamp(-currentVx * 2.0, -1.5, 1.5)
		local brakeTiltZ = MathUtil.clamp(-currentVz * 2.0, -1.5, 1.5)
		Hardware.setTiltVector(brakeTiltX, brakeTiltZ, 1.5, dt)
	else
		Hardware.clearVector()
	end
	Hardware.setGyroStiffness(15, 15)

	local currentY = NavSystem.pos.y or 0
	local targetAlt = FlightManager.target_alt or currentY
	local errorAltitude = targetAlt - currentY

	local targetVy = 0.0
	local deadband = CONFIG.LIMITS.ALT_DEADBAND or 0.5
	if math.abs(errorAltitude) > deadband then
		targetVy = MathUtil.clamp(errorAltitude * 0.8, -1.0, 1.0)
	end

	local computedThrottle = FlightManager.computeThrottle(targetVy, dt, 1.0, false)
	Hardware.applyThrottle(computedThrottle, dt, false)

	FlightManager.status_msg = string.format("FREEZED (Y:%.1f, Alt:%.0fm, Drift:%.2fm/s). Station locked.", currentY, targetAlt, horizontalSpeed)
end

function FlightManager.updateCruise(dt, cruiseTargetVerticalSpeed, cruiseMaxTilt, isHoverMode, isFlatDeck)
	if isHoverMode then
		FlightManager.state = "FREEZED"
		FlightManager.status_msg = "Hover switch ON: Holding station in FREEZED."
		FlightManager.cruise_locked_throttle = nil
		return
	end
	if not NavSystem.is_target_loaded then
		FlightManager.state = "HOVER"
		FlightManager.status_msg = "Compass removed: Leveling vectors to hover."
		FlightManager.cruise_locked_throttle = nil
		return
	end

	local deltaX = NavSystem.target_local_x or 0
	local deltaZ = NavSystem.target_local_z or 0
	local targetDistance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)

	local currentVx = NavSystem.vel.x or 0
	local currentVz = NavSystem.vel.z or 0
	local horizontalSpeed = math.sqrt(currentVx * currentVx + currentVz * currentVz)
	local brakingDistance = MathUtil.computeBrakingDistance(horizontalSpeed)

	if targetDistance <= brakingDistance then
		FlightManager.state = "APPROACH"
		Hardware.setGyroStiffness(15, 15)
		FlightManager.cruise_locked_throttle = nil
		FlightManager.pid_vel_x:reset()
		FlightManager.pid_vel_z:reset()
		FlightManager.status_msg = string.format("Deceleration zone reached (Dist: %.1fm <= SBrake: %.1fm). Engaging soft approach.", targetDistance, brakingDistance)
		return
	end

	local currentY = NavSystem.pos.y or 0
	local targetAlt = FlightManager.target_alt or currentY
	local errorAltitude = targetAlt - currentY

	local isAdjustingCruiseAlt = math.abs(errorAltitude) > 3.0

	if isAdjustingCruiseAlt then
		Hardware.clearVector()
		Hardware.setGyroStiffness(15, 15)
		FlightManager.cruise_locked_throttle = nil
		local computedThrottle, currentVy = FlightManager.computeThrottle(cruiseTargetVerticalSpeed, dt, 1.0, errorAltitude > 0)
		Hardware.applyThrottle(computedThrottle, dt, false)
		FlightManager.status_msg = string.format("CRUISE ALT ADJUST: Y=%.1f->%.0fm (Vy=%.1f m/s). Coasting on inertia.", currentY, targetAlt, currentVy)
		return
	end

	if isFlatDeck then
		Hardware.setGyroStiffness(15, 15)
	else
		Hardware.setGyroStiffness(0, 0)
	end

	local directionX = (targetDistance > 0.05) and (deltaX / targetDistance) or 0.0
	local directionZ = (targetDistance > 0.05) and (deltaZ / targetDistance) or 0.0

	local activeMaxTilt = cruiseMaxTilt
	local tiltX = activeMaxTilt * directionX
	local tiltZ = activeMaxTilt * directionZ

	local totalTilt, normalY = Hardware.setTiltVector(tiltX, tiltZ, activeMaxTilt, dt)

	FlightManager.cruise_calib_timer = (FlightManager.cruise_calib_timer or 0) + dt
	if not FlightManager.cruise_locked_throttle then
		local compThrot, _ = FlightManager.computeThrottle(cruiseTargetVerticalSpeed, dt, normalY, false)
		if FlightManager.cruise_calib_timer >= 2.0 and math.abs(NavSystem.vel.y or 0) < 0.25 then
			FlightManager.cruise_locked_throttle = compThrot
		else
			Hardware.applyThrottle(compThrot, dt, false)
		end
	end
	if FlightManager.cruise_locked_throttle then
		Hardware.applyThrottle(FlightManager.cruise_locked_throttle, dt, false)
	end

	FlightManager.status_msg = string.format("CRUISE (Dist: %.1fm, Tilt: %.1f*, Spd: %.1fm/s, SBrake: %.0fm)", targetDistance, totalTilt, horizontalSpeed, brakingDistance)
end

function FlightManager.updateApproach(dt, cruiseTargetVerticalSpeed, isHoverMode, isLandingMode)
	if isHoverMode then
		FlightManager.state = "FREEZED"
		FlightManager.status_msg = "Hover switch ON: Holding station in FREEZED."
		return
	end
	if not NavSystem.is_target_loaded then
		FlightManager.state = "HOVER"
		FlightManager.status_msg = "No target: Holding hover."
		return
	end

	Hardware.setGyroStiffness(15, 15)

	local computedThrottle, currentVy = FlightManager.computeThrottle(cruiseTargetVerticalSpeed or 0.0, dt, 1.0, false)
	Hardware.applyThrottle(computedThrottle, dt, false)

	local deltaX = NavSystem.target_local_x or 0
	local deltaZ = NavSystem.target_local_z or 0
	local targetDistance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)

	local currentVx = NavSystem.vel.x or 0
	local currentVz = NavSystem.vel.z or 0
	local horizontalSpeed = math.sqrt(currentVx * currentVx + currentVz * currentVz)

	local dirX = (targetDistance > 0.05) and (deltaX / targetDistance) or 0.0
	local dirZ = (targetDistance > 0.05) and (deltaZ / targetDistance) or 0.0

	local vForward = currentVx * dirX + currentVz * dirZ
	local vLateral = currentVx * (-dirZ) + currentVz * dirX

	local isLandingRequested = isLandingMode or (FlightManager.manual_landing == true)

	if targetDistance <= 4.0 then
		if horizontalSpeed <= 0.18 then
			FlightManager.pid_vel_x:reset()
			FlightManager.pid_vel_z:reset()
			FlightManager.waypoint_reached = true
			Hardware.setVectorSoft(0, 1, 0, dt)

			if isLandingRequested and not FlightManager.landing_aborted then
				FlightManager.state = "LANDING"
				FlightManager.touchdown_timer = 0.0
				FlightManager.landing_time_in_state = 0.0
				FlightManager.landing_start_y = NavSystem.pos.y
				FlightManager.landing_has_descended = false
				FlightManager.landing_retry_count = 0
				FlightManager.status_msg = "Arrived at pad: Commencing descent to land."
			else
				FlightManager.state = "HOVER"
				FlightManager.status_msg = "Arrived at target: Station locked in HOVER."
			end
			return
		else
			local brakeTiltX = MathUtil.clamp(-currentVx * 2.0, -1.2, 1.2)
			local brakeTiltZ = MathUtil.clamp(-currentVz * 2.0, -1.2, 1.2)
			Hardware.setTiltVector(brakeTiltX, brakeTiltZ, 1.2, dt)
			FlightManager.status_msg = string.format("APPROACH DOCK (Dist:%.1fm, Spd:%.2fm/s). Braking to settle.", targetDistance, horizontalSpeed)
			return
		end
	end

	local desiredSpeed = 0.20
	if targetDistance > 30.0 then
		desiredSpeed = 1.5
	elseif targetDistance > 15.0 then
		desiredSpeed = 1.0
	elseif targetDistance > 6.0 then
		desiredSpeed = 0.5
	end

	local speedError = desiredSpeed - vForward
	local steerTilt = 0.0
	if speedError >= 0 then
		steerTilt = MathUtil.clamp(speedError * 1.5, 0.0, 1.8)
	else
		steerTilt = MathUtil.clamp(speedError * 2.0, -2.5, 0.0)
	end

	local lateralTilt = 0.0
	if math.abs(vLateral) > 0.05 then
		lateralTilt = MathUtil.clamp(-vLateral * 1.8, -1.2, 1.2)
	end

	local tiltX = dirX * steerTilt + (-dirZ) * lateralTilt
	local tiltZ = dirZ * steerTilt + (dirX) * lateralTilt

	local maxTiltLimit = (targetDistance > 20.0) and 2.5 or 1.5
	local totalTilt, _ = Hardware.setTiltVector(tiltX, tiltZ, maxTiltLimit, dt)

	local brakingDistance = MathUtil.computeBrakingDistance(horizontalSpeed)
	if targetDistance > math.max(CONFIG.LIMITS.APPROACH_MIN_DISTANCE or 45.0, brakingDistance * 1.5) then
		FlightManager.state = "CRUISE"
		FlightManager.status_msg = string.format("Far from target (Dist: %.1fm). Engaging cruise.", targetDistance)
	else
		FlightManager.status_msg = string.format("APPROACH (Dist:%.1fm, Spd:%.2f/%.2fm/s, Tilt:%.1f*, Vy:%.1f)", targetDistance, vForward, desiredSpeed, totalTilt, currentVy)
	end
end

function FlightManager.updateHover(dt, cruiseTargetVerticalSpeed, effectiveTargetAlt, errorAltitude, isHoverMode, isLandingMode)
	Hardware.setGyroStiffness(15, 15)

	local currentY = NavSystem.pos.y or 0
	local startY = FlightManager.liftoff_start_y or currentY

	if currentY >= (startY + 1.2) then
		FlightManager.is_airborne = true
	end

	local deltaX = NavSystem.target_local_x or 0
	local deltaZ = NavSystem.target_local_z or 0
	local targetDistance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)

	local velocityX = NavSystem.vel.x or 0
	local velocityZ = NavSystem.vel.z or 0
	local horizontalSpeed = math.sqrt(velocityX * velocityX + velocityZ * velocityZ)

	local targetVelocityX = 0.0
	local targetVelocityZ = 0.0

	local errorVelocityX = targetVelocityX - velocityX
	local errorVelocityZ = targetVelocityZ - velocityZ
	local errorSpeed = math.sqrt(errorVelocityX * errorVelocityX + errorVelocityZ * errorVelocityZ)

	local deadband = CONFIG.LIMITS.ALT_DEADBAND or 0.5
	local isAdjustingAltitude = math.abs(errorAltitude) > deadband or math.abs(cruiseTargetVerticalSpeed) > 0.10

	if not isAdjustingAltitude and errorSpeed > 0.15 then
		local brakeTiltX = MathUtil.clamp(errorVelocityX * 1.0, -0.8, 0.8)
		local brakeTiltZ = MathUtil.clamp(errorVelocityZ * 1.0, -0.8, 0.8)
		Hardware.setTiltVector(brakeTiltX, brakeTiltZ, 0.8, dt)
	else
		Hardware.setVectorSoft(0, 1, 0, dt)
		FlightManager.pid_vel_x:reset()
		FlightManager.pid_vel_z:reset()
	end

	local isClimbingInHover = (errorAltitude > 0.8)
	local computedThrottle, _ = FlightManager.computeThrottle(cruiseTargetVerticalSpeed, dt, 1.0, isClimbingInHover)
	Hardware.applyThrottle(computedThrottle, dt, false)

	local currentPitch = NavSystem.attitude.pitch or 0
	local currentRoll = NavSystem.attitude.roll or 0
	local restingTilt = math.max(math.abs(currentPitch), math.abs(currentRoll))
	local isWalkableAttitude = restingTilt <= (CONFIG.LIMITS.MAX_RESTING_TILT or 25.0)
	local isStationary = FlightManager.isStationary(0.12)

	if isStationary then
		FlightManager.divergence_alarm = false
		FlightManager.divergence_timer = 0.0
	end

	local isLandingRequested = isLandingMode or (FlightManager.manual_landing == true)

	local nominalHover = FlightManager.hover_throttle or (CONFIG.LIMITS.NOMINAL_HOVER or 0.025)
	local isGroundedInHover = isStationary and isWalkableAttitude and (isLandingRequested or ((errorAltitude <= 1.5) and (computedThrottle <= (nominalHover + 0.015))))
	if FlightManager.processTouchdown(dt, isGroundedInHover, restingTilt, NavSystem.getTargetKey(), targetDistance) then
		FlightManager.manual_landing = false
		return
	end

	if isHoverMode then
		FlightManager.state = "FREEZED"
		FlightManager.status_msg = string.format("FREEZED (Y:%.1f, Alt:%.0fm). Holding station.", currentY, effectiveTargetAlt)
		return
	elseif not NavSystem.is_target_loaded then
		FlightManager.status_msg = string.format("HOVER (Y:%.1f, Alt:%.0fm). Holding altitude. Enter target.", currentY, effectiveTargetAlt)
	end

	if not isLandingMode and not FlightManager.manual_landing then
		FlightManager.landing_aborted = false
	end

	local hoverRadius = CONFIG.LIMITS.HOVER_RADIUS or 5.0
	if targetDistance <= (hoverRadius + 1.0) then
		FlightManager.waypoint_reached = true
	end

	if isLandingRequested and not FlightManager.landing_aborted then
		if targetDistance <= 6.0 and horizontalSpeed <= 0.35 then
			FlightManager.state = "LANDING"
			FlightManager.touchdown_timer = 0.0
			FlightManager.landing_time_in_state = 0.0
			FlightManager.landing_start_y = NavSystem.pos.y
			FlightManager.landing_has_descended = false
			FlightManager.landing_retry_count = 0
			FlightManager.status_msg = isLandingMode and "Landing switch ON: Commencing descent to pad." or "Landing engaged: Commencing descent to pad."
			FlightManager.pid_vel_x:reset()
			FlightManager.pid_vel_z:reset()
			return
		elseif targetDistance > 6.0 then
			FlightManager.state = "APPROACH"
			FlightManager.status_msg = "Landing active: Navigating approach to pad."
			FlightManager.pid_vel_x:reset()
			FlightManager.pid_vel_z:reset()
			return
		end
	else
		local hasDistantTarget = (not isHoverMode) and NavSystem.is_target_loaded and (targetDistance > (hoverRadius + 1.0)) and not FlightManager.divergence_alarm
		if hasDistantTarget then
			if errorAltitude > 3.0 then
				FlightManager.state = "CLIMB"
				Hardware.clearVector()
				Hardware.setGyroStiffness(15, 15)
				FlightManager.status_msg = string.format("CLIMB to target altitude (Y:%.1f -> %.0fm). Pure vertical ascent.", currentY, effectiveTargetAlt)
				return
			end
			local brakingDistance = MathUtil.computeBrakingDistance(horizontalSpeed)
			if targetDistance <= brakingDistance then
				FlightManager.state = "APPROACH"
				FlightManager.pid_vel_x:reset()
				FlightManager.pid_vel_z:reset()
				FlightManager.status_msg = "Target in approach range. Entering APPROACH."
			else
				FlightManager.planToTarget()
			end
			return
		end
	end

	local alarmTag = FlightManager.divergence_alarm and " [INVALID]" or ""
	local hoverType = FlightManager.override_hover_alt and "TILT-HOLD" or "STATION"
	if math.abs(errorAltitude) > 1.5 then
		local directionTag = (errorAltitude > 0) and "CLIMB" or "DESC"
		FlightManager.status_msg = string.format("HOVER %s: Y=%.1f->%.0fm (Vy=%.1f)", directionTag, NavSystem.pos.y, effectiveTargetAlt, NavSystem.vel.y or 0)
	else
		FlightManager.status_msg = string.format("%s HOVER%s (Y:%.1f Drift:%.2fm/s)", hoverType, alarmTag, NavSystem.pos.y, horizontalSpeed)
	end
end

function FlightManager.updateLanding(dt, isLandingMode, isHoverMode)
	local targetKey = NavSystem.getTargetKey()
	local knownPadY = NavSystem.getTargetPadAltitude()
	local currentGroundY = FlightManager.liftoff_start_y or NavSystem.pos.y or 64.0
	local targetLandingAltitude = knownPadY or currentGroundY
	local isLandingRequested = (isLandingMode or (FlightManager.manual_landing == true)) and not isHoverMode

	if not isLandingRequested then
		FlightManager.manual_landing = false
		FlightManager.state = "HOVER"
		FlightManager.status_msg = "Landing aborted to hover."
		return
	end

	local deltaX = NavSystem.target_local_x or 0
	local deltaZ = NavSystem.target_local_z or 0
	local targetDistance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)

	if NavSystem.is_target_loaded and (targetDistance > 6.0) then
		FlightManager.state = "APPROACH"
		FlightManager.landing_has_descended = false
		FlightManager.touchdown_timer = 0.0
		FlightManager.status_msg = string.format("OFF-PAD DISPLACEMENT (Dist: %.1fm > 6m)! Re-approaching pad.", targetDistance)
		return
	end

	local heightRemaining = math.max(0.0, (NavSystem.pos.y or 64.0) - targetLandingAltitude)

	Hardware.setGyroStiffness(15, 15)
	Hardware.setVectorSoft(0, 1, 0, dt)
	FlightManager.pid_vel_x:reset()
	FlightManager.pid_vel_z:reset()

	local currentPitch = NavSystem.attitude.pitch or 0
	local currentRoll = NavSystem.attitude.roll or 0

	local landingStartY = FlightManager.landing_start_y or NavSystem.pos.y
	local verticalDescentDistance = landingStartY - NavSystem.pos.y
	local currentVy = NavSystem.vel.y or 0
	FlightManager.landing_time_in_state = (FlightManager.landing_time_in_state or 0) + dt

	local isNearPad = (heightRemaining <= 1.5)
	if verticalDescentDistance >= 0.4 or currentVy < -0.20 or isNearPad or (FlightManager.landing_time_in_state >= 1.5) then
		FlightManager.landing_has_descended = true
	end

	local isStationary = FlightManager.isStationary(0.12)
	local restingTilt = math.max(math.abs(currentPitch), math.abs(currentRoll))
	local maxRestingTilt = CONFIG.LIMITS.MAX_RESTING_TILT or 25.0
	local isWalkableAttitude = restingTilt <= maxRestingTilt

	local maxSafeLandingTilt = 12.0
	if restingTilt > maxSafeLandingTilt then
		local lastTilt = FlightManager.last_landing_tilt or restingTilt
		FlightManager.last_landing_tilt = restingTilt
		if restingTilt > (lastTilt + 0.8) then
			FlightManager.landing_retry_count = (FlightManager.landing_retry_count or 0) + 1
			FlightManager.override_hover_alt = NavSystem.pos.y + 4.0
			FlightManager.landing_has_descended = false
			FlightManager.touchdown_timer = 0.0
			if FlightManager.landing_retry_count <= 2 then
				FlightManager.state = "HOVER"
				FlightManager.status_msg = string.format("STEEP TILT INCREASING (%.1f*): Climb +4m, retry landing (%d/2).", restingTilt, FlightManager.landing_retry_count)
			else
				FlightManager.state = "HOVER"
				FlightManager.landing_aborted = true
				FlightManager.manual_landing = false
				FlightManager.status_msg = string.format("LANDING ABORTED: Ground slope too steep (%.1f*). Holding safe HOVER.", restingTilt)
			end
			return
		end
	else
		FlightManager.last_landing_tilt = restingTilt
	end

	if FlightManager.landing_has_descended and isStationary and isWalkableAttitude then
		if FlightManager.processTouchdown(dt, true, restingTilt, targetKey, targetDistance) then
			FlightManager.manual_landing = false
			return
		end
	else
		FlightManager.touchdown_timer = 0.0
	end

	local descentVerticalSpeed = -0.75
	local padInfoString = ""
	local effectiveRemaining = heightRemaining

	if effectiveRemaining > 20.0 then
		descentVerticalSpeed = -MathUtil.clamp(effectiveRemaining * 0.12, 2.0, 3.2)
	elseif effectiveRemaining > 6.0 then
		descentVerticalSpeed = -MathUtil.clamp(math.sqrt(0.36 + 2.0 * 0.45 * (effectiveRemaining - 1.0)), 1.0, 2.2)
	elseif effectiveRemaining > 1.2 then
		descentVerticalSpeed = -MathUtil.clamp(math.sqrt(0.04 + 2.0 * 0.40 * effectiveRemaining), 0.35, 1.1)
	else
		descentVerticalSpeed = -0.22
	end

	if knownPadY then
		padInfoString = string.format(" [PAD Y:%.1f, Rem:%.1fm]", knownPadY, effectiveRemaining)
	else
		padInfoString = string.format(" [EST Y:%.1f, Rem:%.1fm]", targetLandingAltitude, effectiveRemaining)
	end

	local nominalHover = FlightManager.hover_throttle or CONFIG.LIMITS.NOMINAL_HOVER or 0.025
	local landingThrottleCap = math.min(Hardware.throttle_ceiling or CONFIG.LIMITS.MAX_THROTTLE, nominalHover * 1.30)
	local computedThrottle, currentVy = FlightManager.computeThrottle(descentVerticalSpeed, dt, 1.0, false, landingThrottleCap)
	Hardware.applyThrottle(computedThrottle, dt, false)
	FlightManager.status_msg = string.format("LAND: Vy=%.1f/%.1fm/s | Dist:%.1fm%s", currentVy, descentVerticalSpeed, targetDistance, padInfoString)
end

function FlightManager.updateManual(dt)
	local commandForward = 0
	local commandRight = 0
	if Hardware.active_keys[87] then commandForward = commandForward + 1 end
	if Hardware.active_keys[83] then commandForward = commandForward - 1 end
	if Hardware.active_keys[68] then commandRight = commandRight + 1 end
	if Hardware.active_keys[65] then commandRight = commandRight - 1 end

	local isVerticalActive = Hardware.active_keys[32]
		or Hardware.active_keys[340] or Hardware.active_keys[344]
	local hasManualInput = (commandForward ~= 0 or commandRight ~= 0) or isVerticalActive

	if hasManualInput then
		FlightManager.manual_inactivity_timer = 0.0
	else
		FlightManager.manual_inactivity_timer = (FlightManager.manual_inactivity_timer or 0.0) + (dt or CONFIG.TICK_RATE)
		if FlightManager.manual_inactivity_timer >= 60.0 then
			FlightManager.state = "HOVER"
			FlightManager.target_alt = NavSystem.pos.y
			FlightManager.status_msg = "Manual timeout (60s inactivity): Ship locked in HOVER."
			FlightManager.manual_inactivity_timer = 0.0
			FlightManager.pid_vel_x:reset()
			FlightManager.pid_vel_z:reset()
			Hardware.setGyroStiffness(0, 0)
			Hardware.clearVector()
			return
		end
	end

	local isCtrlHeld = (Hardware.active_keys[341] or Hardware.active_keys[345]) and true or false
	local normalY = 1.0

	if commandForward ~= 0 or commandRight ~= 0 then
		Hardware.setGyroStiffness(15, 15)

		local length = math.sqrt(commandRight * commandRight + commandForward * commandForward)
		local manualMaxTilt = isCtrlHeld and 12.0 or 8.0
		local tiltX = (commandRight / length) * manualMaxTilt
		local tiltZ = (commandForward / length) * manualMaxTilt

		_, normalY = Hardware.setTiltVector(tiltX, tiltZ, manualMaxTilt, dt)
	else
		Hardware.setGyroStiffness(0, 0)
		FlightManager.pid_vel_x:reset()
		FlightManager.pid_vel_z:reset()
		Hardware.setVectorSoft(0, 1, 0, dt)
	end

	local computedThrottle = 0
	if Hardware.inversion then
		if Hardware.active_keys[32] then
			computedThrottle = isCtrlHeld and 0.35 or 0.25
		elseif Hardware.active_keys[340] or Hardware.active_keys[344] then
			computedThrottle = isCtrlHeld and 0.08 or 0.05
		elseif commandForward ~= 0 or commandRight ~= 0 then
			computedThrottle = isCtrlHeld and 0.22 or 0.16
		else
			computedThrottle = isCtrlHeld and 0.15 or 0.11
		end
	else
		local manualTargetVerticalSpeed = 0.0
		local climbRate = isCtrlHeld and 5.5 or 2.5
		local descentRate = isCtrlHeld and -5.5 or -2.5

		if Hardware.active_keys[32] then
			manualTargetVerticalSpeed = climbRate
			FlightManager.hold_alt = NavSystem.pos.y + (isCtrlHeld and 1.5 or 0.5)
		elseif Hardware.active_keys[340] or Hardware.active_keys[344] then
			manualTargetVerticalSpeed = descentRate
			FlightManager.hold_alt = NavSystem.pos.y - (isCtrlHeld and 1.5 or 0.5)
		else
			if not FlightManager.hold_alt then
				FlightManager.hold_alt = NavSystem.pos.y
			end
			if commandForward ~= 0 or commandRight ~= 0 then
				local tiltCompensation = (1.0 - normalY) * 1.5
				FlightManager.hold_alt = math.min(FlightManager.hold_alt, NavSystem.pos.y + tiltCompensation + 0.3)
				manualTargetVerticalSpeed = 0.0
			else
				local altitudeDifference = FlightManager.hold_alt - NavSystem.pos.y
				manualTargetVerticalSpeed = MathUtil.clamp(altitudeDifference * 0.5, -1.5, 1.5)
			end
		end

		local compThrot, _ = FlightManager.computeThrottle(manualTargetVerticalSpeed, dt, normalY, false)
		computedThrottle = compThrot
	end

	Hardware.applyThrottle(computedThrottle, dt, false)

	local currentPitch = NavSystem.attitude.pitch or 0
	local currentRoll = NavSystem.attitude.roll or 0
	local restingTilt = math.max(math.abs(currentPitch), math.abs(currentRoll))
	local isWalkableAttitude = restingTilt <= (CONFIG.LIMITS.MAX_RESTING_TILT or 25.0)
	local isStationary = FlightManager.isStationary(0.12)
	local _, isLandingMode = Hardware.readLevers()
	local wantsManualTouchdown = isStationary and isWalkableAttitude and (isLandingMode or (Hardware.active_keys[340] or Hardware.active_keys[344]))
	if wantsManualTouchdown and FlightManager.processTouchdown(dt, true, restingTilt, NavSystem.getTargetKey(), NavSystem.target_dHoriz) then
		FlightManager.manual_landing = false
		return
	end

	local speed = math.sqrt((NavSystem.vel.x or 0)^2 + (NavSystem.vel.z or 0)^2)
	local reverseTag = Hardware.inversion and " [REV-HOLD]" or ""
	local modeTag = (commandForward ~= 0 or commandRight ~= 0) and "THRUST" or "DRIFT"
	local lockSeconds = math.max(0, math.floor(60.0 - (FlightManager.manual_inactivity_timer or 0.0)))
	FlightManager.status_msg = string.format("MANUAL [%s]%s (Spd: %.1fm/s, Alt: %.1fm, Lock:%ds)", modeTag, reverseTag, speed, NavSystem.pos.y, lockSeconds)
end

function FlightManager.update(dt)
	local altFloorSetting, isLandingMode, isHoverMode, _, isFlatDeck, _, allowedTiltLimit = Hardware.readLevers()

	local currentTargetKey = NavSystem.getTargetKey()
	local targetJustChanged = (currentTargetKey ~= nil and currentTargetKey ~= FlightManager.last_target_key)
	FlightManager.last_target_key = currentTargetKey
	if targetJustChanged then
		FlightManager.override_hover_alt = nil
		FlightManager.waypoint_reached = false
		if FlightManager.state ~= "PARKED" and FlightManager.state ~= "MANUAL" then
			FlightManager.planToTarget()
		end
	end

	local isStalled = false
	for _, transmission in ipairs(Hardware.transmissions) do
		if transmission.isOverstressed and transmission.isOverstressed() then
			isStalled = true
			break
		end
	end
	if not isStalled then
		for _, bearing in ipairs(Hardware.bearings) do
			if bearing.isOverstressed and bearing.isOverstressed() then
				isStalled = true
				break
			end
		end
	end

	if isStalled then
		local currentThrottle = Hardware.throttle_actual or 0.35
		Hardware.throttle_ceiling = math.max(0.18, math.min(Hardware.throttle_ceiling or CONFIG.LIMITS.MAX_THROTTLE, currentThrottle - 0.03))
		Hardware.applyThrottle(Hardware.throttle_ceiling * 0.70, dt, true)
		FlightManager.status_msg = string.format("OVERSTRESS: Throttle capped to %.1f%%", (Hardware.throttle_ceiling or 0) * 100)
		FlightManager.overstress_timer = 4.0
		return
	end

	if (FlightManager.overstress_timer or 0) > 0 then
		FlightManager.overstress_timer = FlightManager.overstress_timer - dt
	elseif (Hardware.throttle_ceiling or 0) < CONFIG.LIMITS.MAX_THROTTLE then
		Hardware.throttle_ceiling = math.min(CONFIG.LIMITS.MAX_THROTTLE, Hardware.throttle_ceiling + 0.005 * dt)
	end

	if Security.is_locked then
		Hardware.typewriter_keys = {}
		if FlightManager.state == "MANUAL" then
			FlightManager.state = "HOVER"
			FlightManager.status_msg = "Security lock engaged: Stabilized in HOVER."
		end
	elseif Hardware.typewriter then
		local ok, pressedKeyCodes = pcall(Hardware.typewriter.getPressedKeyCodes)
		if ok and type(pressedKeyCodes) == "table" then
			local heldKeySet = {}
			for _, keyCode in ipairs(pressedKeyCodes) do
				heldKeySet[keyCode] = true
				if not Hardware.typewriter_keys[keyCode] then
					if keyCode == 77 or keyCode == 109 then
						if FlightManager.state == "MANUAL" then
							FlightManager.planToTarget()
							FlightManager.status_msg = "Typewriter: Autopilot resumed."
						else
							FlightManager.prev_state = FlightManager.state
							FlightManager.state = "MANUAL"
							FlightManager.manual_landing = false
							FlightManager.landing_aborted = true
							FlightManager.hold_alt = NavSystem.pos.y
							FlightManager.is_grounded = false
							FlightManager.divergence_alarm = false
							FlightManager.divergence_timer = 0.0
							FlightManager.status_msg = "Typewriter: MANUAL mode engaged [M]"
						end
					elseif keyCode == 72 or keyCode == 104 then
						FlightManager.override_hover_alt = nil
						FlightManager.landing_aborted = true
						FlightManager.manual_landing = false
						FlightManager.state = "HOVER"
						local altFloor, _ = Hardware.readLevers()
						FlightManager.target_alt = altFloor
						FlightManager.status_msg = string.format("Typewriter: Leveling to floor altitude (%.0fm) [H]", altFloor)
					elseif keyCode == 76 or keyCode == 108 then
						FlightManager.state = "LANDING"
						FlightManager.manual_landing = true
						FlightManager.baseline_pitch = NavSystem.attitude.pitch or 0
						FlightManager.baseline_roll = NavSystem.attitude.roll or 0
						FlightManager.touchdown_timer = 0.0
						FlightManager.status_msg = "Typewriter: Landing sequence engaged [L]"
					elseif keyCode == 259 or keyCode == 8 then
						FlightManager.manual_landing = false
						FlightManager.state = "PARKED"
						FlightManager.status_msg = "Typewriter: Emergency engine cutoff [Backspace]"
						Hardware.applyThrottle(0, dt, true)
						Hardware.clearVector()
					end
				end
				Hardware.typewriter_keys[keyCode] = true
				Hardware.active_keys[keyCode] = true
			end
			for keyCode, _ in pairs(Hardware.typewriter_keys) do
				if not heldKeySet[keyCode] then
					Hardware.typewriter_keys[keyCode] = nil
					Hardware.active_keys[keyCode] = nil
				end
			end
		end
	end

	local hasFlightKeys = Hardware.active_keys[87] or Hardware.active_keys[83]
	                   or Hardware.active_keys[65] or Hardware.active_keys[68]
	                   or Hardware.active_keys[32] or Hardware.active_keys[340] or Hardware.active_keys[344]
	                   or Hardware.active_keys[342] or Hardware.active_keys[346]
	                   or Hardware.active_keys[56] or Hardware.active_keys[184]

	if hasFlightKeys and FlightManager.state ~= "MANUAL" then
		FlightManager.prev_state = FlightManager.state
		FlightManager.state = "MANUAL"
		FlightManager.manual_landing = false
		FlightManager.landing_aborted = true
		FlightManager.hold_alt = NavSystem.pos.y
		FlightManager.is_grounded = false
		FlightManager.divergence_alarm = false
		FlightManager.divergence_timer = 0.0
		FlightManager.status_msg = "MANUAL flight takeover via typewriter controls."
	end

	local isAltHeld = (Hardware.active_keys[342] or Hardware.active_keys[346]
	                   or Hardware.active_keys[56] or Hardware.active_keys[184]) and true or false
	local isReverseActive = isAltHeld
	if FlightManager.state == "PARKED" then
		isReverseActive = false
	end
	Hardware.setInversion(isReverseActive)

	local pitchTilt = math.abs(NavSystem.attitude.pitch or 0)
	local rollTilt = math.abs(NavSystem.attitude.roll or 0)
	local maxAttitudeTilt = math.max(pitchTilt, rollTilt)
	if maxAttitudeTilt > 55.0 and FlightManager.state ~= "PARKED" then
		Hardware.setGyroStiffness(0, 0)
		Hardware.clearVector()
		if not isReverseActive then
			FlightManager.status_msg = string.format("ANTI-CAPSIZE LOCK (Tilt: %.1f*)", maxAttitudeTilt)
		end
	end

	local currentPressure = NavSystem.pressure or 1.0

	if FlightManager.last_alt_floor and math.abs(altFloorSetting - FlightManager.last_alt_floor) > 1.5 then
		FlightManager.override_hover_alt = nil
	end
	FlightManager.last_alt_floor = altFloorSetting

	local knownTargetPadY = NavSystem.getTargetPadAltitude()
	local currentGroundY = FlightManager.liftoff_start_y or NavSystem.pos.y or 64.0
	local targetPadAlt = knownTargetPadY or currentGroundY
	local isLandingRequested = isLandingMode or (FlightManager.manual_landing == true)

	local effectiveTargetAlt = FlightManager.override_hover_alt or altFloorSetting
	if not FlightManager.is_airborne and (FlightManager.state == "HOVER" or FlightManager.state == "CRUISE" or FlightManager.state == "CLIMB") then
		local minLiftoffAlt = (FlightManager.liftoff_start_y or NavSystem.pos.y) + 5.0
		effectiveTargetAlt = math.max(effectiveTargetAlt, minLiftoffAlt)
	end
	if isLandingRequested then
		if FlightManager.state == "LANDING" then
			effectiveTargetAlt = targetPadAlt
		elseif FlightManager.state == "APPROACH" or FlightManager.state == "HOVER" then
			effectiveTargetAlt = targetPadAlt + 4.0
		else
			effectiveTargetAlt = math.max(effectiveTargetAlt, targetPadAlt + 4.0)
		end
	elseif knownTargetPadY and NavSystem.is_target_loaded and (FlightManager.state == "CRUISE" or FlightManager.state == "APPROACH") then
		if altFloorSetting < (knownTargetPadY + 4.0) then
			effectiveTargetAlt = math.max(effectiveTargetAlt, knownTargetPadY + 4.0)
		end
	end
	FlightManager.target_alt = effectiveTargetAlt
	local errorAltitude = effectiveTargetAlt - NavSystem.pos.y
	local maxClimb = (CONFIG.LIMITS.MAX_CLIMB_SPEED or 3.5) * MathUtil.clamp((currentPressure - 0.10) / 0.30, 0.40, 1.0)
	local cruiseTargetVerticalSpeed = 0.0

	local deadband = CONFIG.LIMITS.ALT_DEADBAND or 0.5
	if math.abs(errorAltitude) <= deadband then
		cruiseTargetVerticalSpeed = 0.0
	elseif errorAltitude < -deadband then
		local excess = math.abs(errorAltitude) - deadband
		local maxDescent = CONFIG.LIMITS.MAX_DESCENT_SPEED or 1.5
		cruiseTargetVerticalSpeed = -math.min(maxDescent, math.sqrt(2.0 * 0.50 * excess))
	else
		local excess = errorAltitude - deadband
		cruiseTargetVerticalSpeed = math.min(maxClimb, math.sqrt(2.0 * 0.80 * excess))
	end

	local maxAllowedTilt = math.min(CONFIG.LIMITS.MAX_CONE_ANGLE or 12.0, allowedTiltLimit or 12.0)
	local cruiseMaxTilt = maxAllowedTilt
	if currentPressure < 0.10 then
		cruiseMaxTilt = math.max(6.0, cruiseMaxTilt * (currentPressure / 0.10))
	end
	if errorAltitude > 15.0 then
		cruiseMaxTilt = math.max(4.0, cruiseMaxTilt * 0.50)
	end

	if NavSystem.is_target_loaded and (FlightManager.state == "CRUISE" or FlightManager.state == "APPROACH") then
		local currentDistance = NavSystem.target_dHoriz or 0
		local currentVx = NavSystem.vel.x or 0
		local currentVz = NavSystem.vel.z or 0
		local horizontalSpeed = math.sqrt(currentVx * currentVx + currentVz * currentVz)

		local hoverRadius = CONFIG.LIMITS.HOVER_RADIUS or 4.0
		if currentDistance > (hoverRadius + 4.0) and horizontalSpeed >= 2.0 then
			FlightManager.dist_sample_timer = (FlightManager.dist_sample_timer or 0) + dt
			if FlightManager.dist_sample_timer >= 1.0 then
				FlightManager.dist_sample_timer = 0.0
				local lastDistance = FlightManager.last_dist_sample or currentDistance
				local deltaDistance = currentDistance - lastDistance
				FlightManager.last_dist_sample = currentDistance

				if deltaDistance > 0.5 then
					local commandX = Hardware.current_vector[1] or 0
					local commandZ = Hardware.current_vector[3] or 0
					local targetX = NavSystem.target_local_x or 0
					local targetZ = NavSystem.target_local_z or 0
					local targetLength = math.sqrt(targetX * targetX + targetZ * targetZ)
					local directionX = (targetLength > 0.05) and (targetX / targetLength) or 0
					local directionZ = (targetLength > 0.05) and (targetZ / targetLength) or 0
					local thrustDot = commandX * directionX + commandZ * directionZ

					FlightManager.divergence_timer = (FlightManager.divergence_timer or 0) + 1.0

					if FlightManager.divergence_timer >= 15.0 then
						FlightManager.state = "HOVER"
						Hardware.clearVector()
						if thrustDot > 0.01 then
							FlightManager.status_msg = string.format("EXTERNAL DRAG/COLLISION (+%.1fm in 15s): Disengaging to HOVER.", currentDistance - lastDistance)
							FlightManager.divergence_timer = 0.0
						else
							FlightManager.divergence_alarm = true
							FlightManager.status_msg = string.format("DIVERGENCE ALARM: Thrust away from target! Aborted to HOVER.")
						end
					end
				elseif deltaDistance < -0.3 then
					FlightManager.divergence_timer = math.max(0.0, (FlightManager.divergence_timer or 0) - 2.0)
					if FlightManager.divergence_timer == 0.0 then
						FlightManager.divergence_alarm = false
					end
				end
			end
		else
			FlightManager.dist_sample_timer = 0.0
			FlightManager.last_dist_sample = currentDistance
		end
	else
		FlightManager.divergence_timer = 0.0
		FlightManager.dist_sample_timer = 0.0
		FlightManager.last_dist_sample = nil
	end

	if isHoverMode and FlightManager.state ~= "PARKED" and FlightManager.state ~= "MANUAL" and FlightManager.state ~= "FREEZED" then
		FlightManager.state = "FREEZED"
		FlightManager.target_alt = NavSystem.pos.y
		FlightManager.pid_vel_x:reset()
		FlightManager.pid_vel_z:reset()
		Hardware.clearVector()
		Hardware.setGyroStiffness(15, 15)
		FlightManager.status_msg = string.format("Hover switch ON: Station locked in FREEZED at Y=%.1f.", NavSystem.pos.y)
	end

	if FlightManager.state == "PARKED" then
		FlightManager.updateParked(dt, effectiveTargetAlt, isLandingMode, isHoverMode, targetJustChanged)

	elseif FlightManager.state == "CLIMB" then
		FlightManager.updateClimb(dt, effectiveTargetAlt, cruiseTargetVerticalSpeed, isLandingMode, isHoverMode)

	elseif FlightManager.state == "FREEZED" then
		FlightManager.updateFreezed(dt, isHoverMode)

	elseif FlightManager.state == "CRUISE" then
		FlightManager.updateCruise(dt, cruiseTargetVerticalSpeed, cruiseMaxTilt, isHoverMode, isFlatDeck)

	elseif FlightManager.state == "APPROACH" then
		FlightManager.updateApproach(dt, cruiseTargetVerticalSpeed, isHoverMode, isLandingMode)

	elseif FlightManager.state == "HOVER" then
		FlightManager.updateHover(dt, cruiseTargetVerticalSpeed, effectiveTargetAlt, errorAltitude, isHoverMode, isLandingMode)

	elseif FlightManager.state == "LANDING" then
		FlightManager.updateLanding(dt, isLandingMode, isHoverMode)

	elseif FlightManager.state == "MANUAL" then
		FlightManager.updateManual(dt)
	end

	FlightLogger.update(dt, cruiseTargetVerticalSpeed)
end

local function renderDashboard()
	term.clear()
	term.setCursorPos(1, 1)

	local altFloorSetting, isLandingMode, isHoverMode, speedLevel, isFlatDeck = Hardware.readLevers()
	local modeString = (FlightManager.state == "MANUAL") and "MAN " or (isLandingMode and "LAND" or (isHoverMode and "HOV " or "FLY "))

	print("==========[ AUTOPILOT CC:TWEAKED ]==========")
	if FlightManager.divergence_alarm then
		print("STATE: [HOVER   ] | ALARM:[INVALID DIRECTION >15s]")
	else
		print(string.format("STATE: [%-8s] | MODE:[%-4s] | SRC:[%-7s]", FlightManager.state, modeString, NavSystem.target_source))
	end
	print("STATUS: " .. tostring(FlightManager.status_msg or ""))
	print("------------------------------------------------")

	if NavSystem.has_spawn_gps then
		print(string.format("GPS POS: X:%-7.1f Y:%-6.1f Z:%-7.1f", NavSystem.pos.x, NavSystem.pos.y, NavSystem.pos.z))
	else
		print(string.format("BARO ALT: Y:%-6.1f | (Spawn GPS Table Offline)", NavSystem.pos.y))
	end

	if NavSystem.is_target_loaded then
		print(string.format("TARGET:  Dist:%-6.1fm | Brg:%-5.1f* | Hdg:%-5.1f*",
			NavSystem.target_dHoriz or 0, NavSystem.target_bearing or 0, NavSystem.heading or 0))
	else
		print(string.format("TARGET:  [NO TARGET - Insert Lodestone or Coords]"))
	end

	print(string.format("SPEEDS:  Vz(Fwd):%-5.2f Vx(Rgt):%-5.2f Vy:%-5.2f m/s",
		NavSystem.vel.z or 0, NavSystem.vel.x or 0, NavSystem.vel.y or 0))

	local currentVx = NavSystem.vel.x or 0
	local currentVz = NavSystem.vel.z or 0
	local horizontalSpeed = math.sqrt(currentVx * currentVx + currentVz * currentVz)
	local speedKmh = horizontalSpeed * 3.6

	local etaString = "---"
	if NavSystem.is_target_loaded and (NavSystem.target_dHoriz or 0) > 0 then
		local targetDistance = NavSystem.target_dHoriz or 0
		if horizontalSpeed >= 0.5 then
			local etaSeconds = targetDistance / horizontalSpeed
			if etaSeconds < 60 then
				etaString = string.format("%ds", math.floor(etaSeconds + 0.5))
			elseif etaSeconds < 3600 then
				local minutes = math.floor(etaSeconds / 60)
				local seconds = math.floor(etaSeconds % 60)
				etaString = string.format("%dm %02ds", minutes, seconds)
			else
				local hours = math.floor(etaSeconds / 3600)
				local minutes = math.floor((etaSeconds % 3600) / 60)
				etaString = string.format("%dh %02dm", hours, minutes)
			end
		elseif targetDistance <= 5.0 then
			etaString = "ARRIVED"
		else
			etaString = "HOLDING"
		end
	end

	print(string.format("FLIGHT:  Spd:%4.1fm/s (%3.0fkm/h) | ETA:%-8s", horizontalSpeed, speedKmh, etaString))
	print(string.format("ATT:     Pitch:%-5.2f* | Roll:%-5.2f* | Pres:%.2f",
		NavSystem.attitude.pitch or 0, NavSystem.attitude.roll or 0, NavSystem.pressure or 1.0))
	print("------------------------------------------------")

	local signalStrings = {}
	for i = 1, math.min(#Hardware.transmissions, 3) do
		local signalValue = (Hardware.cached_signals and Hardware.cached_signals[i]) or 15
		table.insert(signalStrings, string.format("S%d:%02d", i, signalValue))
	end
	local signalLine = table.concat(signalStrings, " ")
	local flatTag = isFlatDeck and " [FLAT]" or ""
	print(string.format("LEVER:   Alt:%-3.0fm | Speed:%2d/15%s | Drive:%4.1f%% (%s Cap:%2.0f%%)",
		altFloorSetting, speedLevel or 15, flatTag, (Hardware.throttle_actual or 0) * 100, signalLine, (Hardware.throttle_ceiling or CONFIG.LIMITS.MAX_THROTTLE) * 100))

	local commandVectorString = "LEVEL (AUTO-GYRO)"
	if not Hardware.vector_cleared and Hardware.last_dispatched_vec then
		commandVectorString = string.format("X:%.2f Y:%.2f Z:%.2f", Hardware.last_dispatched_vec[1], Hardware.last_dispatched_vec[2], Hardware.last_dispatched_vec[3])
	end
	local bearingTilt = 0
	if Hardware.bearings[1] and Hardware.bearings[1].getTiltAngle then
		bearingTilt = Hardware.bearings[1].getTiltAngle() or 0
	end
	local reverseTag = Hardware.inversion and " [REV!]" or ""
	print(string.format("THRUST:  %-20s%s | Tilt:%4.1f*", commandVectorString, reverseTag, bearingTilt))
	if Hardware.last_bearing_err then
		print(string.format("[ERR: %s]", tostring(Hardware.last_bearing_err)))
		if Hardware.bearing_methods_summary and Hardware.bearing_methods_summary ~= "" then
			print(string.format("[METHODS: %s]", tostring(Hardware.bearing_methods_summary)))
		end
	end
end

local function renderNixieTube()
	if not Hardware.nixie_tube then return end

	local width = CONFIG.NIXIE_WIDTH or 10

	if FlightManager.divergence_alarm then
		local formatted = centerText("INVALID", width)
		if Hardware.last_nixie_text ~= formatted then
			Hardware.last_nixie_text = formatted
			pcall(Hardware.nixie_tube.setText, formatted)
		end
		return
	end

	if Security.is_locked and not Security.is_switch_on then
		local text = ""
		if Security.status_msg then
			text = Security.status_msg
		else
			text = Security.blink_state and "PASSWORD" or ""
		end
		local formatted = centerText(text, width)
		if Hardware.last_nixie_text ~= formatted then
			Hardware.last_nixie_text = formatted
			pcall(Hardware.nixie_tube.setText, formatted)
		end
		return
	end

	if JoystickNav.is_dialing then
		local textToDisplay = MathUtil.formatCoordinatesDisplay(JoystickNav.dial_x, JoystickNav.dial_z, width)

		local formatted = centerText(textToDisplay, width)
		if Hardware.last_nixie_text ~= formatted then
			Hardware.last_nixie_text = formatted
			pcall(Hardware.nixie_tube.setText, formatted)
		end
		return
	end

	local currentState = FlightManager.state or "PARKED"

	if currentState == "MANUAL" then
		local currentVx = NavSystem.vel.x or 0
		local currentVz = NavSystem.vel.z or 0
		local horizontalSpeed = math.sqrt(currentVx * currentVx + currentVz * currentVz)
		local roll = NavSystem.attitude.roll or 0

		local textToDisplay = ""
		if width >= 12 then
			textToDisplay = string.format("%.1fM/S %+.1f*", horizontalSpeed, roll)
		elseif width >= 10 then
			textToDisplay = string.format("%.1fMS %+.0f*", horizontalSpeed, roll)
		else
			textToDisplay = string.format("%.0fM %+.0f*", horizontalSpeed, roll)
		end

		local formatted = centerText(textToDisplay, width)
		if Hardware.last_nixie_text ~= formatted then
			Hardware.last_nixie_text = formatted
			pcall(Hardware.nixie_tube.setText, formatted)
		end
		return
	end

	local function formatAltProgression(currentY, targetY, maxWidth)
		maxWidth = maxWidth or 10
		currentY = math.floor((currentY or 0) + 0.5)
		if not targetY then
			return string.format("ALT %dM", currentY)
		end
		targetY = math.floor(targetY + 0.5)
		local textString = string.format("%d->%dM", currentY, targetY)
		if #textString <= maxWidth then return textString end
		textString = string.format("%d>%dM", currentY, targetY)
		if #textString <= maxWidth then return textString end
		textString = string.format("%d>%d", currentY, targetY)
		if #textString <= maxWidth then return textString end
		return string.format("%dM", currentY)
	end

	if not NavSystem.is_target_loaded and currentState == "PARKED" then
		if Hardware.last_nixie_text ~= "" then
			Hardware.last_nixie_text = ""
			pcall(Hardware.nixie_tube.setText, "")
		end
		return
	end
	local textToDisplay = ""

	if currentState == "LANDING" then
		local cycleTime = (os.epoch("utc") / 1000.0) % 4.0
		if cycleTime < 1.2 then
			textToDisplay = "LANDING"
		else
			local currentY = NavSystem.pos.y or 0
			local distanceHoriz = NavSystem.target_dHoriz or 0
			local knownPadY = (NavSystem.is_target_loaded and distanceHoriz <= 6.0) and NavSystem.getTargetPadAltitude() or nil
			if knownPadY and knownPadY >= (currentY - 0.5) then
				knownPadY = nil
			end
			textToDisplay = formatAltProgression(currentY, knownPadY, width)
		end

	elseif currentState == "PARKED" then
		textToDisplay = "PARKED"

	elseif currentState == "FREEZED" then
		textToDisplay = "FREEZED"

	elseif currentState == "CLIMB" then
		local currentY = NavSystem.pos.y or 0
		local targetY = FlightManager.target_alt
		textToDisplay = formatAltProgression(currentY, targetY, width)

	elseif currentState == "HOVER" then
		local currentY = NavSystem.pos.y or 0
		local targetY = FlightManager.target_alt
		local altError = targetY and (targetY - currentY) or 0

		if targetY and math.abs(altError) > 1.5 then
			textToDisplay = formatAltProgression(currentY, targetY, width)
		else
			local name = NavSystem.getTargetName()
			textToDisplay = (name and name ~= "") and name or "HOVER"
		end

	else
		local targetDistance = NavSystem.target_dHoriz or 0
		local horizontalSpeed = math.sqrt((NavSystem.vel.x or 0)^2 + (NavSystem.vel.z or 0)^2)
		local canShowEta = (targetDistance > 5.0) and (horizontalSpeed >= 0.8)

		if canShowEta then
			local cycleTime = (os.epoch("utc") / 1000.0) % 5.0

			if cycleTime < 1.0 then
				local name = NavSystem.getTargetName()
				if name and name ~= "" then
					textToDisplay = name
				elseif NavSystem.target_world_x and NavSystem.target_world_z then
					textToDisplay = MathUtil.formatCoordinatesDisplay(NavSystem.target_world_x, NavSystem.target_world_z, width)
				elseif NavSystem.manual_coord then
					textToDisplay = MathUtil.formatCoordinatesDisplay(NavSystem.manual_coord.x, NavSystem.manual_coord.z, width)
				else
					textToDisplay = "WAYPOINT"
				end

			elseif cycleTime < 4.0 then
				local distString = ""
				if targetDistance < 1000.0 then
					distString = string.format("%.0fM", targetDistance)
				elseif targetDistance < 10000.0 then
					distString = string.format("%.1fKM", targetDistance / 1000.0)
				else
					distString = string.format("%.0fKM", targetDistance / 1000.0)
				end

				local etaSeconds = math.floor(targetDistance / horizontalSpeed + 0.5)
				local minutes = math.floor(etaSeconds / 60)
				local seconds = math.floor(etaSeconds % 60)
				local etaString = ""
				if minutes > 99 then
					etaString = string.format("%dh", math.floor(minutes / 60))
				else
					etaString = string.format("%d:%02d", minutes, seconds)
				end

				local combined = distString .. " " .. etaString
				if #combined > width then
					if string.find(distString, "%.") then
						distString = string.format("%.0fKM", targetDistance / 1000.0)
						combined = distString .. " " .. etaString
					end
					if #combined > width then
						combined = string.sub(combined, 1, width)
					end
				end
				textToDisplay = combined

			else
				if currentState == "CRUISE" then
					textToDisplay = string.format("%.1f M/S", horizontalSpeed)
				else
					textToDisplay = currentState
				end
			end
		else
			local name = NavSystem.getTargetName()
			if name and name ~= "" then
				textToDisplay = name
			else
				textToDisplay = (currentState == "APPROACH") and "APPROACH" or "HOVER"
			end
		end
	end

	local formatted = centerText(textToDisplay, width)
	if Hardware.last_nixie_text ~= formatted then
		Hardware.last_nixie_text = formatted
		pcall(Hardware.nixie_tube.setText, formatted)
	end
end

local function main()
	if term.setTextScale then
		pcall(term.setTextScale, 0.5)
	end
	term.clear()
	print("Initializing CC: Tweaked Quadrocopter Autopilot...")

	local ok, missing = Hardware.init()
	if not ok then
		print("\nCRITICAL HARDWARE ERROR:")
		print("The following required peripherals were not detected on the network:")
		for _, item in ipairs(missing) do
			print("  - " .. item)
		end
		print("\nPlease ensure all blocks are placed and connected via active Wired Modems.")
		return
	end

	print("Hardware verified. Initializing controllers and sensors...")
	for _ = 1, 4 do
		NavSystem.update()
		os.sleep(0.05)
	end
	NavSystem.update()
	FlightManager.reset(true)

	local hasRelays = false
	for _, name in ipairs(peripheral.getNames()) do
		if peripheral.getType(name) == "redstone_relay" then
			hasRelays = true
			break
		end
	end
	if hasRelays and not CabinControl.hasBindings() then
		CabinControl.calibrateInteractive()
	end

	FlightLogger.init()

	local timerId = os.startTimer(CONFIG.TICK_RATE)
	local lastTime = os.epoch("utc")

	while true do
		local event, param1 = os.pullEvent()

		if event == "timer" and param1 == timerId then
			local now = os.epoch("utc")
			local dt = (now - lastTime) / 1000.0
			lastTime = now
			if dt > 0.20 then dt = CONFIG.TICK_RATE end

			local deltaForward, deltaRight, buttonPressed = Hardware.readJoystick()

			local _, _, _, _, _, isLockSwitch = Hardware.readLevers()

			Security.update(dt, isLockSwitch, deltaForward, deltaRight, buttonPressed)

			JoystickNav.update(dt, deltaForward, deltaRight, buttonPressed)

			NavSystem.update()
			FlightManager.update(dt)

			renderDashboard()
			renderNixieTube()

			timerId = os.startTimer(CONFIG.TICK_RATE)

		elseif event == "key" then
			local keyCode = param1

			if keyCode == 342 or keyCode == 346 or keyCode == 56 or keyCode == 184 then
				Hardware.active_keys[keyCode] = true
			elseif keyCode == keys.w then
				Hardware.active_keys[87] = true
			elseif keyCode == keys.s then
				Hardware.active_keys[83] = true
			elseif keyCode == keys.a then
				Hardware.active_keys[65] = true
			elseif keyCode == keys.d then
				Hardware.active_keys[68] = true
			elseif keyCode == keys.space then
				Hardware.active_keys[32] = true
			elseif keyCode == keys.leftShift or keyCode == keys.rightShift then
				Hardware.active_keys[340] = true
			elseif keyCode == keys.leftCtrl or keyCode == keys.rightCtrl then
				Hardware.active_keys[341] = true
			elseif keyCode == keys.m then
				if not Security.is_locked then
					if FlightManager.state == "MANUAL" then
						FlightManager.planToTarget()
						FlightManager.status_msg = "Manual mode disengaged: Autopilot resumed."
					else
						FlightManager.prev_state = FlightManager.state
						FlightManager.state = "MANUAL"
						FlightManager.manual_landing = false
						FlightManager.landing_aborted = true
						FlightManager.hold_alt = NavSystem.pos.y
						FlightManager.status_msg = "MANUAL mode engaged [M]"
					end
				end
			elseif keyCode == keys.h then
				if not Security.is_locked then
					FlightManager.override_hover_alt = nil
					FlightManager.landing_aborted = true
					FlightManager.manual_landing = false
					FlightManager.state = "HOVER"
					local altFloor, _ = Hardware.readLevers()
					FlightManager.target_alt = altFloor
					FlightManager.status_msg = string.format("Leveling to floor altitude (%.0fm) [H]", altFloor)
				end
			elseif keyCode == keys.l then
				if not Security.is_locked then
					FlightManager.state = "LANDING"
					FlightManager.manual_landing = true
					FlightManager.touchdown_timer = 0.0
					FlightManager.status_msg = "Landing sequence engaged [L]"
				end
			elseif keyCode == keys.backspace then
				if not Security.is_locked then
					FlightManager.manual_landing = false
					FlightManager.state = "PARKED"
					FlightManager.status_msg = "Emergency engine cutoff [Backspace]"
					Hardware.applyThrottle(0, CONFIG.TICK_RATE, true)
					Hardware.clearVector()
				end
			end

			if not Security.is_locked then
				if keyCode == keys.c then
					CabinControl.calibrateInteractive(true)
				elseif keyCode == keys.p then
					Security.setupInteractive()
				end
			end

		elseif event == "key_up" then
			local keyCode = param1
			if keyCode == 342 or keyCode == 346 or keyCode == 56 or keyCode == 184 then
				Hardware.active_keys[keyCode] = nil
			elseif keyCode == keys.w then
				Hardware.active_keys[87] = nil
			elseif keyCode == keys.s then
				Hardware.active_keys[83] = nil
			elseif keyCode == keys.a then
				Hardware.active_keys[65] = nil
			elseif keyCode == keys.d then
				Hardware.active_keys[68] = nil
			elseif keyCode == keys.space then
				Hardware.active_keys[32] = nil
			elseif keyCode == keys.leftShift or keyCode == keys.rightShift then
				Hardware.active_keys[340] = nil
			elseif keyCode == keys.leftCtrl or keyCode == keys.rightCtrl then
				Hardware.active_keys[341] = nil
			end
		end
	end
end

main()
