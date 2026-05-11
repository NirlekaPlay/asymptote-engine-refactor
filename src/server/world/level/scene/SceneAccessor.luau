--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Entity = require(ServerScriptService.server.world.entity.Entity)
local DebrisManager = require(ServerScriptService.server.world.level.debris.DebrisManager)
local MissionSetup = require(ServerScriptService.server.world.level.mission.reading.MissionSetup)
local StateComponentType = require(ServerScriptService.server.world.level.scene.components.registry.StateComponentType)

export type SceneAccessor = {
	getDebrisManager: (self: SceneAccessor) -> DebrisManager.DebrisManager,
	--
	evaluateExpression: (self: SceneAccessor, str: string) -> any,
	setState: (self: SceneAccessor, key: string, value: any) -> (),
	hasState: (self: SceneAccessor, state: string) -> (),
	getState: (self: SceneAccessor, state: string) -> any,
	subscribeExpressionChange: (self: SceneAccessor, expressionStr: string, callback: (any) -> ()) -> () -> (),
	getLocalizedStrings: (self: SceneAccessor) -> { [string]: string },
	getSceneConfig: (self: SceneAccessor) -> MissionSetup.MissionSetup,
	--
	getComponent: <T>(self: SceneAccessor, type: StateComponentType.StateComponentType<T>) -> T,
	--
	addFreshEntity: (self: SceneAccessor, entity: Entity.Entity) -> (),
	getEntityByUuid: (self: SceneAccessor, uuid: string) -> Entity.Entity
}

return nil