--!strict

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local CameraBrain = require(ReplicatedStorage.shared.cinemachine.camera.CameraBrain)
local DialogueController = require(StarterPlayer.StarterPlayerScripts.client.modules.ui.dialogue.DialogueController)
local VirtualCamera = require(ReplicatedStorage.shared.cinemachine.camera.VirtualCamera)
local HandheldNoise = require(ReplicatedStorage.shared.cinemachine.camera.components.HandheldNoise)
local MutableTextComponent = require(ReplicatedStorage.shared.network.chat.MutableTextComponent)
local TextColor = require(ReplicatedStorage.shared.network.chat.TextColor)
local TextStyle = require(ReplicatedStorage.shared.network.chat.TextStyle)
require(StarterPlayer.StarterPlayerScripts.client.modules.ui.screens.ObjectivesScreen)

-- STUDIO UTILS:

--

if false then
	local function snapCamToViewport(): ()
		local get = game:GetService("Selection"):Get()[1]
		if get and get:IsA("BasePart") then
			get.CFrame = workspace.CurrentCamera.CFrame
		end
	end
	snapCamToViewport()
end

--

local function createRuleOfThirdsGrid(parent)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RuleOfThirds"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Archivable = false
	gui.Parent = parent

	local function makeLine(pos, size)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		f.BackgroundTransparency = 0.5
		f.BorderSizePixel = 0
		f.Position = pos
		f.Size = size
		f.Parent = gui
	end

	-- vertical lines at 1/3 and 2/3
	makeLine(UDim2.fromScale(1/3, 0), UDim2.fromScale(0, 1) + UDim2.fromOffset(1, 0))
	makeLine(UDim2.fromScale(2/3, 0), UDim2.fromScale(0, 1) + UDim2.fromOffset(1, 0))

	-- horizontal lines at 1/3 and 2/3
	makeLine(UDim2.fromScale(0, 1/3), UDim2.fromScale(1, 0) + UDim2.fromOffset(0, 1))
	makeLine(UDim2.fromScale(0, 2/3), UDim2.fromScale(1, 0) + UDim2.fromOffset(0, 1))

	return gui
end

-- for studio:

createRuleOfThirdsGrid(game:GetService("StarterGui"))

-- FOr live:
--createRuleOfThirdsGrid(Players.LocalPlayer.PlayerGui)

do
	local found = StarterGui:FindFirstChild("RuleOfThirds")
	if found then
		found:Destroy()
	end
end

--

--

--[=[
	Test script to understand what we need before making the actual architecture.
]=]

--[=[
	SCENE: PSD TIER FOUR FACILITY

	OBJECTIVES:
	MISSION: Talk to Alice.

	Alternative trigger on Alice which reads “Talk”

	BEGIN DIALOGUE

	INT. PSD TIER FOUR FACILITY

	ALICE: Oh. Hey Operator. The Council hasn't given you any missions yet. What's up?

	OPERATOR: …I want to know why.

	ALICE: …Why?

	OPERATOR: Why did I do this? Why did I want to join Tier 4?

	ALICE: …

	OPERATOR: You’re my handler. Do you know any of this?

	ALICE: Well, no. I am just your handler. I do not have access to your interviews or any paperwork that leads you here. … Why do you want to know all of a sudden?

	OPERATOR: What kind of a person would pick such a job?

	ALICE: …

	OPERATOR: I need to find or at least try to remember my memories, Alice. Can you help?

	ALICE: *sigh* I don't know how the Council will think of this, but sure. I’ll help.
]=]

--

local TARGET_RATIO = 2.39  -- anamorphic

local function createLetterbox(parent)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Letterbox"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999
	gui.Parent = parent

	local topBar = Instance.new("Frame")
	topBar.BackgroundColor3 = Color3.new(0, 0, 0)
	topBar.BorderSizePixel = 0
	topBar.AnchorPoint = Vector2.new(0, 0)
	topBar.Position = UDim2.fromScale(0, 0)
	topBar.Size = UDim2.fromScale(1, 0)
	topBar.Parent = gui

	local bottomBar = Instance.new("Frame")
	bottomBar.BackgroundColor3 = Color3.new(0, 0, 0)
	bottomBar.BorderSizePixel = 0
	bottomBar.AnchorPoint = Vector2.new(0, 1)
	bottomBar.Position = UDim2.fromScale(0, 1)
	bottomBar.Size = UDim2.fromScale(1, 0)
	bottomBar.Parent = gui

	local function update()
		local screenSize = gui.AbsoluteSize
		local screenRatio = screenSize.X / screenSize.Y

		local barHeightPx: number

		if screenRatio >= TARGET_RATIO then
			-- already 16:9 or narrower (e.g. phone), no bars
			barHeightPx = 0
		else
			-- wider than 16:9 (e.g. ultrawide)
			-- figure out how tall 16:9 would be at this width
			local targetHeight = screenSize.X / TARGET_RATIO
			barHeightPx = (screenSize.Y - targetHeight) / 2
		end

		local barScale = barHeightPx / screenSize.Y

		topBar.Size = UDim2.fromScale(1, barScale)
		bottomBar.Size = UDim2.fromScale(1, barScale)
	end

	gui.DisplayOrder = -99999

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()

	return gui, topBar, bottomBar
end

createLetterbox(Players.LocalPlayer.PlayerGui)

--

-- Hijack the shits in Lighting for absolute control during cutscenes

local function proccessLightingInst(inst: Instance): ()
	if inst:IsA("DepthOfFieldEffect") then
		inst.Enabled = false
	elseif inst:IsA("BloomEffect") then
		inst.Enabled = false
	end
end

for _, inst in Lighting:GetChildren() do
	proccessLightingInst(inst)
end

Lighting.ChildAdded:Connect(proccessLightingInst)

local currentCamera = workspace.CurrentCamera
currentCamera.CameraType = Enum.CameraType.Scriptable

local iDof  = Instance.new("DepthOfFieldEffect")
iDof.Parent = currentCamera
local bloom = Instance.new("BloomEffect")
bloom.Parent = currentCamera

local brain = CameraBrain.new(
	20,
	16,
	0,
	24,
	currentCamera,
	{ dof = iDof, bloom = bloom }
)
brain:init()

local virtualCameras: { [string]: VirtualCamera.VirtualCamera } = {}

local shakeComponent = HandheldNoise.new("light")

local function setupCam(inst: Instance): ()
	if not inst:IsA("BasePart") then
		return
	end

	local vCam = VirtualCamera.new()

	-- TODO: This bullshit.

	vCam._state.fStop = 16
	vCam._state.focalLength = 20
	vCam._state.focusDist = 0

	-- static CFrame cams: no Body/Aim components needed.
	-- we just prime the state directly.
	vCam._state.position = inst.CFrame.Position
	vCam._state.rotation = inst.CFrame - inst.CFrame.Position

	-- every cam in this scene gets the same breathing shake
	vCam:addComponent(shakeComponent)

	inst.Transparency = 1
	virtualCameras[inst.Name] = vCam
end

for _, inst in CollectionService:GetTagged("vCam") do
	setupCam(inst)
end
CollectionService:GetInstanceAddedSignal("vCam"):Connect(setupCam)

local function switchTo(name: string): ()
	brain:setActiveCamera(virtualCameras[name], 0)
end

RunService.PreRender:Connect(function(dt: number)
	brain:update(dt)
end)

--

-- wtf
DialogueController.registerSpeakerId("Alice", MutableTextComponent.literal("Alice"):withStyle(TextStyle.new():withColor(TextColor.fromColor3(Color3.new(0, 0.441611, 1)))))
DialogueController.registerSpeakerId("Operator", MutableTextComponent.literal("Operator"):withStyle(TextStyle.new():withColor(TextColor.fromColor3(Color3.new(1, 1, 1)))))

task.wait(1)

currentCamera.CameraType = Enum.CameraType.Scriptable

switchTo("Cam1")

task.wait(1)

DialogueController.typeOutDialogueSequences({
	{
		SpeakerId = "Alice",
		Dialogues = {
			{
				InitialDelay = 0,
				Text = "Oh. Hey Operator. The Council hasn't given you any missions yet. What's up?"
			}
		}
	},
	{
		SpeakerId = "Operator",
		Dialogues = {
			{
				InitialDelay = 1,
				Text = "...I want to know why."
			}
		}
	},
	{
		SpeakerId = "Alice",
		Dialogues = {
			{
				InitialDelay = 1,
				Text = "'Why'? What do you mean?'"
			}
		}
	}
}, false)

task.wait(5.8) -- problem found. we need to manually do this shit cuz the dialogue plays asynchornously

switchTo("Cam2")

task.wait(3)

switchTo("Cam3")