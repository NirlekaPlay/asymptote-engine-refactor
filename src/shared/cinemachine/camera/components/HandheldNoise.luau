--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraState = require(ReplicatedStorage.shared.cinemachine.camera.CameraState)
local PipelineComponent = require(ReplicatedStorage.shared.cinemachine.camera.PipelineComponent)

--[=[
	@class HandheldNoise
]=]
local HandheldNoise = {}
HandheldNoise.__index = HandheldNoise

local PRESETS = {
	light = {
		breatheAmp = Vector3.new(0.001, 0.001, 0),
		breatheFreq = 0.8,
		swayAmp = Vector3.new(0.0001, 0.0001, 0),
		swayFreq = 1.4,
		jitterAmp = Vector3.new(0.00001, 0.00001, 0),
		jitterFreq = 100,
		rotBreathe = Vector3.new(0.004, 0.003, 0.001),
		rotSway = Vector3.new(0.0002, 0.009, 0.004), -- swayyyy
		rotJitter = Vector3.new(0.015, 0.012, 0.005),
	},
	medium = {
		breatheAmp = Vector3.new(0.003, 0.002, 0),
		breatheFreq = 0.9,
		swayAmp = Vector3.new(0.007, 0.005, 0),
		swayFreq = 1.6,
		jitterAmp = Vector3.new(0.0008, 0.0006, 0),
		jitterFreq = 10.0,
		rotBreathe = Vector3.new(0.09, 0.07, 0.02),
		rotSway = Vector3.new(0.28, 0.22, 0.09),
		rotJitter = Vector3.new(0.03, 0.024, 0.01),
	},
	heavy = {
		breatheAmp = Vector3.new(0.006, 0.004, 0),
		breatheFreq = 1.1,
		swayAmp = Vector3.new(0.014, 0.010, 0),
		swayFreq = 1.9,
		jitterAmp = Vector3.new(0.0016, 0.0012, 0),
		jitterFreq = 12.0,
		rotBreathe = Vector3.new(0.18, 0.13, 0.05),
		rotSway = Vector3.new(0.55, 0.42, 0.18),
		rotJitter = Vector3.new(0.06, 0.048, 0.02),
	},
}

local SEEDS = {
	breathe = { px = {0, 0}, py = {17, 0}, pz = {0, 34}, rx = {51, 0}, ry = {0, 68}, rz = {85, 0} },
	sway = { px = {200, 0}, py = {0, 217}, pz = {234, 0}, rx = {251, 0}, ry = {0, 268}, rz = {285, 0} },
	jitter = { px = {400, 0}, py = {0, 417}, pz = {434, 0}, rx = {451, 0}, ry = {0, 468}, rz = {485, 0} },
}

export type Preset = "light" | "medium" | "heavy"

export type HandheldNoise = PipelineComponent.PipelineComponent & typeof(setmetatable({} :: {
	stage: typeof(PipelineComponent.Stage.NOISE),
	_cfg: typeof(PRESETS.medium),
	_amplitudeGain: number,
	_frequencyGain: number,
	_time: number,
	_active: boolean,
}, HandheldNoise))

local function n(t: number, sA: number, sB: number, freq: number, amp: number): number
	return math.noise(t * freq + sA, sB, 0) * amp
end

local function sampleLayer(
	t: number,
	seeds: typeof(SEEDS.breathe),
	freq: number,
	posAmp: Vector3,
	rotAmp: Vector3
): CFrame
	local px = n(t, seeds.px[1], seeds.px[2], freq, posAmp.X)
	local py = n(t, seeds.py[1], seeds.py[2], freq, posAmp.Y)
	local pz = n(t, seeds.pz[1], seeds.pz[2], freq, posAmp.Z)
	local rx = n(t, seeds.rx[1], seeds.rx[2], freq, rotAmp.X)
	local ry = n(t, seeds.ry[1], seeds.ry[2], freq, rotAmp.Y)
	local rz = n(t, seeds.rz[1], seeds.rz[2], freq, rotAmp.Z)
	return CFrame.new(px, py, pz)
		* CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
end

function HandheldNoise.new(preset: Preset?): HandheldNoise
	local cfg = PRESETS[preset or "medium"] or PRESETS.medium
	return setmetatable({
		stage = PipelineComponent.Stage.NOISE,
		_cfg = cfg,
		_amplitudeGain = 1,
		_frequencyGain = 1,
		_time = math.random() * 1000,
		_active = true,
	}, HandheldNoise) :: HandheldNoise
end

function HandheldNoise.process(
	self: HandheldNoise,
	dt: number,
	inputState: CameraState.CameraState
): CameraState.CameraState
	if not self._active then
		return inputState
	end

	self._time += dt

	local t = self._time
	local cfg = self._cfg
	local ag = self._amplitudeGain
	local fg = self._frequencyGain

	local breathe = sampleLayer(
		t, SEEDS.breathe,
		cfg.breatheFreq * fg,
		cfg.breatheAmp * ag,
		cfg.rotBreathe * ag
	)

	local sway = sampleLayer(
		t, SEEDS.sway,
		cfg.swayFreq * fg,
		cfg.swayAmp * ag,
		cfg.rotSway * ag
	)

	local jitter = sampleLayer(
		t, SEEDS.jitter,
		cfg.jitterFreq * fg,
		cfg.jitterAmp * ag,
		cfg.rotJitter * ag
	)

	local combined = breathe * sway * jitter
	inputState.position = inputState.position + combined.Position
	inputState.rotation = inputState.rotation * (combined - combined.Position)

	return inputState
end

function HandheldNoise.setGain(self: HandheldNoise, amplitude: number, frequency: number): ()
	self._amplitudeGain = amplitude
	self._frequencyGain = frequency
end

function HandheldNoise.onDeactivate(self: HandheldNoise): ()
	self._time = 0
end

return HandheldNoise