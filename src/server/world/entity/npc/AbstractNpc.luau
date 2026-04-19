--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DebugPackets = require(ReplicatedStorage.shared.network.DebugPackets)
local Maid = require(ReplicatedStorage.shared.util.misc.Maid)
local Entity = require(ServerScriptService.server.world.entity.Entity)
local Brain = require(ServerScriptService.server.world.entity.ai.Brain)
local BodyRotationControl = require(ServerScriptService.server.world.entity.ai.control.BodyRotationControl)
local FaceControl = require(ServerScriptService.server.world.entity.ai.control.FaceControl)
local MoveControl = require(ServerScriptService.server.world.entity.ai.control.MoveControl)
local RagdollControl = require(ServerScriptService.server.world.entity.ai.control.RagdollControl)
local MemoryModuleTypes = require(ServerScriptService.server.world.entity.ai.memory.MemoryModuleTypes)
local PathNavigation = require(ServerScriptService.server.world.entity.ai.navigation.PathNavigation)
local HumanoidAnimator = require(ServerScriptService.server.world.entity.animation.HumanoidAnimator)
local TestNpcAi = require(ServerScriptService.server.world.entity.npc.TestNpcAi)
local EntityInLevelCallback = require(ServerScriptService.server.world.level.entity.EntityInLevelCallback)
local Scene = require(ServerScriptService.server.world.level.scene.Scene)
local CollisionGroupTypes = require(ServerScriptService.server.world.physics.collision.CollisionGroupTypes)

local DEFAULT_SIGHT_RADIUS = 50
local DEFAULT_HEARING_RADIUS = 10
local DEFAULT_PERIPH_VISION_ANGLE = 180

--[=[
	@class AbstractNpc
]=]
local AbstractNpc = {}
AbstractNpc.__index = AbstractNpc

type Brain = Brain.Brain<any>

function AbstractNpc.new(scene, character: Model & { Humanoid: Humanoid, HumanoidRootPart: BasePart })
	local self = setmetatable({}, AbstractNpc)

	local humanoid = character.Humanoid

	self.uuid = "UNSET"
	self.scene = scene
	self.character = character
	self.primaryPart = character.PrimaryPart :: BasePart
	self.levelCallback = EntityInLevelCallback.NULL
	self.brain = TestNpcAi.makeBrain(self :: any)
	self.moveControl = MoveControl.new(humanoid)
	self.pathNavigation = PathNavigation.new(scene, character, self.moveControl, {
		AgentRadius = 2,
		AgentHeight = 4,
		AgentCanJump = false,
		WaypointSpacing = 1,
		Costs = {
			Door = 0.1,
			DoorPerpendicularPart = 25
		}
	})
	self.bodyRotationControl = BodyRotationControl.new(character, self.pathNavigation)
	self.faceControl = FaceControl.new(character)
	self.faceControl:setFace("Neutral")
	self.typeId = "npc"
	self.humanoid = (character :: any).Humanoid :: Humanoid
	self.random = Random.new( )
	self._maid = Maid.new()

	-- Animations

	self._animParams = {
		isPathfinding = false,
		isRunning = false,
		isJumping = false,
		isFalling = false,
		speed = 0,
	}
	self._overlayState = {
		isGuarding = false,
		isReporting = false,
		isStunned = false,
	}
	self._animator = HumanoidAnimator.new(humanoid)

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Parent == character then
				part.CollisionGroup = CollisionGroupTypes.NPC_CHAR
			else
				part.CollisionGroup = CollisionGroupTypes.NON_COLLIDE_WITH_PLAYER
			end
		end
	end

	local descendantAddedConnection = character.DescendantAdded:Connect(function(inst)
		-- make the Agent not collide with players
		-- exclude "RagdollColliderPart" as those are ragdoll parts.
		-- making them not have collision will result in weird looking ragdolls.
		if inst:IsA("BasePart") and inst.Name ~= RagdollControl.RAGDOLL_COLLIDER_PART_NAME then
			inst.CollisionGroup = CollisionGroupTypes.NON_COLLIDE_WITH_PLAYER
		end
	end)

	self._maid:giveTask(character.HumanoidRootPart:GetPropertyChangedSignal("Position"):Connect(function()
		self.levelCallback:onMove()
	end))

	self._maid:giveTask(descendantAddedConnection)

	self._maid:giveTask(humanoid.Running:Connect(function(speed: number)
		self._animParams.speed = speed
		self._animParams.isPathfinding = speed > 0
	end))

	self._maid:giveTask(humanoid.Jumping:Connect(function()
		self._animParams.isJumping = true
	end))

	self._maid:giveTask(humanoid.FreeFalling:Connect(function()
		self._animParams.isFalling = true
		self._animParams.isJumping = false
	end))

	self._maid:giveTask(humanoid.StateChanged:Connect(function(_, new: Enum.HumanoidStateType)
		if new == Enum.HumanoidStateType.Landed
		or new == Enum.HumanoidStateType.Running then
			self._animParams.isJumping = false
			self._animParams.isFalling = false
		end
	end))

	return self
end

--

function AbstractNpc.update(self, deltaTime: number): ()
	debug.profilebegin("Npc.update")

	debug.profilebegin("brain")
	TestNpcAi.updateActivity(self)
	self.brain:update(deltaTime)
	self:sendDebugPackets()
	debug.profileend()

	debug.profilebegin("animator")
	self._animator:update(self._animParams, self._overlayState)
	debug.profileend()

	debug.profilebegin("controls")
	self.bodyRotationControl:update(deltaTime)
	debug.profileend()

	debug.profileend()
end

function AbstractNpc.getPosition(self): Vector3
	return self.character.HumanoidRootPart.Position
end

function AbstractNpc.getWorldInstance(self): Instance
	return self.character
end

function AbstractNpc.getUuid(self): string
	return self.uuid
end

function AbstractNpc.setLevelCallback(self, levelCallback): ()
	self.levelCallback = levelCallback
end

function AbstractNpc.remove(self, removalReason: Entity.RemovalReason): ()
	self.removalReason = removalReason
	self.levelCallback:onRemove(removalReason)
	self:onRemove() -- ???
end

function AbstractNpc.isRemoved(self): boolean
	return self.removalReason ~= nil
end

function AbstractNpc.setPosToCFrame(self, cframe: CFrame): ()
	self.character:PivotTo(cframe)
end

--

function AbstractNpc.finalizeSpawn(self): ()
	-- Client tag
	local char = self.character
	local tag = char:GetAttribute("ClientTag") :: string?
	if tag and tag ~= "" then
		char:AddTag(tag)
	end

	-- Nodes for patrolling
	local nodeGroup = char:GetAttribute("Nodes")
	if nodeGroup and type(nodeGroup) == "string" then
		local nodes = self:getScene().navMesh:getPostGroup(nodeGroup)
		local nodesCount = #nodes
		self:setDesignatedPosts(nodes)

		local randomNodeIndex = self:getScene():getRandom():NextInteger(1, nodesCount)
		local selectedRandomNode = nodes[randomNodeIndex]
		local nodeCframe = selectedRandomNode.cframe :: CFrame

		local offsetPosition = nodeCframe.Position
		char:PivotTo(CFrame.new(offsetPosition, offsetPosition + nodeCframe.LookVector))
	end

	-- Finalize
	char.Parent = workspace
end

function AbstractNpc.getPrimaryPart(self): BasePart
	return self.primaryPart
end

function AbstractNpc.getHumanoid(self): Humanoid
	return self.humanoid
end

function AbstractNpc.getBodyRotationControl(self): BodyRotationControl.BodyRotationControl
	return self.bodyRotationControl
end

function AbstractNpc.getRandom(self): Random
	return self.random
end

function AbstractNpc.getBlockPosition(self): Vector3
	local currentPos = self.character.HumanoidRootPart.Position :: Vector3
	return Vector3.new(
		math.round(currentPos.X),
		math.round(currentPos.Y - 2),
		math.round(currentPos.Z)
	)
end

function AbstractNpc.getNavigation(self): PathNavigation.PathNavigation
	return self.pathNavigation
end

function AbstractNpc.getFaceControl(self): FaceControl.FaceControl
	return self.faceControl
end

--

function AbstractNpc.getOverlayState(self): HumanoidAnimator.OverlayState
	return self._overlayState
end

function AbstractNpc.getAnimParams(self): HumanoidAnimator.AnimationParams
	return self._animParams
end

--

function AbstractNpc.getScene(self): Scene.Scene
	return self.scene
end

function AbstractNpc.getBrain(self): Brain
	return self.brain
end

--

function AbstractNpc.getCharacterName(self): string
	return self.character:GetAttribute("CharName")
end

function AbstractNpc.sendDebugPackets(self): ()
	DebugPackets.sendEntityBrain(self)
end

function AbstractNpc.setDesignatedPosts(self, posts): ()
	self.brain:setMemory(MemoryModuleTypes.DESIGNATED_POSTS, posts)
end

function AbstractNpc.getSightRadius(self): number
	return (self.character:GetAttribute("SightRadius") :: number?) or DEFAULT_SIGHT_RADIUS
end

function AbstractNpc.getHearingRadius(self): number
	return (self.character:GetAttribute("HearingRadius") :: number?) or DEFAULT_HEARING_RADIUS
end

function AbstractNpc.getPeripheralVisionAngle(self): number
	return (self.character:GetAttribute("PeriphAngle") :: number?) or DEFAULT_PERIPH_VISION_ANGLE
end

--

function AbstractNpc.onRemove(self): ()
	self._maid:doCleaning()
end

return AbstractNpc