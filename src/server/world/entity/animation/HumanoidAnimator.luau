--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local LocomotionLayer = require(ServerScriptService.server.world.entity.animation.LocomotionLayer)
local OverlayLayer = require(ServerScriptService.server.world.entity.animation.OverlayLayer)

--[=[
	@class HumanoidAnimator
]=]
local HumanoidAnimator = {}
HumanoidAnimator.__index = HumanoidAnimator

export type AnimationParams = {
	isPathfinding: boolean,
	isRunning: boolean,
	isJumping: boolean,
	isFalling: boolean,
	speed: number,
}

export type OverlayState = {
	isGuarding: boolean,
	isReporting: boolean,
	isStunned: boolean,
}

export type HumanoidAnimator = typeof(setmetatable({} :: {
	_locomotion: LocomotionLayer.LocomotionLayer,
	_overlay: OverlayLayer.OverlayLayer,
}, HumanoidAnimator))

function HumanoidAnimator.new(humanoid: Humanoid): HumanoidAnimator
	local animator = humanoid:FindFirstChildOfClass("Animator")
		or Instance.new("Animator", humanoid)

	local locomotion = LocomotionLayer.new(animator)
	local overlay = OverlayLayer.new(animator, function(overrideActive: boolean)
		locomotion:setPaused(overrideActive)
	end)

	return setmetatable({
		_locomotion = locomotion,
		_overlay = overlay,
	}, HumanoidAnimator)
end

function HumanoidAnimator.update(self: HumanoidAnimator, anim: AnimationParams, overlay: OverlayState)
	-- resolve overlay priority: stunned > reporting > guarding > none
	local activeOverlay: string? = nil
	if overlay.isStunned then
		activeOverlay = "stunned"
	elseif overlay.isReporting then
		activeOverlay = "reporting"
	elseif overlay.isGuarding then
		activeOverlay = "guarding"
	end

	self._overlay:setOverlay(activeOverlay)
	self._locomotion:update(anim, activeOverlay)
end

return HumanoidAnimator