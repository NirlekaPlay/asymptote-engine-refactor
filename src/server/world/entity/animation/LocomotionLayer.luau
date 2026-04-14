--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local AnimationDefinitions = require(ServerScriptService.server.world.entity.animation.AnimationDefinitions)
local AnimationTrackPlayer = require(ServerScriptService.server.world.entity.animation.AnimationTrackPlayer)

local PRIORITY = Enum.AnimationPriority.Movement
local TRANSITION = 0.15

local LocomotionLayer = {}
LocomotionLayer.__index = LocomotionLayer

export type LocomotionParams = {
	isPathfinding: boolean,
	isRunning: boolean,
	isJumping: boolean,
	isFalling: boolean,
	speed: number,
}

export type LocomotionLayer = typeof(setmetatable({} :: {
	_player: AnimationTrackPlayer.AnimationTrackPlayer,
	_paused: boolean,  -- true when an Override overlay is active
}, LocomotionLayer))

function LocomotionLayer.new(animator: Animator): LocomotionLayer
	local player = AnimationTrackPlayer.new(animator)

	for name, defs in AnimationDefinitions.Locomotion do
		-- just load the first/only for now. weighted random is a later concern
		player:preload(name, defs[1].id)
	end

	return setmetatable({
		_player = player,
		_paused = false,
	}, LocomotionLayer)
end

function LocomotionLayer.setPaused(self: LocomotionLayer, paused: boolean)
	if paused and not self._paused then
		self._player:stop(0.1)
	end
	self._paused = paused
end

function LocomotionLayer.update(self: LocomotionLayer, params: LocomotionParams, activeOverlay: string?)
	if self._paused then
		return
	end

	-- if a blend overlay is handling the standing pose, don't fight it with idle
	if activeOverlay then
		local def = AnimationDefinitions.Overlays[activeOverlay]
		if def and def.blendMode == "Blend" and not params.isPathfinding and not params.isJumping and not params.isFalling then
			self._player:stop(0.2)
			return
		end
	end

	local targetState: string
	if params.isJumping then
		targetState = "jump"
	elseif params.isFalling then
		targetState = "fall"
	elseif params.isPathfinding then
		targetState = if params.isRunning then "run" else "walk"
	else
		targetState = "idle"
	end

	self._player:play(targetState, PRIORITY, TRANSITION)
end

return LocomotionLayer