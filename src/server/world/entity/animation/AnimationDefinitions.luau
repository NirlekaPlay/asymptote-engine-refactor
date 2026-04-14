--!strict

--[=[
	@class AnimationDefinitions
]=]
local AnimationDefinitions = {}

export type AnimDef = {
	id: string,
	weight: number?,
}

export type OverlayBlendMode = "Blend" | "Override"

export type OverlayDef = {
	animName: string,
	blendMode: OverlayBlendMode,
	priority: Enum.AnimationPriority,
	transitionTime: number,
}

AnimationDefinitions.Locomotion = {
	idle = {
		{ id = "rbxassetid://180435571", weight = 9 },
		{ id = "rbxassetid://180435792", weight = 1 },
	},
	walk = {
		{ id = "rbxassetid://15719486204" },
	},
	run = {
		{ id = "rbxassetid://79947225688040" },
	},
	fall = {
		{ id = "rbxassetid://180436148" },
	},
	jump = {
		{ id = "rbxassetid://125750702" },
	},
} :: {[string]: {AnimDef}}

AnimationDefinitions.Overlays = {
	guarding = {
		animName = "guarding",
		blendMode = "Blend",
		priority = Enum.AnimationPriority.Idle,
		transitionTime = 0.3,
	},
	reporting = {
		animName = "reporting",
		blendMode = "Blend",
		priority = Enum.AnimationPriority.Action4,
		transitionTime = 0.3,
	},
	stunned = {
		animName = "stunned",
		blendMode = "Override",
		priority = Enum.AnimationPriority.Action4,
		transitionTime = 0.1,
	},
} :: {[string]: OverlayDef}

AnimationDefinitions.OverlayAnims = {
	guarding   = { id = "rbxassetid://125499080017830" },
	reporting  = { id = "rbxassetid://103855021506602" }
} :: {[string]: AnimDef}

return AnimationDefinitions