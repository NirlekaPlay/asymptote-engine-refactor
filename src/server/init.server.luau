--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local DebugPacketTypes = require(ReplicatedStorage.shared.network.DebugPacketTypes)
local DebugPackets = require(ReplicatedStorage.shared.network.DebugPackets)
local TypedRemotes = require(ReplicatedStorage.shared.network.remotes.TypedRemotes)
local Maid = require(ReplicatedStorage.shared.util.misc.Maid)
local CharacterFaceService = require(ReplicatedStorage.shared.world.entity.face.CharacterFaceService)
local Level = require(ServerScriptService.server.world.level.Level)
local LevelLoader = require(ServerScriptService.server.world.level.LevelLoader)
local Clutter = require(ServerScriptService.server.world.level.scene.props.Clutter)
local CollisionGroupManager = require(ServerScriptService.server.world.physics.collision.CollisionGroupManager)
local CollisionGroupTypes = require(ServerScriptService.server.world.physics.collision.CollisionGroupTypes)

local level = Level.new()
local playerMaids: { [Player]: Maid.Maid } = {}

local function main(): ()
	CollisionGroupManager.register()
	CharacterFaceService.init()
	Clutter.initialize()
end

local function onPostSimulation(deltaTime: number): ()
	local frameHasListeningClients = DebugPackets.hasListeningClients(DebugPacketTypes.DEBUG_BRAIN)
	level:update(deltaTime)
	if frameHasListeningClients then
		DebugPackets.flushBrainDumpsToListeningClients()
	else
		DebugPackets.clearBatch(DebugPacketTypes.DEBUG_BRAIN)
	end
end

local function onPlayerJoin(player: Player): ()
	local maid = Maid.new()
	playerMaids[player] = maid

	maid:giveTask(player.CharacterAppearanceLoaded:Once(function(character)
		for _, part in character:GetChildren() do
			if part:IsA("BasePart") then
				part.CollisionGroup = CollisionGroupTypes.PLAYER
			end
		end
	end))
end

local function onPlayerLeave(player: Player): ()
	local maid = playerMaids[player]
	if maid then
		maid:doCleaning()
		playerMaids[player] = nil
	end
end

main()

level.scene = LevelLoader.loadFromFolder(workspace.DebugMission)

RunService.PostSimulation:Connect(onPostSimulation)
Players.PlayerAdded:Connect(onPlayerJoin)
Players.PlayerRemoving:Connect(onPlayerLeave)
TypedRemotes.SubscribeDebugDump.OnServerEvent:Connect(DebugPackets.onReceiveSubscription)