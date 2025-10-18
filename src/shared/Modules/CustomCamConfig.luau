local CustomCamConfig = {}

CustomCamConfig.CameraModes = {
	OTS = true,
	OTSShoulderChange = true,
	FPS = true,
}

CustomCamConfig.Keybinds = {
	-- OTS Camera Controls
	OTS = {
		AimButton = Enum.UserInputType.MouseButton2,
		ShoulderSwapKey = Enum.KeyCode.Q,
	},

	-- FPS Camera Controls
	FPS = {
		ToggleFPSKey = Enum.KeyCode.V,
	},
}

CustomCamConfig.NormalMode = {
	MouseSensitivity = 0.3,
	CameraOffset = Vector3.new(2.5, 2.0, 8.0),
	FOV = 70,
	RotationSmoothness = 0.15,
}

CustomCamConfig.AimMode = {
	MouseSensitivity = 0.2,
	CameraOffset = Vector3.new(1.5, 1.8, 6.0),
	FOV = 50,
	RotationSmoothness = 0.8,
}

CustomCamConfig.FPSMode = {
	MouseSensitivity = 0.3,
	CameraOffset = Vector3.new(0, 0.5, 0), -- Camera at head position
	FOV = 80,
	RotationSmoothness = 0.9,
	HideMouseCursor = true, -- Hide mouse cursor in FPS mode
	HideLocalCharacter = true, -- Hide character from local player (still visible to others)
	HeadOffset = Vector3.new(0, 0.5, 0), -- Offset from head position
}

CustomCamConfig.Constraints = {
	MinPitch = -80,
	MaxPitch = 80,
}

CustomCamConfig.Collision = {
	Buffer = 0.2,
	IgnoreWater = true,
}

CustomCamConfig.Transitions = {
	Speed = 10,
}

CustomCamConfig.Input = {
	LockMouseToCenter = true,
	HideMouseIcon = true, -- Global setting (overridden by FPS mode if enabled)
}

CustomCamConfig.Character = {
	DisableAutoRotate = true,
	DefaultShoulderSide = 1, -- 1 for right, -1 for left
}

CustomCamConfig.Debug = {
	EnableDebugPrints = true,
	Version = "0.1.0-beta", -- Beta Release (Major.Minor.Patch-stage)
	ReleaseStage = "Beta",
}

return CustomCamConfig
