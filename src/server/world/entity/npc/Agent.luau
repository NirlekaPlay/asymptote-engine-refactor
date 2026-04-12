--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Entity = require(ServerScriptService.server.world.entity.Entity)
local Brain = require(ServerScriptService.server.world.entity.ai.Brain)
local Scene = require(ServerScriptService.server.world.level.scene.Scene)

export type Agent = Entity.Entity & {
	getBrain: (self: Agent) -> Brain.Brain<Agent>,
	getScene: (self: Agent) -> Scene.Scene,
	getPrimaryPart: (self: Agent) -> BasePart,
	getHumanoid: (self: Agent) -> Humanoid
}

return nil