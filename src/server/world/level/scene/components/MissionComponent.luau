--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AlertLevels = require(ReplicatedStorage.shared.world.stealth.alertlevel.AlertLevels)
local TypedRemotes = require(ReplicatedStorage.shared.network.remotes.TypedRemotes)
local SceneAccessor = require(ServerScriptService.server.world.level.scene.SceneAccessor)
local StateComponent = require(ServerScriptService.server.world.level.scene.components.registry.StateComponent)

local STATE_ALERT_LEVEL = "Mission_AlertLevel"
local STATE_ALARM_RAISED = "Mission_AlarmRaised"

local MAX_ALERT_LEVEL = 4

local ALERT_LEVELS = {
	[0] = AlertLevels.CALM,
	[1] = AlertLevels.NORMAL,
	[2] = AlertLevels.ALERT,
	[3] = AlertLevels.SEARCHING,
	[4] = AlertLevels.LOCKDOWN,
}

--[=[
	@class MissionComponent
]=]
local MissionComponent = {}
MissionComponent.__index = MissionComponent

MissionComponent.STATE_ALERT_LEVEL = STATE_ALERT_LEVEL
MissionComponent.STATE_ALARM_RAISED = STATE_ALARM_RAISED

export type MissionComponent = StateComponent.StateComponent & typeof(setmetatable({} :: {
	_scene: SceneAccessor.SceneAccessor?,
}, MissionComponent))

type SceneAccessor = SceneAccessor.SceneAccessor

function MissionComponent.new(): MissionComponent
	return setmetatable({
		_scene = nil :: SceneAccessor?,
	}, MissionComponent) :: MissionComponent
end

function MissionComponent.setup(self: MissionComponent, scene: SceneAccessor): ()
	self._scene = scene
	scene:setState(STATE_ALERT_LEVEL, 0)
	scene:setState(STATE_ALARM_RAISED, false)
end

function MissionComponent.onSceneReady(self: MissionComponent, _scene: SceneAccessor): ()
	self:_syncClients()
end

function MissionComponent.update(self: MissionComponent, _scene: SceneAccessor, _deltaTime: number): ()
end

function MissionComponent.restart(self: MissionComponent, scene: SceneAccessor): ()
	scene:setState(STATE_ALERT_LEVEL, 0)
	scene:setState(STATE_ALARM_RAISED, false)
	self:_syncClients()
end

function MissionComponent.destroy(self: MissionComponent, _scene: SceneAccessor): ()
	self._scene = nil
end

function MissionComponent.getAlertLevel(self: MissionComponent): AlertLevels.AlertLevel
	local scene = self._scene
	if not scene then
		return AlertLevels.CALM
	end

	local raw = scene:getState(STATE_ALERT_LEVEL) or 0
	local discrete = math.clamp(math.floor(raw), 0, MAX_ALERT_LEVEL)
	return ALERT_LEVELS[discrete]
end

function MissionComponent.getAlertLevelNumericValue(_self: MissionComponent, alertLevel: AlertLevels.AlertLevel): number
	for value, level in ALERT_LEVELS do
		if level == alertLevel then
			return value
		end
	end
	return 0
end

function MissionComponent.raiseAlertLevel(self: MissionComponent, amount: number): ()
	local scene = self._scene
	if not scene then return end

	local current = scene:getState(STATE_ALERT_LEVEL) or 0
	local next = math.clamp(current + amount, 0, MAX_ALERT_LEVEL)

	scene:setState(STATE_ALERT_LEVEL, next)

	if next >= 3 then
		scene:setState(STATE_ALARM_RAISED, true)
	end

	self:_syncClients()
end

function MissionComponent.resetAlertLevel(self: MissionComponent): ()
	local scene = self._scene
	if not scene then return end

	scene:setState(STATE_ALERT_LEVEL, 0)
	scene:setState(STATE_ALARM_RAISED, false)
	self:_syncClients()
end

function MissionComponent._syncClients(self: MissionComponent): ()
	TypedRemotes.AlertLevel:FireAllClients(self:getAlertLevel())
end

return MissionComponent