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
local CharacterConfig = require(Shared.Configs.CharacterConfig)
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

--[[
    Recalculates and strictly enforces:
    Total Stat = Base Stat + Level Growth Bonus + Equipped Item Bonuses
    Guarantees morphing, respawning, buying, selling, or CMD editing never loses or corrupts stats.
--]]
function LevelHandler.RecalculateCharacterStats(player: Player, character: Model)
	if not character or not character.Parent then return end

	local charId = character:GetAttribute("CharacterId") or "Grot"
	local baseCfg = CharacterConfig[charId] or CharacterConfig.Grot

	-- 1. Base Stats
	local baseHp = character:GetAttribute("Base_HP") or baseCfg.HP
	local baseDef = character:GetAttribute("Base_DEF") or baseCfg.DEF
	local baseStamina = character:GetAttribute("Base_Stamina") or baseCfg.Stamina
	local basePhys = character:GetAttribute("Base_Physical") or baseCfg.Physical
	local baseMagic = character:GetAttribute("Base_Magic") or baseCfg.Magic

	-- Cache base stats onto character
	character:SetAttribute("Base_HP", baseHp)
	character:SetAttribute("Base_DEF", baseDef)
	character:SetAttribute("Base_Stamina", baseStamina)
	character:SetAttribute("Base_Physical", basePhys)
	character:SetAttribute("Base_Magic", baseMagic)

	-- 2. Level Growth Bonuses
	local level = player:GetAttribute("Level") or 1
	local levelUps = math.clamp(level - 1, 0, EconomyConfig.MaxLevel - 1)
	local growth = EconomyConfig.LevelUpGrowth[charId] or EconomyConfig.LevelUpGrowth.Grot

	local levelHp = levelUps * (growth.HP or 10)
	local levelDef = levelUps * (growth.DEF or 3)
	local levelStamina = levelUps * (growth.Stamina or 5)

	-- 3. Equipped Item Bonuses
	local itemPhys = 0
	local itemMagic = 0
	local itemDef = 0

	for i = 1, EconomyConfig.MaxInventorySlots do
		local itemId = player:GetAttribute("ItemSlot" .. tostring(i))
		if itemId and itemId ~= "" and EconomyConfig.Items[itemId] then
			local item = EconomyConfig.Items[itemId]
			if item.Stats.Physical then itemPhys += item.Stats.Physical end
			if item.Stats.Magic then itemMagic += item.Stats.Magic end
			if item.Stats.DEF then itemDef += item.Stats.DEF end
		end
	end

	-- 4. Apply Final Combined Stats
	local totalMaxHp = baseHp + levelHp
	local totalDef = baseDef + levelDef + itemDef
	local totalMaxStamina = baseStamina + levelStamina
	local totalPhys = basePhys + itemPhys
	local totalMagic = baseMagic + itemMagic

	character:SetAttribute("MaxHealth", totalMaxHp)
	character:SetAttribute("HP", totalMaxHp)
	character:SetAttribute("DEF", totalDef)
	character:SetAttribute("MaxStamina", totalMaxStamina)
	character:SetAttribute("Physical", totalPhys)
	character:SetAttribute("Magic", totalMagic)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = totalMaxHp
		humanoid.Health = math.clamp(humanoid.Health, 0, totalMaxHp)
		character:SetAttribute("Health", humanoid.Health)
	end
end

function LevelHandler.SyncToCharacter(player: Player, character: Model)
	local lvl = player:GetAttribute("Level") or 1
	local exp = player:GetAttribute("EXP") or 0
	local req = player:GetAttribute("NextLevelEXP") or EconomyConfig.GetRequiredExp(lvl)

	character:SetAttribute("Level", lvl)
	character:SetAttribute("EXP", exp)
	character:SetAttribute("NextLevelEXP", req)

	LevelHandler.RecalculateCharacterStats(player, character)
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
	local levelsGained = 0

	while currentLevel < EconomyConfig.MaxLevel and currentExp >= reqExp do
		currentExp -= reqExp
		currentLevel += 1
		levelsGained += 1
		reqExp = EconomyConfig.GetRequiredExp(currentLevel)
		leveledUp = true
	end

	player:SetAttribute("Level", currentLevel)
	player:SetAttribute("EXP", currentExp)
	player:SetAttribute("NextLevelEXP", reqExp)

	local character = player.Character
	if character then
		LevelHandler.SyncToCharacter(player, character)

		-- Level-up instant heals (+10 HP and +5 Stamina per level gained)
		if levelsGained > 0 then
			local charId = character:GetAttribute("CharacterId") or "Grot"
			local growth = EconomyConfig.LevelUpGrowth[charId] or EconomyConfig.LevelUpGrowth.Grot
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local newHp = math.min(character:GetAttribute("MaxHealth") or 250, humanoid.Health + ((growth.HP or 10) * levelsGained))
				humanoid.Health = newHp
				character:SetAttribute("Health", newHp)
			end
			local curStamina = character:GetAttribute("Stamina") or 75
			local newStamina = math.min(character:GetAttribute("MaxStamina") or 75, curStamina + ((growth.Stamina or 5) * levelsGained))
			character:SetAttribute("Stamina", newStamina)
		end
	end

	if leveledUp then
		levelUpRemote:FireAllClients(player, currentLevel)
	end
end

return LevelHandler
