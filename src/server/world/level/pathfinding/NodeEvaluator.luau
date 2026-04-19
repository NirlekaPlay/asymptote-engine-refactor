--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Draw = require(ReplicatedStorage.shared.thirdparty.Draw)
local CollectionTags = require(ServerScriptService.server.world.collection.CollectionTags)
local TraversableDoor = require(ServerScriptService.server.world.level.pathfinding.TraversableDoor)
local SceneAccessor = require(ServerScriptService.server.world.level.scene.SceneAccessor)

--[=[
	@class NodeEvaluator
]=]
local NodeEvaluator = {}
NodeEvaluator.__index = NodeEvaluator

export type NodeEvaluator = typeof(setmetatable({} :: {
	currentScene: SceneAccessor.SceneAccessor
}, NodeEvaluator))

function NodeEvaluator.new(
	scene: SceneAccessor.SceneAccessor
): NodeEvaluator
	return setmetatable({
		currentScene = scene
	}, NodeEvaluator)
end

--

function NodeEvaluator.isWaypointDoor(self: NodeEvaluator, waypoint: PathWaypoint): boolean
	return waypoint.Label == "Door" or waypoint.Label == "DoorPerpendicularPart"
end

function NodeEvaluator.getDoorBoundPartsAt(self: NodeEvaluator, atPos: Vector3): {BasePart}
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = CollectionService:GetTagged(CollectionTags.DOOR_PATH_BOUNDS)
	return workspace:GetPartBoundsInRadius(atPos, 5, overlapParams)
end

function NodeEvaluator.getDoorOnPathSegment(self: NodeEvaluator, fromPos: Vector3, toPos: Vector3): TraversableDoor.TraversableDoor?
	local scene = self.currentScene
	local midPoint = (fromPos + toPos) / 2
	local segmentDir = toPos - fromPos
	local segmentLength = segmentDir.Magnitude

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = scene.propManager:getDoorBoundParts()

	-- use a box oriented along the path segment to only catch doors the path goes through
	local segmentCFrame = CFrame.lookAt(midPoint, toPos) * CFrame.new(0, 1, 0) -- offset up to door body height
	local segmentSize = Vector3.new(2, 4, segmentLength) -- width, tall enough to catch door, length of segment

	local parts = workspace:GetPartBoundsInBox(segmentCFrame, segmentSize, overlapParams)
	if parts[1] then
		return scene.propManager:getDoorFromPart(parts[1])
	end

	return nil
end

function NodeEvaluator.canOpenDoors(self: NodeEvaluator): boolean
	return true
end

function NodeEvaluator.canOpenDoor(self: NodeEvaluator, door: TraversableDoor.TraversableDoor): boolean
	return true
end

return NodeEvaluator