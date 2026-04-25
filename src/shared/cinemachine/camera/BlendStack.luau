--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraState = require(ReplicatedStorage.shared.cinemachine.camera.CameraState)
local VirtualCamera = require(ReplicatedStorage.shared.cinemachine.camera.VirtualCamera)

local Curves = {
	Cut       = function(_t: number) return 1 end,
	Linear    = function(t:  number) return t end,
	EaseIn    = function(t:  number) return t * t end,
	EaseOut   = function(t:  number) return t * (2 - t) end,
	EaseInOut = function(t:  number)
		t = t * 2
		if t < 1 then return 0.5 * t * t end
		t -= 1
		return -0.5 * (t * (t - 2) - 1)
	end,
}

local EnumCurves = {
	CUT = "Cut",
	LINEAR = "Linear",
	EASE_IN = "EaseIn",
	EASE_OUT = "EaseOut",
	EASE_IN_OUT = "EaseInOut"
}

export type BlendCurve = "Cut" | "Linear" | "EaseIn" | "EaseOut" | "EaseInOut"

export type Blend = {
	from: VirtualCamera.VirtualCamera,
	to: VirtualCamera.VirtualCamera,
	duration: number,
	curve: BlendCurve,
	elapsed: number,
	fromSnapshot: CameraState.CameraState,
}

--[=[
	@class BlendStack
]=]
local BlendStack = {}
BlendStack.__index = BlendStack

export type BlendStack = typeof(setmetatable({} :: {
	-- stack of active blends, newest at the back
	_stack: { Blend },
	-- the camera that is fully live when the stack is empty
	_activeVCam: VirtualCamera.VirtualCamera?,
	_seedState: CameraState.CameraState?
}, BlendStack))

function BlendStack.new(): BlendStack
	return setmetatable({
		_stack = {},
		_activeVCam = nil :: VirtualCamera.VirtualCamera?,
		_seedState = nil :: CameraState.CameraState?
	}, BlendStack)
end

function BlendStack.getActiveVCam(self: BlendStack): VirtualCamera.VirtualCamera?
	return self._activeVCam
end

--[=[
	Request a transition to `toVCam`.
	If a blend is already running, the outgoing state is snapshotted so
	we get a blend-of-blends rather than a jump.
]=]
function BlendStack.pushBlend(
	self: BlendStack,
	toVCam: VirtualCamera.VirtualCamera,
	duration: number,
	curve: BlendCurve?
): ()
	local fromVCam = self._activeVCam

	local snapshot: CameraState.CameraState
	if #self._stack > 0 then
		-- we're mid-blend, snapshot the blended output right now
		snapshot = self:evaluate(0) -- dt=0 reads current position
	elseif fromVCam then
		snapshot = fromVCam._state:clone()
	else
		snapshot = if self._seedState
				then self._seedState:clone()
				else CameraState.new()
	end

	if duration <= 0 then
		-- hard cut, skip the stack entirely
		if fromVCam then fromVCam:onDeactivate() end
		self._activeVCam = toVCam
		self._stack = {}
		toVCam:onActivate()
		return
	end

	table.insert(self._stack, {
		from = fromVCam,
		to = toVCam,
		duration = duration,
		curve = curve or EnumCurves.EASE_IN_OUT,
		elapsed = 0,
		fromSnapshot = snapshot,
	} :: Blend)

	self._activeVCam = toVCam
	toVCam:onActivate()
end

--[=[
	Advance all blends, clean up completed ones, return blended CameraState.
]=]
function BlendStack.update(self: BlendStack, dt: number): CameraState.CameraState
	return self:evaluate(dt)
end

function BlendStack.evaluate(self: BlendStack, dt: number): CameraState.CameraState
	for _, blend in self._stack do
		blend.elapsed += dt
	end

	while #self._stack > 0 and self._stack[1].elapsed >= self._stack[1].duration do
		local done = table.remove(self._stack, 1) :: Blend
		if done.from then done.from:onDeactivate() end
	end

	if #self._stack == 0 then
		if self._activeVCam then
			return self._activeVCam:computeState(dt)
		else
			return if self._seedState
				then self._seedState:clone()
				else CameraState.new()
		end
	end

	local state = self._stack[1].fromSnapshot:clone()
	for _, blend in self._stack do
		local t = math.clamp(blend.elapsed / blend.duration, 0, 1)
		local curved = Curves[blend.curve](t)
		local toState = blend.to:computeState(dt)
		state = CameraState.lerp(state, toState, curved)
	end

	return state
end

return BlendStack