--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local DetectableEntity = require(ServerScriptService.server.world.entity.ai.detection.entity.DetectableEntity)
local DetectionContext = require(ServerScriptService.server.world.entity.ai.detection.entity.DetectionContext)

--[=[
	@class DetectionTracker
]=]
local DetectionTracker = {}
DetectionTracker.__index = DetectionTracker

export type DetectionTracker = typeof(setmetatable({} :: {
	source: DetectableEntity.DetectableEntity,
	value: number,
	lastSeenAt: number,
	context: DetectionContext.DetectionContext,
	wasCappedLastFrame: boolean
}, DetectionTracker))

function DetectionTracker.new(source: DetectableEntity.DetectableEntity, context: DetectionContext.DetectionContext): DetectionTracker
	return setmetatable({
		source = source,
		value = 0.0,
		lastSeenAt = os.clock(),
		context = context,
		wasCappedLastFrame = false
	}, DetectionTracker)
end

function DetectionTracker.getContext(self: DetectionTracker): DetectionContext.DetectionContext
	return self.context
end

function DetectionTracker.increase(self: any, amount: number): ()
	self.value = math.clamp(self.value + amount, 0, 1)
	self.lastSeenAt = os.clock()
end

function DetectionTracker.decay(self: any, rate: number, dt: number): ()
	self.value = math.max(0, self.value - (rate * dt))
end

return DetectionTracker