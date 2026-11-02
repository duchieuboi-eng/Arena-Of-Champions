--[[
    ClientMain.client.lua
    Client Entry Point for Arena of Champions.
    Handles controller initialization and camera subject binding upon morphing and respawning.
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
local Controllers = PlayerScripts:WaitForChild("Controllers")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteManager = require(Shared.Modules.RemoteManager)

local InputController = require(Controllers:WaitForChild("InputController"))
local HUDController = require(Controllers:WaitForChild("HUDController"))
local CombatController = require(Controllers:WaitForChild("CombatController"))
local GrotAnimationController = require(Controllers:WaitForChild("GrotAnimationController"))
local CMDController = require(Controllers:WaitForChild("CMDController"))

-- Initialize all client controllers
CMDController.Init()
InputController.Init()
HUDController.Init()
CombatController.Init()
GrotAnimationController.Init()

--[[
    Ensures the camera immediately targets the active character's Humanoid.
    Fixes the post-morph camera desync bug cleanly.
--]]
local function setupCamera(character: Model?)
	if not character then return end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		local camera = Workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end
end

LocalPlayer.CharacterAdded:Connect(setupCamera)
if LocalPlayer.Character then
	setupCamera(LocalPlayer.Character)
end

-- Listen for server morph camera reset remote
local cameraResetRemote = RemoteManager.GetRemoteEvent("ResetCameraSubject")
cameraResetRemote.OnClientEvent:Connect(function(character)
	setupCamera(character or LocalPlayer.Character)
end)

print("[ArenaOfChampions] Client initialized successfully with Camera Subject Fix, Grot Animations, and Dropdown Stat Panel.")
