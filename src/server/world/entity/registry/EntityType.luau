--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Entity = require(ServerScriptService.server.world.entity.Entity)
local AbstractNpc = require(ServerScriptService.server.world.entity.npc.AbstractNpc)

--[=[
	@class EntityType
]=]
local EntityType = {}

export type EntityType<T> = {
	create: (level: any) -> Entity.Entity & T,
	typeId: string
}

local registryByNames: { [string]: EntityType<any> } = {}

local function register<T>(factory: (level: any) -> T, name: string): EntityType<T>
	local entityType = {
		create = factory,
		typeId = name
	}

	registryByNames[name] = entityType

	return entityType
end

function EntityType.getEntityTypeByName(name: string): EntityType<Entity.Entity>?
	return registryByNames[name]
end

EntityType.NPC = register(function(level)
	local clonedChar = ReplicatedStorage.shared.assets.characters.Rig:Clone()
	return AbstractNpc.new(level, clonedChar)
end, "npc")

EntityType.C4 = register(function(level)
	return {} -- TODO: Add C4 entity class
end, "c4")

EntityType.PLAYER = register(function(level)
	return {}
end, "player")

return EntityType