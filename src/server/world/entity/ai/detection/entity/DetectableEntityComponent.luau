--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local DetectionContext = require(ServerScriptService.server.world.entity.ai.detection.entity.DetectionContext)
local Agent = require(ServerScriptService.server.world.entity.npc.Agent)

local DetectableComponent = {}
DetectableComponent.__index = DetectableComponent

local Builder = {}
Builder.__index = Builder

export type DetectableComponent = typeof(setmetatable({} :: {
	uuid: string,
	_getPosition: () -> Vector3,
	_detectionRadius: number,
	_getBasePriority: (context: DetectionContext.DetectionContext) -> number,
	_getDetectionMultiplier: (context: DetectionContext.DetectionContext) -> number,
	_getMovementMultiplier: (context: DetectionContext.DetectionContext) -> number,
	_shouldRaiseDetection: ((agent: Agent.Agent, context: DetectionContext.DetectionContext) -> boolean)?,
}, DetectableComponent))

export type Builder = typeof(setmetatable({} :: {
	_uuid: string,
	_getPosition: (() -> Vector3)?,
	_detectionRadius: number?,
	_getBasePriority: ((context: DetectionContext.DetectionContext) -> number)?,
	_getDetectionMultiplier: ((context: DetectionContext.DetectionContext) -> number)?,
	_getMovementMultiplier: ((context: DetectionContext.DetectionContext) -> number)?,
	_shouldRaiseDetection: ((agent: Agent.Agent, context: DetectionContext.DetectionContext) -> boolean)?,
}, Builder))

function DetectableComponent.builder(uuid: string): Builder
	return setmetatable({
		_uuid = uuid,
		_getPosition = nil,
		_detectionRadius = nil,
		_getBasePriority = nil,
		_getDetectionMultiplier = nil,
		_getMovementMultiplier = nil,
		_shouldRaiseDetection = nil,
	}, Builder) :: Builder
end

function Builder.withPosition(self: Builder, fn: () -> Vector3): Builder
	self._getPosition = fn
	return self
end

function Builder.withDetectionRadius(self: Builder, radius: number): Builder
	self._detectionRadius = radius
	return self
end

function Builder.withBasePriority(self: Builder, fn: (context: DetectionContext.DetectionContext) -> number): Builder
	self._getBasePriority = fn
	return self
end

function Builder.withDetectionMultiplier(self: Builder, fn: (context: DetectionContext.DetectionContext) -> number): Builder
	self._getDetectionMultiplier = fn
	return self
end

function Builder.withMovementMultiplier(self: Builder, fn: (context: DetectionContext.DetectionContext) -> number): Builder
	self._getMovementMultiplier = fn
	return self
end

function Builder.withShouldRaiseDetection(self: Builder, fn: (agent: any, context: DetectionContext.DetectionContext) -> boolean): Builder
	self._shouldRaiseDetection = fn
	return self
end

function Builder.build(self: Builder): DetectableComponent
	assert(self._getPosition, "DetectableComponent: withPosition is required")
	assert(self._detectionRadius, "DetectableComponent: withDetectionRadius is required")
	assert(self._getBasePriority, "DetectableComponent: withBasePriority is required")

	return setmetatable({
		uuid = self._uuid,
		_getPosition = self._getPosition,
		_detectionRadius = self._detectionRadius,
		_getBasePriority = self._getBasePriority,
		_getDetectionMultiplier = self._getDetectionMultiplier or function() return 1.0 end,
		_getMovementMultiplier = self._getMovementMultiplier or function() return 1.0 end,
		_shouldRaiseDetection = self._shouldRaiseDetection,
	}, DetectableComponent) :: DetectableComponent
end

function DetectableComponent.getUuid(self: DetectableComponent): string
	return self.uuid
end

function DetectableComponent.getPosition(self: DetectableComponent): Vector3
	return self._getPosition()
end

function DetectableComponent.getBaseDetectionRadius(self: DetectableComponent): number
	return self._detectionRadius
end

function DetectableComponent.getBasePriority(self: DetectableComponent, context: DetectionContext.DetectionContext): number
	return self._getBasePriority(context)
end

function DetectableComponent.getPriority(self: DetectableComponent, context: DetectionContext.DetectionContext): number
	return self:getBasePriority(context) * self:getMovementMultiplier(context)
end

function DetectableComponent.getDetectionMultiplier(self: DetectableComponent, context: DetectionContext.DetectionContext): number
	return self._getDetectionMultiplier(context)
end

function DetectableComponent.getMovementMultiplier(self: DetectableComponent, context: DetectionContext.DetectionContext): number
	return self._getMovementMultiplier(context)
end

function DetectableComponent.shouldRaiseDetection(self: DetectableComponent, agent: Agent.Agent, context: DetectionContext.DetectionContext): boolean
	if self._shouldRaiseDetection then
		return self._shouldRaiseDetection(agent, context)
	end
	return true
end

return DetectableComponent