--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Entity = require(ServerScriptService.server.world.entity.Entity)
local CellManager = require(ServerScriptService.server.world.level.cell.CellManager)
local EntitySectionManager = require(ServerScriptService.server.world.level.entity.EntitySectionManager)
local EntityTickList = require(ServerScriptService.server.world.level.entity.EntityTickList)
local LevelCallback = require(ServerScriptService.server.world.level.entity.LevelCallback)
local NavMesh = require(ServerScriptService.server.world.level.navmesh.NavMesh)
local PropManager = require(ServerScriptService.server.world.level.scene.props.PropManager)

--[=[
	@class Scene
]=]
local Scene = {}
Scene.__index = Scene

export type Scene = typeof(setmetatable({} :: {
	cellManager: CellManager.CellManager,
	propManager: PropManager.PropManager,
	entityManager: EntitySectionManager.EntitySectionManager,
	entityTickList: EntityTickList.EntityTickList,
	navMesh: NavMesh.NavMesh,
	--
	random: Random
}, Scene))

type Entity = Entity.Entity
type LevelCallback = LevelCallback.LevelCallback<Entity>

function Scene.new(cells, missionSetup): Scene
	local this = setmetatable({
		cellManager = CellManager.new(cells, missionSetup.cells),
		propManager = PropManager.new(),
		entityTickList = EntityTickList.new(),
		navMesh = NavMesh.new(),
		random = Random.new()
	}, Scene)

	--

	local Callback = {}
	Callback.__index = Callback

	function Callback.new(): LevelCallback
		return setmetatable({}, Callback) :: LevelCallback
	end

	function Callback.onTickingStart(self: LevelCallback, entity: Entity): ()
		this.entityTickList:add(entity)
	end

	function Callback.onTickingStop(self: LevelCallback, entity: Entity): ()
		this.entityTickList:remove(entity)
	end

	this.entityManager = EntitySectionManager.new(Callback)

	return this
end

--

function Scene.addFreshEntity(self: Scene, entity: Entity): ()
	self.entityManager:addEntity(entity)
end

function Scene.getEntitiesInRadius(self: Scene, origin: Vector3, radius: number): {Entity}
	return self.entityManager:getEntitiesInRange(origin, 0, radius)
end

--

function Scene.getRandom(self: Scene): Random
	return self.random
end

--

function Scene.update(self: Scene, deltaTime: number): ()
	debug.profilebegin("Scene.update")
	debug.profilebegin("entities")
	self.entityTickList:forEach(function(entity)
		if entity:isRemoved() then
			return
		end

		entity:update(deltaTime)
	end)
	debug.profileend()
	debug.profileend()
end

return Scene