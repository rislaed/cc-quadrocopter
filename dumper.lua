-- Peripheral Dumper for CC: Tweaked & Create: Avionics / Simulated
-- Automatically discovers peripherals on all sides and wired modems,
-- queries their methods, executes safe getters, and exports dumps to text files.

local function serializeValue(val, depth)
	depth = depth or 0
	if depth > 4 then
		return "..."
	end

	local valType = type(val)
	if valType == "nil" then
		return "nil"
	elseif valType == "boolean" or valType == "number" then
		return tostring(val)
	elseif valType == "string" then
		return string.format("%q", val)
	elseif valType == "table" then
		local indent = string.rep("\t", depth + 1)
		local outerIndent = string.rep("\t", depth)
		local parts = {}
		local isArray = true
		local count = 0

		for k, _ in pairs(val) do
			count = count + 1
			if type(k) ~= "number" or k ~= count then
				isArray = false
			end
		end

		for k, v in pairs(val) do
			local kStr = isArray and "" or (tostring(k) .. " = ")
			table.insert(parts, indent .. kStr .. serializeValue(v, depth + 1))
		end

		if #parts == 0 then
			return "{}"
		end
		return "{\n" .. table.concat(parts, ",\n") .. "\n" .. outerIndent .. "}"
	else
		return "<" .. valType .. ">"
	end
end

local function isSafeGetter(name)
	local lower = string.lower(name)
	if string.sub(lower, 1, 3) == "get" or
	   string.sub(lower, 1, 2) == "is" or
	   string.sub(lower, 1, 3) == "has" or
	   string.sub(lower, 1, 4) == "read" or
	   lower == "status" or
	   lower == "summary" or
	   lower == "dump" or
	   lower == "info" then
		return true
	end
	return false
end

local function sanitizeFileName(name)
	local clean = string.gsub(name, "[^%w_%-]", "_")
	if clean == "" then
		clean = "peripheral"
	end
	return clean
end

local function getDummyForType(tName)
	tName = string.lower(tName or "")
	if string.find(tName, "str") then
		return ""
	elseif string.find(tName, "num") or string.find(tName, "int") or string.find(tName, "double") or string.find(tName, "float") then
		return 0
	elseif string.find(tName, "bool") then
		return false
	elseif string.find(tName, "tab") or string.find(tName, "map") or string.find(tName, "list") or string.find(tName, "array") then
		return {}
	elseif string.find(tName, "func") then
		return function() end
	else
		return 0
	end
end

local function parseArgError(errStr)
	if type(errStr) ~= "string" then
		return nil
	end

	-- Pattern 1: "bad argument #1 (string expected, got no value)"
	local idx1, t1 = string.match(errStr, "bad argument #?(%d+)%s*%(%s*([%w_]+)%s+expected")
	if idx1 and t1 then
		return tonumber(idx1), string.lower(t1)
	end

	-- Pattern 2: "bad argument #1 (expected string, got nil)"
	local idx2, t2 = string.match(errStr, "bad argument #?(%d+)%s*%(%s*expected%s+([%w_]+)")
	if idx2 and t2 then
		return tonumber(idx2), string.lower(t2)
	end

	-- Pattern 3: "expected string, got nil"
	local t3 = string.match(errStr, "expected%s+([%w_]+),%s*got")
	if t3 then
		return 1, string.lower(t3)
	end

	-- Pattern 4: "number expected, got nil"
	local t4 = string.match(errStr, "([%w_]+)%s+expected,%s*got")
	if t4 then
		return 1, string.lower(t4)
	end

	-- Pattern 5: "expected 1 argument(s), got 0"
	local count = string.match(errStr, "expected%s+(%d+)%s+argument")
	if count then
		return tonumber(count), "value"
	end

	return nil
end

local function probeMethodSignature(dev, name)
	local fn = dev[name]
	if type(fn) ~= "function" then
		return name .. " (not a function)"
	end

	-- Attempt 0: Invocation with 0 arguments (getters, simple actions):
	local ok, res1 = pcall(fn)
	if ok then
		return name .. "()"
	end

	local errStr = tostring(res1)
	local argTypes = {}
	local dummyArgs = {}
---@diagnostic disable-next-line: deprecated
	local unpackFn = unpack or table.unpack

	-- Iterative probing: pass dummy arguments to uncover full signature:
	for _ = 1, 8 do
		local argIdx, expectedType = parseArgError(errStr)
		if not argIdx or not expectedType then
			break
		end

		argTypes[argIdx] = expectedType
		dummyArgs[argIdx] = getDummyForType(expectedType)

		local nextOk, nextRes = pcall(fn, unpackFn(dummyArgs))
		if nextOk then
			break
		else
			errStr = tostring(nextRes)
		end
	end

	if #argTypes > 0 then
		return string.format("%s(%s)", name, table.concat(argTypes, ", "))
	end

	return name .. "()"
end

local function dumpPeripheral(name)
	local pType = peripheral.getType(name) or "unknown"
	local dev = peripheral.wrap(name)
	if not dev then
		print("Failed to wrap peripheral: " .. tostring(name))
		return
	end

	local methods = peripheral.getMethods(name) or {}
	table.sort(methods)

	local lines = {}
	table.insert(lines, "==================================================")
	table.insert(lines, "Peripheral Name: " .. tostring(name))
	table.insert(lines, "Peripheral Type: " .. tostring(pType))
	table.insert(lines, "Methods Count:   " .. tostring(#methods))
	table.insert(lines, "==================================================")
	table.insert(lines, "")
	table.insert(lines, "## All Available Methods & Signatures:")
	for _, m in ipairs(methods) do
		local sig = probeMethodSignature(dev, m)
		table.insert(lines, "\t- " .. sig)
	end

	table.insert(lines, "")
	table.insert(lines, "## Inspection & Getter Invocations:")

	for _, m in ipairs(methods) do
		if isSafeGetter(m) and type(dev[m]) == "function" then
			local success, res1, res2, res3, res4 = pcall(dev[m])
			if success then
				local returns = {}
				if res1 ~= nil then table.insert(returns, serializeValue(res1)) end
				if res2 ~= nil then table.insert(returns, serializeValue(res2)) end
				if res3 ~= nil then table.insert(returns, serializeValue(res3)) end
				if res4 ~= nil then table.insert(returns, serializeValue(res4)) end

				if #returns == 0 then
					table.insert(lines, string.format("\t%s() -> (void/nil)", m))
				else
					table.insert(lines, string.format("\t%s() -> %s", m, table.concat(returns, ", ")))
				end
			else
				table.insert(lines, string.format("\t%s() -> Error: %s", m, tostring(res1)))
			end
		end
	end

	table.insert(lines, "")
	table.insert(lines, "## Direct Fields (if exposed):")
	local hasFields = false
	if type(dev) == "table" then
		for k, v in pairs(dev) do
			if type(v) ~= "function" then
				hasFields = true
				table.insert(lines, string.format("\t%s = %s", tostring(k), serializeValue(v)))
			end
		end
	end
	if not hasFields then
		table.insert(lines, "\t(No direct non-function fields found)")
	end

	local fileName = sanitizeFileName(pType) .. ".txt"
	if fs.exists(fileName) then
		local uniqueName = sanitizeFileName(pType) .. "_" .. sanitizeFileName(name) .. ".txt"
		fileName = uniqueName
	end

	local file = fs.open(fileName, "w")
	if file then
		file.write(table.concat(lines, "\n") .. "\n")
		file.close()
		print(string.format("Saved: %-20s -> %s", name .. " (" .. pType .. ")", fileName))
	else
		print(string.format("Error opening file %s for writing", fileName))
	end
end

local function dumpEnvironment()
	local standardGlobals = {
		["_G"] = true, ["_VERSION"] = true, ["assert"] = true, ["collectgarbage"] = true,
		["coroutine"] = true, ["debug"] = true, ["dofile"] = true, ["error"] = true,
		["getfenv"] = true, ["getmetatable"] = true, ["ipairs"] = true, ["load"] = true,
		["loadfile"] = true, ["loadstring"] = true, ["math"] = true, ["module"] = true,
		["next"] = true, ["os"] = true, ["package"] = true, ["pairs"] = true,
		["pcall"] = true, ["print"] = true, ["rawequal"] = true, ["rawget"] = true,
		["rawlen"] = true, ["rawset"] = true, ["require"] = true, ["select"] = true,
		["setfenv"] = true, ["setmetatable"] = true, ["string"] = true, ["table"] = true,
		["tonumber"] = true, ["tostring"] = true, ["type"] = true, ["unpack"] = true,
		["xpcall"] = true, ["bit32"] = true, ["bit"] = true, ["colors"] = true,
		["colours"] = true, ["commands"] = true, ["disk"] = true, ["fs"] = true,
		["gps"] = true, ["help"] = true, ["http"] = true, ["io"] = true,
		["keys"] = true, ["multishell"] = true, ["paintutils"] = true, ["parallel"] = true,
		["peripheral"] = true, ["pocket"] = true, ["rednet"] = true, ["redstone"] = true,
		["settings"] = true, ["shell"] = true, ["term"] = true, ["textutils"] = true,
		["turtle"] = true, ["vector"] = true, ["window"] = true, ["sleep"] = true,
		["write"] = true, ["read"] = true
	}

	local lines = {}
	table.insert(lines, "==================================================")
	table.insert(lines, "System Environment & Coordinates Probe")
	table.insert(lines, "==================================================")
	table.insert(lines, "")

	table.insert(lines, "## GPS Coordinates Probe (gps.locate):")
	if gps and gps.locate then
		local ok, x, y, z = pcall(gps.locate, 2)
		if ok and x and y and z then
			table.insert(lines, string.format("\tGPS Status: ONLINE -> X=%.2f, Y=%.2f, Z=%.2f", x, y, z))
		else
			table.insert(lines, "\tGPS Status: OFFLINE or No Satellite Response (nil)")
		end
	else
		table.insert(lines, "\tGPS API: Not available in this environment")
	end

	table.insert(lines, "")
	table.insert(lines, "## Custom / Non-Standard Global APIs in _G:")
	local customCount = 0
	for k, v in pairs(_G) do
		if not standardGlobals[k] then
			customCount = customCount + 1
			table.insert(lines, string.format("\t%s (%s) = %s", tostring(k), type(v), serializeValue(v, 1)))
		end
	end
	if customCount == 0 then
		table.insert(lines, "\t(No custom global APIs detected in _G)")
	end

	local file = fs.open("system_env.txt", "w")
	if file then
		file.write(table.concat(lines, "\n") .. "\n")
		file.close()
		print("Saved: system_env.txt")
	end
end

local function run()
	term.clear()
	term.setCursorPos(1, 1)
	print("=== CC: Tweaked Peripheral Dumper ===")
	print("Scanning connected hardware...\n")

	dumpEnvironment()

	local peripheralNames = peripheral.getNames()
	if #peripheralNames == 0 then
		print("No peripherals detected around the computer or on the network.")
		print("Make sure blocks are placed directly adjacent or connected via active Wired Modems.")
		return
	end

	print(string.format("Found %d peripheral(s):", #peripheralNames))
	for _, name in ipairs(peripheralNames) do
		dumpPeripheral(name)
	end

	print("\nScan completed successfully.")
	print("Dump files have been generated in the root directory.")
end

run()

