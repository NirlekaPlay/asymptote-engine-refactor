--!strict

--[=[
	@class CameraState
]=]
local CameraState = {}
CameraState.__index = CameraState

export type CameraState = typeof(setmetatable({} :: {
	position: Vector3,
	rotation: CFrame, -- orientation only (no translation used)
	focalLength: number,
	fStop: number,
	focusDist: number,
}, CameraState))

function CameraState.new(): CameraState
	return setmetatable({
		position = Vector3.new(),
		rotation = CFrame.identity, -- i never knew this existed lmao
		focalLength = 50,
		fStop = 2.8,
		focusDist = 10,
	}, CameraState)
end

function CameraState.lerp(a: CameraState, b: CameraState, t: number): CameraState
	local s = CameraState.new()
	s.position = a.position:Lerp(b.position, t)
	s.rotation = a.rotation:Lerp(b.rotation, t) -- quaternion slerp
	s.focalLength = a.focalLength + (b.focalLength - a.focalLength) * t
	s.fStop = a.fStop + (b.fStop - a.fStop) * t
	s.focusDist = a.focusDist + (b.focusDist - a.focusDist) * t
	return s
end

function CameraState.clone(self: CameraState): CameraState
	local s = CameraState.new()
	s.position = self.position
	s.rotation = self.rotation
	s.focalLength = self.focalLength
	s.fStop = self.fStop
	s.focusDist = self.focusDist
	return s
end

return CameraState