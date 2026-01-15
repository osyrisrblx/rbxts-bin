--!strict
--[[
	TestEZ-style test framework for Lune
	Provides describe/it/expect API similar to TestEZ
]]

local stdio = require("@lune/stdio")

export type TestResult = {
	name: string,
	passed: boolean,
	error: string?,
	duration: number,
}

export type SuiteResult = {
	name: string,
	tests: { TestResult },
	passed: number,
	failed: number,
	skipped: number,
}

export type RunResults = {
	suites: { SuiteResult },
	passed: number,
	failed: number,
	total: number,
}

export type TestNode = {
	type: "describe" | "it",
	name: string,
	callback: () -> (),
}

export type TestSpec = {
	name: string,
	tests: { TestNode },
}

local TestEZ = {}

-- Internal state
local currentSpec: TestSpec? = nil
local currentDescribe: string? = nil

-- Create a new test specification
function TestEZ.describe(name: string, callback: () -> ()): TestSpec
	local spec: TestSpec = {
		name = name,
		tests = {},
	}

	currentSpec = spec
	currentDescribe = name

	-- Execute the describe block to collect tests
	local success, err = pcall(callback)
	if not success then
		-- Add a failed test for the describe block itself
		table.insert(spec.tests, {
			type = "it" :: "it",
			name = "[describe setup failed]",
			callback = function()
				error(err)
			end,
		})
	end

	currentSpec = nil
	currentDescribe = nil

	return spec
end

-- Add a test case
function TestEZ.it(name: string, callback: () -> ())
	if not currentSpec then
		error("it() must be called within describe()")
	end

	table.insert(currentSpec.tests, {
		type = "it" :: "it",
		name = name,
		callback = callback,
	})
end

-- Expectation builder
type ExpectMethods<T> = {
	toBe: (expected: T) -> (),
	toEqual: (expected: T) -> (),
	toBeTruthy: () -> (),
	toBeFalsy: () -> (),
	toBeNil: () -> (),
	toBeGreaterThan: (expected: number) -> (),
	toBeLessThan: (expected: number) -> (),
	toHaveLength: (expected: number) -> (),
	toThrow: () -> (),
	never: {
		toBe: (expected: T) -> (),
		toBeNil: () -> (),
		toThrow: () -> (),
	},
}

function TestEZ.expect<T>(value: T): ExpectMethods<T>
	local methods: ExpectMethods<T>

	methods = {
		toBe = function(expected: T)
			if value ~= expected then
				error(`Expected {tostring(expected)}, got {tostring(value)}`, 2)
			end
		end,

		toEqual = function(expected: T)
			-- Deep equality check for tables
			if type(value) == "table" and type(expected) == "table" then
				local function deepEqual(a: any, b: any): boolean
					if type(a) ~= type(b) then
						return false
					end
					if type(a) ~= "table" then
						return a == b
					end
					for k, v in a do
						if not deepEqual(v, b[k]) then
							return false
						end
					end
					for k, v in b do
						if not deepEqual(v, a[k]) then
							return false
						end
					end
					return true
				end

				if not deepEqual(value, expected) then
					error(`Expected tables to be equal`, 2)
				end
			elseif value ~= expected then
				error(`Expected {tostring(expected)}, got {tostring(value)}`, 2)
			end
		end,

		toBeTruthy = function()
			if not value then
				error(`Expected truthy value, got {tostring(value)}`, 2)
			end
		end,

		toBeFalsy = function()
			if value then
				error(`Expected falsy value, got {tostring(value)}`, 2)
			end
		end,

		toBeNil = function()
			if value ~= nil then
				error(`Expected nil, got {tostring(value)}`, 2)
			end
		end,

		toBeGreaterThan = function(expected: number)
			if type(value) ~= "number" then
				error(`Expected number, got {type(value)}`, 2)
			end
			if (value :: any) <= expected then
				error(`Expected {tostring(value)} to be greater than {expected}`, 2)
			end
		end,

		toBeLessThan = function(expected: number)
			if type(value) ~= "number" then
				error(`Expected number, got {type(value)}`, 2)
			end
			if (value :: any) >= expected then
				error(`Expected {tostring(value)} to be less than {expected}`, 2)
			end
		end,

		toHaveLength = function(expected: number)
			local len: number
			if type(value) == "table" then
				len = #(value :: any)
			elseif type(value) == "string" then
				len = #(value :: any)
			else
				error(`Expected table or string, got {type(value)}`, 2)
			end
			if len ~= expected then
				error(`Expected length {expected}, got {len}`, 2)
			end
		end,

		toThrow = function()
			if type(value) ~= "function" then
				error("toThrow() expects a function", 2)
			end
			local success = pcall(value :: any)
			if success then
				error("Expected function to throw, but it didn't", 2)
			end
		end,

		never = {
			toBe = function(expected: T)
				if value == expected then
					error(`Expected value not to be {tostring(expected)}`, 2)
				end
			end,

			toBeNil = function()
				if value == nil then
					error("Expected value not to be nil", 2)
				end
			end,

			toThrow = function()
				if type(value) ~= "function" then
					error("toThrow() expects a function", 2)
				end
				local success, err = pcall(value :: any)
				if not success then
					error(`Expected function not to throw, but it threw: {err}`, 2)
				end
			end,
		},
	}

	return methods
end

-- Run a collection of test specs
function TestEZ.run(specs: { TestSpec }): RunResults
	local results: RunResults = {
		suites = {},
		passed = 0,
		failed = 0,
		total = 0,
	}

	for _, spec in specs do
		local suiteResult: SuiteResult = {
			name = spec.name,
			tests = {},
			passed = 0,
			failed = 0,
			skipped = 0,
		}

		for _, test in spec.tests do
			if test.type == "it" then
				local startTime = os.clock()
				local success, err = pcall(test.callback)
				local duration = os.clock() - startTime

				local testResult: TestResult = {
					name = test.name,
					passed = success,
					error = if success then nil else tostring(err),
					duration = duration,
				}

				table.insert(suiteResult.tests, testResult)

				if success then
					suiteResult.passed += 1
					results.passed += 1
				else
					suiteResult.failed += 1
					results.failed += 1
				end

				results.total += 1
			end
		end

		table.insert(results.suites, suiteResult)
	end

	return results
end

-- Print test results
function TestEZ.printResults(results: RunResults)
	print("")
	print(string.rep("=", 60))
	print(stdio.color("cyan") .. "TEST RESULTS" .. stdio.color("reset"))
	print(string.rep("=", 60))

	for _, suite in results.suites do
		print("")
		print(stdio.color("white") .. suite.name .. stdio.color("reset"))
		print(string.rep("-", 50))

		for _, test in suite.tests do
			local status: string
			local color: string

			if test.passed then
				status = "[PASS]"
				color = "green"
			else
				status = "[FAIL]"
				color = "red"
			end

			print(`  {stdio.color(color)}{status}{stdio.color("reset")} {test.name}`)

			if test.error then
				print(stdio.color("red") .. `         Error: {test.error}` .. stdio.color("reset"))
			end
		end
	end

	print("")
	print(string.rep("=", 60))

	local summaryColor = if results.failed > 0 then "red" else "green"
	print(
		stdio.color(summaryColor)
			.. `Total: {results.total} tests, {results.passed} passed, {results.failed} failed`
			.. stdio.color("reset")
	)
	print(string.rep("=", 60))
	print("")
end

return TestEZ
