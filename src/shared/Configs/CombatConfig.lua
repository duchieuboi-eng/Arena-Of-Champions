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
	-- Heavy blow dealing math.ceil(Physical - Walk) = 25 - 14 = 11 Physical Damage
	-- Heals Grot once by {Regen} (+2.5 HP) if at least 1 enemy is hit
	-- StaminaCost = 0, Cooldown = 2.0s, Windup = 0.25s, Linger = 0.10s
	GrotM1 = {
		Name = "Sprout grows",
		DamageType = "Physical",
		Formula = "math.ceil(Physical - Walk)", -- Dynamic: attacker's Physical minus Walk stat
		BasePhysicalDamage = 11,
		StaminaCost = 0,
		Cooldown = 2.0,       -- True 2.0s cooldown starting immediately upon click
		Windup = 0.25,        -- 0.25s delay after pressing MB1 before hitbox appears
		Linger = 0.10,        -- Active hitbox linger reduced to 0.10s
		HealStat = "Regen",    -- Heals once by attacker's {Regen} stat (2.5 HP) if >= 1 enemy hit
		Hitstun = 0.4,
		Knockback = 12,
		SoundId = "rbxasset://sounds/sword/swish.wav",
	},

	-- Grot Character Skill 1 (E Key): "Vine"
	-- Grot ultra-charges a heavy impact growing spiky vines in a line area.
	-- Deals pulsing damage and heals Grot on hit.
	-- Cooldown = 16.0s, StaminaCost = 0
	-- 5-frame wind-up (0.95s total): Frames 1-4 (0.75s) player can spin/aim, Frame 5 (0.20s) rotation locked.
	-- Zone lingers for 3.0s, pulsing every 0.5s (6 pulses):
	-- Damage per pulse: math.ceil((Physical / 2) + Magic) = math.ceil(12.5 + 0) = 13 Physical DMG (reduced by target DEF)
	-- Heal per pulse: if >= 1 enemy hit, heals Grot once by {Regen} (+2.5 HP)
	GrotS1 = {
		Name = "Vine",
		Key = "E",
		DamageType = "Physical",
		Formula = "math.ceil((Physical / 2) + Magic)",
		StaminaCost = 0,
		Cooldown = 16.0,
		Windup = 0.95,
		AimLockTime = 0.75,   -- Rotation locked after 0.75s (when entering Frame 5)
		WindupFrames = {
			{ Name = "Grot_S1frame1", Duration = 0.15, CanRotate = true },
			{ Name = "Grot_S1frame2", Duration = 0.25, CanRotate = true },
			{ Name = "Grot_S1frame3", Duration = 0.15, CanRotate = true },
			{ Name = "Grot_S1frame4", Duration = 0.20, CanRotate = true },
			{ Name = "Grot_S1frame5", Duration = 0.20, CanRotate = false },
		},
		Linger = 3.0,         -- Vine zone lingers for 3.0s
		PulseInterval = 0.5,  -- Pulses every 0.5s
		TotalPulses = 6,      -- 3.0s / 0.5s = 6 pulses
		HealStat = "Regen",   -- Heals once per pulse by {Regen} (+2.5 HP) if >= 1 enemy hit
		Hitstun = 0.2,
		Knockback = 6,
		SoundId = "rbxasset://sounds/sword/swish.wav",
	},
}

return CombatConfig
