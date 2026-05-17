--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Entity = require(ServerScriptService.server.world.entity.Entity)
local LevelLoader = require(ServerScriptService.server.world.level.LevelLoader)
local LevelCallback = require(ServerScriptService.server.world.level.entity.LevelCallback)
local Scene = require(ServerScriptService.server.world.level.scene.Scene)

local TICK_RATE = 1 / 20
local MAX_TICKS_PER_FRAME = 5

--[=[
	@class Level
]=]
local Level = {}
Level.__index = Level

export type Level = typeof(setmetatable({} :: {
	isHandlingTick: boolean,
	--
	scene: Scene.Scene?,
	--
	_accumulator: number
}, Level))

type Entity = Entity.Entity
type LevelCallback = LevelCallback.LevelCallback<Entity>

function Level.new(): Level
	local this = setmetatable({
		isHandlingTick = false,
		scene = nil :: Scene.Scene?,
		_accumulator = 0
	}, Level)

	return this
end

--

function Level.init(self: Level): ()
	local levelFolder = workspace:FindFirstChild("DebugMission") or workspace:FindFirstChild("Level")
	if levelFolder and levelFolder:IsA("Folder") then
		self.scene = LevelLoader.loadFromFolder(levelFolder)
	end
end

function Level.update(self: Level, deltaTime: number): ()
	if self.isHandlingTick then
		return
	end

	self.isHandlingTick = true
	self._accumulator += deltaTime

	local ticks = 0

	while self._accumulator >= TICK_RATE and ticks < MAX_TICKS_PER_FRAME do
		self:doUpdate(TICK_RATE)
		self._accumulator -= TICK_RATE
		ticks += 1
	end

	if self._accumulator > TICK_RATE * MAX_TICKS_PER_FRAME then
		self._accumulator = 0
	end

	self.isHandlingTick = false
end

function Level.doUpdate(self: Level, deltaTime: number): ()
	if self.scene then
		self.scene:update(deltaTime)
	end
end

return Level