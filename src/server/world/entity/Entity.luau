--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local EntityInLevelCallback = require(ServerScriptService.server.world.level.entity.EntityInLevelCallback)

export type Entity = {
	getPosition: (self: Entity) -> Vector3,
	getWorldInstance: (self: Entity) -> Instance,
	getUuid: (self: Entity) -> string,
	update: (self: Entity, deltaTime: number) -> (),
	isRemoved: (self: Entity) -> boolean,
	setLevelCallback: (self: Entity, callback: EntityInLevelCallback.EntityInLevelCallback) -> (),
	remove: (self: Entity, removalReason: RemovalReason) -> (),
	setPosToCFrame: (self: Entity, cframe: CFrame) -> (),
	--
	typeId: string
}

export type RemovalReason = number

local REMOVAL_REASONS = {
	KILLED = 0 :: RemovalReason,
	DISCARDED = 1 :: RemovalReason
}

return {
	RemovalReason = REMOVAL_REASONS
}