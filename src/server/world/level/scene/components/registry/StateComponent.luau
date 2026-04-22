--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local SceneAccessor = require(ServerScriptService.server.world.level.scene.SceneAccessor)

export type StateComponent = {
	setup: (self: StateComponent, scene: SceneAccessor) -> (),
	update: (self: StateComponent, scene: SceneAccessor, deltaTime: number) -> (),
	restart: (self: StateComponent, scene: SceneAccessor) -> (),
	destroy: (self: StateComponent, scene: SceneAccessor) -> (),
	--
	onSceneReady: (self: StateComponent, scene: SceneAccessor) -> ()
}

type SceneAccessor = SceneAccessor.SceneAccessor

return nil