--[[
    CharacterConfig.lua
    Centralized data definitions for ALL characters using the 12-stat schema.
    Stats:
      HP, Regen, Stamina, Recovery, Walk, Sprint, Jump, Physical, Magic, DEF, Crit, CritDMG
--]]

local CharacterConfig = {
	-- Unmorphed: Default spawn state before stepping onto a morph stand
	Unmorphed = {
		Name = "Unmorphed",
		Description = "Default player avatar before stepping onto a morph stand.",
		
		-- 12-Stat Schema
		HP = 100,
		Regen = 1.0,
		Stamina = 100,
		Recovery = 10.0,
		Walk = 16,
		Sprint = 24,
		Jump = 100, -- Basic JumpPower
		Physical = 0,
		Magic = 0,
		DEF = 0,
		Crit = 0,
		CritDMG = 100,
		
		StaminaDrainRate = 15,
		Skills = {},
		PortraitImage = "rbxasset://textures/ui/GuiImagePlaceholder.png",
	},

	-- Blocky: Iconic brawler with 111 HP/Stamina and a devastating 25 DMG M1 strike
	Blocky = {
		Name = "Blocky",
		Description = "Iconic blocky character with 111 HP/Stamina and a devastating 25 DMG M1 strike.",
		
		-- 12-Stat Schema
		HP = 111,
		Regen = 11.0,
		Stamina = 111,
		Recovery = 11.0,
		Walk = 16,
		Sprint = 26,
		Jump = 111, -- Blocky 111 JumpPower
		Physical = 25,
		Magic = 0,
		DEF = 0,
		Crit = 0,
		CritDMG = 100,
		
		StaminaDrainRate = 15,
		Skills = {
			M1 = "BlockyM1",
		},
		PortraitImage = "rbxasset://textures/ui/GuiImagePlaceholder.png",
	},

	-- Grot: Heavy nature golem with innate DEF and Sprout Grows M1
	Grot = {
		Name = "Grot",
		Description = "Sturdy nature golem with high HP, innate DEF barrier, and life-stealing Sprout Grows M1.",
		
		-- 12-Stat Schema
		HP = 250,
		Regen = 2.5,
		Stamina = 75,
		Recovery = 2.5,
		Walk = 15,
		Sprint = 20,
		Jump = 75, -- Heavy golem 75 JumpPower
		Physical = 25,
		Magic = 0,
		DEF = 15,
		Crit = 0,
		CritDMG = 100,
		
		StaminaDrainRate = 15,
		Skills = {
			M1 = "GrotM1",
		},
		PortraitImage = "rbxasset://textures/ui/GuiImagePlaceholder.png",
	},

	-- Legacy / NPC Templates
	Champion = {
		Name = "Champion",
		Description = "A versatile warrior with balanced health and stamina.",
		HP = 100,
		Regen = 1.0,
		Stamina = 100,
		Recovery = 5.0,
		Walk = 16,
		Sprint = 26,
		Jump = 100,
		Physical = 15,
		Magic = 0,
		DEF = 0,
		Crit = 5,
		CritDMG = 120,
		StaminaDrainRate = 15,
		Skills = {},
		PortraitImage = "rbxasset://textures/ui/GuiImagePlaceholder.png",
	},
}

return CharacterConfig
