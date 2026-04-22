--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SceneAccessor = require(ServerScriptService.server.world.level.scene.SceneAccessor)
local StateComponent = require(ServerScriptService.server.world.level.scene.components.registry.StateComponent)
local ObjectiveManager = require(ServerScriptService.server.world.level.objectives.ObjectiveManager)
local Maid = require(ReplicatedStorage.shared.util.misc.Maid)

--[=[
	@class ObjectivesComponent

	The entire objective system of a mission.
	Wraps ObjectiveManager and ties its lifetime to the scene lifecycle.
]=]
local ObjectivesComponent = {}
ObjectivesComponent.__index = ObjectivesComponent

export type ObjectivesComponent = StateComponent.StateComponent & typeof(setmetatable({} :: {
	maid: Maid.Maid,
	manager: ObjectiveManager.ObjectiveManager?,
}, ObjectivesComponent))

type SceneAccessor = SceneAccessor.SceneAccessor

function ObjectivesComponent.new(): ObjectivesComponent
	return setmetatable({
		maid = Maid.new(),
		manager = nil,
	}, ObjectivesComponent) :: ObjectivesComponent
end

local function setupManager(self: ObjectivesComponent, scene: SceneAccessor)
	self.maid:doCleaning()

	local missionTable = scene:getSceneConfig()
	if not missionTable then
		return
	end

	local manager = ObjectiveManager.new()
	manager:fromMissionSetupTable(missionTable:getObjectives())

	local unsubscribe = manager:subscribe(scene)
	self.maid:giveTask(unsubscribe)


	self.maid:giveTask(Players.PlayerAdded:Connect(function(player)
		manager:sendCurrentObjectivesToPlayer(player)
	end))

	self.manager = manager
end

--

function ObjectivesComponent.setup(self: ObjectivesComponent, scene: SceneAccessor): ()
	return
end

function ObjectivesComponent.onSceneReady(self: ObjectivesComponent, scene: SceneAccessor): ()
	setupManager(self, scene)
end

function ObjectivesComponent.update(self: ObjectivesComponent, _scene: SceneAccessor): ()
	return
end

function ObjectivesComponent.restart(self: ObjectivesComponent, scene: SceneAccessor): ()
	setupManager(self, scene)
end

function ObjectivesComponent.destroy(self: ObjectivesComponent, _scene: SceneAccessor): ()
	if self.manager then
		self.manager:sendEmptyObjectivesToClients()
	end
	self.maid:doCleaning()
	self.manager = nil
end

return ObjectivesComponent