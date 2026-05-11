--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MissionComponent = require(ServerScriptService.server.world.level.scene.components.MissionComponent)
local UString = require(ReplicatedStorage.shared.util.string.UString)
local NpcStateTrackerComponent = require(ServerScriptService.server.world.level.scene.components.NpcStateTrackerComponent)
local StateComponent = require(ServerScriptService.server.world.level.scene.components.registry.StateComponent)
local StateComponentType = require(ServerScriptService.server.world.level.scene.components.registry.StateComponentType)

local COMPONENT_TYPE_ATTRIBUTE_NAME = "Type"

--[=[
	@class StateComponentRegistry
]=]
local StateComponentRegistry = {}

type StateComponentType<T> = StateComponentType.StateComponentType<T>

local function registerType<T>(class: any, name: string): StateComponentType<T>
	-- I might be overcomplicating shit but ehhhhhhhh
	return {
		name = name,
		isInstanceOf = function(v)
			return getmetatable(v) == class
		end
	}
end
StateComponentRegistry.Types = {}
StateComponentRegistry.Types.MISSION = registerType(MissionComponent, "mission") :: StateComponentType<MissionComponent.MissionComponent>

local handlersForInstance: { [string]: (inst: Instance) -> StateComponent.StateComponent? } = {}

function StateComponentRegistry.register(): ()
	handlersForInstance["NpcStateTracker"] = NpcStateTrackerComponent.fromInstance
end

function StateComponentRegistry.createFromInstance(inst: Instance): StateComponent.StateComponent?
	local typeName = StateComponentRegistry.getComponentType(inst) or inst.Name
	local creator = handlersForInstance[typeName]
	
	if creator then
		return creator(inst)
	end

	return nil
end

function StateComponentRegistry.getComponentType(instance: Instance): string?
	local specifiedType = instance:GetAttribute(COMPONENT_TYPE_ATTRIBUTE_NAME)
	if type(specifiedType) ~= "string" then
		return nil
	end

	if UString.isBlank(specifiedType) then
		return nil
	end

	return specifiedType
end

--

StateComponentRegistry.register()

return StateComponentRegistry