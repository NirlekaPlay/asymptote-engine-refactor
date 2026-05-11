--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local DetectableEntity = require(ServerScriptService.server.world.entity.ai.detection.entity.DetectableEntity)
local DetectionAgent = require(ServerScriptService.server.world.entity.ai.detection.DetectionAgent)
local DetectionTracker = require(ServerScriptService.server.world.entity.ai.detection.DetectionTracker)
local DetectionContext = require(ServerScriptService.server.world.entity.ai.detection.entity.DetectionContext)

local DECAY_RATE_PER_SEC = 0.01 / 0.045 -- ≈ 0.222 (Sec. 1(d) of Plan doc.)
local QUICK_DETECTION_RANGE = 10
local QUIK_DETECTION_MULTIPLIER = 3.33
local BASE_DETECTION_TIME = 1.25

--[=[
	@class DetectionManager

	Handles what an entity can detect.
]=]
local DetectionManager = {}
DetectionManager.__index = DetectionManager

export type DetectionManager = typeof(setmetatable({} :: {
	agent: DetectionAgent.DetectionAgent,
	trackers: { [DetectableEntity.DetectableEntity]: DetectionTracker.DetectionTracker },
	highestTarget: DetectableEntity.DetectableEntity?
}, DetectionManager))

function DetectionManager.new(agent: DetectionAgent.DetectionAgent): DetectionManager
	return setmetatable({
		agent = agent,
		trackers = {},
		highestTarget = nil :: DetectableEntity.DetectableEntity?
	}, DetectionManager)
end

function DetectionManager.processPerception(
	self: DetectionManager,
	perceived: {DetectableEntity.DetectableEntity},
	contexts: {[string]: DetectionContext.DetectionContext},
	deltaTime: number
): ()
	local seenThisFrame: { [DetectableEntity.DetectableEntity]: boolean } = {}

	local priorityFloor = 0
	for entity, tracker in self.trackers do
		if tracker.value >= 1 then
			priorityFloor = math.max(priorityFloor, entity:getPriority(contexts[tracker.source:getUuid()]))
		end
	end

	for _, detectable in perceived do
		local context = contexts[detectable:getUuid()]
		local dist = (self.agent:getPosition() - detectable:getPosition()).Magnitude

		if dist > detectable:getBaseDetectionRadius() then
			continue
		end

		if not detectable:shouldRaiseDetection(self.agent :: any, context) then
			continue
		end

		local priority = detectable:getPriority(context)
		if priority < priorityFloor then
			continue
		end

		local tracker = self:getOrCreateTracker(detectable, context)
		local speed = self:calculateSpeed(detectable, dist, context)
		tracker:increase(speed * deltaTime)
		seenThisFrame[detectable] = true
	end

	for entity, tracker in self.trackers do
		if not seenThisFrame[entity] then
			if tracker.value >= 1 then
				continue
			end

			-- FUCK SEPERATION OF CONCERNS AT THIS POINT
			-- TODO: FUCK
			if self.agent:getScene():getEntityByUuid(entity:getUuid()) == nil then
				self.trackers[entity] = nil
				continue
			end

			tracker:decay(DECAY_RATE_PER_SEC, deltaTime)

			if tracker.value <= 0 then
				self.trackers[entity] = nil
			end
		end
	end

	self:updateHighestPriority()
end

function DetectionManager.updateHighestPriority(self: DetectionManager): ()
	local bestTarget: DetectableEntity.DetectableEntity? = nil
	local highestScore = -1
	local activeFloor = -1

	-- Step 1: Find the floor based on what is ALREADY at 1.0 value
	for entity, tracker in self.trackers do
		if tracker.value >= 1.0 then
			activeFloor = math.max(activeFloor, entity:getBasePriority(tracker:getContext()))
		end
	end

	-- Step 2: Only consider entities that meet or beat that floor
	for entity, tracker in self.trackers do
		local priority = entity:getBasePriority(tracker:getContext())
		
		if priority < activeFloor then
			continue
		end

		-- Tie-breaking: If priorities are same, focus on the one closest to being fully detected
		local score = priority + tracker.value 
		
		if score > highestScore then
			highestScore = score
			bestTarget = entity
		end
	end

	self.highestTarget = bestTarget
end

function DetectionManager.getOrCreateTracker(
	self: DetectionManager,
	entity: DetectableEntity.DetectableEntity,
	context: DetectionContext.DetectionContext
): DetectionTracker.DetectionTracker
	local tracker = self.trackers[entity]

	if not tracker then
		tracker = DetectionTracker.new(entity, context or {})
		self.trackers[entity] = tracker
	else
		tracker.context = if context ~= nil then context else {} -- FUCK YOU ABSOLUTE FUCKING FUCK YOU RETARDED ASSHOLES
	end

	return tracker
end

function DetectionManager.calculateSpeed(
	self: DetectionManager,
	entity: DetectableEntity.DetectableEntity,
	distance: number,
	context: DetectionContext.DetectionContext
): number
	local speedMultiplier = entity:getDetectionMultiplier(context)

	if distance <= QUICK_DETECTION_RANGE then
		speedMultiplier *= QUIK_DETECTION_MULTIPLIER
	end

	speedMultiplier *= entity:getMovementMultiplier(context)

	local progressRate = (1 / BASE_DETECTION_TIME) * speedMultiplier

	return progressRate
end

return DetectionManager