--!strict

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local DialogueController = require(StarterPlayer.StarterPlayerScripts.client.modules.ui.dialogue.DialogueController)
local VirtualCamera = require(ReplicatedStorage.shared.cinemachine.camera.VirtualCamera)
local MutableTextComponent = require(ReplicatedStorage.shared.network.chat.MutableTextComponent)
local TextColor = require(ReplicatedStorage.shared.network.chat.TextColor)
local TextStyle = require(ReplicatedStorage.shared.network.chat.TextStyle)
local ObjectivesScreen = require(StarterPlayer.StarterPlayerScripts.client.modules.ui.screens.ObjectivesScreen)

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
	if StarterGui:FindFirstChild("RuleOfThirds") then
		StarterGui:FindFirstChild("RuleOfThirds"):Destroy()
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

local currentCamera = workspace.CurrentCamera
currentCamera.CameraType = Enum.CameraType.Scriptable
local virtualCameras = {}

local function setupCam(inst: Instance): ()
	if not inst:IsA("BasePart") then
		return
	end

	local vCam = VirtualCamera.new()
	vCam:setCFrame(inst.CFrame)

	inst.Transparency = 1

	virtualCameras[inst.Name] = vCam
end

for _, inst in CollectionService:GetTagged("vCam") do
	setupCam(inst)
end

CollectionService:GetInstanceAddedSignal("vCam"):Connect(setupCam)

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
	end
end

for _, inst in Lighting:GetChildren() do
	proccessLightingInst(inst)
end

Lighting.ChildAdded:Connect(proccessLightingInst)

--

local SHAKE_AMPLITUDE = 0.02  -- how much it moves (position)
local SHAKE_ROTATION_AMPLITUDE = 0.2  -- how much it tilts (degrees)
local SHAKE_FREQUENCY = 0.8  -- how fast it breathes
local shakeTime = 0

local RunService = game:GetService("RunService")

local function getShakeOffset(t: number): CFrame
	local px = math.noise(t * SHAKE_FREQUENCY, 0, 0) * SHAKE_AMPLITUDE
	local py = math.noise(0, t * SHAKE_FREQUENCY, 0) * SHAKE_AMPLITUDE
	local pz = math.noise(0, 0, t * SHAKE_FREQUENCY) * SHAKE_AMPLITUDE

	local rx = math.noise(t * SHAKE_FREQUENCY, 100, 0) * SHAKE_ROTATION_AMPLITUDE
	local ry = math.noise(0, 100, t * SHAKE_FREQUENCY) * SHAKE_ROTATION_AMPLITUDE
	local rz = math.noise(100, t * SHAKE_FREQUENCY, 0) * SHAKE_ROTATION_AMPLITUDE

	return CFrame.new(px, py, pz) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
end

local activeCFrame = CFrame.new()

RunService.RenderStepped:Connect(function(dt: number)
	shakeTime += dt
	currentCamera.CFrame = activeCFrame * getShakeOffset(shakeTime)
end)

--

local function switchTo(name: string): ()
	activeCFrame = virtualCameras[name].cframe
end

local SENSOR_HEIGHT_IN_MM = 24
local currentFocalLength = 35
local currentFStop = 16

local applyFStop

local function setFocalLength(f: number): ()
	if f <= 0 then
		return
	end
	
	local fovRadians = 2 * math.atan(SENSOR_HEIGHT_IN_MM / (2 * f))
	
	currentCamera.FieldOfView = math.deg(fovRadians)
	currentFocalLength = f
	applyFStop(currentFStop)
	currentCamera:SetAttribute("FocalLength", f)
end

currentCamera:GetAttributeChangedSignal("FocalLength"):Connect(function()
	local f = currentCamera:GetAttribute("FocalLength")
	if f == currentFocalLength then
		return
	end
	setFocalLength(f :: number)
end)

currentCamera:SetAttribute("FocalLength", currentFocalLength)

--

local iDof = Instance.new("DepthOfFieldEffect")
iDof.Parent = currentCamera

applyFStop = function(dof: DepthOfFieldEffect, focusDistance: number, fStop: number, focalLength: number): ()
	local c = 0.03
	local dofDepth = (2 * focusDistance^2 * fStop * c) / (focalLength^2)
	local inFocusRadius = dofDepth * 0.5

	local intensity = math.clamp(1 / (fStop / 1.4), 0, 1)

	dof.FocusDistance = focusDistance
	dof.InFocusRadius = inFocusRadius
	dof.FarIntensity = intensity
	dof.NearIntensity = intensity * 0.5
end

local function setFStop(f: number): ()
	applyFStop(iDof, 0, f, currentFocalLength)
end

currentCamera:GetAttributeChangedSignal("FStop"):Connect(function()
	local f = currentCamera:GetAttribute("FStop")
	if f == currentFStop then
		return
	end
	setFStop(f :: number)
end)

currentCamera:SetAttribute("FStop", currentFStop)

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