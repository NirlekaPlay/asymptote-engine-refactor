--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local DetectionContext = require(ServerScriptService.server.world.entity.ai.detection.entity.DetectionContext)
local Agent = require(ServerScriptService.server.world.entity.npc.Agent)

export type DetectableEntity = {
	getUuid: (self: DetectableEntity) -> string,
	getPosition: (self: DetectableEntity) -> Vector3,
	getBasePriority: (self: DetectableEntity, context: DetectionContext.DetectionContext) -> number,
	getPriority: (self: DetectableEntity, context: DetectionContext.DetectionContext) -> number,
	getBaseDetectionRadius: (self: DetectableEntity) -> number,
	getDetectionMultiplier: (self: DetectableEntity, context: DetectionContext.DetectionContext) -> number,
	getMovementMultiplier: (self: DetectableEntity, context: DetectionContext.DetectionContext) -> number,
	shouldRaiseDetection: (self: DetectableEntity, agent: Agent.Agent, context: DetectionContext.DetectionContext) -> boolean
}

return nil