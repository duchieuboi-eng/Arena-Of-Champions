--[[
    CMDHandler.lua
    Server-side handler for the Forsaken / Item Asylum style Testing Command (CMD) Panel:
    - Cheats: No Cooldown and Invincible
    - Live Stat Editor: updates character attributes and Humanoid properties in real time
    - Dummy Spawner: Moving Dummy, Tank Dummy, Aggressive Dummy, and Clear All Dummies
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteManager = require(Shared.Modules.RemoteManager)
local DummyHandler = require(script.Parent.DummyHandler)

local CMDHandler = {}

local toggleCheatRemote = RemoteManager.GetRemoteEvent("CMD_ToggleCheat")
local applyStatsRemote = RemoteManager.GetRemoteEvent("CMD_ApplyStats")
local spawnDummyRemote = RemoteManager.GetRemoteEvent("CMD_SpawnDummy")
local clearDummiesRemote = RemoteManager.GetRemoteEvent("CMD_ClearDummies")

function CMDHandler.Init()
	-- 1. Toggle Cheats
	toggleCheatRemote.OnServerEvent:Connect(function(player: Player, cheatName: string, state: boolean)
		if type(cheatName) ~= "string" or type(state) ~= "boolean" then return end

		if cheatName == "NoCooldown" or cheatName == "Invincible" then
			player:SetAttribute(cheatName, state)
			local character = player.Character
			if character then
				character:SetAttribute(cheatName, state)
			end
		end
	end)

	-- 2. Apply Stats
	applyStatsRemote.OnServerEvent:Connect(function(player: Player, targetPlayerName: string, statsTable: { [string]: any })
		if type(statsTable) ~= "table" then return end

		local targetPlayer = player
		if type(targetPlayerName) == "string" and targetPlayerName ~= "" then
			targetPlayer = Players:FindFirstChild(targetPlayerName) or player
		end

		local character = targetPlayer and targetPlayer.Character
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")

		-- HP / MaxHealth
		if statsTable.HP ~= nil then
			local hpVal = math.max(1, tonumber(statsTable.HP) or 100)
			character:SetAttribute("MaxHealth", hpVal)
			character:SetAttribute("HP", hpVal)
			character:SetAttribute("Health", hpVal)
			if humanoid then
				humanoid.MaxHealth = hpVal
				humanoid.Health = hpVal
			end
		end

		-- Regen
		if statsTable.Regen ~= nil then
			local regenVal = tonumber(statsTable.Regen) or 0
			character:SetAttribute("Regen", regenVal)
		end

		-- Stamina / MaxStamina
		if statsTable.Stamina ~= nil then
			local staminaVal = math.max(0, tonumber(statsTable.Stamina) or 100)
			character:SetAttribute("MaxStamina", staminaVal)
			character:SetAttribute("Stamina", staminaVal)
		end

		-- Recovery
		if statsTable.Recovery ~= nil then
			local recoveryVal = tonumber(statsTable.Recovery) or 0
			character:SetAttribute("Recovery", recoveryVal)
		end

		-- Walk
		if statsTable.Walk ~= nil then
			local walkVal = math.max(0, tonumber(statsTable.Walk) or 16)
			character:SetAttribute("Walk", walkVal)
			if humanoid and not character:GetAttribute("IsSprinting") and not character:GetAttribute("IsCastingSkill") then
				humanoid.WalkSpeed = walkVal
			end
		end

		-- Sprint
		if statsTable.Sprint ~= nil then
			local sprintVal = math.max(0, tonumber(statsTable.Sprint) or 24)
			character:SetAttribute("Sprint", sprintVal)
			if humanoid and character:GetAttribute("IsSprinting") and not character:GetAttribute("IsCastingSkill") then
				humanoid.WalkSpeed = sprintVal
			end
		end

		-- Jump
		if statsTable.Jump ~= nil then
			local jumpVal = math.max(0, tonumber(statsTable.Jump) or 50)
			character:SetAttribute("Jump", jumpVal)
			if humanoid then
				humanoid.UseJumpPower = true
				humanoid.JumpPower = jumpVal
			end
		end

		-- Combat & Defensive Stats
		if statsTable.Physical ~= nil then
			character:SetAttribute("Physical", tonumber(statsTable.Physical) or 0)
		end
		if statsTable.Magic ~= nil then
			character:SetAttribute("Magic", tonumber(statsTable.Magic) or 0)
		end
		if statsTable.DEF ~= nil then
			character:SetAttribute("DEF", tonumber(statsTable.DEF) or 0)
		end
		if statsTable.Crit ~= nil then
			character:SetAttribute("Crit", tonumber(statsTable.Crit) or 0)
		end
		if statsTable.CritDMG ~= nil then
			character:SetAttribute("CritDMG", tonumber(statsTable.CritDMG) or 100)
		end
	end)

	-- 3. Spawn Dummies
	spawnDummyRemote.OnServerEvent:Connect(function(player: Player, dummyType: string)
		local character = player.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Grot_hitbox") :: BasePart?
		if not rootPart then return end

		-- Spawn 8 studs in front of player
		local spawnPos = rootPart.Position + (rootPart.CFrame.LookVector * 8)
		local lookTarget = spawnPos + rootPart.CFrame.LookVector
		local spawnCFrame = CFrame.lookAt(spawnPos, Vector3.new(lookTarget.X, spawnPos.Y, lookTarget.Z))

		if dummyType == "Moving" then
			DummyHandler.CreateMovingDummy(spawnCFrame)
		elseif dummyType == "Tank" then
			DummyHandler.CreateTankDummy(spawnCFrame)
		elseif dummyType == "Aggressive" then
			DummyHandler.CreateAggressiveDummy(spawnCFrame)
		else
			DummyHandler.CreateNoobDummy(spawnCFrame)
		end
	end)

	-- 4. Clear Dummies
	clearDummiesRemote.OnServerEvent:Connect(function(player: Player)
		DummyHandler.ClearAllDummies()
	end)
end

return CMDHandler
