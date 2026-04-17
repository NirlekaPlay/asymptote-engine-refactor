--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SceneAccessor = require(ServerScriptService.server.world.level.scene.SceneAccessor)
local StateComponent = require(ServerScriptService.server.world.level.scene.components.registry.StateComponent)
local Maid = require(ReplicatedStorage.shared.util.misc.Maid)


local function isEmptyString(str: string?): boolean
	if not str then
		return true
	end

	return string.match(str, "%S") == nil
end

--[=[
	@class NpcStateTracker

	Tracks the states of tagged NPC(s) and sets a variable if that state changes.
]=]
local NpcStateTracker = {}
NpcStateTracker.__index = NpcStateTracker

export type NpcStateTracker = StateComponent.StateComponent & typeof(setmetatable({} :: {
	npcServerTag: string,
	deathCountVariable: string?,
	maid: Maid.Maid
}, NpcStateTracker))

type SceneAccessor = SceneAccessor.SceneAccessor

function NpcStateTracker.new(npcServerTag: string, deathCountVariable: string?): NpcStateTracker
	return setmetatable({
		npcServerTag = npcServerTag,
		deathCountVariable = deathCountVariable :: string?,
		maid = Maid.new()
	}, NpcStateTracker) :: NpcStateTracker
end

function NpcStateTracker.fromInstance(inst: Instance): NpcStateTracker?
	return NpcStateTracker.new(
		inst:GetAttribute("NpcServerTag") :: string? or error(`Empty 'NpcServerTag': NpcStateTracker currently cannot track all NPCs.`),
		inst:GetAttribute("DeathCountVariable") :: string?
	)
end

--

function NpcStateTracker.setup(self: NpcStateTracker, scene: SceneAccessor): ()
	local npcServerTag = self.npcServerTag
	if isEmptyString(npcServerTag) then
		error(`Empty 'NpcServerTag': NpcStateTracker currently cannot track all NPCs.`)
	end

	local deathCountVariable = self.deathCountVariable
	if not isEmptyString(deathCountVariable) then
		if not scene:hasState(deathCountVariable :: string) then
			scene:setState(deathCountVariable :: string, 0)
		end
	end

	local maid = Maid.new()

	-- TODO: Bad practice. Will fix later.
	local function proccessTagged(tagged: Instance)
		if tagged:IsA("Model") and tagged.Parent == workspace and tagged:FindFirstChildOfClass("Humanoid") then
			local conns: {RBXScriptConnection} = {}
			if not isEmptyString(deathCountVariable) then
				local humanoid = tagged:FindFirstChildOfClass("Humanoid") :: Humanoid
				local diedConn = maid:giveTask(humanoid.Died:Once(function()
					scene:setState(deathCountVariable :: string, scene:getState(deathCountVariable :: string) + 1)
				end))

				table.insert(conns, diedConn)
			end

			maid:giveTask(tagged.Destroying:Once(function()
				for _, conn in conns do
					conn:Disconnect()
				end
			end))
		end
	end

	for _, tagged in CollectionService:GetTagged(npcServerTag) do
		proccessTagged(tagged)
	end

	maid:giveTask(CollectionService:GetInstanceAddedSignal(npcServerTag):Connect(function(tagged)
		proccessTagged(tagged)
	end))
end

function NpcStateTracker.update(self: NpcStateTracker, scene: SceneAccessor): ()
	return
end

function NpcStateTracker.restart(self: NpcStateTracker, scene: SceneAccessor): ()
	if self.deathCountVariable then
		scene:setState(self.deathCountVariable, 0)
	end
end

--

function NpcStateTracker.destroy(self: NpcStateTracker, scene: SceneAccessor): ()
	self.maid:doCleaning()
end

return NpcStateTracker