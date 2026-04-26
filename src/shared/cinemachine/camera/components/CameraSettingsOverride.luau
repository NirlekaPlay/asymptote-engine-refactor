--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraState = require(ReplicatedStorage.shared.cinemachine.camera.CameraState)
local PipelineComponent = require(ReplicatedStorage.shared.cinemachine.camera.PipelineComponent)

--[=[
	@class CameraSettingsOverride
	Finalizer stage component that overrides lens/DOF settings on a per-vcam basis.
	Fields set to `nil` are left untouched (inherited from upstream state).
]=]
local CameraSettingsOverride = {}
CameraSettingsOverride.__index = CameraSettingsOverride

export type CameraSettings = {
	focalLength: number?,
	fStop: number?,
	focusDist: number?,
}

export type CameraSettingsOverride = PipelineComponent.PipelineComponent & typeof(setmetatable({} :: {

}, CameraSettingsOverride))

function CameraSettingsOverride.new(settings: CameraSettings?): CameraSettingsOverride
	local s = (settings or {}) :: CameraSettings
	return setmetatable({
		stage = PipelineComponent.Stage.FINALIZE,
		focalLength = s.focalLength,
		fStop = s.fStop,
		focusDist = s.focusDist,
	}, CameraSettingsOverride) :: CameraSettingsOverride
end

function CameraSettingsOverride:process(dt: number, inputState: CameraState.CameraState): CameraState.CameraState
	local out = inputState:clone()
	if self.focalLength ~= nil then
		out.focalLength = self.focalLength
	end
	if self.fStop ~= nil then
		out.fStop = self.fStop
	end
	if self.focusDist ~= nil then
		out.focusDist = self.focusDist
	end
	return out
end

return CameraSettingsOverride