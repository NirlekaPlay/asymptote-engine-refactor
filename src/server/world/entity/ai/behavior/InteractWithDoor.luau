--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Agent = require(ServerScriptService.server.world.entity.npc.Agent)
local MemoryModuleTypes = require(ServerScriptService.server.world.entity.ai.memory.MemoryModuleTypes)
local MemoryStatus = require(ServerScriptService.server.world.entity.ai.memory.MemoryStatus)
local TraversableDoor = require(ServerScriptService.server.world.level.pathfinding.TraversableDoor)

--[=[
	@class InteractWithDoor
]=]
local InteractWithDoor = {}
InteractWithDoor.__index = InteractWithDoor
InteractWithDoor.ClassName = "InteractWithDoor"

export type InteractWithDoor = typeof(setmetatable({} :: {
	sanityInduceThread: thread?
}, InteractWithDoor))

type MemoryModuleType<T> = MemoryModuleTypes.MemoryModuleType<T>
type MemoryStatus = MemoryStatus.MemoryStatus
type Agent = Agent.Agent

function InteractWithDoor.new(): InteractWithDoor
	return setmetatable({
		minDuration = nil :: number?,
		maxDuration = nil :: number?,
		sanityInduceThread = nil :: thread?
	}, InteractWithDoor)
end

local MEMORY_REQUIREMENTS = {
	[MemoryModuleTypes.PATH] = MemoryStatus.VALUE_PRESENT,
	[MemoryModuleTypes.WALK_TARGET] = MemoryStatus.VALUE_PRESENT
}

function InteractWithDoor.getMemoryRequirements(self: InteractWithDoor): { [MemoryModuleType<any>]: MemoryStatus }
	return MEMORY_REQUIREMENTS
end

function InteractWithDoor.checkExtraStartConditions(self: InteractWithDoor, agent: Agent): boolean
	local isPathDone = agent:getBrain():getMemory(MemoryModuleTypes.PATH):get():isDone()
	if isPathDone then
		return false
	end

	return true
end

function InteractWithDoor.canStillUse(self: InteractWithDoor, agent: Agent): boolean
	return agent:getBrain():hasMemoryValue(MemoryModuleTypes.PATH)
		and not agent:getBrain():getMemory(MemoryModuleTypes.PATH):get():isDone()
end

function InteractWithDoor.doStart(self: InteractWithDoor, agent: Agent): ()
	return
end

function InteractWithDoor.doStop(self: InteractWithDoor, agent: Agent): ()
	return
end

function InteractWithDoor.doUpdate(self: InteractWithDoor, agent: Agent, deltaTime: number): ()
	local path = agent:getBrain():getMemory(MemoryModuleTypes.PATH):get()
	if path:isDone() then
		return
	end

	local nextNode = path:getNextNode()
	local prevNode = path:getPreviousNode()
	local nodeEvaluator = agent:getNavigation():getPathfinder():getNodeEvaluator()

	if not nodeEvaluator:isWaypointDoor(nextNode) then
		return
	end

	local door = nodeEvaluator:getDoorOnPathSegment(prevNode.Position, nextNode.Position)
	if not door then
		return
	end

	if not door:isClosed() and not door:isClosing() then
		self:scheduleClose(door)
		return
	end

	local agentPos = agent:getPosition()
	local side = door:getSideRelativeTo(agentPos)
	door:open(side, true)
	self:scheduleClose(door)
end

function InteractWithDoor.scheduleClose(self: InteractWithDoor, door: TraversableDoor.TraversableDoor): ()
	if self.sanityInduceThread then return end
	self.sanityInduceThread = task.delay(1, function()
		if not door:isClosed() or door:isClosing() then
			door:close()
		end
		self.sanityInduceThread = nil
	end)
end

return InteractWithDoor