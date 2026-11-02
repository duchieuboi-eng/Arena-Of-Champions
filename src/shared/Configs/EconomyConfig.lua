--[[
    EconomyConfig.lua
    Configuration for Arena of Valor (AoV) style economy, items, and leveling systems:
    - Gold & EXP economy (+100G and +100 EXP on dummy kill)
    - 3-slot Tier I Item Shop:
        * Shortsword (150G | 75G sell | +10 Physical)
        * Magic dust (250G | 125G sell | +30 Magic)
        * Leather armor (300G | 150G sell | +5 DEF)
    - Leveling system (Capped at 10, EXP formula: Level * 100 + Level)
    - Grot level-up permanent stat growth (+3 DEF, +10 HP, +5 Stamina)
--]]

local EconomyConfig = {
	MaxLevel = 10,

	-- EXP required to reach the next level from current level
	-- Formula: {Level} * 100 + {Level} (e.g. Lv1 -> 101 EXP, Lv2 -> 202 EXP)
	GetRequiredExp = function(level: number): number
		if level >= 10 then
			return 999999 -- Capped at Lv 10
		end
		return (level * 100) + level
	end,

	-- Rewards for defeating any dummy
	DummyRewards = {
		Gold = 100,
		EXP = 100,
	},

	-- Maximum inventory item slots
	MaxInventorySlots = 3,

	-- Tier I Item Definitions
	Items = {
		Shortsword = {
			Id = "Shortsword",
			Name = "Shortsword",
			Icon = "⚔️",
			Cost = 150,
			SellPrice = 75, -- 50% refund
			Stats = {
				Physical = 10,
			},
			Description = "+10 Physical Damage",
		},
		MagicDust = {
			Id = "MagicDust",
			Name = "Magic dust",
			Icon = "✨",
			Cost = 250,
			SellPrice = 125, -- 50% refund
			Stats = {
				Magic = 30,
			},
			Description = "+30 Magic Power",
		},
		LeatherArmor = {
			Id = "LeatherArmor",
			Name = "Leather armor",
			Icon = "🛡️",
			Cost = 300,
			SellPrice = 150, -- 50% refund
			Stats = {
				DEF = 5,
			},
			Description = "+5 Flat DEF",
		},
	},

	-- Permanent stat growths on level up
	LevelUpGrowth = {
		Grot = {
			DEF = 3,
			HP = 10,
			Stamina = 5,
		},
		Blocky = {
			DEF = 2,
			HP = 10,
			Stamina = 5,
		},
		Unmorphed = {
			DEF = 2,
			HP = 10,
			Stamina = 5,
		},
	},
}

return EconomyConfig
