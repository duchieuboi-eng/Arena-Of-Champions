--[[
    CombatController.lua
    Client controller for handling user combat inputs (M1 attacks).
    Strictly disables M1 while "Unmorphed".
    Manages true 2.0s Grot M1 and 1.5s Blocky M1 with 0 stamina lockout,
    triggers instant HUD cooldown sweeps, and replicates attack visuals.
--]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteManager = require(Shared.Modules.RemoteManager)
local CombatConfig = require(Shared.Configs.CombatConfig)
local HUDController = require(script.Parent.HUDController)
local GrotAnimationController = require(script.Parent.GrotAnimationController)

local CombatController = {}

local attackRemote = RemoteManager.GetRemoteEvent("PerformAttack")
local visualRemote = RemoteManager.GetRemoteEvent("PlayAttackVisuals")

local lastAttackTime = 0

local BLOCKY_COOLDOWN = 1.5
local GROT_COOLDOWN = 2.0

function CombatController.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local character = Players.LocalPlayer.Character
			local charId = character and character:GetAttribute("CharacterId")

			-- Strictly disallow M1 while Unmorphed
			if not charId or charId == "Unmorphed" then
				return
			end

			local now = os.clock()

			-- 1. Blocky M1 Attack (1.5s CD)
			if charId == "Blocky" then
				if (now - lastAttackTime) < BLOCKY_COOLDOWN then
					return
				end
				lastAttackTime = now

				HUDController.TriggerSkillCooldown("M1", BLOCKY_COOLDOWN)
				CombatController.RequestAttack("BlockyM1")

			-- 2. Grot M1 Attack (True 2.0s CD, 0 Stamina lockout)
			elseif charId == "Grot" then
				if (now - lastAttackTime) < GROT_COOLDOWN then
					return
				end
				lastAttackTime = now

				-- Start cooldown sweep immediately at the moment MB1 is pressed
				HUDController.TriggerSkillCooldown("M1", GROT_COOLDOWN)
				CombatController.RequestAttack("GrotM1")
			end
		end
	end)

	visualRemote.OnClientEvent:Connect(function(attackerPlayer, attackType, comboStep)
		CombatController.OnPlayVisuals(attackerPlayer, attackType, comboStep)
	end)
end

function CombatController.RequestAttack(attackType: string)
	local character = Players.LocalPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	attackRemote:FireServer(attackType)
end

function CombatController.OnPlayVisuals(attackerPlayer: Player, attackType: string, comboStep: number)
	local character = attackerPlayer.Character
	if not character then return end

	if attackType == "BlockyM1" then
		local attackData = CombatConfig.BlockyM1
		local torso = character:FindFirstChild("Torso") :: BasePart
		if torso then
			local rightShoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D
			if rightShoulder then
				local defaultC0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
				local punchC0 = defaultC0 * CFrame.Angles(math.rad(85), 0, math.rad(25))

				local punchTween = TweenService:Create(rightShoulder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					C0 = punchC0
				})
				punchTween:Play()

				task.delay(0.1, function()
					TweenService:Create(rightShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						C0 = defaultC0
					}):Play()
				end)
			end
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
		if rootPart then
			local punchWave = Instance.new("Part")
			punchWave.Name = "PunchVFX"
			punchWave.Size = Vector3.new(4, 5, 0.5)
			punchWave.CFrame = rootPart.CFrame * CFrame.new(attackData.HitboxOffset)
			punchWave.Color = Color3.fromRGB(0, 225, 255)
			punchWave.Material = Enum.Material.Neon
			punchWave.Transparency = 0.5
			punchWave.CanCollide = false
			punchWave.Anchored = true
			punchWave.Parent = Workspace

			TweenService:Create(punchWave, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
				Size = Vector3.new(4.5, 5.2, 0.6)
			}):Play()
			Debris:AddItem(punchWave, 0.25)

			local sound = Instance.new("Sound")
			sound.SoundId = "rbxasset://sounds/sword/swish.wav"
			sound.Volume = 0.8
			sound.Parent = rootPart
			sound:Play()
			Debris:AddItem(sound, 1)
		end

	elseif attackType == "GrotM1" then
		-- Heavy Tanker Slam visuals & camera bump
		GrotAnimationController.PlayM1(character)

		local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Grot_hitbox") :: BasePart
		if rootPart then
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxasset://sounds/sword/swish.wav"
			sound.Volume = 0.9
			sound.PlaybackSpeed = 0.82
			sound.Parent = rootPart
			sound:Play()
			Debris:AddItem(sound, 1)
		end
	end
end

return CombatController
