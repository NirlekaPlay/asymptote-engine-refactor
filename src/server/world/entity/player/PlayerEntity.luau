--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Maid = require(ReplicatedStorage.shared.util.misc.Maid)
local Entity = require(ServerScriptService.server.world.entity.Entity)
local Brain = require(ServerScriptService.server.world.entity.ai.Brain)
local EntityInLevelCallback = require(ServerScriptService.server.world.level.entity.EntityInLevelCallback)
local Scene = require(ServerScriptService.server.world.level.scene.Scene)

--[=[
	@class PlayerEntity
]=]
local PlayerEntity = {}
PlayerEntity.__index = PlayerEntity

type Brain = Brain.Brain<any>

function PlayerEntity.new(scene, character: Model & { Humanoid: Humanoid, HumanoidRootPart: BasePart })
	local self = setmetatable({}, PlayerEntity)

	self.character = character
	self.humanoid = character.Humanoid

	--

	self.levelCallback = EntityInLevelCallback.NULL
	self.typeId = "npc"
	self.uuid = "UNSET"
	self._maid = Maid.new()

	self._maid:giveTask(character.HumanoidRootPart:GetPropertyChangedSignal("Position"):Connect(function()
		self.levelCallback:onMove()
	end))

	self._maid:giveTask(self.humanoid.Died:Once(function()
		self:remove(Entity.RemovalReason.KILLED)
	end))

	self._maid:giveTask(self.character.AncestryChanged:Connect(function()
		if not self.character:IsDescendantOf(game) then
			self:remove(Entity.RemovalReason.DISCARDED)
		end
	end))

	return self
end

--

function PlayerEntity.update(self, deltaTime: number): ()
	return
end

function PlayerEntity.getPosition(self): Vector3
	return self.character.HumanoidRootPart.Position
end

function PlayerEntity.getWorldInstance(self): Instance
	return self.character
end

function PlayerEntity.getUuid(self): string
	return self.uuid
end

function PlayerEntity.setLevelCallback(self, levelCallback): ()
	self.levelCallback = levelCallback
end

function PlayerEntity.remove(self, removalReason: Entity.RemovalReason): ()
	self.removalReason = removalReason
	self.levelCallback:onRemove(removalReason)
	self:onRemove() -- ???
end

function PlayerEntity.isRemoved(self): boolean
	return self.removalReason ~= nil
end

function PlayerEntity.setPosToCFrame(self, cframe: CFrame): ()
	self.character:PivotTo(cframe)
end

--

function PlayerEntity.getScene(self): Scene.Scene
	return self.scene
end

function PlayerEntity.onRemove(self): ()
	self._maid:doCleaning()
end

return PlayerEntity