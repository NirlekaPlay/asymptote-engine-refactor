--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TypedRemotes = require(ReplicatedStorage.shared.network.remotes.TypedRemotes)
local SceneAccessor = require(ServerScriptService.server.world.level.scene.SceneAccessor)
local StateComponent = require(ServerScriptService.server.world.level.scene.components.registry.StateComponent)
local Maid = require(ReplicatedStorage.shared.util.misc.Maid)

--[=[
	@class LocalizedStringsReplicator

	Replicates the localized strings of a scene to clients.
]=]
local LocalizedStringsReplicator = {}
LocalizedStringsReplicator.__index = LocalizedStringsReplicator

export type LocalizedStringsReplicator = StateComponent.StateComponent & typeof(setmetatable({} :: {
	maid: Maid.Maid
}, LocalizedStringsReplicator))

type SceneAccessor = SceneAccessor.SceneAccessor

function LocalizedStringsReplicator.new(): LocalizedStringsReplicator
	return setmetatable({
		maid = Maid.new()
	}, LocalizedStringsReplicator) :: LocalizedStringsReplicator
end

--

function LocalizedStringsReplicator.setup(self: LocalizedStringsReplicator, scene: SceneAccessor): ()
	local localizationTable = scene:getLocalizedStrings()
	self.maid:giveTask(Players.PlayerAdded:Connect(function(player: Player)
		TypedRemotes.ClientboundLocalizationAppend:FireClient(player, localizationTable)
	end))

	TypedRemotes.ClientboundLocalizationAppend:FireAllClients(localizationTable)
end

function LocalizedStringsReplicator.update(self: LocalizedStringsReplicator, scene: SceneAccessor): ()
	return
end

function LocalizedStringsReplicator.restart(self: LocalizedStringsReplicator, scene: SceneAccessor): ()
	return
end

--

function LocalizedStringsReplicator.destroy(self: LocalizedStringsReplicator, scene: SceneAccessor): ()
	self.maid:doCleaning()
end

return LocalizedStringsReplicator