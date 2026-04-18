--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local InteractionPromptBuilder = require(ServerScriptService.server.world.level.interaction.InteractionPromptBuilder)

export type PropSceneAccessor = {
	evaluateExpression: (self: PropSceneAccessor, str: string) -> any,
	setState: (self: PropSceneAccessor, key: string, value: any) -> (),
	hasState: (self: PropSceneAccessor, state: string) -> (),
	getState: (self: PropSceneAccessor, state: string) -> any,
	subscribeExpressionChange: (self: PropSceneAccessor, expressionStr: string, callback: (any) -> ()) -> () -> (),
	getLocalizedStrings: (self: PropSceneAccessor) -> { [string]: string },
	promptBuilder: (self: PropSceneAccessor) -> InteractionPromptBuilder.InteractionPromptBuilder
}

return nil