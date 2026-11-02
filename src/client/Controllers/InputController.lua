--[[
    InputController.lua
    Manages client inputs:
    - Dedicated Custom Shift-Lock Controller:
        * Toggled strictly by LeftControl and RightControl.
        * When ON: locks mouse to center, sets shoulder camera offset Vector3.new(1.75, 0, 0),
          and on RenderStepped rotates character horizontally to face camera LookVector
          (UNLESS character attribute RotationLocked is true).
        * When OFF: unlocks mouse, resets CameraOffset to Vector3.zero.
    - LeftShift & RightShift: Exclusively controls Sprint (never toggles Shift-Lock).
    - 'E' Key: Casts Skill 1 ("Vine" for Grot).
    - 'B' Key: Spawns Noob test dummy (legacy quick spawn).
    - '~' Key (Backquote): Toggles the Testing CMD Panel.
--]]

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteManager = require(Shared.Modules.RemoteManager)

local InputController = {}
local sprintRemote = RemoteManager.GetRemoteEvent("SetSprintState")
local spawnDummyRemote = RemoteManager.GetRemoteEvent("SpawnTestingDummy")

local isSprinting = false
local isShiftLockActive = false

--[[
    Disables Roblox's built-in Shift-Lock entirely so LeftShift never interferes,
    and disables default backpack hotbar opening on backtick.
--]]
function InputController.DisableRobloxDefaultShiftLock()
	local localPlayer = Players.LocalPlayer
	localPlayer.DevEnableMouseLock = false

	-- Disable Backpack CoreGui to stop default backtick inventory popups
	task.spawn(function()
		for i = 1, 10 do
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			task.wait(0.3)
		end
	end)

	pcall(function()
		ContextActionService:UnbindAction("MouseLockSwitchAction")
	end)

	local playerScripts = localPlayer:WaitForChild("PlayerScripts")

	task.spawn(function()
		local playerModule = playerScripts:WaitForChild("PlayerModule", 5)
		if playerModule then
			local cameraModule = playerModule:FindFirstChild("CameraModule")
			if cameraModule then
				local mouseLockController = cameraModule:FindFirstChild("MouseLockController")
				if mouseLockController then
					local boundKeysVal = mouseLockController:FindFirstChild("BoundKeys")
					if not boundKeysVal then
						boundKeysVal = Instance.new("StringValue")
						boundKeysVal.Name = "BoundKeys"
						boundKeysVal.Parent = mouseLockController
					end
					boundKeysVal.Value = "None"
				end
			end
		end

		pcall(function()
			ContextActionService:UnbindAction("MouseLockSwitchAction")
		end)
	end)
end

--[[
    Toggles our custom Shift-Lock state on or off.
--]]
function InputController.ToggleShiftLock()
	isShiftLockActive = not isShiftLockActive

	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if isShiftLockActive then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		if humanoid then
			humanoid.CameraOffset = Vector3.new(1.75, 0, 0)
		end
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
		end
	end
end

function InputController.IsShiftLockActive(): boolean
	return isShiftLockActive
end

function InputController.Init()
	InputController.DisableRobloxDefaultShiftLock()

	local CombatController = require(script.Parent.CombatController)
	local CMDController = require(script.Parent.CMDController)

	-- Custom Shift-Lock RenderStepped loop
	RunService.RenderStepped:Connect(function()
		if not isShiftLockActive then return end

		local character = Players.LocalPlayer.Character
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			if isShiftLockActive then
				InputController.ToggleShiftLock()
			end
			return
		end

		-- Keep mouse locked to center while active
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end

		-- Do not rotate character root if rotation is locked (Frame 5 of Vine skill)
		if character:GetAttribute("RotationLocked") then
			return
		end

		local camera = Workspace.CurrentCamera
		if not camera then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Grot_hitbox") :: BasePart?
		if not rootPart then return end

		local camLook = camera.CFrame.LookVector
		local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
		if flatLook.Magnitude > 0.02 then
			flatLook = flatLook.Unit
			rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flatLook)
		end
	end)

	-- Handle character respawn / reset
	Players.LocalPlayer.CharacterAdded:Connect(function(newChar)
		if isShiftLockActive then
			local hum = newChar:WaitForChild("Humanoid", 5) :: Humanoid?
			if hum then
				hum.CameraOffset = Vector3.new(1.75, 0, 0)
			end
		end
	end)

	-- Intercept Backquote (~) at high priority to prevent Roblox inventory / chat popups
	ContextActionService:BindActionAtPriority("ToggleCMDPanelAction", function(actionName, inputState, inputObject)
		if inputState == Enum.UserInputState.Begin then
			if not UserInputService:GetFocusedTextBox() then
				CMDController.Toggle()
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 2000, Enum.KeyCode.Backquote)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- 1. Dedicated Shift-Lock Toggle (LeftControl / RightControl ONLY)
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
			InputController.ToggleShiftLock()
			return
		end

		-- 2. Sprint Input (LeftShift / RightShift ONLY)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			if not isSprinting then
				isSprinting = true
				sprintRemote:FireServer(true)
			end
			return
		end

		-- 3. 'E' Key: Cast Skill 1 ("Vine" for Grot)
		if input.KeyCode == Enum.KeyCode.E then
			CombatController.HandleSkill1Input()
			return
		end

		-- 4. 'B' Key: Spawn Quick Testing Dummy
		if input.KeyCode == Enum.KeyCode.B then
			spawnDummyRemote:FireServer()
			return
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