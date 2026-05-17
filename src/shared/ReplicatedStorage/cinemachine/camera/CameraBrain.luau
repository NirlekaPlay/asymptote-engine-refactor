--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlendStack = require(ReplicatedStorage.shared.cinemachine.camera.BlendStack)
local CameraState = require(ReplicatedStorage.shared.cinemachine.camera.CameraState)
local VirtualCamera = require(ReplicatedStorage.shared.cinemachine.camera.VirtualCamera)
local Maid = require(ReplicatedStorage.shared.util.misc.Maid)

local ATTRIBUTE_FSTOP = "FStop"
local ATTRIBUTE_FOCUS_DIST = "FocusDistance"
local ATTRIBUTE_FOCAL_LENGTH = "FocalLength"
local ATTRIBUTE_ALLOW_OVERRIDE = "AllowOverride"
local ALLOW_CAMERA_SETTINGS_OVERRIDE = true

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

function CameraBrain.exposeAttributes(self: CameraBrain): ()
	local camera = self.camera

	camera:SetAttribute(ATTRIBUTE_FSTOP, self.fStop)
	camera:SetAttribute(ATTRIBUTE_FOCUS_DIST, self.focusDist)
	camera:SetAttribute(ATTRIBUTE_FOCAL_LENGTH, self.focalLength)
	camera:SetAttribute(ATTRIBUTE_ALLOW_OVERRIDE, ALLOW_CAMERA_SETTINGS_OVERRIDE)

	self._maid:giveTask(
		camera:GetAttributeChangedSignal(ATTRIBUTE_FSTOP):Connect(function()
			local val = camera:GetAttribute(ATTRIBUTE_FSTOP)
			if val ~= self.fStop then
				self:setFStop(val)
			end
		end)
	)

	self._maid:giveTask(
		camera:GetAttributeChangedSignal(ATTRIBUTE_FOCUS_DIST):Connect(function()
			local val = camera:GetAttribute(ATTRIBUTE_FOCUS_DIST)
			if val ~= self.focusDist then
				self:setFocusDistance(val)
			end
		end)
	)

	self._maid:giveTask(
		camera:GetAttributeChangedSignal(ATTRIBUTE_FOCAL_LENGTH):Connect(function()
			local val = camera:GetAttribute(ATTRIBUTE_FOCAL_LENGTH)
			print(val, self.focalLength)
			if val ~= self.focalLength then
				print(val)
				self:setFocalLength(val)
			end
		end)
	)

	self._maid:giveTask(
		camera:GetAttributeChangedSignal(ATTRIBUTE_ALLOW_OVERRIDE):Connect(function()
			local val = camera:GetAttribute(ATTRIBUTE_ALLOW_OVERRIDE)
			ALLOW_CAMERA_SETTINGS_OVERRIDE = val
		end)
	)
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
	debug.profilebegin("CameraBrain.update")
	local state = self._blendStack:update(deltaTime)

	self.camera.CFrame = CFrame.new(state.position) * state.rotation.Rotation

	if ALLOW_CAMERA_SETTINGS_OVERRIDE then
		if state.focalLength ~= self.focalLength then
		self:setFocalLength(state.focalLength)
		end
		
		if state.focusDist ~= self.focalLength then
			self:setFocusDistance(state.focusDist)
		end

		if state.fStop ~= self.fStop then
			self:setFStop(state.fStop)
		end
	end

	debug.profileend()
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
	self.camera:SetAttribute(ATTRIBUTE_FOCAL_LENGTH, fl)
end

function CameraBrain.setFocusDistance(self: CameraBrain, distance: number): ()
	if distance <= 0 then
		distance = 0.1
	end

	self.focusDist = distance
	self:setFStop()
	self.camera:SetAttribute(ATTRIBUTE_FOCUS_DIST, distance)
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

	self.camera:SetAttribute(ATTRIBUTE_FSTOP, currentFStop)
end 

--

function CameraBrain.destroy(self: CameraBrain): ()
	self._maid:doCleaning()
end

return CameraBrain