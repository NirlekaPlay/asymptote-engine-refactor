--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local SceneAccessor = require(ServerScriptService.server.world.level.scene.SceneAccessor)
local StateComponent = require(ServerScriptService.server.world.level.scene.components.registry.StateComponent)

--[=[
	@class StateComponentManager
]=]
local StateComponentManager = {}
StateComponentManager.__index = StateComponentManager

export type StateComponentManager = typeof(setmetatable({} :: {
	components: { StateComponent },
	scene: SceneAccessor
}, StateComponentManager))

type StateComponent = StateComponent.StateComponent
type SceneAccessor = SceneAccessor.SceneAccessor

function StateComponentManager.new(scene: SceneAccessor): StateComponentManager
	return setmetatable({
		components = {},
		scene = scene
	}, StateComponentManager)
end

--

function StateComponentManager.addComponent<T>(self: StateComponentManager, component: StateComponent): ()	
	table.insert(self.components, component)
	component:setup(self.scene)
end

function StateComponentManager.update(self: StateComponentManager, deltaTime: number): ()
	local scene = self.scene
	for _, component in self.components do
		component:update(scene, deltaTime)
	end
end

--

function StateComponentManager.sceneReady(self: StateComponentManager): ()
	local scene = self.scene
	for _, component in self.components do
		if component.onSceneReady then
			component:onSceneReady(scene)
		end
	end
end

--

function StateComponentManager.destroy(self: StateComponentManager): ()
	for _, component in self.components do
		component:destroy(self.scene)
	end

	table.clear(self.components)
end

return StateComponentManager