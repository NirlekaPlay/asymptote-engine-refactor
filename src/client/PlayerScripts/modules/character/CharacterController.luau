--!nonstrict

local LEAN_SPEED = 20

--[=[
	@class CharacterController

	Handles physics-safe character rotation using AlignOrientation and dynamic leaning.
]=]
local CharacterController = {}
CharacterController.__index = CharacterController

export type CharacterController = typeof(setmetatable({} :: {
	_camera: Camera,
	_alignOrientation: AlignOrientation?,
	_attachment: Attachment?,
	--
	_character: Model?,
	_humanoid: Humanoid?,
	_rootPart: BasePart?,
	_targetJoint: Motor6D?,
	_originalRootC0: CFrame?,
	--
	shouldFaceAlongCamera: boolean,
}, CharacterController))

function CharacterController.new(): CharacterController
	return setmetatable({
		_camera = workspace.CurrentCamera,
		_alignOrientation = nil :: AlignOrientation?,
		_attachment = nil :: Attachment?,
		shouldFaceAlongCamera = false,
	}, CharacterController) :: CharacterController
end

function CharacterController.setFaceAlongCamera(self: CharacterController, faceAlongCamera: boolean)
	self.shouldFaceAlongCamera = faceAlongCamera
end

function CharacterController.setCharacter(self: CharacterController, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	
	local rootJoint = rootPart:FindFirstChild("Root") or rootPart:FindFirstChild("Root Joint")
	if not rootJoint or not rootJoint:IsA("Motor6D") then
		for _, child in rootPart:GetChildren() do
			if child:IsA("Motor6D") then
				rootJoint = child
				break
			end
		end
	end
	
	if not rootJoint then
		warn("Could not find Root Motor6D!")
		return
	end
	
	local targetJoint = rootJoint :: Motor6D
	local originalRootC0 = targetJoint.C0
	
	-- Turn off Roblox's default rotation handler
	humanoid.AutoRotate = false

	self:stop()

	self._targetJoint = targetJoint
	self._originalRootC0 = originalRootC0
	self._character = character
	self._humanoid = humanoid
	self._rootPart = rootPart

	--

	local attachment = Instance.new("Attachment")
	attachment.Name = "RotationAttachment"
	attachment.Parent = rootPart
	self._attachment = attachment
	
	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "RotationConstraint"
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	-- Leave it disabled initially; we only turn it on when we want to force rotate
	alignOrientation.Enabled = false 
	
	-- Tuning properties for the physics rotation feel
	alignOrientation.MaxTorque = 400000 -- High enough to snap instantly but responsive
	alignOrientation.Responsiveness = 25 -- Controls how smooth/fast the pan is
	alignOrientation.ReactionTorqueEnabled = false
	alignOrientation.Parent = rootPart
	self._alignOrientation = alignOrientation
end

function CharacterController.update(self: CharacterController, deltaTime: number): ()
	local character = self._character
	local humanoid = self._humanoid
	if not character.Parent or humanoid.Health <= 0 then
		self:stop()
		return
	end
	
	local isMoving = humanoid.MoveDirection.Magnitude > 0
	local shouldFaceCamera = isMoving or self.shouldFaceAlongCamera
	
	if shouldFaceCamera and self._alignOrientation then
		local cameraCFrame = self._camera.CFrame
		local lookVector = cameraCFrame.LookVector
		local targetDirection = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

		self._alignOrientation.Enabled = true
		self._alignOrientation.CFrame = CFrame.lookAt(Vector3.zero, targetDirection)
	else
		if self._alignOrientation then
			self._alignOrientation.Enabled = false
		end
	end

	local rootPart = self._rootPart
	local originalRootC0 = self._originalRootC0
	local targetJoint = self._targetJoint

	-- Use MoveDirection (0 to 1 input vector) instead of physics velocity
	-- to completely ignore animation swaying and physics noise.
	local moveDir = rootPart.CFrame:VectorToObjectSpace(humanoid.MoveDirection)

	local currentSpeed = rootPart.AssemblyLinearVelocity.Magnitude
	local speedFactor = math.clamp(currentSpeed / 16, 0, 1)

	local tiltSide = if isMoving then (moveDir.X * 0.35) * speedFactor else 0
	local tiltFront = if isMoving then (-moveDir.Z * 0.30) * speedFactor else 0

	tiltSide = math.clamp(tiltSide, -math.rad(12), math.rad(12))
	tiltFront = math.clamp(tiltFront, -math.rad(12), math.rad(12))

	local targetTilt = originalRootC0
		* CFrame.Angles(tiltFront, 0, 0)  -- Pitch (Forward/Back)
		* CFrame.Angles(0, 0, tiltSide)   -- Roll (Left/Right)
		
	local leanAlpha = 1 - math.exp(-LEAN_SPEED * deltaTime)
	targetJoint.C0 = targetJoint.C0:Lerp(targetTilt, math.clamp(leanAlpha, 0, 1))
end

function CharacterController.stop(self: CharacterController): ()
	if self._alignOrientation then
		self._alignOrientation:Destroy()
		self._alignOrientation = nil
	end

	if self._attachment then
		self._attachment:Destroy()
		self._attachment = nil
	end

	self._targetJoint = nil
	self._originalRootC0 = nil
	self._character = nil
	self._humanoid = nil
	self._rootPart = nil
end

return CharacterController