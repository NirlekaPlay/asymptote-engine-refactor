--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local MemoryModuleTypes = require(ServerScriptService.server.world.entity.ai.memory.MemoryModuleTypes)
local Sensor = require(ServerScriptService.server.world.entity.ai.sensing.Sensor)

local SensorWrapper = {}
SensorWrapper.__index = SensorWrapper

export type SensorWrapper<T> = typeof(setmetatable({} :: {
	sensor: Sensor.Sensor<T>,
	scanRate: number,
	timeAccumulator: number,
}, SensorWrapper))

function SensorWrapper.new<T>(sensor: Sensor.Sensor<T>): SensorWrapper<T>
	return setmetatable({
		sensor = sensor,
		scanRate = sensor:getScanRate(),
		timeAccumulator = 0
	}, SensorWrapper)
end

function SensorWrapper.getRequiredMemories<T>(self: SensorWrapper<T>): { MemoryModuleTypes.MemoryModuleType<any> }
	return self.sensor:getRequiredMemories()
end

function SensorWrapper.update<T>(self: SensorWrapper<T>, agent: T, deltaTime: number): ()
	self.timeAccumulator += deltaTime

	if self.timeAccumulator >= self.scanRate then
		self.timeAccumulator = 0
		self.sensor:doUpdate(agent, deltaTime)
	end
end

return SensorWrapper