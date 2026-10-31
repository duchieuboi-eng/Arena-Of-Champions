--[[
    GrotAnimationController.lua
    Client-side animation controller for Grot character models.
    Executes smooth pose-based tweens:
    - Idle: Smoothly transitions limbs to Grot_model pose when stationary
    - Walk: Smoothly transitions to Grot_walk pose when moving
    - Sprint: Continuously loops smooth tween between Grot_walk -> Grot_sprint -> Grot_walk while sprinting
    - M1 Heavy Tanker Strike: Weighted 0.25s wind-up, heavy 0.08s slam to Frame 3 with camera impact bump!
--]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GrotRigFactory = require(Shared.Modules.GrotRigFactory)

local GrotAnimationController = {}

local LIMB_NAMES = {
	"Brown arm",
	"Brown leg",
	"Head",
	"Orange arm",
	"Orange leg",
	"Torso",
}

local activeGrotStates = {}

function GrotAnimationController.Init()
	RunService.RenderStepped:Connect(function(dt)
		GrotAnimationController.OnUpdate(dt)
	end)
end

--[[
    Applies a brief, subtle camera bump/shake on impact for the local player.
--]]
local function triggerCameraImpactBump()
	local camera = Workspace.CurrentCamera
	if not camera then return end

	task.spawn(function()
		local startTime = os.clock()
		local duration = 0.12
		while true do
			local elapsed = os.clock() - startTime
			if elapsed >= duration then break end
			local progress = elapsed / duration
			local intensity = math.sin(progress * math.pi) * 0.8
			camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(-1.2 * intensity), 0, 0)
			RunService.RenderStepped:Wait()
		end
	end)
end

--[[
    Finds or registers animation tracking data for a Grot character model.
--]]
local function getGrotData(character: Model)
	if activeGrotStates[character] then
		return activeGrotStates[character]
	end

	local grotHitbox = character:FindFirstChild("Grot_hitbox")
	if not grotHitbox then return nil end

	local motors = {}
	for _, limbName in ipairs(LIMB_NAMES) do
		local motor = grotHitbox:FindFirstChild(limbName) :: Motor6D
		if motor and motor:IsA("Motor6D") then
			motors[limbName] = motor
		end
	end

	local data = {
		character = character,
		motors = motors,
		currentState = "None",
		isAttacking = false,
		sprintThread = nil,
		activeTweens = {},
	}
	activeGrotStates[character] = data

	character.Destroying:Connect(function()
		if data.sprintThread then
			task.cancel(data.sprintThread)
		end
		activeGrotStates[character] = nil
	end)

	return data
end

--[[
    Smoothly tweens all limb Motor6Ds to a specified pose table.
--]]
local function tweenToPose(data: any, pose: { [string]: CFrame }, duration: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	style = style or Enum.EasingStyle.Quad
	direction = direction or Enum.EasingDirection.Out
	local tweenInfo = TweenInfo.new(duration, style, direction)

	for limbName, targetC0 in pairs(pose) do
		local motor = data.motors[limbName]
		if motor then
			if data.activeTweens[limbName] then
				data.activeTweens[limbName]:Cancel()
			end
			local tween = TweenService:Create(motor, tweenInfo, { C0 = targetC0 })
			data.activeTweens[limbName] = tween
			tween:Play()
		end
	end
end

--[[
    Plays the Heavy Tanker M1 attack animation for Grot:
    - Weighted Wind-up: Frame 1 (0.11s) -> Frame 2 (0.14s) = 0.25s total wind-up
    - Heavy Impact: Frame 3 slams down in 0.08s (Back/Quart Out) with camera bump
    - Return to idle/movement cleanly after linger.
--]]
function GrotAnimationController.PlayM1(character: Model)
	local data = getGrotData(character)
	if not data then return end

	local poses = GrotRigFactory.GetCachedPoses()
	if not poses.M1Frame1 or not poses.M1Frame2 or not poses.M1Frame3 then
		poses = GrotRigFactory.ExtractAllPoses()
	end

	if data.sprintThread then
		task.cancel(data.sprintThread)
		data.sprintThread = nil
	end

	data.isAttacking = true

	task.spawn(function()
		-- 1. Wind-up Phase (Total 0.25s) with weighty feel
		if poses.M1Frame1 then
			tweenToPose(data, poses.M1Frame1, 0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		end
		task.wait(0.11)

		if poses.M1Frame2 then
			tweenToPose(data, poses.M1Frame2, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.wait(0.14)

		-- 2. Heavy Slam Impact (0.08s) right as hitbox appears
		if poses.M1Frame3 then
			tweenToPose(data, poses.M1Frame3, 0.08, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		end

		if character == Players.LocalPlayer.Character then
			triggerCameraImpactBump()
		end
		task.wait(0.12)

		-- 3. Recovery Phase: Smoothly return to idle/movement
		data.isAttacking = false
		data.currentState = "None"
	end)
end

--[[
    Per-frame update managing smooth transitions between Idle, Walk, and Sprinting.
--]]
function GrotAnimationController.OnUpdate(deltaTime: number)
	for character, data in pairs(activeGrotStates) do
		if not character or not character.Parent then
			activeGrotStates[character] = nil
			continue
		end

		if data.isAttacking or character:GetAttribute("IsAttacking") then
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		local poses = GrotRigFactory.GetCachedPoses()
		local isMoving = humanoid.MoveDirection.Magnitude > 0.08
		local isSprinting = character:GetAttribute("IsSprinting") or false

		if not isMoving then
			-- 1. Stationary -> IDLE Pose
			if data.currentState ~= "Idle" then
				data.currentState = "Idle"
				if data.sprintThread then
					task.cancel(data.sprintThread)
					data.sprintThread = nil
				end
				if poses.Idle then
					tweenToPose(data, poses.Idle, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				end
			end
		elseif not isSprinting then
			-- 2. Walking -> WALK Pose
			if data.currentState ~= "Walk" then
				data.currentState = "Walk"
				if data.sprintThread then
					task.cancel(data.sprintThread)
					data.sprintThread = nil
				end
				if poses.Walk then
					tweenToPose(data, poses.Walk, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				end
			end
		else
			-- 3. Sprinting -> Continuously loop smooth tween between Walk -> Sprint -> Walk
			if data.currentState ~= "Sprint" then
				data.currentState = "Sprint"
				if data.sprintThread then
					task.cancel(data.sprintThread)
				end

				data.sprintThread = task.spawn(function()
					while data.currentState == "Sprint" and not data.isAttacking do
						if poses.Sprint then
							tweenToPose(data, poses.Sprint, 0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
						end
						task.wait(0.22)

						if data.currentState ~= "Sprint" or data.isAttacking then break end

						if poses.Walk then
							tweenToPose(data, poses.Walk, 0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
						end
						task.wait(0.22)
					end
				end)
			end
		end
	end

	local localChar = Players.LocalPlayer.Character
	if localChar and localChar:GetAttribute("CharacterId") == "Grot" and not activeGrotStates[localChar] then
		getGrotData(localChar)
	end
end

return GrotAnimationController
