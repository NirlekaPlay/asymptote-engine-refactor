--!strict

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local CoreCall = require(StarterPlayer.StarterPlayerScripts.client.modules.util.CoreCall)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local isDevConsoleVisible = CoreCall.call("StarterGui", "GetCore", "DevConsoleVisible")
local shouldLockAndHideMouse = true

local DISTANCE = 8
local HEIGHT = 2
local SHOULDER = 2.5
local TWEEN_SPEED = 0.2

local currentSide = 1 -- 1 right, -1 left
local targetSide = 0 -- The goal (1, -1, or 0)
local holdLean = true

local cameraRaycastParams = RaycastParams.new()
cameraRaycastParams.CollisionGroup = "ClientCamOcclusionRay"
cameraRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

camera.CameraType = Enum.CameraType.Scriptable

local rotX, rotY = 0, 0
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		rotX -= math.rad(input.Delta.Y * 0.3)
		rotY -= math.rad(input.Delta.X * 0.3)
		rotX = math.clamp(rotX, math.rad(-80), math.rad(80))
	end
end)

ContextActionService:BindAction("AsymptoteLeanRight", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		targetSide = 1
	elseif inputState == Enum.UserInputState.End and holdLean and targetSide ~= -1 then
		targetSide = 0
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.E)

ContextActionService:BindAction("AsymptoteLeanLeft", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		targetSide = -1
	elseif inputState == Enum.UserInputState.End and holdLean and targetSide ~= 1 then
		targetSide = 0
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Q)

RunService.PreRender:Connect(function(dt)
	camera.CameraType = Enum.CameraType.Scriptable

	isDevConsoleVisible = StarterGui:GetCore("DevConsoleVisible")
	shouldLockAndHideMouse = not isDevConsoleVisible

	if shouldLockAndHideMouse then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end

	local char = player.Character :: Instance
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
	if not root then
		return
	end

	cameraRaycastParams.FilterDescendantsInstances = {char}
	
	currentSide = currentSide + (targetSide - currentSide) * (dt / TWEEN_SPEED)
	
	local baseCF = CFrame.new(root.Position) 
		* CFrame.Angles(0, rotY, 0) 
		* CFrame.Angles(rotX, 0, 0)

	local relativeOffset = Vector3.new(currentSide * SHOULDER, HEIGHT, DISTANCE)
	local targetCameraPos = (baseCF * CFrame.new(relativeOffset)).Position

	local startPos = root.Position + Vector3.new(0, HEIGHT, 0)
	local direction = targetCameraPos - startPos
	
	local raycastResult = Workspace:Raycast(startPos, direction, cameraRaycastParams)

	local finalPos = targetCameraPos
	if raycastResult then
		finalPos = raycastResult.Position + (raycastResult.Normal * 0.5)
	end

	camera.CFrame = CFrame.new(finalPos, finalPos + baseCF.LookVector)
end)