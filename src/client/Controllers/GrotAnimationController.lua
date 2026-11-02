--[[
    GrotAnimationController.lua
    Client-side animation controller for Grot character models.
    Executes smooth pose-based tweens:
    - Idle: Smoothly transitions limbs to Grot_model pose when stationary
    - Walk: Smooth 2-frame loop between Grot_walk1 -> Grot_walk2 -> Grot_walk1 (0.24s per step at speed 14)
    - Sprint: Heavy, lumbering 2-frame loop between Grot_sprint1 -> Grot_sprint2 -> Grot_sprint1 (0.45s per step at speed 18)
    - M1 Heavy Tanker Strike: 0.25s wind-up, 0.08s slam impact with camera bump (0.10s linger)
    - S1 "Vine" (E Key): 5-frame wind-up (0.95s total) with real Skill area models,
      free aiming rotation during frames 1-4 (0.00s to 0.75s), rotation locked in Frame 5 (0.75s to 0.95s),
      and 3.0s lingering spiky vine zone!
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
		local duration = 0.14
		while true do
			local elapsed = os.clock() - startTime
			if elapsed >= duration then break end
			local progress = elapsed / duration
			local intensity = math.sin(progress * math.pi) * 1.2
			camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(-1.8 * intensity), 0, 0)
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

	-- Safety timeout ensuring M1 flags never get stuck
	task.delay(0.6, function()
		if data.isAttacking then
			data.isAttacking = false
			data.currentState = "None"
			if character and character.Parent then
				character:SetAttribute("IsAttacking", false)
			end
		end
	end)

	task.spawn(function()
		local success, err = pcall(function()
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
		end)

		if not success then
			warn("[GrotAnimationController] M1 error: " .. tostring(err))
		end

		-- 3. Recovery Phase: Return to normal state cleanly
		data.isAttacking = false
		data.currentState = "None"
		if character and character.Parent then
			character:SetAttribute("IsAttacking", false)
		end
	end)
end

--[[
    Plays Skill 1 ("Vine" / E Key) 5-Frame wind-up sequence and real Skill area model growth:
    - Total wind-up: 0.95s (Frame 1: 0.15s, Frame 2: 0.25s, Frame 3: 0.15s, Frame 4: 0.20s, Frame 5: 0.20s).
    - Frames 1 to 4 (0.00s to 0.75s): WalkSpeed = 0, player CAN rotate/aim freely. Real Skill area follows live rotation!
    - Frame 5 (0.75s to 0.95s): WalkSpeed = 0, rotation locked completely.
    - Post-windup (0.95s+): Movement & rotation unlocked immediately, Frame 5 Skill area stays anchored for 3.0s!
--]]
function GrotAnimationController.PlayS1(character: Model)
	local data = getGrotData(character)
	if not data then return end

	local poses = GrotRigFactory.GetCachedPoses()
	if not poses.S1Frame1 then
		poses = GrotRigFactory.ExtractAllPoses()
	end

	local s1Frames = {
		{ pose = poses.S1Frame1 or poses.M1Frame1, duration = 0.15, frameIndex = 1 },
		{ pose = poses.S1Frame2 or poses.M1Frame2, duration = 0.25, frameIndex = 2 },
		{ pose = poses.S1Frame3 or poses.M1Frame1, duration = 0.15, frameIndex = 3 },
		{ pose = poses.S1Frame4 or poses.M1Frame2, duration = 0.20, frameIndex = 4 },
		{ pose = poses.S1Frame5 or poses.M1Frame3, duration = 0.20, frameIndex = 5 },
	}

	if data.movementThread then
		task.cancel(data.movementThread)
		data.movementThread = nil
	end

	data.isAttacking = true

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local grotHitbox = character:FindFirstChild("Grot_hitbox") :: BasePart? or rootPart
	local isLocal = (character == Players.LocalPlayer.Character)

	-- Lock movement speed to 0 during full 0.95s wind-up
	if humanoid then
		humanoid.WalkSpeed = 0
	end

	-- Safety timeout ensuring S1 flags and WalkSpeed never get permanently stuck
	task.delay(1.5, function()
		if data.isAttacking then
			data.isAttacking = false
			data.currentState = "None"
			if character and character.Parent then
				character:SetAttribute("RotationLocked", false)
				character:SetAttribute("IsCastingSkill", false)
				character:SetAttribute("IsAttacking", false)
			end
			if humanoid and humanoid.Parent and humanoid.WalkSpeed == 0 then
				humanoid.WalkSpeed = character:GetAttribute("Walk") or 14
				humanoid.AutoRotate = true
			end
		end
	end)

	task.spawn(function()
		local activeSkillAreaModel: Model? = nil
		local activePartOffsets: { [BasePart]: CFrame }? = nil
		local spinFollowConnection: RBXScriptConnection? = nil

		-- Helper to clean up active visual stage
		local function cleanupActiveVisual()
			if spinFollowConnection then
				spinFollowConnection:Disconnect()
				spinFollowConnection = nil
			end
			if activeSkillAreaModel and activeSkillAreaModel.Parent then
				activeSkillAreaModel:Destroy()
				activeSkillAreaModel = nil
				activePartOffsets = nil
			end
		end

		local success, err = pcall(function()
			-- Frames 1 to 4 (0.00s to 0.75s): Player CAN rotate/spin freely to aim!
			for i = 1, 4 do
				local frameInfo = s1Frames[i]

				-- Pose tween
				if frameInfo.pose then
					tweenToPose(data, frameInfo.pose, frameInfo.duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				end

				-- Spawn REAL frame Skill area model
				cleanupActiveVisual()
				activeSkillAreaModel, activePartOffsets = GrotRigFactory.SpawnSkillAreaForFrame(i, character)

				-- Follow Grot's live rotation as the player aims during this frame
				if activePartOffsets and grotHitbox then
					spinFollowConnection = RunService.RenderStepped:Connect(function()
						local currentHitbox = character:FindFirstChild("Grot_hitbox") or character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if not currentHitbox or not currentHitbox.Parent then return end
						for part, relCF in pairs(activePartOffsets) do
							if part and part.Parent then
								part.CFrame = currentHitbox.CFrame * relCF
							end
						end
					end)
				end

				task.wait(frameInfo.duration)
			end

			-- =====================================================================
			-- Entering Frame 5 (0.75s to 0.95s): Lock rotation completely!
			-- =====================================================================
			character:SetAttribute("RotationLocked", true)
			if humanoid then
				humanoid.AutoRotate = false
			end

			local liveRoot = character:FindFirstChild("Grot_hitbox") or character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local lockedOrientationCFrame = liveRoot and liveRoot.CFrame or CFrame.identity

			-- Disconnect live spin follower and spawn final Frame 5 spiky Skill area model
			cleanupActiveVisual()

			local frame5Model, frame5Offsets = GrotRigFactory.SpawnSkillAreaForFrame(5, character)
			if frame5Model and frame5Offsets and lockedOrientationCFrame then
				for part, relCF in pairs(frame5Offsets) do
					if part and part.Parent then
						part.CFrame = lockedOrientationCFrame * relCF
					end
				end
				-- Leave Frame 5 spiky model anchored in the world for 3.0s!
				Debris:AddItem(frame5Model, 3.0)
			end

			-- Play Frame 5 pose slam (0.20s)
			local frame5 = s1Frames[5]
			if frame5.pose then
				tweenToPose(data, frame5.pose, frame5.duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			end

			-- Maintain rotation lock strictly during Frame 5 (0.20s)
			local lockStart = os.clock()
			while (os.clock() - lockStart) < 0.20 do
				local currentRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if currentRoot and lockedOrientationCFrame then
					currentRoot.CFrame = CFrame.new(currentRoot.Position) * lockedOrientationCFrame.Rotation
				end
				RunService.RenderStepped:Wait()
			end

			-- Camera bump impact
			if isLocal then
				triggerCameraImpactBump()
			end
		end)

		if not success then
			warn("[GrotAnimationController] S1 error: " .. tostring(err))
		end

		cleanupActiveVisual()

		-- =====================================================================
		-- At 0.95s: Wind-up completes! Unlock movement & rotation immediately!
		-- =====================================================================
		character:SetAttribute("RotationLocked", false)
		character:SetAttribute("IsCastingSkill", false)
		character:SetAttribute("IsAttacking", false)

		if humanoid and humanoid.Parent then
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

		if data.isAttacking or character:GetAttribute("IsAttacking") or character:GetAttribute("IsCastingSkill") then
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
			-- 2. Walking -> 2-Frame Loop (Grot_walk1 -> Grot_walk2 -> Grot_walk1 at speed 14, 0.24s per step)
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
			-- 3. Sprinting -> Heavy, Lumbering 2-Frame Loop (0.45s per step, slowed down 2.5x)
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
							tweenToPose(data, sprint1, 0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
						end
						task.wait(0.45)

						if data.currentState ~= "Sprint" or data.isAttacking then break end

						if sprint2 then
							tweenToPose(data, sprint2, 0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
						end
						task.wait(0.45)
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