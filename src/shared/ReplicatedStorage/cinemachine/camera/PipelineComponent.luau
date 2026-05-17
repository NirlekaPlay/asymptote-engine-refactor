--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraState = require(ReplicatedStorage.shared.cinemachine.camera.CameraState)

export type Stage = "Body" | "Aim" | "Noise" | "Finalize"

export type PipelineComponent = {
	stage: Stage,
	-- dt: deltaTime. inputState: state coming in from previous stage.
	-- Returns the mutated state for the next stage.
	process: (self: any, dt: number, inputState: CameraState.CameraState) -> CameraState.CameraState,
	-- Called when this vcam becomes live (starts being blended to/is active)
	onActivate: ((self: any) -> ())?,
	-- Called when this vcam is fully inactive (blend complete, not live)
	onDeactivate: ((self: any) -> ())?,
}

return {
	Stage = {
		BODY = "Body" :: "Body",
		AIM = "Aim" :: "Aim",
		NOISE = "Noise" :: "Noise",
		FINALIZE = "Finalize" :: "Finalize"
	}
}