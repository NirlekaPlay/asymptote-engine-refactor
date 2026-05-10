--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local DetectableEntity = require(ServerScriptService.server.world.entity.ai.detection.entity.DetectableEntity)

--[=[
	@class DetectableComponent
]=]
local DetectableComponent = {}
DetectableComponent.__index = DetectableComponent

export type DetectableComponent = DetectableEntity.DetectableEntity & {
	_getPosition: () -> Vector3,
	_detectionRadius: number | () -> number,
	_basePriority: number,
	_detectionMultiplier: number,
	_getMovementMultiplier: (() -> number)?,
}

function DetectableComponent.new(
	uuid: string,
	getPositionFn: () -> Vector3,
	opts: {
		detectionRadius: number | () -> number,
		basePriority: number?,
		detectionMultiplier: number?,
		getMovementMultiplier: (() -> number)?,
	}?
): DetectableComponent
	local o = (opts or {}) :: any
	return setmetatable({
		uuid = uuid,
		_getPosition = getPositionFn,
		_detectionRadius = opts.detectionRadius,
		_basePriority = o.basePriority or 1.0,
		_detectionMultiplier = o.detectionMultiplier or 1.0,
		_getMovementMultiplier = o.getMovementMultiplier,
	}, DetectableComponent) :: any
end

function DetectableComponent.getPosition(self: DetectableComponent): Vector3
	return self._getPosition()
end

function DetectableComponent.getBasePriority(self: DetectableComponent): number
	return self._basePriority
end

function DetectableComponent.getPriority(self: DetectableComponent): number
	return self._basePriority * self:getMovementMultiplier()
end

function DetectableComponent.getBaseDetectionRadius(self: DetectableComponent): number
	if self._detectionRadius then
		if type(self._detectionRadius) == "number" then
			return self._detectionRadius
		else
			return self._detectionRadius()
		end
	end

	return 0
end

function DetectableComponent.getDetectionMultiplier(self: DetectableComponent): number
	return self._detectionMultiplier
end

function DetectableComponent.getMovementMultiplier(self: DetectableComponent): number
	if self._getMovementMultiplier then
		return self._getMovementMultiplier()
	end
	return 1.0
end

return DetectableComponent