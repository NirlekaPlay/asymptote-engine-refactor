--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlendStack = require(ReplicatedStorage.shared.cinemachine.camera.BlendStack)
local CameraState = require(ReplicatedStorage.shared.cinemachine.camera.CameraState)
local VirtualCamera = require(ReplicatedStorage.shared.cinemachine.camera.VirtualCamera)
local Maid = require(ReplicatedStorage.shared.util.misc.Maid)

--[=[
	@class CameraBrain
]=]
local CameraBrain = {}
CameraBrain.__index = CameraBrain

export type CameraBrain = typeof(setmetatable({} :: {
	focalLength: number,
	fStop: number,
	focusDist: number,
	sensorHeight: number,
	camera: Camera,
	instances: {
		dof: DepthOfFieldEffect,
		bloom: BloomEffect
	},
	--
	_maid: Maid.Maid,
	_blendStack: BlendStack.BlendStack
}, CameraBrain))

function CameraBrain.new(
	focalLength: number,
	fStop: number,
	focusDist: number,
	sensorHeight: number,
	camera: Camera,
	instances: {
		dof: DepthOfFieldEffect,
		bloom: BloomEffect
	}
): CameraBrain
	return setmetatable({
		focalLength= focalLength,
		fStop = fStop,
		focusDist = focusDist,
		sensorHeight = sensorHeight,
		camera = camera,
		instances = instances,
		--
		_maid = Maid.new(),
		_blendStack = BlendStack.new()
	}, CameraBrain)
end

function CameraBrain.init(self: CameraBrain): ()
	local seedState = CameraState.new()
	seedState.focalLength = self.focalLength
	seedState.fStop = self.fStop
	seedState.focusDist = self.focusDist
	self._blendStack._seedState = seedState

	self:setFocalLength(self.focalLength)
end

--

function CameraBrain.setActiveCamera(
	self: CameraBrain,
	vcam: VirtualCamera.VirtualCamera,
	duration: number,
	curve: BlendStack.BlendCurve?
): ()
	self._blendStack:pushBlend(vcam, duration, curve)
end

function CameraBrain.update(self: CameraBrain, deltaTime: number): ()
	local state = self._blendStack:update(deltaTime)

	self.camera.CFrame = CFrame.new(state.position) * state.rotation.Rotation

	self:setFocalLength(state.focalLength)
	self:setFocusDistance(state.focusDist)
	self:setFStop(state.fStop)
end

--

function CameraBrain.setFocalLength(self: CameraBrain, fl: number): ()
	if fl <= 0 then
		return
	end

	local fovRadians = 2 * math.atan(self.sensorHeight / (2 * fl))

	self.focalLength = fl
	self.camera.FieldOfView = math.deg(fovRadians)
	self:setFStop()
end

function CameraBrain.setFocusDistance(self: CameraBrain, distance: number): ()
	if distance <= 0 then
		distance = 0.1
	end

	self.focusDist = distance
	self:setFStop()
end

function CameraBrain.setFStop(self: CameraBrain, fStop: number?): ()
	local currentFStop = fStop or self.fStop
	self.fStop = currentFStop

	local dof = self.instances.dof
	local bloom = self.instances.bloom

	local focusDistance = self.focusDist
	local c = 0.03
	local dofDepth = (2 * focusDistance^2 * currentFStop * c) / (self.focalLength^2)
	local inFocusRadius = dofDepth * 0.5

	local intensity = math.clamp(1 / (currentFStop / 1.4), 0, 1)

	dof.FocusDistance = focusDistance
	dof.InFocusRadius = inFocusRadius
	dof.FarIntensity = intensity
	dof.NearIntensity = intensity * 0.5

	-- smaller fStop = Larger Aperture = More Light/Glow
	-- We map f-stop (1.4 to 16) to Bloom Intensity
	local bloomBase = 1.0
	local intensityAdjust = math.clamp(2 / currentFStop, 0, 2) -- f/1.4 is bright, f/16 is dim
	
	-- min size should be 21
	bloom.Intensity = bloomBase * intensityAdjust
	bloom.Size = 21 + (100 * (1 / currentFStop - 1 / 16))
end 

--

function CameraBrain.destroy(self: CameraBrain): ()
	self._maid:doCleaning()
end

return CameraBrain