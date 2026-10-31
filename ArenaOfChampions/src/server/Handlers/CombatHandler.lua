--[[
    CombatHandler.lua
    Server-authoritative combat handler.
    Validates attack requests, checks 2.0s cooldown starting immediately upon click,
    executes lingering hitboxes strictly in front of the player (negative local Z),
    applies flat DEF damage mitigation, and resets IsAttacking cleanly at 0.45s.
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

local playerAttackCooldowns = {}

function CombatHandler.Init()
	attackRemote.OnServerEvent:Connect(function(player, attackType)
		CombatHandler.ProcessAttack(player, attackType)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerAttackCooldowns[player] = nil
	end)
end

function CombatHandler.ProcessAttack(player: Player, attackType: string)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Grot_hitbox") :: BasePart
	if not humanoid or humanoid.Health <= 0 or not rootPart then return end

	-- Disallow M1 if Unmorphed, Hitstunned, or currently executing another attack swing
	local charId = character:GetAttribute("CharacterId") or "Unmorphed"
	if charId == "Unmorphed" then
		return
	end

	if character:GetAttribute("IsHitstunned") or character:GetAttribute("IsAttacking") then
		return
	end

	local currentTime = os.clock()
	local lastCooldown = playerAttackCooldowns[player] or 0

	-- =========================================================================
	-- 1. BLOCKY M1 ATTACK (1.5s Cooldown, 0 Stamina)
	-- =========================================================================
	if attackType == "BlockyM1" and charId == "Blocky" then
		local attackData = CombatConfig.BlockyM1
		if not attackData then return end

		-- Check 1.5s cooldown (0.08s buffer for network latency)
		if (currentTime - lastCooldown) < (attackData.Cooldown - 0.08) then
			return
		end

		-- Start cooldown timer immediately upon attack initiation
		playerAttackCooldowns[player] = currentTime
		character:SetAttribute("IsAttacking", true)

		visualRemote:FireAllClients(player, "BlockyM1", 1)

		task.delay(0.08, function()
			if not character or not character.Parent or not rootPart then return end

			local hitboxCFrame = rootPart.CFrame * CFrame.new(attackData.HitboxOffset)
			local targets = HitboxEngine.GetTargetsInBox(character, hitboxCFrame, attackData.HitboxSize)

			for _, targetChar in ipairs(targets) do
				CombatHandler.ApplyDamage(character, targetChar, attackData.Damage, attackData.DamageType or "Physical", attackData.Knockback, attackData.Hitstun)
			end
		end)

		-- Reset IsAttacking right when attack duration finishes
		task.delay(attackData.HitboxDuration + 0.1, function()
			if character and character.Parent then
				character:SetAttribute("IsAttacking", false)
			end
		end)

	-- =========================================================================
	-- 2. GROT M1 ATTACK ("Sprout grows" - True 2.0s Cooldown, 0 Stamina)
	-- =========================================================================
	elseif attackType == "GrotM1" and charId == "Grot" then
		local attackData = CombatConfig.GrotM1
		if not attackData then return end

		-- Check 2.0s cooldown (0.08s buffer for network latency)
		if (currentTime - lastCooldown) < (attackData.Cooldown - 0.08) then
			return
		end

		-- Start 2.0s cooldown timer immediately at the exact click timestamp
		playerAttackCooldowns[player] = currentTime
		character:SetAttribute("IsAttacking", true)

		-- Trigger visual 3-frame animation
		visualRemote:FireAllClients(player, "GrotM1", 1)

		-- 0.25s Wind-up delay, then 0.20s active linger window
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
			Debris:AddItem(hitboxVisual, attackData.Linger + 0.05)

			local hitTargets = {}
			local hasHitAtLeastOneEnemy = false
			local lingerStartTime = os.clock()

			-- Base Physical Damage = Physical (25) - Walk (15) = 10
			local physStat = character:GetAttribute("Physical") or 25
			local walkStat = character:GetAttribute("Walk") or 15
			local baseDamage = math.max(0, physStat - walkStat)

			local critChance = character:GetAttribute("Crit") or 0
			local critDmg = character:GetAttribute("CritDMG") or 100
			if critChance > 0 and math.random(1, 100) <= critChance then
				baseDamage = baseDamage * (critDmg / 100)
			end

			local lingerConnection: RBXScriptConnection
			lingerConnection = RunService.Heartbeat:Connect(function()
				local elapsed = os.clock() - lingerStartTime
				if elapsed >= attackData.Linger or not character or not character.Parent or not rootPart then
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

						-- Self-Heal: once per swing if at least one enemy hit
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

		-- Reset IsAttacking cleanly after 0.45s (0.25s windup + 0.20s linger = 0.45s)
		task.delay(0.45, function()
			if character and character.Parent then
				character:SetAttribute("IsAttacking", false)
			end
		end)
	end
end

--[[
    Applies server-authoritative damage, flat DEF mitigation, knockback, and hitstun.
    Formula: FinalDamage = math.max(0, RawDamage - TargetDEF). TRUE damage bypasses DEF.
--]]
function CombatHandler.ApplyDamage(attacker: Model, target: Model, rawDamage: number, damageType: string, knockback: number, hitstun: number)
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	local targetRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Grot_hitbox") :: BasePart
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") or attacker:FindFirstChild("Grot_hitbox") :: BasePart

	if not targetHumanoid or targetHumanoid.Health <= 0 then return end

	local finalDamage = rawDamage
	if damageType ~= "TRUE" then
		local targetDef = target:GetAttribute("DEF") or 0
		finalDamage = math.max(0, rawDamage - targetDef)
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
