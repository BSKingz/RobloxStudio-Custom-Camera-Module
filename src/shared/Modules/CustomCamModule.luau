local CustomCamModule = {}
CustomCamModule.__index = CustomCamModule

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraMode = {
	OTS = "OTS", -- Over-the-shoulder (third-person)
	FPS = "FPS", -- First-person shooter
}

--[[
    Creates a new custom camera instance

    @param player: Player - The LocalPlayer
    @param character: Model - The player's character
    @param config: table - Configuration table (from CustomCamConfig module)
    @return CustomCamModule - New camera instance
]]
function CustomCamModule.new(player, character, config)
	local self = setmetatable({}, CustomCamModule)

	self.player = player
	self.character = character
	self.config = config or {}

	self.humanoid = character:WaitForChild("Humanoid")
	self.rootPart = character:WaitForChild("HumanoidRootPart")
	self.head = character:WaitForChild("Head")
	self.camera = workspace.CurrentCamera

	self.currentMode = CameraMode.OTS
	self.currentYaw = 0
	self.currentPitch = 0
	self.isAiming = false
	self.shoulderSide = config.Character and config.Character.DefaultShoulderSide or 1
	self.isActive = false

	local normalOffset = config.NormalMode and config.NormalMode.CameraOffset or Vector3.new(2.5, 2.0, 8.0)
	self.effectiveOffset = Vector3.new(normalOffset.X * self.shoulderSide, normalOffset.Y, normalOffset.Z)
	self.effectiveFov = config.NormalMode and config.NormalMode.FOV or 70

	self.raycastParams = RaycastParams.new()
	self.raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.raycastParams.FilterDescendantsInstances = { character }
	self.raycastParams.IgnoreWater = config.Collision and config.Collision.IgnoreWater or true

	self.originalTransparencies = {}
	self.isCharacterHidden = false

	self.connections = {}

	return self
end

--[[
    Starts the camera system
    Initializes camera settings and begins updating every frame
]]
function CustomCamModule:Start()
	if self.isActive then
		warn("CustomCamModule: Camera is already active")
		return
	end

	self.isActive = true

	self.camera.CameraType = Enum.CameraType.Scriptable

	if self.config.Input then
		if self.config.Input.LockMouseToCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		if self.config.Input.HideMouseIcon then
			UserInputService.MouseIconEnabled = false
		end
	end

	if self.config.Character and self.config.Character.DisableAutoRotate then
		self.humanoid.AutoRotate = false
	end

	self.connections.renderStepped = RunService.RenderStepped:Connect(function(deltaTime)
		self:_updateCamera(deltaTime)
	end)

	self:_connectInputHandlers()

	if self.config.Debug and self.config.Debug.EnableDebugPrints then
		print("CustomCamModule: Camera system started (" .. (self.config.Debug.Version or "unknown version") .. ")")
		print(
			"CustomCamModule: Available modes - OTS: "
				.. tostring(self.config.CameraModes and self.config.CameraModes.OTS)
				.. ", FPS: "
				.. tostring(self.config.CameraModes and self.config.CameraModes.FPS)
		)
	end
end

--[[
    Stops the camera system and cleans up
]]
function CustomCamModule:Destroy()
	self.isActive = false

	if self.isCharacterHidden then
		self:_showCharacter()
	end

	for _, connection in pairs(self.connections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	self.connections = {}

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	self.camera.CameraType = Enum.CameraType.Custom

	if self.humanoid then
		self.humanoid.AutoRotate = true
	end

	if self.config.Debug and self.config.Debug.EnableDebugPrints then
		print("CustomCamModule: Camera system destroyed")
	end
end

--[[
    Sets the camera mode

    @param mode: string - CameraMode.OTS or CameraMode.FPS
]]
function CustomCamModule:SetCameraMode(mode)
	if mode ~= CameraMode.OTS and mode ~= CameraMode.FPS then
		warn("CustomCamModule: Invalid camera mode '" .. tostring(mode) .. "'")
		return
	end

	if mode == CameraMode.OTS and not (self.config.CameraModes and self.config.CameraModes.OTS) then
		warn("CustomCamModule: OTS mode is disabled in config")
		return
	end

	if mode == CameraMode.FPS and not (self.config.CameraModes and self.config.CameraModes.FPS) then
		warn("CustomCamModule: FPS mode is disabled in config")
		return
	end

	local previousMode = self.currentMode
	self.currentMode = mode

	if mode == CameraMode.FPS then
		local fpsConfig = self.config.FPSMode or {}

		if fpsConfig.HideLocalCharacter then
			self:_hideCharacter()
		end

		if fpsConfig.HideMouseCursor then
			UserInputService.MouseIconEnabled = false
		end

		if self.config.Debug and self.config.Debug.EnableDebugPrints then
			print("CustomCamModule: Switched to FPS mode")
		end
	elseif mode == CameraMode.OTS and previousMode == CameraMode.FPS then
		if self.isCharacterHidden then
			self:_showCharacter()
		end

		local hideIcon = self.config.Input and self.config.Input.HideMouseIcon or false
		UserInputService.MouseIconEnabled = not hideIcon

		if self.config.Debug and self.config.Debug.EnableDebugPrints then
			print("CustomCamModule: Switched to OTS mode")
		end
	end
end

--[[
    Gets the current camera mode

    @return string - Current camera mode
]]
function CustomCamModule:GetCameraMode()
	return self.currentMode
end

--[[
    Toggles between OTS and FPS modes
]]
function CustomCamModule:ToggleCameraMode()
	if self.currentMode == CameraMode.OTS then
		self:SetCameraMode(CameraMode.FPS)
	else
		self:SetCameraMode(CameraMode.OTS)
	end
end

--[[
    Sets the aiming state (OTS mode only)

    @param aiming: boolean - Whether the player should be aiming
]]
function CustomCamModule:SetAiming(aiming)
	self.isAiming = aiming
end

--[[
    Gets the current aiming state

    @return boolean - Whether the player is currently aiming
]]
function CustomCamModule:IsAiming()
	return self.isAiming
end

--[[
    Swaps the camera shoulder (left/right) - OTS mode only
]]
function CustomCamModule:SwapShoulder()
	if self.currentMode ~= CameraMode.OTS then
		return
	end
	self.shoulderSide = self.shoulderSide * -1
end

--[[
    Gets the current shoulder side

    @return number - 1 for right shoulder, -1 for left shoulder
]]
function CustomCamModule:GetShoulderSide()
	return self.shoulderSide
end

--[[
    Sets the camera's yaw and pitch angles

    @param yaw: number - Horizontal rotation in degrees
    @param pitch: number - Vertical rotation in degrees
]]
function CustomCamModule:SetRotation(yaw, pitch)
	self.currentYaw = yaw
	self.currentPitch = pitch
end

--[[
    Gets the camera's current rotation

    @return number, number - yaw (horizontal) and pitch (vertical) in degrees
]]
function CustomCamModule:GetRotation()
	return self.currentYaw, self.currentPitch
end

--[[
    Hides the local character (but keeps it visible to other players on server)
    PRIVATE METHOD - Do not call directly
]]
function CustomCamModule:_hideCharacter()
	if self.isCharacterHidden then
		return
	end

	self.originalTransparencies = {}

	for _, part in ipairs(self.character:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
			self.originalTransparencies[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end

	self.isCharacterHidden = true
end

--[[
    Shows the local character (restores visibility)
    PRIVATE METHOD - Do not call directly
]]
function CustomCamModule:_showCharacter()
	if not self.isCharacterHidden then
		return
	end

	for part, originalTransparency in pairs(self.originalTransparencies) do
		if part and part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
			part.LocalTransparencyModifier = originalTransparency
		end
	end

	self.originalTransparencies = {}
	self.isCharacterHidden = false
end

--[[
    Connects input handlers for camera controls
    PRIVATE METHOD - Do not call directly
]]
function CustomCamModule:_connectInputHandlers()
	local function handleInput(input, gameProcessed)
		if gameProcessed or not self.isActive then
			return
		end

		if self.currentMode == CameraMode.OTS and self.config.CameraModes and self.config.CameraModes.OTS then
			local aimButton = self.config.Keybinds and self.config.Keybinds.OTS and self.config.Keybinds.OTS.AimButton
				or Enum.UserInputType.MouseButton2

			if input.UserInputType == aimButton then
				if input.UserInputState == Enum.UserInputState.Begin then
					self.isAiming = true
				elseif input.UserInputState == Enum.UserInputState.End then
					self.isAiming = false
				end
			end
		end

		if
			self.currentMode == CameraMode.OTS
			and self.config.CameraModes
			and self.config.CameraModes.OTSShoulderChange
		then
			local swapKey = self.config.Keybinds
					and self.config.Keybinds.OTS
					and self.config.Keybinds.OTS.ShoulderSwapKey
				or Enum.KeyCode.Q

			if input.KeyCode == swapKey and input.UserInputState == Enum.UserInputState.Begin then
				self:SwapShoulder()
			end
		end

		if self.config.CameraModes and self.config.CameraModes.FPS then
			local toggleKey = self.config.Keybinds
					and self.config.Keybinds.FPS
					and self.config.Keybinds.FPS.ToggleFPSKey
				or Enum.KeyCode.V

			if input.KeyCode == toggleKey and input.UserInputState == Enum.UserInputState.Begin then
				self:ToggleCameraMode()
			end
		end
	end

	self.connections.inputBegan = UserInputService.InputBegan:Connect(handleInput)
	self.connections.inputEnded = UserInputService.InputEnded:Connect(handleInput)
end

--[[
    Main camera update function - called every frame
    PRIVATE METHOD - Do not call directly

    @param deltaTime: number - Time since last frame
]]
function CustomCamModule:_updateCamera(deltaTime)
	if not self.isActive or not self.rootPart then
		return
	end

	if self.currentMode == CameraMode.OTS then
		self:_updateOTSCamera(deltaTime)
	elseif self.currentMode == CameraMode.FPS then
		self:_updateFPSCamera(deltaTime)
	end
end

--[[
    Updates camera in OTS (over-the-shoulder) mode
    PRIVATE METHOD - Do not call directly

    @param deltaTime: number - Time since last frame
]]
function CustomCamModule:_updateOTSCamera(deltaTime)
	local targetBaseOffset, targetFov, sensitivity, rotSmoothness

	if self.isAiming then
		local aimConfig = self.config.AimMode or {}
		targetBaseOffset = aimConfig.CameraOffset or Vector3.new(1.5, 1.8, 6.0)
		targetFov = aimConfig.FOV or 50
		sensitivity = aimConfig.MouseSensitivity or 0.2
		rotSmoothness = aimConfig.RotationSmoothness or 0.8
	else
		local normalConfig = self.config.NormalMode or {}
		targetBaseOffset = normalConfig.CameraOffset or Vector3.new(2.5, 2.0, 8.0)
		targetFov = normalConfig.FOV or 70
		sensitivity = normalConfig.MouseSensitivity or 0.3
		rotSmoothness = normalConfig.RotationSmoothness or 0.15
	end

	local fullTargetOffset = Vector3.new(targetBaseOffset.X * self.shoulderSide, targetBaseOffset.Y, targetBaseOffset.Z)

	local transitionSpeed = self.config.Transitions and self.config.Transitions.Speed or 10
	local alpha = self:_getLerpAlpha(transitionSpeed, deltaTime)

	self.effectiveOffset = self.effectiveOffset:Lerp(fullTargetOffset, alpha)
	self.effectiveFov = self:_lerp(self.effectiveFov, targetFov, alpha)

	local mouseDelta = UserInputService:GetMouseDelta()
	self.currentYaw = self.currentYaw - mouseDelta.X * sensitivity

	local minPitch = self.config.Constraints and self.config.Constraints.MinPitch or -80
	local maxPitch = self.config.Constraints and self.config.Constraints.MaxPitch or 80
	self.currentPitch = math.clamp(self.currentPitch - mouseDelta.Y * sensitivity, minPitch, maxPitch)

	local yawRad = math.rad(self.currentYaw)
	local pitchRad = math.rad(self.currentPitch)

	local cameraRotation = CFrame.Angles(0, yawRad, 0) * CFrame.Angles(pitchRad, 0, 0)
	local anchorPosition = self.rootPart.Position

	local idealShoulderOffsetCFrame = CFrame.new(self.effectiveOffset.X, self.effectiveOffset.Y, self.effectiveOffset.Z)
	local idealCameraCFrame = CFrame.new(anchorPosition) * cameraRotation * idealShoulderOffsetCFrame
	local idealPosition = idealCameraCFrame.Position

	local finalOffsetVector = self.effectiveOffset
	local rayOrigin = anchorPosition
	local rayDirection = idealPosition - rayOrigin
	local idealDistance = rayDirection.Magnitude

	if idealDistance > 0.01 then
		local raycastResult = workspace:Raycast(rayOrigin, rayDirection.Unit * idealDistance, self.raycastParams)

		if raycastResult then
			local hitDistance = raycastResult.Distance
			if hitDistance < idealDistance then
				local collisionBuffer = self.config.Collision and self.config.Collision.Buffer or 0.2
				local scaleFactor = math.clamp((hitDistance - collisionBuffer) / idealDistance, 0, 1)
				finalOffsetVector = self.effectiveOffset * scaleFactor
			end
		end
	end

	local finalAppliedOffsetCFrame = CFrame.new(finalOffsetVector.X, finalOffsetVector.Y, finalOffsetVector.Z)
	local finalCameraCFrame = CFrame.new(anchorPosition) * cameraRotation * finalAppliedOffsetCFrame

	self.camera.CFrame = finalCameraCFrame
	self.camera.Focus = CFrame.new(anchorPosition)
	self.camera.FieldOfView = self.effectiveFov

	local targetRootCFrame = CFrame.new(self.rootPart.Position) * CFrame.Angles(0, yawRad, 0)
	self.rootPart.CFrame = self.rootPart.CFrame:Lerp(targetRootCFrame, rotSmoothness)
end

--[[
    Updates camera in FPS (first-person) mode
    PRIVATE METHOD - Do not call directly

    @param deltaTime: number - Time since last frame
]]
function CustomCamModule:_updateFPSCamera(deltaTime)
	local fpsConfig = self.config.FPSMode or {}
	local sensitivity = fpsConfig.MouseSensitivity or 0.3
	local targetFov = fpsConfig.FOV or 80
	local rotSmoothness = fpsConfig.RotationSmoothness or 0.9
	local headOffset = fpsConfig.HeadOffset or Vector3.new(0, 0.5, 0)

	local transitionSpeed = self.config.Transitions and self.config.Transitions.Speed or 10
	local alpha = self:_getLerpAlpha(transitionSpeed, deltaTime)

	self.effectiveFov = self:_lerp(self.effectiveFov, targetFov, alpha)

	local mouseDelta = UserInputService:GetMouseDelta()
	self.currentYaw = self.currentYaw - mouseDelta.X * sensitivity

	local minPitch = self.config.Constraints and self.config.Constraints.MinPitch or -80
	local maxPitch = self.config.Constraints and self.config.Constraints.MaxPitch or 80
	self.currentPitch = math.clamp(self.currentPitch - mouseDelta.Y * sensitivity, minPitch, maxPitch)

	local yawRad = math.rad(self.currentYaw)
	local pitchRad = math.rad(self.currentPitch)

	local cameraPosition = self.head.Position + headOffset
	local cameraRotation = CFrame.Angles(0, yawRad, 0) * CFrame.Angles(pitchRad, 0, 0)

	self.camera.CFrame = CFrame.new(cameraPosition) * cameraRotation
	self.camera.Focus = self.camera.CFrame * CFrame.new(0, 0, -1)
	self.camera.FieldOfView = self.effectiveFov

	local targetRootCFrame = CFrame.new(self.rootPart.Position) * CFrame.Angles(0, yawRad, 0)
	self.rootPart.CFrame = self.rootPart.CFrame:Lerp(targetRootCFrame, rotSmoothness)
end

--[[
    Linear interpolation for numbers
    PRIVATE METHOD - Do not call directly

    @param a: number - Start value
    @param b: number - End value
    @param t: number - Interpolation factor (0-1)
    @return number - Interpolated value
]]
function CustomCamModule:_lerp(a, b, t)
	return a + (b - a) * t
end

--[[
    Frame-rate independent Lerp alpha calculation
    PRIVATE METHOD - Do not call directly

    @param speed: number - Speed of interpolation
    @param deltaTime: number - Time since last frame
    @return number - Alpha value for Lerp
]]
function CustomCamModule:_getLerpAlpha(speed, deltaTime)
	deltaTime = math.min(deltaTime, 0.1)
	return 1 - math.exp(-speed * deltaTime)
end

return CustomCamModule
