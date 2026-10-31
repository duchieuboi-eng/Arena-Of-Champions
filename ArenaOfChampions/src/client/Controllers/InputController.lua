--[[
    InputController.lua
    Manages client inputs:
    - Shift key for Sprint
    - 'B' key to request spawning a Noob test dummy (6 studs in front of player)
--]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteManager = require(Shared.Modules.RemoteManager)

local InputController = {}
local sprintRemote = RemoteManager.GetRemoteEvent("SetSprintState")
local spawnDummyRemote = RemoteManager.GetRemoteEvent("SpawnTestingDummy")

local isSprinting = false

function InputController.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- Sprint Input (LeftShift / RightShift)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			if not isSprinting then
				isSprinting = true
				sprintRemote:FireServer(true)
			end
		end

		-- 'B' Key: Spawn Noob Testing Dummy
		if input.KeyCode == Enum.KeyCode.B then
			spawnDummyRemote:FireServer()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			if isSprinting then
				isSprinting = false
				sprintRemote:FireServer(false)
			end
		end
	end)
end

return InputController
