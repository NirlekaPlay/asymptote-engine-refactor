--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Entity = require(ServerScriptService.server.world.entity.Entity)
local DetectionManager = require(ServerScriptService.server.world.entity.ai.detection.DetectionManager)
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
		local healthScriptProccessed = false
		for _, child in character:GetChildren() do
			if child:IsA("Script") and child.Name == "Health" then
				child:Destroy()
				healthScriptProccessed = true
			end
		end
		
		if not healthScriptProccessed then
			local conn
		
			conn = character.ChildAdded:Connect(function(child)
				if child:IsA("Script") and child.Name == "Health" then
					child:Destroy()
					if conn then
						conn:Disconnect()
						conn = nil
					end
				end
			end)
		end

		scene:addFreshEntity(PlayerEntity.new(scene, tostring(player.UserId), player, character))
	end))
end

function PlayerEntityManagerComponent.setup(self: PlayerEntityManagerComponent, scene: SceneAccessor): ()
	-- TODO: Potential duplication.
	self.maid:giveTask(Players.PlayerAdded:Connect(function(player: Player)
		self:onPlayerAdded(player, scene)
	end))

	self.maid:giveTask(Players.PlayerRemoving:Connect(function(player)
		local entity = scene:getEntityByUuid(tostring(player.UserId))
		if entity then
			entity:remove(Entity.RemovalReason.DISCARDED) -- FUCK OFF
		end
	end))

	for _, player in Players:GetPlayers() do
		self:onPlayerAdded(player, scene) -- NOTES: Reference leak?
	end

	-- Detection

	self.maid:giveTask(scene.afterEvents.postUpdateEntities:Connect(function()
		DetectionManager.flushToClients() -- TODO: Could be a better way to do this but ehhh
	end))
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