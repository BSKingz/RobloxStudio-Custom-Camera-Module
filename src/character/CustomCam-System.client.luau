local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = script.Parent

local CustomCamModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("CustomCamModule"))
local CustomCamConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("CustomCamConfig"))
local camera = CustomCamModule.new(player, character, CustomCamConfig)

camera:Start()

character.Destroying:Connect(function()
	camera:Destroy()
end)

character:SetAttribute("CustomCameraActive", true)
