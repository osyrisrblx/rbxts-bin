--!strict
--[[
	Test runner for Lune
	Executes compiled TypeScript tests using TestEZ

	Run with: lune run tests/run.luau
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local task = require("@lune/task")

-- Helper to merge tables
local function tableJoin(...: { [any]: any }): { [any]: any }
	local result = {}
	for i = 1, select("#", ...) do
		for k, v in select(i, ...) do
			result[k] = v
		end
	end
	return result
end

-- Simple Instance mock with __index for child access
local function createInstance(className: string, name: string?): any
	local inst: any = {}
	local children: { [string]: any } = {}

	inst.ClassName = className
	inst.Name = name or className
	inst.Parent = nil :: any?
	inst._children = children

	inst.GetFullName = function(self: any): string
		if self.Parent and self.Parent.GetFullName then
			return self.Parent:GetFullName() .. "." .. self.Name
		end
		return self.Name
	end

	inst.FindFirstChild = function(self: any, childName: string): any?
		return children[childName]
	end

	inst.WaitForChild = function(self: any, childName: string): any
		local child = children[childName]
		if not child then
			error(`WaitForChild failed: {childName} not found in {self.Name}`)
		end
		return child
	end

	inst.GetChildren = function(self: any): { any }
		local result = {}
		for _, child in children do
			table.insert(result, child)
		end
		return result
	end

	inst.IsA = function(self: any, cn: string): boolean
		return inst.ClassName == cn or cn == "Instance" or cn == "LuaSourceContainer"
	end

	inst.GetDescendants = function(self: any): { any }
		local result = {}
		local function collect(parent: any)
			for _, child in parent._children do
				table.insert(result, child)
				if child._children then
					collect(child)
				end
			end
		end
		collect(inst)
		return result
	end

	inst._addChild = function(self: any, child: any)
		child.Parent = inst
		children[child.Name] = child
	end

	-- Add metatable to support direct child access (instance.ChildName)
	setmetatable(inst, {
		__index = function(_, key)
			return children[key]
		end,
	})

	return inst
end

-- Module cache for require
local requireCache: { [string]: { any } } = {}

-- Build the mock game tree based on Rojo config
local function buildGameTree(): any
	local game = createInstance("DataModel", "game")

	-- ReplicatedStorage
	local repStorage = createInstance("ReplicatedStorage", "ReplicatedStorage")
	game:_addChild(repStorage)

	-- include folder (runtime)
	local include = createInstance("Folder", "include")
	repStorage:_addChild(include)

	-- RuntimeLib
	local runtimeLib = createInstance("ModuleScript", "RuntimeLib")
	runtimeLib.Source = fs.readFile("tests/include/RuntimeLib.lua")
	include:_addChild(runtimeLib)

	-- Promise
	local promise = createInstance("ModuleScript", "Promise")
	promise.Source = fs.readFile("tests/include/Promise.lua")
	include:_addChild(promise)

	-- node_modules folder
	local nodeModules = createInstance("Folder", "node_modules")
	include:_addChild(nodeModules)

	-- @rbxts folder
	local rbxts = createInstance("Folder", "@rbxts")
	nodeModules:_addChild(rbxts)

	-- Load testez
	local testez = createInstance("Folder", "testez")
	rbxts:_addChild(testez)
	local testezSrc = createInstance("Folder", "src")
	testez:_addChild(testezSrc)

	-- Recursively load testez source
	local function loadDir(dirPath: string, parent: any)
		for _, entry in fs.readDir(dirPath) do
			local fullPath = dirPath .. "/" .. entry
			if fs.isDir(fullPath) then
				local folder = createInstance("Folder", entry)
				parent:_addChild(folder)
				loadDir(fullPath, folder)
			elseif entry:match("%.luau?$") then
				local name = entry:gsub("%.luau?$", "")
				if name == "init" then
					parent.Source = fs.readFile(fullPath)
					parent.ClassName = "ModuleScript"
				else
					local mod = createInstance("ModuleScript", name)
					mod.Source = fs.readFile(fullPath)
					parent:_addChild(mod)
				end
			end
		end
	end
	loadDir("tests/node_modules/@rbxts/testez/src", testezSrc)

	-- services module
	local services = createInstance("ModuleScript", "services")
	services.Source = [[
-- Mock services module
return setmetatable({}, {
	__index = function(_, key)
		return game:GetService(key)
	end
})
]]
	rbxts:_addChild(services)

	-- bin module (the library we're testing) - directly under ReplicatedStorage
	local bin = createInstance("ModuleScript", "bin")
	bin.Source = fs.readFile("out/init.luau")
	repStorage:_addChild(bin)

	-- ServerScriptService
	local serverScript = createInstance("ServerScriptService", "ServerScriptService")
	game:_addChild(serverScript)

	-- main script
	local main = createInstance("Script", "main")
	main.Source = fs.readFile("tests/out/main.server.luau")
	serverScript:_addChild(main)

	-- tests folder
	local tests = createInstance("Folder", "tests")
	serverScript:_addChild(tests)

	-- Load spec files
	for _, entry in fs.readDir("tests/out") do
		if entry:match("%.spec%.luau$") then
			local name = entry:gsub("%.luau$", "")
			local spec = createInstance("ModuleScript", name)
			spec.Source = fs.readFile("tests/out/" .. entry)
			tests:_addChild(spec)
		end
	end

	return game
end

-- Run a script in the mock environment
local function runScript(game: any)
	local function robloxRequire(moduleScript: any): ...any
		if moduleScript == nil then
			error("require called with nil - check that module path exists")
		end
		if type(moduleScript) ~= "table" then
			error(`Invalid require target: expected ModuleScript, got {type(moduleScript)}`)
		end
		if not moduleScript.Source then
			error(`Cannot require {moduleScript.Name or "unknown"}: not a ModuleScript`)
		end

		local path = moduleScript:GetFullName()
		if requireCache[path] then
			return table.unpack(requireCache[path])
		end

		local env = tableJoin(getfenv(), {
			game = game,
			script = moduleScript,
			require = robloxRequire,
			task = task,
			tick = os.clock,
		})

		local fn = luau.load(moduleScript.Source, {
			debugName = path,
			environment = env,
		})

		local result = table.pack(fn())
		requireCache[path] = result
		return table.unpack(result)
	end

	-- Set up game:GetService
	local mockServices: { [string]: any } = {
		ReplicatedStorage = game:FindFirstChild("ReplicatedStorage"),
		ServerScriptService = game:FindFirstChild("ServerScriptService"),
		RunService = {
			Name = "RunService",
			ClassName = "RunService",
			Heartbeat = {
				Connect = function()
					return { Disconnect = function() end }
				end,
			},
		},
		TestService = {
			Name = "TestService",
			ClassName = "TestService",
			Error = function(_, desc: string)
				print(`[TestService:Error] {desc}`)
			end,
		},
		Workspace = createInstance("Workspace", "Workspace"),
	}

	game.GetService = function(_, serviceName: string)
		local svc = mockServices[serviceName]
		if not svc then
			error(`Unknown service: {serviceName}`)
		end
		return svc
	end

	-- Run main script
	local mainScript = game:FindFirstChild("ServerScriptService"):FindFirstChild("main")

	local env = tableJoin(getfenv(), {
		game = game,
		script = mainScript,
		require = robloxRequire,
		task = task,
		tick = os.clock,
	})

	local fn = luau.load(mainScript.Source, {
		debugName = mainScript:GetFullName(),
		environment = env,
	})

	return fn()
end

-- Main
local function main()
	print("Building test environment...")
	local game = buildGameTree()

	print("Running tests...")
	print(string.rep("=", 60))

	local success, err = pcall(runScript, game)

	print(string.rep("=", 60))

	if not success then
		print(`Tests failed: {err}`)
		process.exit(1)
	end

	print("All tests passed!")
end

main()
