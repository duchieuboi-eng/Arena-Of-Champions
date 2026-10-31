--[[
    CombatConfig.lua
    Data-driven combat configuration for attacks, combos, timings, and hitboxes.
--]]

local CombatConfig = {
	-- Blocky Character M1: 25 DMG strike (StaminaCost = 0 to prevent stamina lockout)
	BlockyM1 = {
		Name = "Blocky Strike",
		DamageType = "Physical",
		Damage = 25,
		StaminaCost = 0,
		Cooldown = 1.5,
		HitboxSize = Vector3.new(4, 5, 5),
		HitboxOffset = Vector3.new(0, 0, -3.2),
		HitboxDuration = 0.15,
		Hitstun = 0.3,
		Knockback = 11,
		AnimationId = "rbxassetid://0",
		SoundId = "rbxasset://sounds/sword/swish.wav",
	},

	-- Grot Character M1: "Sprout grows"
	-- Heavy blow dealing {Physical} - {Walk} = 10 Physical Damage and healing Grot once by {Regen} (+2.5 HP)
	-- StaminaCost = 0 so M1 never drains stamina or gets locked out while sprinting
	GrotM1 = {
		Name = "Sprout grows",
		DamageType = "Physical",
		Formula = "Physical - Walk", -- Dynamic: uses attacker's Physical stat minus base Walk stat
		BasePhysicalDamage = 10,
		StaminaCost = 0,
		Cooldown = 2.0,       -- True 2.0s cooldown starting immediately upon click
		Windup = 0.25,        -- 0.25s delay after pressing MB1 before hitbox appears
		Linger = 0.20,        -- Hitbox lingers for 0.20s following root part
		HealStat = "Regen",    -- Heals once by attacker's {Regen} stat (2.5 HP) if >= 1 enemy hit
		Hitstun = 0.4,
		Knockback = 12,
		SoundId = "rbxasset://sounds/sword/swish.wav",
	},
}

return CombatConfig
