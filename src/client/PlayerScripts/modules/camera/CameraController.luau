--!strict

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local TransparencyController = require(StarterPlayer.StarterPlayerScripts.client.modules.camera.TransparencyController)
local CoreCall = require(StarterPlayer.StarterPlayerScripts.client.modules.util.CoreCall)

local DISTANCE = 8
local SHOULDER = 2.5
local TWEEN_SPEED = 0.2
local ZOOM_LERP_SPEED = 0.1
local CAMERA_RADIUS = 0.5 -- padding so screen edges don't clip walls
local CAMERA_HEIGHT_OFFSET = 1.5

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local transparencyController = TransparencyController.new()

local isDevConsoleVisible = CoreCall.call("StarterGui", "GetCore", "DevConsoleVisible")
local shouldLockAndHideMouse = true

local zoomState = 1 -- 0 for First Person, 1 for Third Person
local currentZoom = 1 -- Used for the interpolation/smooth transition
local currentSide = 1 -- 1 right, -1 left
local targetSide = 0 -- The goal (1, -1, or 0)
local defaultTargetSide = 1
local keyHeldLeanLeft = false
local keyHeldLeanRight = false
local holdLean = true
local rotX, rotY = 0, 0

local cameraRaycastParams = RaycastParams.new()
cameraRaycastParams.CollisionGroup = "ClientCamOcclusionRay"
cameraRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

camera.CameraType = Enum.CameraType.Scriptable

--[=[
	@class CameraController
]=]
local CameraController = {}

function CameraController.setHoldLean(holdToLean: boolean): ()
	holdLean = holdToLean
	if not holdToLean and targetSide == 0 then
		targetSide = defaultTargetSide
	elseif holdToLean and not (keyHeldLeanLeft or keyHeldLeanRight) then
		targetSide = 0
	end
end

function CameraController.update(deltaTime: number): ()
	debug.profilebegin("Camera.update")
	isDevConsoleVisible = StarterGui:GetCore("DevConsoleVisible")
	shouldLockAndHideMouse = not isDevConsoleVisible

	if shouldLockAndHideMouse then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end

	if holdLean and targetSide ~= 0 then
		targetSide = if (keyHeldLeanLeft or keyHeldLeanRight) then targetSide else 0
	end

	local char = player.Character :: Instance
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
	--local head = char and char:FindFirstChild("Head") :: BasePart
	if not root then
		return
	end

	cameraRaycastParams.FilterDescendantsInstances = {char}

	currentZoom = currentZoom + (zoomState - currentZoom) * (deltaTime / ZOOM_LERP_SPEED)
	currentSide = currentSide + (targetSide - currentSide) * (deltaTime / TWEEN_SPEED)
	
	local baseCF = CFrame.new(root.Position) * CFrame.Angles(0, rotY, 0) * CFrame.Angles(rotX, 0, 0)

	local pivotPos = root.Position + Vector3.new(0, CAMERA_HEIGHT_OFFSET, 0)
	local shoulderOffset = baseCF.RightVector * (currentSide * SHOULDER)
	local cameraOrigin = pivotPos + shoulderOffset
	
	local targetOffset = baseCF.LookVector * -DISTANCE
	local finalPos = cameraOrigin + targetOffset

	if currentZoom > 0.1 then
		local castResult = Workspace:Spherecast(
			cameraOrigin,
			CAMERA_RADIUS,
			targetOffset,
			cameraRaycastParams
		)

		if castResult then
			local safeDist = math.max(0, castResult.Distance - 0.1)
			finalPos = cameraOrigin + (targetOffset.Unit * safeDist)
		end
	end

	local headPos = pivotPos
	local actualPos = headPos:Lerp(finalPos, currentZoom)

	camera.CFrame = CFrame.new(actualPos, actualPos + baseCF.LookVector)
	
	if zoomState == 1 then
		transparencyController:show()
	else
		transparencyController:hide()
	end
	transparencyController:update(deltaTime)

	debug.profileend()
end

function CameraController.init(): ()
	if player.Character then
		transparencyController:setCharacter(player.Character)
	end

	player.CharacterAdded:Connect(function(character)
		transparencyController:setCharacter(character)
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			rotX -= math.rad(input.Delta.Y * 0.3)
			rotY -= math.rad(input.Delta.X * 0.3)
			rotX = math.clamp(rotX, math.rad(-80), math.rad(80))
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			-- SCROLL UP (Z > 0) -> First Person
			-- SCROLL DOWN (Z < 0) -> Third Person
			if input.Position.Z > 0 then
				zoomState = 0
			else
				zoomState = 1
			end
		end
	end)

	ContextActionService:BindAction("AsymptoteLeanRight", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			targetSide = 1
			defaultTargetSide = 1
		elseif inputState == Enum.UserInputState.End and holdLean and targetSide ~= -1 then
			targetSide = 0
		end

		keyHeldLeanRight = if inputState == Enum.UserInputState.Begin then true else false
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E)

	ContextActionService:BindAction("AsymptoteLeanLeft", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			targetSide = -1
			defaultTargetSide = -1
		elseif inputState == Enum.UserInputState.End and holdLean and targetSide ~= 1 then
			targetSide = 0
		end

		keyHeldLeanLeft = if inputState == Enum.UserInputState.Begin then true else false
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q)
end

return CameraController