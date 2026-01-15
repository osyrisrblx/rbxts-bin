--!strict
--[[
	Roblox API mocks for testing outside of Roblox
	Provides mock objects that simulate Roblox types for testing purposes
]]

local Mocks = {}

-- Create a mock RBXScriptConnection
function Mocks.createRBXScriptConnection(): any
	local connection = {
		Connected = true,
		Disconnect = function(self: any)
			self.Connected = false
		end,
	}

	setmetatable(connection, {
		__type = "RBXScriptConnection",
	})

	return connection
end

-- Create a mock Instance with Destroy method
function Mocks.createInstance(): any
	return {
		Destroyed = false,
		Destroy = function(self: any)
			self.Destroyed = true
		end,
	}
end

-- Create an object with destroy() method (lowercase)
function Mocks.createDestroyable(): any
	return {
		destroyed = false,
		destroy = function(self: any)
			self.destroyed = true
		end,
	}
end

-- Create an object with Destroy() method (uppercase)
function Mocks.createDestroyableUppercase(): any
	return {
		destroyed = false,
		Destroy = function(self: any)
			self.destroyed = true
		end,
	}
end

-- Create an object with disconnect() method (lowercase)
function Mocks.createDisconnectable(): any
	return {
		disconnected = false,
		disconnect = function(self: any)
			self.disconnected = true
		end,
	}
end

-- Create an object with Disconnect() method (uppercase)
function Mocks.createDisconnectableUppercase(): any
	return {
		disconnected = false,
		Disconnect = function(self: any)
			self.disconnected = true
		end,
	}
end

return Mocks
