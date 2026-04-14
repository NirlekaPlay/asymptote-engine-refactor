--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Entity = require(ServerScriptService.server.world.entity.Entity)
local Brain = require(ServerScriptService.server.world.entity.ai.Brain)
local BodyRotationControl = require(ServerScriptService.server.world.entity.ai.control.BodyRotationControl)
local Scene = require(ServerScriptService.server.world.level.scene.Scene)

export type Agent = Entity.Entity & {
	getBrain: (self: Agent) -> Brain.Brain<Agent>,
	getBodyRotationControl: (self: Agent) -> BodyRotationControl.BodyRotationControl,
	getBlockPosition: (self: Agent) -> Vector3,
	getScene: (self: Agent) -> Scene.Scene,
	getPrimaryPart: (self: Agent) -> BasePart,
	getHumanoid: (self: Agent) -> Humanoid
}

return nil