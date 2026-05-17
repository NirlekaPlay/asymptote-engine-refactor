--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraState = require(ReplicatedStorage.shared.cinemachine.camera.CameraState)
local PipelineComponent = require(ReplicatedStorage.shared.cinemachine.camera.PipelineComponent)

local STAGE_ORDER: { PipelineComponent.Stage } = {
	PipelineComponent.Stage.BODY,
	PipelineComponent.Stage.AIM,
	PipelineComponent.Stage.NOISE,
	PipelineComponent.Stage.FINALIZE
}

--[=[
	@class VirtualCamera
]=]
local VirtualCamera = {}
VirtualCamera.__index = VirtualCamera

export type VirtualCamera = typeof(setmetatable({} :: {
	priority: number,
	_components: { [string]: PipelineComponent.PipelineComponent },
	_state: CameraState.CameraState,
}, VirtualCamera))

function VirtualCamera.new(): VirtualCamera
	return setmetatable({
		priority = 0,
		_components = {},
		_state = CameraState.new(),
	}, VirtualCamera)
end

function VirtualCamera.addComponent(self: VirtualCamera, component: PipelineComponent.PipelineComponent): ()
	local stage = component.stage
	assert(table.find(STAGE_ORDER, stage), ("Unknown pipeline stage %q"):format(stage))
	if self._components[stage] then
		warn(("[VirtualCamera] Replacing existing %s component"):format(stage))
	end
	self._components[stage] = component
end

function VirtualCamera.removeComponent(self: VirtualCamera, stage: string): ()
	self._components[stage] = nil
end

function VirtualCamera.getComponent(self: VirtualCamera, stage: string): PipelineComponent.PipelineComponent?
	return self._components[stage]
end

function VirtualCamera.computeState(self: VirtualCamera, dt: number): CameraState.CameraState
	local state = self._state:clone()

	for _, stage in STAGE_ORDER do
		local comp = self._components[stage]
		if comp then
			state = comp:process(dt, state)
		end
	end

	self._state = state
	return state
end

function VirtualCamera.setPriority(self: VirtualCamera, priority: number): ()
	self.priority = priority
end

function VirtualCamera.onActivate(self: VirtualCamera): ()
	for _, comp in self._components do
		if comp.onActivate then
			comp:onActivate()
		end
	end
end

function VirtualCamera.onDeactivate(self: VirtualCamera): ()
	for _, comp in self._components do
		if comp.onDeactivate then
			comp:onDeactivate()
		end
	end
end

return VirtualCamera