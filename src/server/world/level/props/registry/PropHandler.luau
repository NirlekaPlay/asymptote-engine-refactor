--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Prop = require(ServerScriptService.server.world.level.props.Prop)
local PropSceneAccessor = require(ServerScriptService.server.world.level.scene.props.PropSceneAccessor)

export type PropHandler = {
	proccess: (self: PropHandler, placeholder: BasePart, prop: Model?, scene: PropSceneAccessor.PropSceneAccessor) -> (boolean, Prop.Prop?)
}

return nil