--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local PropSceneAccessor = require(ServerScriptService.server.world.level.scene.props.PropSceneAccessor)

export type Fields = {
	id: number,
	updatesPerSec: number?,
	_elapsed: number,
}

export type Prop = Fields & {
	getId: (self: Prop) -> number,
	destroy: ((self: Prop) -> ())?,
	restart: ((self: Prop, scene: PropSceneAccessor.PropSceneAccessor) -> ())?,
	update: ((self: Prop, deltaTime: number, scene: PropSceneAccessor.PropSceneAccessor) -> ())?,
	setup: ((self: Prop, scene: PropSceneAccessor.PropSceneAccessor) -> ())
}

return nil