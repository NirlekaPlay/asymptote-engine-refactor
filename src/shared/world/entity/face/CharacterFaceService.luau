--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Maid = require(ReplicatedStorage.shared.util.misc.Maid)
local CollectionTags = require(ReplicatedStorage.shared.world.collection.CollectionTags)
local ClientFaceControl = require(ReplicatedStorage.shared.world.entity.face.ClientFaceControl)
local ServerFaceControl = require(ReplicatedStorage.shared.world.entity.face.ServerFaceControl)

local FACE_STATE_ATTRIBUTE = "FaceState"

local maid: Maid.Maid = Maid.new()
local controls: { [Configuration]: ServerFaceControl.ServerFaceControl | ClientFaceControl.FaceControl } = {}

--[=[
	@class CharacterFaceService

	Owns all FaceControl instances for every character in the world.
]=]
local CharacterFaceService = {}

local function getCharacterFromConfig(config: Configuration): Model?
	local parent = config.Parent
	if parent and parent:IsA("Model") then
		return parent :: Model
	end
	return nil
end

local function applyFaceState(faceControl: ClientFaceControl.FaceControl, raw: string?)
	if not raw or raw == "" then
		return
	end

	local faceAlias = raw:match('"faceAlias":"([^"]+)"')
	local eyesAlias = raw:match('"eyesAlias":"([^"]+)"')
	local mouthStr = raw:match('"mouthOverride":(%d+)')
	local mouthReset = raw:find('"mouthOverride":false') ~= nil

	if faceAlias then
		faceControl:setFace(faceAlias :: any)
	end
	if eyesAlias then
		faceControl:setEyesAlias(eyesAlias :: any)
	end
	if mouthStr then
		faceControl:setMouth(tonumber(mouthStr))
	elseif mouthReset then
		faceControl:resetMouthToExpression()
	end
end

local function setupServer(config: Configuration)
	local character = getCharacterFromConfig(config)
	if not character then
		return
	end

	local configMaid = Maid.new()
	maid:giveTask(configMaid)

	local control = ServerFaceControl.new(character)
	controls[config] = control

	configMaid:giveTask(config.AncestryChanged:Connect(function()
		if not config:IsDescendantOf(game) then
			controls[config] = nil
			configMaid:doCleaning()
		end
	end))
end

local function setupClient(config: Configuration)
	local character = getCharacterFromConfig(config)
	if not character then
		return
	end

	-- TODO: May cause problems
	local head = character:WaitForChild("Head", 5) :: BasePart?
	if not head then
		return
	end

	local configMaid = Maid.new()
	maid:giveTask(configMaid)

	local control = ClientFaceControl.new(character)
	controls[config] = control

	applyFaceState(control, head:GetAttribute(FACE_STATE_ATTRIBUTE))

	configMaid:giveTask(head:GetAttributeChangedSignal(FACE_STATE_ATTRIBUTE):Connect(function()
		applyFaceState(control, head:GetAttribute(FACE_STATE_ATTRIBUTE))
	end))

	configMaid:giveTask(config.AncestryChanged:Connect(function()
		if not config:IsDescendantOf(game) then
			controls[config] = nil
			configMaid:doCleaning()
		end
	end))
end

--

function CharacterFaceService.init()
	local setup = if RunService:IsServer() then setupServer else setupClient

	for _, config in CollectionService:GetTagged(CollectionTags.CHARACTER_FACE_CONFIG) do
		if config:IsA("Configuration") then
			task.spawn(setup, config)
		end
	end

	maid:giveTask(CollectionService:GetInstanceAddedSignal(CollectionTags.CHARACTER_FACE_CONFIG):Connect(function(config)
		if config:IsA("Configuration") then
			setup(config)
		end
	end))
end

function CharacterFaceService.register(character: Model): ServerFaceControl.ServerFaceControl
	assert(RunService:IsServer(), "CharacterFaceService.register() should only be called from the server")

	local existing = character:FindFirstChild("FaceConfig")
	if existing and existing:IsA("Configuration") and controls[existing] then
		return controls[existing :: Configuration] :: ServerFaceControl.ServerFaceControl
	end

	local config = Instance.new("Configuration")
	config.Name = "FaceConfig"
	config.Parent = character
	CollectionService:AddTag(config, CollectionTags.CHARACTER_FACE_CONFIG)

	setupServer(config)
	return controls[config] :: ServerFaceControl.ServerFaceControl
end

function CharacterFaceService.get(character: Model): (ServerFaceControl.ServerFaceControl | ClientFaceControl.FaceControl)?
	for config, control in controls do
		if config.Parent == character then
			return control
		end
	end
	return nil
end

function CharacterFaceService.clear()
	maid:doCleaning()
	maid = Maid.new()
	table.clear(controls)
end

return CharacterFaceService