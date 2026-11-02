--[[
    LevelHandler.lua
    Manages player Leveling & EXP progression (Capped at Level 10):
    - Formula: EXP required = {Level} * 100 + {Level}
    - Grot Permanent Stat Growth: +3 DEF, +10 HP, +5 Stamina per level up
    - Synchronizes Level, EXP, and NextLevelEXP attributes across player and character
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared.Configs.EconomyConfig)
local RemoteManager = require(Shared.Modules.RemoteManager)

local LevelHandler = {}
local levelUpRemote = RemoteManager.GetRemoteEvent("LevelUpNotification")

function LevelHandler.Init()
	Players.PlayerAdded:Connect(LevelHandler.OnPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		LevelHandler.OnPlayerAdded(player)
	end
end

function LevelHandler.OnPlayerAdded(player: Player)
	if not player:GetAttribute("Level") then
		player:SetAttribute("Level", 1)
		player:SetAttribute("EXP", 0)
		player:SetAttribute("NextLevelEXP", EconomyConfig.GetRequiredExp(1))
	end

	player.CharacterAdded:Connect(function(character)
		LevelHandler.SyncToCharacter(player, character)
	end)
	player:GetPropertyChangedSignal("Character"):Connect(function()
		if player.Character then
			LevelHandler.SyncToCharacter(player, player.Character)
		end
	end)

	if player.Character then
		LevelHandler.SyncToCharacter(player, player.Character)
	end
end

function LevelHandler.SyncToCharacter(player: Player, character: Model)
	local lvl = player:GetAttribute("Level") or 1
	local exp = player:GetAttribute("EXP") or 0
	local req = player:GetAttribute("NextLevelEXP") or EconomyConfig.GetRequiredExp(lvl)

	character:SetAttribute("Level", lvl)
	character:SetAttribute("EXP", exp)
	character:SetAttribute("NextLevelEXP", req)
end

function LevelHandler.AddExp(player: Player, amount: number)
	if not player or amount <= 0 then return end

	local currentLevel = player:GetAttribute("Level") or 1
	if currentLevel >= EconomyConfig.MaxLevel then
		return
	end

	local currentExp = (player:GetAttribute("EXP") or 0) + amount
	local reqExp = EconomyConfig.GetRequiredExp(currentLevel)

	local leveledUp = false

	while currentLevel < EconomyConfig.MaxLevel and currentExp >= reqExp do
		currentExp -= reqExp
		currentLevel += 1
		reqExp = EconomyConfig.GetRequiredExp(currentLevel)
		leveledUp = true

		-- Apply Permanent Stat Growth per Level Up
		local character = player.Character
		if character then
			local charId = character:GetAttribute("CharacterId") or "Unmorphed"
			local growth = EconomyConfig.LevelUpGrowth[charId] or EconomyConfig.LevelUpGrowth.Grot

			local humanoid = character:FindFirstChildOfClass("Humanoid")

			-- 1. DEF Growth
			if growth.DEF then
				local currentDef = character:GetAttribute("DEF") or 0
				character:SetAttribute("DEF", currentDef + growth.DEF)
			end

			-- 2. HP Growth (+10 HP, MaxHealth +10, instant heal +10)
			if growth.HP then
				local currentMaxHp = character:GetAttribute("MaxHealth") or 100
				local newMaxHp = currentMaxHp + growth.HP
				character:SetAttribute("MaxHealth", newMaxHp)
				character:SetAttribute("HP", newMaxHp)

				if humanoid then
					humanoid.MaxHealth = newMaxHp
					humanoid.Health = math.min(newMaxHp, humanoid.Health + growth.HP)
					character:SetAttribute("Health", humanoid.Health)
				end
			end

			-- 3. Stamina Growth (+5 Stamina, MaxStamina +5)
			if growth.Stamina then
				local currentMaxStamina = character:GetAttribute("MaxStamina") or 100
				local newMaxStamina = currentMaxStamina + growth.Stamina
				character:SetAttribute("MaxStamina", newMaxStamina)
				local curStamina = character:GetAttribute("Stamina") or currentMaxStamina
				character:SetAttribute("Stamina", math.min(newMaxStamina, curStamina + growth.Stamina))
			end
		end
	end

	player:SetAttribute("Level", currentLevel)
	player:SetAttribute("EXP", currentExp)
	player:SetAttribute("NextLevelEXP", reqExp)

	if player.Character then
		LevelHandler.SyncToCharacter(player, player.Character)
	end

	if leveledUp then
		levelUpRemote:FireAllClients(player, currentLevel)
	end
end

return LevelHandler
