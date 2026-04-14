--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Brain = require(ServerScriptService.server.world.entity.ai.Brain)
local Activity = require(ServerScriptService.server.world.entity.ai.behavior.Activity)
local BehaviorWrapper = require(ServerScriptService.server.world.entity.ai.behavior.BehaviorWrapper)
local WalkToRandomPost = require(ServerScriptService.server.world.entity.ai.behavior.WalkToRandomPost)
local WalkToTargetSink = require(ServerScriptService.server.world.entity.ai.behavior.WalkToTargetSink)
local MemoryModuleTypes = require(ServerScriptService.server.world.entity.ai.memory.MemoryModuleTypes)
local MemoryStatus = require(ServerScriptService.server.world.entity.ai.memory.MemoryStatus)
local SensorFactories = require(ServerScriptService.server.world.entity.ai.sensing.SensorFactories)
local Agent = require(ServerScriptService.server.world.entity.npc.Agent)

local TestNpcAi = {}

type Agent = Agent.Agent
type Brain<T> = Brain.Brain<T>

local MEMORY_TYPES = {
	MemoryModuleTypes.TARGETABLE_ENTITIES,
	MemoryModuleTypes.LOOK_TARGET,
	MemoryModuleTypes.KILL_TARGET,
	MemoryModuleTypes.PANIC_SOURCE_ENTITY_UUID,
	MemoryModuleTypes.PRIORITIZED_ENTITY,
	MemoryModuleTypes.IS_INVESTIGATING,
	MemoryModuleTypes.FLEE_TO_POSITION,
	MemoryModuleTypes.IS_COMBAT_MODE,
	MemoryModuleTypes.IS_CURIOUS,
	MemoryModuleTypes.IS_PANICKING,
	MemoryModuleTypes.IS_FLEEING,
	MemoryModuleTypes.IS_INTIMIDATED,
	MemoryModuleTypes.DESIGNATED_POSTS,
	MemoryModuleTypes.PATROL_STATE,
	MemoryModuleTypes.CURRENT_POST,
	MemoryModuleTypes.TARGET_POST,
	MemoryModuleTypes.POST_VACATE_COOLDOWN,
	MemoryModuleTypes.CONFRONTING_TRESPASSER,
	MemoryModuleTypes.TRESPASSERS_WARNS,
	MemoryModuleTypes.TRESPASSERS_ENCOUNTERS,
	MemoryModuleTypes.REPORTING_ON,
	MemoryModuleTypes.PANIC_POSITION,
	MemoryModuleTypes.HAS_FLED,
	MemoryModuleTypes.HAS_RETREATED,
	MemoryModuleTypes.WALK_TARGET,
	MemoryModuleTypes.PATH,
	MemoryModuleTypes.CANT_REACH_WALK_TARGET_SINCE,
	MemoryModuleTypes.ATTENTION_LEVEL
}
 
local SENSOR_FACTORIES = {
	SensorFactories.VISIBLE_ENTITIES_SENSOR,
	SensorFactories.HEARING_PLAYERS_SENSOR
}

function TestNpcAi.makeBrain(agent: Agent)
	local brain = Brain.new(agent, MEMORY_TYPES, SENSOR_FACTORIES)
	TestNpcAi.initCoreActivity(brain)
	TestNpcAi.initWorkActivity(brain)
	--TestNpcAi.initPanicActivity(brain)
	--TestNpcAi.initConfrontActivity(brain)
	--TestNpcAi.initFightActivity(brain)
	brain:setCoreActivities({Activity.CORE})
	brain:setDefaultActivity(Activity.IDLE)
	brain:useDefaultActivity()
	return brain
end

function TestNpcAi.initCoreActivity(brain: Brain<Agent>): ()
	brain:addActivity(Activity.CORE, 2, {
		BehaviorWrapper.new(WalkToTargetSink.new())
	})
end

function TestNpcAi.initWorkActivity(brain: Brain<Agent>): ()
	brain:addActivityWithConditions(Activity.WORK, 4, {
		BehaviorWrapper.new(WalkToRandomPost.new()),
	}, {
		[MemoryModuleTypes.CONFRONTING_TRESPASSER] = MemoryStatus.VALUE_ABSENT,
		[MemoryModuleTypes.IS_PANICKING] = MemoryStatus.VALUE_ABSENT,
		[MemoryModuleTypes.KILL_TARGET] = MemoryStatus.VALUE_ABSENT
	})
end

function TestNpcAi.initPanicActivity(brain: Brain<Agent>): ()
	brain:addActivityWithConditions(Activity.PANIC, 1, {
		BehaviorWrapper.new(SetPanicFace.new()),
		BehaviorWrapper.new(FleeToEscapePoints.new()),
		BehaviorWrapper.new(KillTarget.new()),
		BehaviorWrapper.new(PleaForMercy.new())
	}, {
		[MemoryModuleTypes.IS_PANICKING] = MemoryStatus.VALUE_PRESENT
	})
end

function TestNpcAi.initConfrontActivity(brain: Brain<Agent>): ()
	brain:addActivityWithConditions(Activity.CONFRONT, 3, {
		BehaviorWrapper.new(ReportMajorTrespasser.new())
	}, {
		[MemoryModuleTypes.IS_PANICKING] = MemoryStatus.VALUE_ABSENT,
		[MemoryModuleTypes.CONFRONTING_TRESPASSER] = MemoryStatus.VALUE_PRESENT
	})
end

function TestNpcAi.initFightActivity(brain: Brain<Agent>): ()
	brain:addActivityWithConditions(Activity.FIGHT, 1, {
		BehaviorWrapper.new(KillCaughtOrThreateningPlayers.new()),
		BehaviorWrapper.new(KillTargetableEntities.new()),
		BehaviorWrapper.new(KillTarget.new()),
		BehaviorWrapper.new(RetreatToCombatNodes.new())
	}, {
		[MemoryModuleTypes.IS_COMBAT_MODE] = MemoryStatus.VALUE_PRESENT,
	})
end

function TestNpcAi.updateActivity(guard: Agent): ()
	guard:getBrain():setActiveActivityToFirstValid({
		Activity.FIGHT, Activity.PANIC, Activity.CONFRONT, Activity.WORK
	})
end

function TestNpcAi.onDiedOrDestroyed(guard: Agent): ()
	return
end

return TestNpcAi