--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local UString = require(ReplicatedStorage.shared.util.string.UString)
local NpcStateTrackerComponent = require(ServerScriptService.server.world.level.scene.components.NpcStateTrackerComponent)
local StateComponent = require(ServerScriptService.server.world.level.scene.components.registry.StateComponent)

local COMPONENT_TYPE_ATTRIBUTE_NAME = "Type"

--[=[
	@class StateComponentRegistry
]=]
local StateComponentRegistry = {}

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