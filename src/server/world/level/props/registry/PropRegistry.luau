--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local UString = require(ReplicatedStorage.shared.util.string.UString)
local PropHandler = require(ServerScriptService.server.world.level.props.registry.PropHandler)
local PropHandlerBuilder = require(ServerScriptService.server.world.level.props.registry.PropHandlerBuilder)
local DoorCreator = require(ServerScriptService.server.world.level.props.doors.DoorCreator)
local TriggerZone = require(ServerScriptService.server.world.level.props.triggers.TriggerZone)

--[=[
	@class PropRegistry
]=]
local PropRegistry = {}

local registry: { [string]: PropHandler.PropHandler } = {}
local registryByPrefixes: { {prefix: string, handler: PropHandler.PropHandler} } = {}

local function register(name: string, handler: PropHandler.PropHandler): ()
	registry[name] = handler
end

local function registerPrefix(prefix: string, handler: PropHandler.PropHandler): ()
	table.insert(registryByPrefixes, {
		prefix = prefix,
		handler = handler
	})
end

function PropRegistry.getHandler(propName: string): PropHandler.PropHandler?
	local standardHandler = registry[propName]
	if standardHandler then
		return standardHandler
	end

	for _, shit in registryByPrefixes do
		if UString.startsWith(propName, shit.prefix) then
			return shit.handler
		end
	end

	return nil
end

function PropRegistry.register(): ()
	register("SpawnLocation", PropHandlerBuilder.new()
		:onProccess(function(placeholder, prop, scene)
			local newSpawnLocation = Instance.new("SpawnLocation")
			local decal = newSpawnLocation:FindFirstChildOfClass("Decal")
			if decal then
				decal:Destroy()
			end
			newSpawnLocation.Anchored = true
			newSpawnLocation.CFrame = placeholder.CFrame
			newSpawnLocation.Size = placeholder.Size
			newSpawnLocation.Transparency = 1
			newSpawnLocation.CanCollide = false
			newSpawnLocation.CanQuery = false
			newSpawnLocation.CanTouch = false
			newSpawnLocation.AudioCanCollide = false
			newSpawnLocation.Duration = 0
			newSpawnLocation.Parent = placeholder.Parent
			placeholder:Destroy()
			return true, nil
		end)
		:build()
	)

	register("TriggerZone", TriggerZone.handler())

	registerPrefix("Door", PropHandlerBuilder.new()
		:onProccess(function(placeholder: BasePart, prop: Model?, scene)
			return true, DoorCreator.createFromPlaceholder(placeholder, prop, scene)
		end)
		:build()
	)
end

PropRegistry.register()

return PropRegistry