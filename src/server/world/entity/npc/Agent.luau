--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Entity = require(ServerScriptService.server.world.entity.Entity)
local Brain = require(ServerScriptService.server.world.entity.ai.Brain)
local BodyRotationControl = require(ServerScriptService.server.world.entity.ai.control.BodyRotationControl)
local PathNavigation = require(ServerScriptService.server.world.entity.ai.navigation.PathNavigation)
local HumanoidAnimator = require(ServerScriptService.server.world.entity.animation.HumanoidAnimator)
local Scene = require(ServerScriptService.server.world.level.scene.Scene)

export type Agent = Entity.Entity & {
	getBrain: (self: Agent) -> Brain.Brain<Agent>,
	getBodyRotationControl: (self: Agent) -> BodyRotationControl.BodyRotationControl,
	getBlockPosition: (self: Agent) -> Vector3,
	getNavigation: (self: Agent) -> PathNavigation.PathNavigation,
	getScene: (self: Agent) -> Scene.Scene,
	getPrimaryPart: (self: Agent) -> BasePart,
	getHumanoid: (self: Agent) -> Humanoid,
	getRandom: (self: Agent) -> Random,
	--
	getOverlayState: (self: Agent) -> HumanoidAnimator.OverlayState
}

return nil