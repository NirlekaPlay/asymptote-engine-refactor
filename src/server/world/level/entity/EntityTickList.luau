--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Entity = require(ServerScriptService.server.world.entity.Entity)
local LinkedHashMap = require(ReplicatedStorage.shared.util.collections.LinkedHashMap)

local UNPROTECTED_LOOP_CALL = (workspace:GetAttribute("UnprotectedEntityLoopCall") == true) or false

local function try(func, ...)
	return xpcall(func, function(err)
		warn(tostring(err) .. "\n" .. debug.traceback())
		return false, err
	end, ...)
end

local function safeWaitExecute(func: (...any) -> (...any), ...: any): ()
	local caller = coroutine.running()
	local completed = false

	local worker = task.spawn(function(...)
		func(...)
		completed = true
		task.defer(caller)
	end, ...)

	task.spawn(function()
		while not completed do
			if coroutine.status(worker) == "dead" then
				completed = true
				task.defer(caller)
				return
			end
			task.wait()
		end
	end)

	return coroutine.yield()
end

--[=[
	@class EntityTickList
]=]
local EntityTickList = {}
EntityTickList.__index = EntityTickList

export type EntityTickList = typeof(setmetatable({} :: {
	active: LinkedHashMap<Entity, boolean>,
	passive: LinkedHashMap<Entity, boolean>,
	iterated: LinkedHashMap<Entity, boolean>?
}, EntityTickList))

type Entity = Entity.Entity
type LinkedHashMap<K, V> = LinkedHashMap.LinkedHashMap<K, V>

function EntityTickList.new(): EntityTickList
	return setmetatable({
		active = LinkedHashMap.new(),
		passive = LinkedHashMap.new(),
		iterated = nil :: LinkedHashMap<Entity, boolean>?
	}, EntityTickList)
end

function EntityTickList.add(self: EntityTickList, entity: Entity): ()
	self:_ensureActiveIsNotIterated()
	self.active:put(entity, true)
end

function EntityTickList.remove(self: EntityTickList, entity: Entity): ()
	self:_ensureActiveIsNotIterated()
	self.active:remove(entity, true)
end

function EntityTickList.has(self: EntityTickList, entity: Entity): boolean
	return self.active:has(entity)
end

function EntityTickList.forEach(self: EntityTickList, fn: (entity: Entity) -> ()): ()
	if self.iterated ~= nil then
		error("Only one concurrent iteration supported")
	else
		self.iterated = self.active

		local iterating = self.active -- Is this necessary?

		local f = function()
			debug.profilebegin("entities")
			for entity in iterating:keys() do
				fn(entity)
			end
			debug.profileend()
		end

		if not UNPROTECTED_LOOP_CALL then
			try(f)
		else
			safeWaitExecute(f)
		end

		self.iterated = nil
	end
end

--

function EntityTickList._ensureActiveIsNotIterated(self: EntityTickList): ()
	if self.iterated == self.active then
		self.passive:clear()

		self.active:forEach(function(entity)
			self.passive:put(entity, true)
		end)

		local map = self.active
		self.active = self.passive
		self.passive = map
	end
end

return EntityTickList