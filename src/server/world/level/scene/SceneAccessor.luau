--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local MissionSetup = require(ServerScriptService.server.world.level.mission.reading.MissionSetup)

export type SceneAccessor = {
	evaluateExpression: (self: SceneAccessor, str: string) -> any,
	setState: (self: SceneAccessor, key: string, value: any) -> (),
	hasState: (self: SceneAccessor, state: string) -> (),
	getState: (self: SceneAccessor, state: string) -> any,
	subscribeExpressionChange: (self: SceneAccessor, expressionStr: string, callback: (any) -> ()) -> () -> (),
	getLocalizedStrings: (self: SceneAccessor) -> { [string]: string },
	getSceneConfig: (self: SceneAccessor) -> MissionSetup.MissionSetup
}

return nil