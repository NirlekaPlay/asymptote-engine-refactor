--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local DetectionManager = require(ServerScriptService.server.world.entity.ai.detection.DetectionManager)

export type DetectingAgent = {
	getDetectionManager: (self: DetectingAgent) -> DetectionManager.DetectionManager
}

return nil