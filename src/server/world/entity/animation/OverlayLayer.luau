--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local AnimationDefinitions = require(ServerScriptService.server.world.entity.animation.AnimationDefinitions)
local AnimationTrackPlayer = require(ServerScriptService.server.world.entity.animation.AnimationTrackPlayer)

--[=[
	@class OverlayLayer
]=]
local OverlayLayer = {}
OverlayLayer.__index = OverlayLayer

export type OverlayLayer = typeof(setmetatable({} :: {
	_player: AnimationTrackPlayer.AnimationTrackPlayer,
	_current: string?,
	_onOverride: (active: boolean) -> (),
}, OverlayLayer))

function OverlayLayer.new(animator: Animator, onOverride: (active: boolean) -> ()): OverlayLayer
	local player = AnimationTrackPlayer.new(animator)

	for name, animDef in AnimationDefinitions.OverlayAnims do
		player:preload(name, animDef.id)
	end

	return setmetatable({
		_player = player,
		_current = nil :: string?,
		_onOverride = onOverride,
	}, OverlayLayer)
end

function OverlayLayer.setOverlay(self: OverlayLayer, name: string?)
	if self._current == name then return end

	-- clear old override if we're switching away from one
	if self._current then
		local oldDef = AnimationDefinitions.Overlays[self._current]
		if oldDef and oldDef.blendMode == "Override" then
			self._onOverride(false)
		end
	end

	self._current = name

	if name == nil then
		self._player:stop(0.2)
		return
	end

	local def = AnimationDefinitions.Overlays[name]
	if not def then
		warn("OverlayLayer: no def for overlay", name)
		return
	end

	if def.blendMode == "Override" then
		self._onOverride(true)
	end

	self._player:play(name, def.priority, def.transitionTime)
end

return OverlayLayer