--[[
    CharacterHandler.lua
    Manages player spawning, stat initialization (11-stat schema),
    strictly separated HP regeneration & Stamina recovery, and server-authoritative sprint logic.
    Ensures players start and respawn in an "Unmorphed" state where M1 is disabled.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared.Configs.CharacterConfig)
local RemoteManager = require(Shared.Modules.RemoteManager)

local CharacterHandler = {}

local sprintRemote = RemoteManager.GetRemoteEvent("SetSprintState")
local cameraResetRemote = RemoteManager.GetRemoteEvent("ResetCameraSubject")

function CharacterHandler.Init()
	-- Listen for new players joining
	Players.PlayerAdded:Connect(CharacterHandler.OnPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		CharacterHandler.OnPlayerAdded(player)
	end

	-- Listen for sprint remote from client
	sprintRemote.OnServerEvent:Connect(function(player, isSprintingRequested)
		CharacterHandler.SetSprintState(player, isSprintingRequested)
	end)

	-- Single centralized Heartbeat loop for passive HP regen and Stamina drain/recovery
	RunService.Heartbeat:Connect(CharacterHandler.OnUpdate)
end

function CharacterHandler.OnPlayerAdded(player: Player)
	-- Default state when joining is "Unmorphed"
	player:SetAttribute("SelectedCharacterId", "Unmorphed")

	player.CharacterAdded:Connect(function(character)
		CharacterHandler.OnCharacterSpawned(player, character)
	end)

	if player.Character then
		CharacterHandler.OnCharacterSpawned(player, player.Character)
	end
end

function CharacterHandler.OnCharacterSpawned(player: Player, character: Model)
	-- Remove default Roblox "Health" script to eliminate any conflicting regen loops
	local defaultHealth = character:FindFirstChild("Health")
	if defaultHealth and defaultHealth:IsA("Script") then
		defaultHealth:Destroy()
	end
	character.ChildAdded:Connect(function(child)
		if child.Name == "Health" and child:IsA("Script") then
			task.defer(function()
				child:Destroy()
			end)
		end
	end)

	-- If this character is already a custom rig (Blocky or Grot), attributes are configured by factory
	if character:GetAttribute("IsBlockyRig") or character:GetAttribute("IsGrotRig") then
		return
	end

	-- Player joins or respawns in "Unmorphed" default state
	player:SetAttribute("SelectedCharacterId", "Unmorphed")
	local config = CharacterConfig.Unmorphed

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	-- Apply full 11-stat schema as attributes
	character:SetAttribute("CharacterId", "Unmorphed")
	character:SetAttribute("CharacterName", "Unmorphed")
	character:SetAttribute("MaxHealth", config.HP)
	character:SetAttribute("Health", config.HP)
	character:SetAttribute("HP", config.HP)
	character:SetAttribute("Regen", config.Regen)
	character:SetAttribute("MaxStamina", config.Stamina)
	character:SetAttribute("Stamina", config.Stamina)
	character:SetAttribute("Recovery", config.Recovery)
	character:SetAttribute("Walk", config.Walk)
	character:SetAttribute("Sprint", config.Sprint)
	character:SetAttribute("Jump", config.Jump or 100)
	character:SetAttribute("Physical", config.Physical)
	character:SetAttribute("Magic", config.Magic)
	character:SetAttribute("DEF", config.DEF)
	character:SetAttribute("Crit", config.Crit)
	character:SetAttribute("CritDMG", config.CritDMG)
	character:SetAttribute("StaminaDrainRate", config.StaminaDrainRate or 15)
	character:SetAttribute("IsSprinting", false)
	character:SetAttribute("IsAttacking", false)

	humanoid.MaxHealth = config.HP
	humanoid.Health = config.HP
	humanoid.WalkSpeed = config.Walk
	humanoid.UseJumpPower = true
	humanoid.JumpPower = config.Jump or 100

	-- Fire Camera reset remote to guarantee client camera binds to new Humanoid
	cameraResetRemote:FireClient(player, character)

	-- Sync Humanoid Health with character attribute
	humanoid.HealthChanged:Connect(function(newHealth)
		character:SetAttribute("Health", math.clamp(newHealth, 0, character:GetAttribute("MaxHealth") or config.HP))
	end)

	-- Respawn after 3 seconds when dead (prevents permanent softlock)
	local hasDied = false
	humanoid.Died:Connect(function()
		if hasDied then return end
		hasDied = true
		task.wait(3)
		if player and player.Parent then
			player:SetAttribute("SelectedCharacterId", "Unmorphed")
			player:LoadCharacter()
		end
	end)
end

function CharacterHandler.SetSprintState(player: Player, isSprinting: boolean)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
	if not humanoid or humanoid.Health <= 0 then return end

	local walkSpeed = character:GetAttribute("Walk") or 16
	local sprintSpeed = character:GetAttribute("Sprint") or 24
	local stamina = character:GetAttribute("Stamina") or 0

	if isSprinting and stamina > 5 then
		character:SetAttribute("IsSprinting", true)
		humanoid.WalkSpeed = sprintSpeed
	else
		character:SetAttribute("IsSprinting", false)
		humanoid.WalkSpeed = walkSpeed
	end
end

function CharacterHandler.OnUpdate(deltaTime: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if not character then continue end

		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
		if not humanoid or humanoid.Health <= 0 then continue end

		local maxHealth = character:GetAttribute("MaxHealth") or 100
		local currentHealth = humanoid.Health
		local regen = character:GetAttribute("Regen") or 1.0

		local maxStamina = character:GetAttribute("MaxStamina") or 100
		local currentStamina = character:GetAttribute("Stamina") or maxStamina
		local recovery = character:GetAttribute("Recovery") or 10.0
		local drainRate = character:GetAttribute("StaminaDrainRate") or 15
		local isSprinting = character:GetAttribute("IsSprinting") or false
		local walkSpeed = character:GetAttribute("Walk") or 16

		-- 1. Strictly Separated Health Regeneration: HP + (Regen * dt)
		if currentHealth < maxHealth then
			local newHealth = math.min(maxHealth, currentHealth + (regen * deltaTime))
			humanoid.Health = newHealth
			character:SetAttribute("Health", newHealth)
		end

		-- 2. Strictly Separated Stamina Recovery & Sprint Drain: Stamina + (Recovery * dt)
		if isSprinting then
			local newStamina = math.max(0, currentStamina - (drainRate * deltaTime))
			character:SetAttribute("Stamina", newStamina)

			if newStamina <= 0 then
				character:SetAttribute("IsSprinting", false)
				humanoid.WalkSpeed = walkSpeed
			end
		else
			if currentStamina < maxStamina then
				local newStamina = math.min(maxStamina, currentStamina + (recovery * deltaTime))
				character:SetAttribute("Stamina", newStamina)
			end
		end
	end
end

return CharacterHandler
