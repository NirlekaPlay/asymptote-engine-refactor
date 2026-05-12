--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerStatusRegistry = require(ServerScriptService.server.player.PlayerStatusRegistry)
local Maid = require(ReplicatedStorage.shared.util.misc.Maid)
local PlayerStatusTypes = require(ReplicatedStorage.shared.world.stealth.playerstatus.PlayerStatusTypes)
local Entity = require(ServerScriptService.server.world.entity.Entity)
local Brain = require(ServerScriptService.server.world.entity.ai.Brain)
local DetectableEntityComponent = require(ServerScriptService.server.world.entity.ai.detection.entity.DetectableEntityComponent)
local EntityInLevelCallback = require(ServerScriptService.server.world.level.entity.EntityInLevelCallback)
local Scene = require(ServerScriptService.server.world.level.scene.Scene)
local StateComponentRegistry = require(ServerScriptService.server.world.level.scene.components.registry.StateComponentRegistry)

--[=[
	@class PlayerEntity
]=]
local PlayerEntity = {}
PlayerEntity.__index = PlayerEntity

type Brain = Brain.Brain<any>

function PlayerEntity.new(scene, uuid: string, player: Player, character: Model & { Humanoid: Humanoid, HumanoidRootPart: BasePart })
	local self = setmetatable({}, PlayerEntity)

	self.player = player
	self.character = character
	self.humanoid = character.Humanoid

	--

	self.levelCallback = EntityInLevelCallback.NULL
	self.typeId = "player"
	self.uuid = uuid
	self._maid = Maid.new()

	self.detectableComponent = DetectableEntityComponent.builder(self.uuid)
		:withPosition(function()
			return self.character.HumanoidRootPart.Position
		end)
		:withDetectionRadius(50)
		:withBasePriority(function(context)
			context = context or {} -- NIL NIL NIL MF HOW TF IS IT NIL YOU RETARDED CUNTS
			-- JESUS FUCKING CHRIST
			-- IT SEEMS LIKE ALL OF THESE CODES ARE SO FUCKING RETARDED
			-- NIL MY FUCKING ASS
			-- I PASSED THAT SHIT AND IT WORKS AND IT NOW IT FUCKING DOESNT
			-- WHO FUCKING DESIGNED THIS SHIT
			-- OH YEAH THATS ME YOU RETARDS
			-- BUT YOU STILL HAVE NO RIGHT TO PASS MY ASS A FUCKING NIL
			-- OH WHATS THIS NOW IT FUCKING THROWS ME A COMPLETELY DIFFERENT ERROR WHENEVER I LEAVE
			-- WHAT THE FUCK IS WRONG WITH YOU
			-- DID THEY FUCKING USE AI OR SOME SHIT
			--[=[
				ServerScriptService.server.world.entity.player.PlayerEntity:51: attempt to index nil with 'getHighestDetectableStatus'
				ServerScriptService.server.world.level.entity.EntityTickList:10
				ServerScriptService.server.world.entity.player.PlayerEntity:51
				ServerScriptService.server.world.entity.ai.detection.entity.DetectableEntityComponent:104 function getBasePriority
				ServerScriptService.server.world.entity.ai.detection.entity.DetectableEntityComponent:108 function getPriority
				ServerScriptService.server.world.entity.ai.detection.DetectionManager:47 function processPerception
				ServerScriptService.server.world.entity.npc.AbstractNpc:205 function update
				ServerScriptService.server.world.level.scene.Scene:155
				ServerScriptService.server.world.level.entity.EntityTickList:62
				ServerScriptService.server.world.level.entity.EntityTickList:9 function try
				ServerScriptService.server.world.level.entity.EntityTickList:60 function forEach
				ServerScriptService.server.world.level.scene.Scene:150 function update
				ServerScriptService.server.world.level.Level:60 function doUpdate
				ServerScriptService.server.world.level.Level:47 function update
				ServerScriptService.server:29 function onPostSimulation

				JESUS FUCKING CHRIST
				A CALL STACK?
				DIDNT KNOW THEY STACKED SHIT THAT HIGH

				AND NOW IM FUCKING THRISTY
				WHERE THE FUCK IS MY WATER GLASS

				ITS LIKE FUCKING 12:14 AM

				WHERES MY FUCKING GLASS OF WATER YOU CUNTS

				11:05 AM

				Next day.

				Fixed it. I was supposed to do the plastiche o qualcosa di merda
				But I fucking fixed it.

				voglio un applauso.
			--]=]
			local statusHolder = PlayerStatusRegistry.getPlayerStatusHolder(self.player)
			if not statusHolder then
				return 0
			end

			local status = statusHolder:getHighestDetectableStatus(context.isVisible or false, context.isHeard or false)
			if not status then
				return 0
			end
			return status:getPriorityLevel()
		end)
		:withDetectionMultiplier(function(context)
			local statusHolder = PlayerStatusRegistry.getPlayerStatusHolder(self.player)
			local status = statusHolder:getHighestDetectableStatus(context.isVisible or false, context.isHeard or false)
			if not status then
				return 1.0
			end
			return status:getDetectionSpeedModifier()
		end)
		:withMovementMultiplier(function(context)
			if context.isHeard then
				local vel = self.character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude
				return 1 + (vel / 16)
			else
				return 1
			end
		end)
		:withShouldRaiseDetection(function(agent, context)
			local statusHolder = PlayerStatusRegistry.getPlayerStatusHolder(self.player)
			local status = statusHolder:getHighestDetectableStatus(context.isVisible or false, context.isHeard or false)
			if not status then
				return false
			end

			if status ~= PlayerStatusTypes.DISGUISED then
				return true
			end

			local agentEnforceClass = (agent :: any).enforceClass
			local disguise = statusHolder:getDisguise()
			if not agentEnforceClass[disguise] then
				return false
			end

			local condition = agentEnforceClass[disguise]
			local mission = self:getScene():getComponent(StateComponentRegistry.Types.MISSION)
			local alertLevel = mission:getAlertLevel()
			local alertValue = mission:getAlertLevelNumericValue(alertLevel)

			if condition >= 5 then
				return true
			elseif condition == 4 and alertValue >= 3 then
				return true
			elseif condition == 3 and alertValue >= 0 then
				return true
			elseif condition == 2 and alertValue >= 1 then
				return true
			elseif condition == 1 and alertValue >= 2 then
				return true
			end

			return false
		end)
		:build()

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
	-- Fuck you Roblox.

	local currentPos = self:getPosition()
	local lastPos = self.lastPos
	if currentPos ~= lastPos then
		self.levelCallback:onMove()
	end

	lastPos = currentPos
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

function PlayerEntity.getPlayer(self): Player
	return self.player
end

--

function PlayerEntity.getScene(self): Scene.Scene
	return self.scene
end

function PlayerEntity.onRemove(self): ()
	self._maid:doCleaning()
	local holder = PlayerStatusRegistry.getPlayerStatusHolder(self.player)
	if holder then
		holder:clearAllStatuses()
	end
end

return PlayerEntity