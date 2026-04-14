--!strict

--[=[
	@class NodeEvaluator
]=]
local NodeEvaluator = {}
NodeEvaluator.__index = NodeEvaluator

export type NodeEvaluator = typeof(setmetatable({} :: {
}, NodeEvaluator))

function NodeEvaluator.new(
): NodeEvaluator
	return setmetatable({
	}, NodeEvaluator)
end

function NodeEvaluator.isWaypointDoor(self: NodeEvaluator, waypoint: PathWaypoint): boolean
	return waypoint.Label == "Door" or waypoint.Label == "DoorPerpendicularPart"
end

function NodeEvaluator.getDoorBoundPartsAt(self: NodeEvaluator, atPos: Vector3): {BasePart}
	--[[local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = CollectionService:GetTagged(CollectionTags.DOOR_PATH_BOUNDS)
	return workspace:GetPartBoundsInRadius(atPos, 5, overlapParams)]]

	return {} -- TODO: Implement the door getting logic or dedicate this responsibility elsewhere
end

function NodeEvaluator.getDoorOnPathSegment(self: NodeEvaluator, fromPos: Vector3, toPos: Vector3): Door.Door?
	--[[local parts = self:getDoorBoundPartsAt(toPos)
	local dir = (toPos - fromPos)
	local length = dir.Magnitude
	local unitDir = dir / length

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = parts :: {Instance}

	local result = workspace:Raycast(fromPos, unitDir * length, raycastParams)
	if result then
		return DoorRegistry.getDoorFromPart(result.Instance)
	end]]
	return nil
end

function NodeEvaluator.canOpenDoors(self: NodeEvaluator): boolean
	return true
end

function NodeEvaluator.canOpenDoor(self: NodeEvaluator, door: Door.Door): boolean
	return true
end

return NodeEvaluator