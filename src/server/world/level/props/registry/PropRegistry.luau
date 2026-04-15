--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local PropHandler = require(ServerScriptService.server.world.level.props.registry.PropHandler)
local PropHandlerBuilder = require(ServerScriptService.server.world.level.props.registry.PropHandlerBuilder)
local TriggerZone = require(ServerScriptService.server.world.level.props.triggers.TriggerZone)

--[=[
	@class PropRegistry
]=]
local PropRegistry = {}

local registry: { [string]: PropHandler.PropHandler } = {}

local function register(name: string, handler: PropHandler.PropHandler): ()
	registry[name] = handler
end

function PropRegistry.getHandler(propName: string): PropHandler.PropHandler?
	return registry[propName]
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
end

PropRegistry.register()

return PropRegistry