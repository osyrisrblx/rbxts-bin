--!strict
--[[
	Test runner entry point for Lune
	Run with: lune run tests/init.luau
]]

local process = require("@lune/process")
local luneTask = require("@lune/task")

-- IMPORTANT: Set up Roblox API mocks BEFORE any other requires
-- We need to inject these as true globals that other modules can see

-- Inject task as a global (Roblox-style global task library)
rawset(_G, "task", {
	cancel = luneTask.cancel,
	defer = luneTask.defer,
	delay = luneTask.delay,
	spawn = luneTask.spawn,
	wait = luneTask.wait,
})

-- Inject typeof as a global
rawset(_G, "typeof", function(value: any): string
	local luaType = type(value)

	-- Check for mock RBXScriptConnection
	if luaType == "table" then
		local mt = getmetatable(value)
		if mt and (mt :: any).__type then
			return (mt :: any).__type
		end
	end

	return luaType
end)

-- Now load the rest of the modules
local Mocks = require("./mocks")
local testez = require("./testez")

-- Load test specs (which will load the Bin module with mocks in place)
local binSpecs = require("./Bin.spec")

-- Combine all specs into a single array
local allSpecs = {}
for _, spec in binSpecs do
	table.insert(allSpecs, spec)
end

-- Run all tests
local results = testez.run(allSpecs)

-- Print results
testez.printResults(results)

-- Exit with appropriate code
if results.failed > 0 then
	process.exit(1)
end
