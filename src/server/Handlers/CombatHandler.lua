--[[
    CombatHandler.lua
    Server-authoritative combat handler.
    Validates attack and skill requests, tracks cooldowns per skill independently
    (bypassed when player has NoCooldown cheat enabled),
    executes lingering hitboxes strictly in front of the player (negative local Z),
    applies dynamic stat formulas with math.ceil() rounding, flat DEF damage mitigation
    (bypassed / 0 damage when target has Invincible cheat enabled),
    and coordinates Grot M1 (0.10s linger) and Grot S1 "Vine" (0.95s windup, 3.0s zone, 0.5s pulses).
--]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Configs.CombatConfig)
local HitboxEngine = require(Shared.Modules.HitboxEngine)
local RemoteManager = require(Shared.Modules.RemoteManager)
local GrotRigFactory = require(Shared.Modules.GrotRigFactory)

local CombatHandler = {}

local attackRemote = RemoteManager.GetRemoteEvent("PerformAttack")
local visualRemote = RemoteManager.GetRemoteEvent("PlayAttackVisuals")

-- playerSkillCooldowns[player][attackType] = lastTimestamp
local playerSkillCooldowns = {}

function CombatHandler.Init()
	attackRemote.OnServerEvent:Connect(function(player, attackType)
		CombatHandler.ProcessAttack(player, attackType)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerSkillCooldowns[player] = nil
	end)
end

function CombatHandler.ProcessAttack(player: Player, attackType: string)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Grot_hitbox") :: BasePart
	if not humanoid or humanoid.Health <= 0 or not rootPart then return end

	-- Disallow attacks if Unmorphed, Hitstunned, or currently executing another attack swing
	local charId = character:GetAttribute("CharacterId") or "Unmorphed"
	if charId == "Unmorphed" then
		return
	end

	if character:GetAttribute("IsHitstunned") or character:GetAttribute("IsAttacking") or character:GetAttribute("IsCastingSkill") then
		return
	end

	local currentTime = os.clock()
	if not playerSkillCooldowns[player] then
		playerSkillCooldowns[player] = {}
	end
	local lastCooldown = playerSkillCooldowns[player][attackType] or 0
	local hasNoCooldown = (player:GetAttribute("NoCooldown") == true) or (character:GetAttribute("NoCooldown") == true)

	-- =========================================================================
	-- 1. BLOCKY M1 ATTACK (1.5s Cooldown, 0 Stamina)
	-- =========================================================================
	if attackType == "BlockyM1" and charId == "Blocky" then
		local attackData = CombatConfig.BlockyM1
		if not attackData then return end

		-- Check 1.5s cooldown (bypassed if NoCooldown cheat is active)
		if not hasNoCooldown and (currentTime - lastCooldown) < (attackData.Cooldown - 0.08) then
			return
		end

		playerSkillCooldowns[player][attackType] = currentTime
		character:SetAttribute("IsAttacking", true)

		visualRemote:FireAllClients(player, "BlockyM1", 1)

		task.delay(0.08, function()
			if not character or not character.Parent or not rootPart then return end

			local hitboxCFrame = rootPart.CFrame * CFrame.new(attackData.HitboxOffset)
			local targets = HitboxEngine.GetTargetsInBox(character, hitboxCFrame, attackData.HitboxSize)

			local physStat = character:GetAttribute("Physical") or 25
			local rawDamage = math.ceil(physStat > 0 and physStat or attackData.Damage)

			for _, targetChar in ipairs(targets) do
				CombatHandler.ApplyDamage(character, targetChar, rawDamage, attackData.DamageType or "Physical", attackData.Knockback, attackData.Hitstun)
			end
		end)

		-- Reset IsAttacking cleanly
		task.delay(attackData.HitboxDuration + 0.1, function()
			if character and character.Parent then
				character:SetAttribute("IsAttacking", false)
			end
		end)

	-- =========================================================================
	-- 2. GROT M1 ATTACK ("Sprout grows" - 2.0s Cooldown, 0.10s Linger, 0 Stamina)
	-- =========================================================================
	elseif attackType == "GrotM1" and charId == "Grot" then
		local attackData = CombatConfig.GrotM1
		if not attackData then return end

		-- Check 2.0s cooldown (bypassed if NoCooldown cheat is active)
		if not hasNoCooldown and (currentTime - lastCooldown) < (attackData.Cooldown - 0.08) then
			return
		end

		playerSkillCooldowns[player][attackType] = currentTime
		character:SetAttribute("IsAttacking", true)

		visualRemote:FireAllClients(player, "GrotM1", 1)

		-- 0.25s Wind-up delay, then 0.10s active linger window
		local lingerDuration = attackData.Linger or 0.10
		task.delay(attackData.Windup, function()
			if not character or not character.Parent or not rootPart then return end

			local hitboxData = GrotRigFactory.ExtractHitboxData()
			local rawOffset = hitboxData.Offset
			local hitboxSize = hitboxData.Size

			-- Strictly enforce negative Z (in front of character's LookVector)
			local forwardZ = -math.abs(rawOffset.Z)
			if math.abs(forwardZ) < 3.5 then
				forwardZ = -4.5
			end
			local forwardOffset = CFrame.new(rawOffset.X, rawOffset.Y, forwardZ)

			-- Spawn translucent red debug visual box (Neon, Transparency 0.6)
			local hitboxVisual = Instance.new("Part")
			hitboxVisual.Name = "GrotM1HitboxVisual"
			hitboxVisual.Size = hitboxSize
			hitboxVisual.CFrame = rootPart.CFrame * forwardOffset
			hitboxVisual.Color = Color3.fromRGB(255, 50, 50)
			hitboxVisual.Transparency = 0.6
			hitboxVisual.Material = Enum.Material.Neon
			hitboxVisual.CanCollide = false
			hitboxVisual.CanTouch = false
			hitboxVisual.CanQuery = false
			hitboxVisual.Anchored = true
			hitboxVisual.Parent = Workspace
			Debris:AddItem(hitboxVisual, lingerDuration + 0.05)

			local hitTargets = {}
			local hasHitAtLeastOneEnemy = false
			local lingerStartTime = os.clock()

			-- Dynamic Formula: math.ceil(Physical - Walk) = math.ceil(25 - 14) = 11
			local physStat = character:GetAttribute("Physical") or 25
			local walkStat = character:GetAttribute("Walk") or 14
			local baseDamage = math.ceil(math.max(0, physStat - walkStat))

			local critChance = character:GetAttribute("Crit") or 0
			local critDmg = character:GetAttribute("CritDMG") or 100
			if critChance > 0 and math.random(1, 100) <= critChance then
				baseDamage = math.ceil(baseDamage * (critDmg / 100))
			end

			local lingerConnection: RBXScriptConnection
			lingerConnection = RunService.Heartbeat:Connect(function()
				local elapsed = os.clock() - lingerStartTime
				if elapsed >= lingerDuration or not character or not character.Parent or not rootPart then
					if lingerConnection then
						lingerConnection:Disconnect()
						lingerConnection = nil
					end
					if hitboxVisual and hitboxVisual.Parent then
						hitboxVisual:Destroy()
					end
					return
				end

				-- Follow rootPart during linger
				local currentHitboxCFrame = rootPart.CFrame * forwardOffset
				if hitboxVisual and hitboxVisual.Parent then
					hitboxVisual.CFrame = currentHitboxCFrame
				end

				-- Query targets (attacker strictly excluded)
				local targets = HitboxEngine.GetTargetsInBox(character, currentHitboxCFrame, hitboxSize)
				for _, targetChar in ipairs(targets) do
					if not hitTargets[targetChar] then
						hitTargets[targetChar] = true

						CombatHandler.ApplyDamage(character, targetChar, baseDamage, "Physical", attackData.Knockback, attackData.Hitstun)

						-- Self-Heal: once per swing if at least one enemy hit (+Regen = 2.5 HP)
						if not hasHitAtLeastOneEnemy then
							hasHitAtLeastOneEnemy = true
							local regenStat = character:GetAttribute("Regen") or 2.5
							local maxHp = character:GetAttribute("MaxHealth") or 250
							local newHp = math.min(maxHp, humanoid.Health + regenStat)
							humanoid.Health = newHp
							character:SetAttribute("Health", newHp)
						end
					end
				end
			end)
		end)

		-- Reset IsAttacking cleanly after 0.35s (0.25s windup + 0.10s linger = 0.35s)
		task.delay(attackData.Windup + lingerDuration, function()
			if character and character.Parent then
				character:SetAttribute("IsAttacking", false)
			end
		end)

	-- =========================================================================
	-- 3. GROT SKILL 1 ("Vine" / E Key - 16.0s Cooldown, 0.95s Windup, 3.0s Zone)
	-- =========================================================================
	elseif attackType == "GrotS1" and charId == "Grot" then
		local skillData = CombatConfig.GrotS1
		if not skillData then return end

		-- Check 16.0s cooldown (bypassed if NoCooldown cheat is active)
		if not hasNoCooldown and (currentTime - lastCooldown) < (skillData.Cooldown - 0.08) then
			return
		end

		playerSkillCooldowns[player][attackType] = currentTime
		character:SetAttribute("IsAttacking", true)
		character:SetAttribute("IsCastingSkill", true)

		-- 1. Lock movement speed to 0 for full 0.95s wind-up
		local normalWalkSpeed = character:GetAttribute("Walk") or 14
		humanoid.WalkSpeed = 0

		-- 2. Trigger 5-frame visuals across all clients
		visualRemote:FireAllClients(player, "GrotS1", 1)

		-- 3. Frames 1 to 4 (0.00s to 0.75s): Player can spin/aim. At 0.75s, entering Frame 5: lock rotation!
		task.delay(skillData.AimLockTime or 0.75, function()
			if character and character.Parent then
				character:SetAttribute("RotationLocked", true)
			end
			if humanoid and humanoid.Parent then
				humanoid.AutoRotate = false
			end
		end)

		-- 4. At 0.95s: Frame 5 finishes! Unlock movement/rotation, establish 3.0s lingering zone
		task.delay(skillData.Windup or 0.95, function()
			if not character or not character.Parent or not rootPart then return end

			-- Unlock movement and rotation immediately
			character:SetAttribute("IsCastingSkill", false)
			character:SetAttribute("RotationLocked", false)
			character:SetAttribute("IsAttacking", false)

			humanoid.WalkSpeed = normalWalkSpeed
			humanoid.AutoRotate = true

			-- Capture final orientation where Grot faced at Frame 5
			local finalFacingCFrame = rootPart.CFrame
			local s1HitboxData = GrotRigFactory.ExtractS1HitboxData()
			local zoneCFrame = finalFacingCFrame * s1HitboxData.Offset
			local hitboxSize = s1HitboxData.Size

			-- Spawn Frame 5 real spiky Skill area model anchored in world for 3.0s
			local frame5Model, frame5Offsets = GrotRigFactory.SpawnSkillAreaForFrame(5, character)
			if frame5Model and frame5Offsets then
				for part, relCF in pairs(frame5Offsets) do
					if part and part.Parent then
						part.CFrame = finalFacingCFrame * relCF
					end
				end
				Debris:AddItem(frame5Model, skillData.Linger or 3.0)
			end

			-- Pulse Logic: Every 0.5s for 3.0s = 6 pulses total
			task.spawn(function()
				local totalPulses = skillData.TotalPulses or 6
				local pulseInterval = skillData.PulseInterval or 0.5

				for pulseIndex = 1, totalPulses do
					if not character or not character.Parent then break end

					-- Show translucent red debug hitbox visual for each pulse
					local pulseDebug = Instance.new("Part")
					pulseDebug.Name = "VinePulseDebug"
					pulseDebug.Size = hitboxSize
					pulseDebug.CFrame = zoneCFrame
					pulseDebug.Color = Color3.fromRGB(255, 50, 50)
					pulseDebug.Transparency = 0.6
					pulseDebug.Material = Enum.Material.Neon
					pulseDebug.CanCollide = false
					pulseDebug.CanTouch = false
					pulseDebug.CanQuery = false
					pulseDebug.Anchored = true
					pulseDebug.Parent = Workspace
					Debris:AddItem(pulseDebug, 0.20)

					-- Query enemies inside the vine zone
					local targets = HitboxEngine.GetTargetsInBox(character, zoneCFrame, hitboxSize)

					-- Formula: math.ceil((Physical / 2) + Magic) = math.ceil(12.5 + 0) = 13
					local physStat = character:GetAttribute("Physical") or 25
					local magicStat = character:GetAttribute("Magic") or 0
					local pulseDamage = math.ceil((physStat / 2) + magicStat)

					local critChance = character:GetAttribute("Crit") or 0
					local critDmg = character:GetAttribute("CritDMG") or 100
					if critChance > 0 and math.random(1, 100) <= critChance then
						pulseDamage = math.ceil(pulseDamage * (critDmg / 100))
					end

					for _, targetChar in ipairs(targets) do
						CombatHandler.ApplyDamage(character, targetChar, pulseDamage, "Physical", skillData.Knockback, skillData.Hitstun)
					end

					-- Heal Rule: If pulse hits >= 1 enemy, heal Grot once by {Regen} (+2.5 HP)
					if #targets > 0 and humanoid and humanoid.Health > 0 then
						local regenStat = character:GetAttribute("Regen") or 2.5
						local maxHp = character:GetAttribute("MaxHealth") or 250
						local newHp = math.min(maxHp, humanoid.Health + regenStat)
						humanoid.Health = newHp
						character:SetAttribute("Health", newHp)
					end

					task.wait(pulseInterval)
				end

				if frame5Model and frame5Model.Parent then
					frame5Model:Destroy()
				end
			end)
		end)
	end
end

--[[
    Applies server-authoritative damage, flat DEF mitigation, knockback, and hitstun.
    Formula: FinalDamage = math.max(0, math.ceil(RawDamage) - TargetDEF). TRUE damage bypasses DEF.
    If target character has Invincible == true, all incoming damage deals 0!
--]]
function CombatHandler.ApplyDamage(attacker: Model, target: Model, rawDamage: number, damageType: string, knockback: number, hitstun: number)
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	local targetRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Grot_hitbox") :: BasePart
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") or attacker:FindFirstChild("Grot_hitbox") :: BasePart

	if not targetHumanoid or targetHumanoid.Health <= 0 then return end

	-- Invincible Cheat Check: deals 0 damage
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if target:GetAttribute("Invincible") == true or (targetPlayer and targetPlayer:GetAttribute("Invincible") == true) then
		return
	end

	local roundedDamage = math.ceil(rawDamage)
	local finalDamage = roundedDamage

	if damageType ~= "TRUE" then
		local targetDef = target:GetAttribute("DEF") or 0
		finalDamage = math.max(0, roundedDamage - targetDef)
	end

	targetHumanoid:TakeDamage(finalDamage)
	target:SetAttribute("Health", math.max(0, targetHumanoid.Health))

	if targetRoot and attackerRoot and knockback and knockback > 0 then
		local dir = (targetRoot.Position - attackerRoot.Position)
		local flatDir = Vector3.new(dir.X, 0, dir.Z)
		if flatDir.Magnitude > 0.01 then
			flatDir = flatDir.Unit
		else
			flatDir = attackerRoot.CFrame.LookVector
		end
		local knockbackVelocity = (flatDir + Vector3.new(0, 0.25, 0)).Unit * knockback

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Velocity = knockbackVelocity
		bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
		bodyVelocity.Parent = targetRoot
		Debris:AddItem(bodyVelocity, 0.15)
	end

	if hitstun and hitstun > 0 then
		target:SetAttribute("IsHitstunned", true)
		task.delay(hitstun, function()
			if target and target.Parent then
				target:SetAttribute("IsHitstunned", false)
			end
		end)
	end
end

return CombatHandler