--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local SceneAccessor = require(ServerScriptService.server.world.level.scene.SceneAccessor)

--[=[
	@class ParsedObjective
]=]
local ParsedObjective = {}
ParsedObjective.__index = ParsedObjective

export type ParsedObjective = typeof(setmetatable({} :: {
	conditionExpressionStr: string,
	tagExpressionStr: string,
	localizedTextKey: string,
}, ParsedObjective))

type SceneAccessor = SceneAccessor.SceneAccessor

function ParsedObjective.new(
	conditionExpressionStr: string,
	tagExpressionStr: string,
	localizedTextKey: string
): ParsedObjective
	return setmetatable({
		conditionExpressionStr = conditionExpressionStr,
		tagExpressionStr = tagExpressionStr,
		localizedTextKey = localizedTextKey,
	}, ParsedObjective)
end

function ParsedObjective.getConditionExpressionString(self: ParsedObjective): string
	return self.conditionExpressionStr
end

function ParsedObjective.getTagExpressionStr(self: ParsedObjective): string
	return self.tagExpressionStr
end

function ParsedObjective.getLocalizedTextKey(self: ParsedObjective): string
	return self.localizedTextKey
end

function ParsedObjective.evaluateCondition(self: ParsedObjective, scene: SceneAccessor): boolean
	if self.conditionExpressionStr == "" then
		return true
	end
	return if scene:evaluateExpression(self.conditionExpressionStr) then true else false
end

function ParsedObjective.evaluateTag(self: ParsedObjective, scene: SceneAccessor): string
	if self.tagExpressionStr == "" then
		return ""
	end
	return tostring(scene:evaluateExpression(self.tagExpressionStr))
end

return ParsedObjective