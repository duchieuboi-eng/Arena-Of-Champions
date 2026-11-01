--[[
    InputController.lua
    Manages client inputs:
    - Rebinds Roblox Shift-Lock to LeftControl and RightControl so LeftShift sprint never conflicts.
    - Shift key (LeftShift / RightShift) for Sprint
    - 'E' key to cast Skill 1 ("Vine" for Grot)
    - 'B' key to request spawning a Noob test dummy (6 studs in front of player)
--]]

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteManager = require(Shared.Modules.RemoteManager)

local InputController = {}
local sprintRemote = RemoteManager.GetRemoteEvent("SetSprintState")
local spawnDummyRemote = RemoteManager.GetRemoteEvent("SpawnTestingDummy")

local isSprinting = false

--[[
    Rebinds Roblox Shift-Lock to LeftControl and RightControl by setting BoundKeys
    on Roblox PlayerModule's MouseLockController.
--]]
function InputController.SetupShiftLock()
	local localPlayer = Players.LocalPlayer
	local playerScripts = localPlayer:WaitForChild("PlayerScripts")

	task.spawn(function()
		local playerModule = playerScripts:WaitForChild("PlayerModule", 10)
		if playerModule then
			local cameraModule = playerModule:WaitForChild("CameraModule", 10)
			if cameraModule then
				local mouseLockController = cameraModule:WaitForChild("MouseLockController", 10)
				if mouseLockController then
					local boundKeysVal = mouseLockController:FindFirstChild("BoundKeys")
					if not boundKeysVal then
						boundKeysVal = Instance.new("StringValue")
						boundKeysVal.Name = "BoundKeys"
						boundKeysVal.Parent = mouseLockController
					end
					boundKeysVal.Value = "LeftControl,RightControl"
				end
			end
		end

		-- Also protect against default ContextActionService binding if still active
		pcall(function()
			ContextActionService:UnbindAction("MouseLockSwitchAction")
		end)
	end)
end

function InputController.Init()
	InputController.SetupShiftLock()

	local CombatController = require(script.Parent.CombatController)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- 1. Sprint Input (LeftShift / RightShift)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			if not isSprinting then
				isSprinting = true
				sprintRemote:FireServer(true)
			end
		end

		-- 2. 'E' Key: Cast Skill 1 ("Vine" for Grot)
		if input.KeyCode == Enum.KeyCode.E then
			CombatController.HandleSkill1Input()
		end

		-- 3. 'B' Key: Spawn Noob Testing Dummy
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