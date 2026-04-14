--!strict

--[=[
	@class AnimationTrackPlayer
]=]
local AnimationTrackPlayer = {}
AnimationTrackPlayer.__index = AnimationTrackPlayer

export type AnimationTrackPlayer = typeof(setmetatable({} :: {
	_animator: Animator,
	_cache: {[string]: AnimationTrack},
	_current: AnimationTrack?,
	_currentName: string?,
}, AnimationTrackPlayer))

function AnimationTrackPlayer.new(animator: Animator): AnimationTrackPlayer
	return setmetatable({
		_animator = animator,
		_cache = {},
		_current = nil :: AnimationTrack?,
		_currentName = nil :: string?,
	}, AnimationTrackPlayer)
end

function AnimationTrackPlayer.preload(self: AnimationTrackPlayer, name: string, assetId: string): ()
	local anim = Instance.new("Animation")
	anim.AnimationId = assetId
	self._cache[name] = self._animator:LoadAnimation(anim)
end

function AnimationTrackPlayer.play(
	self: AnimationTrackPlayer,
	name: string,
	priority: Enum.AnimationPriority,
	transitionTime: number
): ()
	if self._currentName == name then
		return
	end

	local track = self._cache[name]
	if not track then
		warn("AnimationTrackPlayer: no track loaded for", name)
		return
	end

	if self._current then
		self._current:Stop(transitionTime)
	end

	track.Priority = priority
	track:Play(transitionTime)
	self._current = track
	self._currentName = name
end

function AnimationTrackPlayer.stop(self: AnimationTrackPlayer, transitionTime: number)
	if self._current then
		self._current:Stop(transitionTime)
		self._current = nil
		self._currentName = nil
	end
end

function AnimationTrackPlayer.getCurrentName(self: AnimationTrackPlayer): string?
	return self._currentName
end

function AnimationTrackPlayer.adjustSpeed(self: AnimationTrackPlayer, speed: number)
	if self._current then
		self._current:AdjustSpeed(speed)
	end
end

return AnimationTrackPlayer