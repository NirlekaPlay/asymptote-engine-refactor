--!strict

local DEFAULT_GROUP = "Default"

--[=[
	@class DebrisManager
]=]
local DebrisManager = {}
DebrisManager.__index = DebrisManager

export type DebrisManager = typeof(setmetatable({} :: {
	registry: { [any]: { [Instance]: true }}
}, DebrisManager))

function DebrisManager.new(): DebrisManager
	return setmetatable({
		registry = {}
	}, DebrisManager)
end

--

function DebrisManager.register(self: DebrisManager, instance: Instance, group: any): ()
	group = group or DEFAULT_GROUP
	if self.registry[group] == nil then
		self.registry[group] = {}
	end

	self.registry[group][instance] = true
end

function DebrisManager.registerInstances(self: DebrisManager, instances: {Instance}, group: any): ()
	for _, instance in instances do
		self:register(instance, group)
	end
end

function DebrisManager.scheduleDestroy(self: DebrisManager, instance: Instance, delay: number): ()
	if self.registry[DEFAULT_GROUP] == nil then
		self.registry[DEFAULT_GROUP] = {}
	end

	self.registry[DEFAULT_GROUP][instance] = true

	task.delay(delay, function()
		if instance and instance.Parent then
			self.registry[DEFAULT_GROUP][instance] = nil
			instance:Destroy()
		end
	end)
end

function DebrisManager.destroyGroup(self: DebrisManager, group: any): ()
	if not group or not self.registry[group] then
		return
	end

	for instance in self.registry[group] do
		instance:Destroy()
		self.registry[group][instance] = nil
	end
end

function DebrisManager.destroyAll(self: DebrisManager): ()
	for _, group in self.registry do
		for instance in self.registry[group] do
			instance:Destroy()
			self.registry[group][instance] = nil
		end
	end

	table.clear(self.registry)
end

return DebrisManager