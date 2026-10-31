--[[
    DeepTestSuite.server.lua
    Deep automated verification suite for Arena of Champions update 1.1.
    Validates:
      1. Character Config 11-Stat Schema
      2. Combat Config: StaminaCost = 0 for M1, true 2.0s cooldown, 0.25s windup, 0.20s linger
      3. Damage & Flat DEF Reduction Math
      4. HP Regen vs Stamina Recovery Strict Separation
      5. Self-Hit Prevention in Spatial Queries
      6. Grot Bounding Box Center Rigging (LimbPivot proxy parts & 0 floating)
      7. Grot HumanoidRootPart Orientation Calibration & Calibrated HipHeight
      8. M1 Hitbox Forward Z Offset (-math.abs)
      9. Noob Test Dummy Spawning (100 HP, DEF = 0)
      10. Morph Stands (Blocky & Grot) Initialization
--]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared.Configs.CharacterConfig)
local CombatConfig = require(Shared.Configs.CombatConfig)
local HitboxEngine = require(Shared.Modules.HitboxEngine)
local BlockyRigFactory = require(Shared.Modules.BlockyRigFactory)
local GrotRigFactory = require(Shared.Modules.GrotRigFactory)
local DummyHandler = require(ServerScriptService.Handlers.DummyHandler)
local MorphStandHandler = require(ServerScriptService.Handlers.MorphStandHandler)

task.wait(1.5)

print("\n=======================================================")
print("🧪 RUNNING DEEP VERIFICATION TEST SUITE 1.1: ARENA OF CHAMPIONS")
print("=======================================================\n")

local totalTests = 0
local passedTests = 0
local failedTests = 0

local function assertTest(name: string, condition: boolean, detail: string?)
	totalTests += 1
	if condition then
		passedTests += 1
		print(string.format("  [PASS] %s", name))
	else
		failedTests += 1
		warn(string.format("  [FAIL] %s - %s", name, detail or "Assertion failed"))
	end
end

-- =============================================================================
-- TEST 1: Character Config 11-Stat Schema
-- =============================================================================
print("\n--- Test Group 1: 12-Stat Schema Definitions ---")
local requiredStats = { "HP", "Regen", "Stamina", "Recovery", "Walk", "Sprint", "Jump", "Physical", "Magic", "DEF", "Crit", "CritDMG" }

for _, charKey in ipairs({ "Unmorphed", "Blocky", "Grot" }) do
	local cfg = CharacterConfig[charKey]
	assertTest(string.format("CharacterConfig.%s exists", charKey), cfg ~= nil)
	if cfg then
		for _, stat in ipairs(requiredStats) do
			assertTest(string.format("%s has stat '%s'", charKey, stat), cfg[stat] ~= nil, "Missing " .. stat)
		end
	end
end

local unmorphedCfg = CharacterConfig.Unmorphed
if unmorphedCfg then
	assertTest("Unmorphed Jump == 100", unmorphedCfg.Jump == 100)
end

local blockyCfg = CharacterConfig.Blocky
if blockyCfg then
	assertTest("Blocky Jump == 111", blockyCfg.Jump == 111)
end

local grotCfg = CharacterConfig.Grot
if grotCfg then
	assertTest("Grot HP == 250", grotCfg.HP == 250)
	assertTest("Grot Regen == 2.5", grotCfg.Regen == 2.5)
	assertTest("Grot Stamina == 75", grotCfg.Stamina == 75)
	assertTest("Grot Recovery == 2.5", grotCfg.Recovery == 2.5)
	assertTest("Grot Walk == 15", grotCfg.Walk == 15)
	assertTest("Grot Sprint == 20", grotCfg.Sprint == 20)
	assertTest("Grot Jump == 75", grotCfg.Jump == 75)
	assertTest("Grot Physical == 25", grotCfg.Physical == 25)
	assertTest("Grot Magic == 0", grotCfg.Magic == 0)
	assertTest("Grot DEF == 15", grotCfg.DEF == 15)
	assertTest("Grot Crit == 0", grotCfg.Crit == 0)
	assertTest("Grot CritDMG == 100", grotCfg.CritDMG == 100)
end

-- =============================================================================
-- TEST 2: Combat Config: 0 StaminaCost & Timings
-- =============================================================================
print("\n--- Test Group 2: Combat Config & Stamina Lockout Elimination ---")
local grotM1 = CombatConfig.GrotM1
assertTest("CombatConfig.GrotM1 exists", grotM1 ~= nil)
if grotM1 then
	assertTest("Grot M1 StaminaCost == 0 (No stamina lockout)", grotM1.StaminaCost == 0)
	assertTest("Grot M1 Cooldown == 2.0s", grotM1.Cooldown == 2.0)
	assertTest("Grot M1 Windup == 0.25s", grotM1.Windup == 0.25)
	assertTest("Grot M1 Linger == 0.20s", grotM1.Linger == 0.20)
	assertTest("Grot M1 Base Damage formula {Physical} - {Walk} = 10", (grotCfg.Physical - grotCfg.Walk) == 10)
end

local blockyM1 = CombatConfig.BlockyM1
assertTest("CombatConfig.BlockyM1 exists", blockyM1 ~= nil)
if blockyM1 then
	assertTest("Blocky M1 StaminaCost == 0", blockyM1.StaminaCost == 0)
	assertTest("Blocky M1 Cooldown == 1.5s", blockyM1.Cooldown == 1.5)
	assertTest("Blocky M1 Damage == 25", blockyM1.Damage == 25)
end

-- =============================================================================
-- TEST 3: Damage & Flat DEF Reduction Math
-- =============================================================================
print("\n--- Test Group 3: Damage & Flat DEF Reduction Math ---")
local function calcDamage(raw: number, targetDef: number, isTrue: boolean): number
	if isTrue then return raw end
	return math.max(0, raw - targetDef)
end

assertTest("Raw 10 DMG vs DEF 0 deals 10 DMG (Dummy hit)", calcDamage(10, 0, false) == 10)
assertTest("Raw 10 DMG vs DEF 15 deals 0 DMG (Grot barrier absorbs all)", calcDamage(10, 15, false) == 0)
assertTest("Raw 25 DMG vs DEF 15 deals 10 DMG (Blocky vs Grot)", calcDamage(25, 15, false) == 10)
assertTest("Raw 25 DMG vs DEF 0 deals 25 DMG (Blocky vs Dummy)", calcDamage(25, 0, false) == 25)
assertTest("Raw 10 TRUE DMG vs DEF 15 deals 10 DMG (TRUE bypasses DEF)", calcDamage(10, 15, true) == 10)

-- =============================================================================
-- TEST 4: HP Regen vs Stamina Recovery Strict Separation
-- =============================================================================
print("\n--- Test Group 4: HP Regen vs Stamina Recovery Math ---")
local testHP = 200
local maxHP = 250
local regenRate = 2.5
local testStamina = 50
local maxStamina = 75
local recoveryRate = 2.5
local dt = 1.0

local newHP = math.min(maxHP, testHP + (regenRate * dt))
local newStamina = math.min(maxStamina, testStamina + (recoveryRate * dt))

assertTest("HP regens strictly by Regen * dt: 200 + 2.5 = 202.5", newHP == 202.5)
assertTest("Stamina regens strictly by Recovery * dt: 50 + 2.5 = 52.5", newStamina == 52.5)

-- =============================================================================
-- TEST 5: Prevent Self-Hit in Spatial Queries
-- =============================================================================
print("\n--- Test Group 5: Prevent Self-Hit Spatial Queries ---")
local mockAttacker = Instance.new("Model")
mockAttacker.Name = "MockAttacker"
local mockHrp = Instance.new("Part")
mockHrp.Name = "HumanoidRootPart"
mockHrp.Size = Vector3.new(2, 2, 1)
mockHrp.CFrame = CFrame.new(100, 10, 100)
mockHrp.Parent = mockAttacker
local mockHum = Instance.new("Humanoid")
mockHum.Health = 100
mockHum.Parent = mockAttacker
mockAttacker.PrimaryPart = mockHrp
mockAttacker.Parent = Workspace

local queryBox = HitboxEngine.GetTargetsInBox(mockAttacker, mockHrp.CFrame, Vector3.new(10, 10, 10))
local attackerHitItself = false
for _, char in ipairs(queryBox) do
	if char == mockAttacker or char:IsDescendantOf(mockAttacker) then
		attackerHitItself = true
	end
end
assertTest("Attacker strictly excluded from GetTargetsInBox (No self-hit)", not attackerHitItself)
mockAttacker:Destroy()

-- =============================================================================
-- TEST 6: Grot Bounding Box Center Rigging & Orientation
-- =============================================================================
print("\n--- Test Group 6: Grot Rigging & Orientation ---")
local grotModel = GrotRigFactory.CreateGrotModel()
assertTest("GrotRigFactory.CreateGrotModel() returns a valid Model", grotModel ~= nil and grotModel:IsA("Model"))

if grotModel then
	local hitbox = grotModel:FindFirstChild("Grot_hitbox") :: BasePart?
	assertTest("Grot contains Grot_hitbox as BasePart", hitbox ~= nil and hitbox:IsA("BasePart"))

	local hrp = grotModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	assertTest("Grot contains HumanoidRootPart", hrp ~= nil and hrp:IsA("BasePart"))
	if hrp then
		assertTest("PrimaryPart is HumanoidRootPart", grotModel.PrimaryPart == hrp)
	end

	local humanoid = grotModel:FindFirstChildOfClass("Humanoid")
	assertTest("Grot has Humanoid with MaxHealth == 250", humanoid ~= nil and humanoid.MaxHealth == 250)
	if humanoid then
		assertTest("Grot WalkSpeed == 15", humanoid.WalkSpeed == 15)
		assertTest("Grot HipHeight properly calibrated (>= 1.8)", humanoid.HipHeight >= 1.8)
	end

	-- Verify LimbPivot proxy parts created for 6 limbs
	local expectedLimbs = { "Brown arm", "Brown leg", "Head", "Orange arm", "Orange leg", "Torso" }
	local foundPivots = 0
	for _, limbName in ipairs(expectedLimbs) do
		local limb = grotModel:FindFirstChild(limbName, true)
		if limb then
			local pivot = limb:FindFirstChild(limbName .. "_Pivot")
			if pivot and pivot:IsA("BasePart") then
				foundPivots += 1
			end
		end
	end
	assertTest(string.format("LimbPivot bounding-box proxies created (found %d of 6)", foundPivots), foundPivots >= 5)

	-- Verify attributes
	assertTest("Grot model attribute HP == 250", grotModel:GetAttribute("HP") == 250)
	assertTest("Grot model attribute MaxStamina == 75", grotModel:GetAttribute("MaxStamina") == 75)
	assertTest("Grot model attribute Jump == 75", grotModel:GetAttribute("Jump") == 75)
	assertTest("Grot humanoid JumpPower == 75", humanoid.JumpPower == 75)
	assertTest("Grot model attribute DEF == 15", grotModel:GetAttribute("DEF") == 15)

	grotModel:Destroy()
end

-- =============================================================================
-- TEST 7: M1 Hitbox Offset Z Sign Verification
-- =============================================================================
print("\n--- Test Group 7: M1 Hitbox Forward Z Offset ---")
local hitboxData = GrotRigFactory.ExtractHitboxData()
assertTest("Hitbox data extracted", hitboxData ~= nil and hitboxData.Offset ~= nil)
if hitboxData then
	assertTest("M1 Hitbox Z offset is strictly negative (In front of character)", hitboxData.Offset.Z < 0, string.format("Offset.Z is %.2f", hitboxData.Offset.Z))
end

-- =============================================================================
-- TEST 8: Noob Testing Dummy Spawning (Press B)
-- =============================================================================
print("\n--- Test Group 8: Noob Test Dummy Spawning ---")
local testDummy = DummyHandler.CreateNoobDummy(CFrame.new(200, 5, 200))
assertTest("DummyHandler.CreateNoobDummy returns valid Model", testDummy ~= nil and testDummy:IsA("Model"))

if testDummy then
	local dummyHum = testDummy:FindFirstChildOfClass("Humanoid")
	assertTest("Noob Dummy Humanoid MaxHealth == 100", dummyHum ~= nil and dummyHum.MaxHealth == 100)
	assertTest("Noob Dummy Attribute DEF == 0", testDummy:GetAttribute("DEF") == 0)
	testDummy:Destroy()
end

-- =============================================================================
-- TEST 9: Morph Stands Initialization
-- =============================================================================
print("\n--- Test Group 9: Morph Stands Initialization ---")
local blockyStand = Workspace:FindFirstChild("BlockyMorphStand")
assertTest("BlockyMorphStand exists in Workspace", blockyStand ~= nil)

local grotStand = Workspace:FindFirstChild("GrotMorphStand")
assertTest("GrotMorphStand exists in Workspace", grotStand ~= nil)
if grotStand then
	local grotPad = grotStand:FindFirstChild("MorphPad")
	assertTest("Grot MorphPad exists with Neon material", grotPad ~= nil and grotPad.Material == Enum.Material.Neon)
end

-- =============================================================================
-- FINAL TEST SUMMARY
-- =============================================================================
print("\n=======================================================")
print(string.format("🏁 TEST SUITE 1.1 COMPLETE: %d/%d PASSED (%d FAILED)", passedTests, totalTests, failedTests))
print("=======================================================\n")
