--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Entity = require(ServerScriptService.server.world.entity.Entity)
local PlayerEntity = require(ServerScriptService.server.world.entity.player.PlayerEntity)
local SceneAccessor = require(ServerScriptService.server.world.level.scene.SceneAccessor)
local StateComponent = require(ServerScriptService.server.world.level.scene.components.registry.StateComponent)
local Maid = require(ReplicatedStorage.shared.util.misc.Maid)

--[=[
	@class PlayerEntityManagerComponent

	Adds or removes a Player entity in the Scene.
]=]
local PlayerEntityManagerComponent = {}
PlayerEntityManagerComponent.__index = PlayerEntityManagerComponent

export type PlayerEntityManagerComponent = StateComponent.StateComponent & typeof(setmetatable({} :: {
	maid: Maid.Maid,
	playersToEntity: { [Player]: Entity.Entity }
}, PlayerEntityManagerComponent))

type SceneAccessor = SceneAccessor.SceneAccessor

function PlayerEntityManagerComponent.new(): PlayerEntityManagerComponent
	return setmetatable({
		maid = Maid.new(),
		playersToEntity = {}
	}, PlayerEntityManagerComponent) :: PlayerEntityManagerComponent
end

--

function PlayerEntityManagerComponent.onPlayerAdded(self: PlayerEntityManagerComponent, player: Player, scene: SceneAccessor): ()
	self.maid:giveTask(player.CharacterAdded:Connect(function(character)
		scene:addFreshEntity(PlayerEntity.new(scene, character))
	end))
end

function PlayerEntityManagerComponent.setup(self: PlayerEntityManagerComponent, scene: SceneAccessor): ()
	-- TODO: Potential duplication.
	self.maid:giveTask(Players.PlayerAdded:Connect(function(player: Player)
		self:onPlayerAdded(player, scene)
	end))

	for _, player in Players:GetPlayers() do
		self:onPlayerAdded(player, scene) -- NOTES: Reference leak?
	end
end

function PlayerEntityManagerComponent.onSceneReady(self: PlayerEntityManagerComponent, scene: SceneAccessor): ()
	return
end

function PlayerEntityManagerComponent.update(self: PlayerEntityManagerComponent, _scene: SceneAccessor): ()
	return
end

function PlayerEntityManagerComponent.restart(self: PlayerEntityManagerComponent, scene: SceneAccessor): ()
	return
end

function PlayerEntityManagerComponent.destroy(self: PlayerEntityManagerComponent, _scene: SceneAccessor): ()
	self.maid:doCleaning()
end

return PlayerEntityManagerComponent