--[[
    GrotAnimationController.lua
    Client-side animation controller for Grot character models.
    Executes smooth pose-based tweens:
    - Idle: Smoothly transitions limbs to Grot_model pose when stationary
    - Walk: Smooth 2-frame loop between Grot_walk1 -> Grot_walk2 -> Grot_walk1 (Speed 14)
    - Sprint: Smooth 2-frame loop between Grot_sprint1 -> Grot_sprint2 -> Grot_sprint1 (Speed 18)
    - M1 Heavy Tanker Strike: 0.25s wind-up, 0.08s slam impact with camera bump (0.10s linger)
    - S1 "Vine" (E Key): 5-frame wind-up (0.80s total) with free aiming rotation for frames 1-4,
      rotation lock during frame 5 slam, progressive Skill area visual growth, and 2.0s lingering zone!
--]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

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
			local intensity = math.sin(progress * math.pi) * 1.0
			camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(-1.5 * intensity), 0, 0)
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
		movementThread = nil,
		activeTweens = {},
	}
	activeGrotStates[character] = data

	character.Destroying:Connect(function()
		if data.movementThread then
			task.cancel(data.movementThread)
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
    - Wind-up: Frame 1 (0.11s) -> Frame 2 (0.14s) = 0.25s
    - Impact: Frame 3 slams down in 0.08s with camera bump
    - Return to idle/movement cleanly after linger (0.10s).
--]]
function GrotAnimationController.PlayM1(character: Model)
	local data = getGrotData(character)
	if not data then return end

	local poses = GrotRigFactory.GetCachedPoses()
	if not poses.M1Frame1 or not poses.M1Frame2 or not poses.M1Frame3 then
		poses = GrotRigFactory.ExtractAllPoses()
	end

	if data.movementThread then
		task.cancel(data.movementThread)
		data.movementThread = nil
	end

	data.isAttacking = true

	task.spawn(function()
		-- 1. Wind-up Phase (0.25s total)
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
		task.wait(0.10) -- 0.10s active linger

		-- 3. Recovery Phase: Return to normal state
		data.isAttacking = false
		data.currentState = "None"
	end)
end

--[[
    Plays Skill 1 ("Vine" / E Key) 5-Frame wind-up sequence and visual growth:
    - Frames 1-4 (0.55s): Speed = 0, player CAN rotate/aim freely.
    - Frame 5 (0.25s): Speed = 0, rotation locked completely.
    - Post-windup: Movement & rotation unlocked immediately, 2.0s lingering vine zone.
--]]
function GrotAnimationController.PlayS1(character: Model)
	local data = getGrotData(character)
	if not data then return end

	local poses = GrotRigFactory.GetCachedPoses()
	if not poses.S1Frame1 then
		poses = GrotRigFactory.ExtractAllPoses()
	end

	local s1Frames = {
		{ pose = poses.S1Frame1 or poses.M1Frame1, duration = 0.10, frameIndex = 1 },
		{ pose = poses.S1Frame2 or poses.M1Frame2, duration = 0.25, frameIndex = 2 },
		{ pose = poses.S1Frame3 or poses.M1Frame1, duration = 0.10, frameIndex = 3 },
		{ pose = poses.S1Frame4 or poses.M1Frame2, duration = 0.10, frameIndex = 4 },
		{ pose = poses.S1Frame5 or poses.M1Frame3, duration = 0.25, frameIndex = 5 },
	}

	if data.movementThread then
		task.cancel(data.movementThread)
		data.movementThread = nil
	end

	data.isAttacking = true

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Grot_hitbox") :: BasePart?
	local isLocal = (character == Players.LocalPlayer.Character)

	-- Lock movement speed to 0 during wind-up (0.80s)
	if humanoid then
		humanoid.WalkSpeed = 0
	end

	task.spawn(function()
		local activeVineVisual: Instance? = nil

		-- Frames 1 to 4 (0.55s total): Player CAN rotate/spin freely to aim
		for i = 1, 4 do
			local frameInfo = s1Frames[i]
			if frameInfo.pose then
				tweenToPose(data, frameInfo.pose, frameInfo.duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			end

			-- Display progressive vine visual stage
			if rootPart then
				if activeVineVisual and activeVineVisual.Parent then
					activeVineVisual:Destroy()
				end
				activeVineVisual = GrotRigFactory.CreateSkillAreaVisual(i)
				if activeVineVisual then
					local s1Data = GrotRigFactory.ExtractS1HitboxData()
					if activeVineVisual:IsA("Model") and activeVineVisual.PrimaryPart then
						activeVineVisual:PivotTo(rootPart.CFrame * s1Data.Offset)
					elseif activeVineVisual:IsA("BasePart") then
						activeVineVisual.CFrame = rootPart.CFrame * s1Data.Offset
					end
					activeVineVisual.Parent = Workspace
				end
			end

			task.wait(frameInfo.duration)
		end

		-- Entering Frame 5 (final 0.25s): Lock rotation completely!
		local lockedOrientationCFrame = rootPart and rootPart.CFrame
		if humanoid then
			humanoid.AutoRotate = false
		end

		local frame5 = s1Frames[5]
		if frame5.pose then
			tweenToPose(data, frame5.pose, frame5.duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		end

		-- Final spiky visual placed at locked position
		if rootPart and lockedOrientationCFrame then
			if activeVineVisual and activeVineVisual.Parent then
				activeVineVisual:Destroy()
			end
			activeVineVisual = GrotRigFactory.CreateSkillAreaVisual(5)
			local s1Data = GrotRigFactory.ExtractS1HitboxData()
			if activeVineVisual:IsA("Model") and activeVineVisual.PrimaryPart then
				activeVineVisual:PivotTo(lockedOrientationCFrame * s1Data.Offset)
			elseif activeVineVisual:IsA("BasePart") then
				activeVineVisual.CFrame = lockedOrientationCFrame * s1Data.Offset
			end
			activeVineVisual.Parent = Workspace
			Debris:AddItem(activeVineVisual, 2.0)
		end

		-- Hold rotation lock strictly for 0.25s
		local lockStart = os.clock()
		while (os.clock() - lockStart) < 0.25 do
			if rootPart and lockedOrientationCFrame then
				rootPart.CFrame = CFrame.new(rootPart.Position) * lockedOrientationCFrame.Rotation
			end
			RunService.RenderStepped:Wait()
		end

		-- Camera bump impact
		if isLocal then
			triggerCameraImpactBump()
		end

		-- Immediately unlock movement & rotation after Frame 5 (at 0.80s)!
		if humanoid then
			humanoid.WalkSpeed = character:GetAttribute("Walk") or 14
			humanoid.AutoRotate = true
		end

		data.isAttacking = false
		data.currentState = "None"
	end)
end

--[[
    Per-frame update managing smooth transitions between Idle, 2-frame Walk, and 2-frame Sprint.
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
				if data.movementThread then
					task.cancel(data.movementThread)
					data.movementThread = nil
				end
				if poses.Idle then
					tweenToPose(data, poses.Idle, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				end
			end
		elseif not isSprinting then
			-- 2. Walking -> 2-Frame Loop (Grot_walk1 -> Grot_walk2 -> Grot_walk1 at speed 14)
			if data.currentState ~= "Walk" then
				data.currentState = "Walk"
				if data.movementThread then
					task.cancel(data.movementThread)
				end

				data.movementThread = task.spawn(function()
					local walk1 = poses.Walk1 or poses.Walk
					local walk2 = poses.Walk2 or poses.Walk

					while data.currentState == "Walk" and not data.isAttacking do
						if walk1 then
							tweenToPose(data, walk1, 0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
						end
						task.wait(0.24)

						if data.currentState ~= "Walk" or data.isAttacking then break end

						if walk2 then
							tweenToPose(data, walk2, 0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
						end
						task.wait(0.24)
					end
				end)
			end
		else
			-- 3. Sprinting -> 2-Frame Loop (Grot_sprint1 -> Grot_sprint2 -> Grot_sprint1 at speed 18)
			if data.currentState ~= "Sprint" then
				data.currentState = "Sprint"
				if data.movementThread then
					task.cancel(data.movementThread)
				end

				data.movementThread = task.spawn(function()
					local sprint1 = poses.Sprint1 or poses.Sprint
					local sprint2 = poses.Sprint2 or poses.Sprint

					while data.currentState == "Sprint" and not data.isAttacking do
						if sprint1 then
							tweenToPose(data, sprint1, 0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
						end
						task.wait(0.18)

						if data.currentState ~= "Sprint" or data.isAttacking then break end

						if sprint2 then
							tweenToPose(data, sprint2, 0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
						end
						task.wait(0.18)
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