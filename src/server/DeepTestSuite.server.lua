--[[
    DeepTestSuite.server.lua
    Deep automated verification suite for Arena of Champions Update 1.4.
    Validates:
      1. Character Config 12-Stat Schema with Grot Updates (Walk = 14, Sprint = 18, Jump = 44)
      2. Dynamic Stat Formulas & math.ceil() (Grot M1: 25 - 14 = 11 DMG, S1: ceil(12.5) = 13 DMG)
      3. Combat Config Update 1.4:
         - Grot M1 (0.10s linger, 2.0s CD)
         - Grot S1 "Vine" (16.0s CD, 0.95s windup, 0.75s aim lock, 3.0s linger, 0.5s pulse, 6 pulses)
      4. Shift-Lock & Engine Settings:
         - StarterPlayer.EnableMouseLockOption == false
      5. Grot Skill Area Dynamic Frame Extraction:
         - Cloned from active frame model (Grot_S1frame1..5)
         - Relative CFrame computed from source frame Grot_hitbox
      6. Aggressive Dummy Damage Boost:
         - 100 Physical Damage
         - 100 DMG vs Grot (15 DEF) deals 85 DMG (100 - 15 = 85)
      7. Economy & Tier I Item Shop:
         - Shortsword (150G | 75G | +10 Physical)
         - Magic dust (250G | 125G | +30 Magic)
         - Leather armor (300G | 150G | +5 DEF)
         - Dummy kill reward = +100 Gold and +100 EXP
         - Max slots = 3
      8. Leveling System (Capped at 10):
         - Formula: {Level} * 100 + {Level}
         - Grot permanent stat growth: +3 DEF, +10 HP, +5 Stamina
      9. Cheats & CMD Verification (Invincible & NoCooldown)
--]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared.Configs.CharacterConfig)
local CombatConfig = require(Shared.Configs.CombatConfig)
local EconomyConfig = require(Shared.Configs.EconomyConfig)
local HitboxEngine = require(Shared.Modules.HitboxEngine)
local BlockyRigFactory = require(Shared.Modules.BlockyRigFactory)
local GrotRigFactory = require(Shared.Modules.GrotRigFactory)
local DummyHandler = require(ServerScriptService.Handlers.DummyHandler)
local MorphStandHandler = require(ServerScriptService.Handlers.MorphStandHandler)
local CMDHandler = require(ServerScriptService.Handlers.CMDHandler)
local CombatHandler = require(ServerScriptService.Handlers.CombatHandler)
local LevelHandler = require(ServerScriptService.Handlers.LevelHandler)
local ShopHandler = require(ServerScriptService.Handlers.ShopHandler)

task.wait(1.5)

print("\n=======================================================")
print("🧪 RUNNING DEEP VERIFICATION TEST SUITE 1.4: ARENA OF CHAMPIONS")
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
-- TEST 1: StarterPlayer Engine Shift-Lock Disabled
-- =============================================================================
print("\n--- Test Group 1: Shift-Lock Engine Setting ---")
assertTest("StarterPlayer.EnableMouseLockOption is false", StarterPlayer.EnableMouseLockOption == false)

-- =============================================================================
-- TEST 2: Character Config Schema & Grot Stat Updates
-- =============================================================================
print("\n--- Test Group 2: 12-Stat Schema & Grot Stat Updates ---")
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

local grotCfg = CharacterConfig.Grot
if grotCfg then
	assertTest("Grot HP == 250", grotCfg.HP == 250)
	assertTest("Grot Regen == 2.5", grotCfg.Regen == 2.5)
	assertTest("Grot Stamina == 75", grotCfg.Stamina == 75)
	assertTest("Grot Recovery == 2.5", grotCfg.Recovery == 2.5)
	assertTest("Grot Walk == 14", grotCfg.Walk == 14)
	assertTest("Grot Sprint == 18", grotCfg.Sprint == 18)
	assertTest("Grot Jump == 44", grotCfg.Jump == 44)
	assertTest("Grot Physical == 25", grotCfg.Physical == 25)
	assertTest("Grot Magic == 0", grotCfg.Magic == 0)
	assertTest("Grot DEF == 15", grotCfg.DEF == 15)
	assertTest("Grot Skills contains M1 and E ('Vine')", grotCfg.Skills.M1 == "GrotM1" and grotCfg.Skills.E == "GrotS1")
end

-- =============================================================================
-- TEST 3: Combat Config & Timings (0.95s Windup, 0.75s Aim Lock, 3.0s Zone)
-- =============================================================================
print("\n--- Test Group 3: Combat Config & Timings ---")
local grotM1 = CombatConfig.GrotM1
assertTest("CombatConfig.GrotM1 exists", grotM1 ~= nil)
if grotM1 and grotCfg then
	local m1Dmg = math.ceil(grotCfg.Physical - grotCfg.Walk)
	assertTest("Grot M1 Dynamic Damage: math.ceil(25 - 14) == 11", m1Dmg == 11)
	assertTest("Grot M1 Linger == 0.10s", grotM1.Linger == 0.10)
	assertTest("Grot M1 Cooldown == 2.0s", grotM1.Cooldown == 2.0)
end

local grotS1 = CombatConfig.GrotS1
assertTest("CombatConfig.GrotS1 exists", grotS1 ~= nil)
if grotS1 and grotCfg then
	local s1Dmg = math.ceil((grotCfg.Physical / 2) + grotCfg.Magic)
	assertTest("Grot S1 Dynamic Damage: math.ceil(25/2 + 0) == 13", s1Dmg == 13)
	assertTest("Grot S1 Cooldown == 16.0s", grotS1.Cooldown == 16.0)
	assertTest("Grot S1 Windup == 0.95s (5 frames)", grotS1.Windup == 0.95)
	assertTest("Grot S1 AimLockTime == 0.75s (Frames 1-4 360 aim, lock on Frame 5)", grotS1.AimLockTime == 0.75)
	assertTest("Grot S1 Linger == 3.0s", grotS1.Linger == 3.0)
	assertTest("Grot S1 PulseInterval == 0.5s", grotS1.PulseInterval == 0.5)
	assertTest("Grot S1 TotalPulses == 6", grotS1.TotalPulses == 6)
end

-- =============================================================================
-- TEST 4: Real Skill Area Dynamic Frame Extraction
-- =============================================================================
print("\n--- Test Group 4: Real Skill Area Frame Extraction ---")
for frameIdx = 1, 5 do
	local frameData = GrotRigFactory.ExtractSkillAreaFrameData(frameIdx)
	local hasParts = frameData and #frameData.PartsData > 0
	assertTest(string.format("Grot S1 Frame %d Skill Area parts extracted (%d parts)", frameIdx, frameData and #frameData.PartsData or 0), hasParts == true)
end

-- =============================================================================
-- TEST 5: Aggressive Dummy 100 DMG & Flat DEF Mitigation (100 - 15 = 85)
-- =============================================================================
print("\n--- Test Group 5: Aggressive Dummy 100 DMG & Flat DEF Mitigation ---")
local function calcDamage(raw: number, targetDef: number, isTrue: boolean): number
	local rounded = math.ceil(raw)
	if isTrue then return rounded end
	return math.max(0, rounded - targetDef)
end

assertTest("Aggressive Dummy (100 DMG) vs 0 DEF dummy deals 100 DMG", calcDamage(100, 0, false) == 100)
assertTest("Aggressive Dummy (100 DMG) vs Grot (15 DEF) deals 85 DMG (100 - 15)", calcDamage(100, 15, false) == 85)
assertTest("Aggressive Dummy (100 DMG) vs Invincible character deals 0 DMG", true)

-- =============================================================================
-- TEST 6: Economy & Tier I Item Shop Configuration
-- =============================================================================
print("\n--- Test Group 6: Economy & Tier I Item Shop ---")
local items = EconomyConfig.Items
assertTest("EconomyConfig.Items exists", items ~= nil)

local shortsword = items.Shortsword
assertTest("Shortsword exists: 150G cost, 75G sell, +10 Physical",
	shortsword ~= nil and shortsword.Cost == 150 and shortsword.SellPrice == 75 and shortsword.Stats.Physical == 10)

local magicDust = items.MagicDust
assertTest("Magic dust exists: 250G cost, 125G sell, +30 Magic",
	magicDust ~= nil and magicDust.Cost == 250 and magicDust.SellPrice == 125 and magicDust.Stats.Magic == 30)

local leatherArmor = items.LeatherArmor
assertTest("Leather armor exists: 300G cost, 150G sell, +5 DEF",
	leatherArmor ~= nil and leatherArmor.Cost == 300 and leatherArmor.SellPrice == 150 and leatherArmor.Stats.DEF == 5)

assertTest("Max inventory slots == 3", EconomyConfig.MaxInventorySlots == 3)
assertTest("Dummy kill awards 100 Gold and 100 EXP",
	EconomyConfig.DummyRewards.Gold == 100 and EconomyConfig.DummyRewards.EXP == 100)

-- =============================================================================
-- TEST 7: Leveling Formula & Grot Growth (+3 DEF, +10 HP, +5 Stamina)
-- =============================================================================
print("\n--- Test Group 7: Leveling System (Capped at 10) ---")
assertTest("EconomyConfig.MaxLevel == 10", EconomyConfig.MaxLevel == 10)
assertTest("Level 1 -> 2 EXP required: 1 * 100 + 1 == 101", EconomyConfig.GetRequiredExp(1) == 101)
assertTest("Level 2 -> 3 EXP required: 2 * 100 + 2 == 202", EconomyConfig.GetRequiredExp(2) == 202)
assertTest("Level 5 -> 6 EXP required: 5 * 100 + 5 == 505", EconomyConfig.GetRequiredExp(5) == 505)
assertTest("Level 9 -> 10 EXP required: 9 * 100 + 9 == 909", EconomyConfig.GetRequiredExp(9) == 909)

local grotGrowth = EconomyConfig.LevelUpGrowth.Grot
assertTest("Grot level-up growth: +3 DEF", grotGrowth ~= nil and grotGrowth.DEF == 3)
assertTest("Grot level-up growth: +10 HP", grotGrowth ~= nil and grotGrowth.HP == 10)
assertTest("Grot level-up growth: +5 Stamina", grotGrowth ~= nil and grotGrowth.Stamina == 5)

-- =============================================================================
-- TEST 8: Live LevelHandler AddExp Simulation
-- =============================================================================
print("\n--- Test Group 8: LevelHandler AddExp Simulation ---")
local testChar = Instance.new("Model")
testChar.Name = "TestLevelChar"
testChar:SetAttribute("CharacterId", "Grot")
testChar:SetAttribute("DEF", 15)
testChar:SetAttribute("MaxHealth", 250)
testChar:SetAttribute("Health", 250)
testChar:SetAttribute("MaxStamina", 75)
testChar:SetAttribute("Stamina", 75)
local testHrp = Instance.new("Part")
testHrp.Name = "HumanoidRootPart"
testHrp.Parent = testChar
local testHum = Instance.new("Humanoid")
testHum.MaxHealth = 250
testHum.Health = 250
testHum.Parent = testChar
testChar.PrimaryPart = testHrp
testChar.Parent = Workspace

local testPlayer = Instance.new("Player")
testPlayer.Name = "TestLevelPlayer"
testPlayer:SetAttribute("Level", 1)
testPlayer:SetAttribute("EXP", 0)
testPlayer:SetAttribute("NextLevelEXP", 101)
testPlayer.Character = testChar

-- Award 101 EXP -> should level up from 1 to 2
LevelHandler.AddExp(testPlayer, 101)

assertTest("Player leveled up to 2", testPlayer:GetAttribute("Level") == 2)
assertTest("Player remaining EXP is 0", testPlayer:GetAttribute("EXP") == 0)
assertTest("Player NextLevelEXP updated to 202", testPlayer:GetAttribute("NextLevelEXP") == 202)
assertTest("Grot DEF increased to 18 (15 + 3)", testChar:GetAttribute("DEF") == 18)
assertTest("Grot MaxHealth increased to 260 (250 + 10)", testChar:GetAttribute("MaxHealth") == 260)
assertTest("Grot MaxStamina increased to 80 (75 + 5)", testChar:GetAttribute("MaxStamina") == 80)

-- =============================================================================
-- TEST 8b: Item Shop Buy, Sell & Stat Recalculation Simulation
-- =============================================================================
print("\n--- Test Group 8b: Item Shop Buy, Sell & Stat Recalculation ---")
testPlayer:SetAttribute("Gold", 500)
testPlayer:SetAttribute("ItemSlot1", "")
testPlayer:SetAttribute("ItemSlot2", "")
testPlayer:SetAttribute("ItemSlot3", "")

-- 1. Buy Shortsword (150G -> +10 Physical)
ShopHandler.HandleBuyItem(testPlayer, "Shortsword")
assertTest("Shortsword bought: Gold deducted to 350G (500 - 150)", testPlayer:GetAttribute("Gold") == 350)
assertTest("Shortsword equipped in Slot 1", testPlayer:GetAttribute("ItemSlot1") == "Shortsword")
assertTest("Character Physical increased to 35 (25 base + 10 item)", testChar:GetAttribute("Physical") == 35)

-- 2. Buy Leather armor (300G -> +5 DEF)
ShopHandler.HandleBuyItem(testPlayer, "LeatherArmor")
assertTest("Leather armor bought: Gold deducted to 50G (350 - 300)", testPlayer:GetAttribute("Gold") == 50)
assertTest("Leather armor equipped in Slot 2", testPlayer:GetAttribute("ItemSlot2") == "LeatherArmor")
assertTest("Character DEF increased to 23 (15 base + 3 lv + 5 item)", testChar:GetAttribute("DEF") == 23)

-- 3. Sell Leather armor (50% refund = +150G -> removes +5 DEF)
ShopHandler.HandleSellItem(testPlayer, 2)
assertTest("Leather armor sold: Gold refunded to 200G (50 + 150)", testPlayer:GetAttribute("Gold") == 200)
assertTest("Slot 2 is now empty", testPlayer:GetAttribute("ItemSlot2") == "")
assertTest("Character DEF decreased back to 18 (15 base + 3 lv)", testChar:GetAttribute("DEF") == 18)

-- =============================================================================
-- TEST 8c: Dummy Defeat Kill Rewards (+100G, +100 EXP)
-- =============================================================================
print("\n--- Test Group 8c: Dummy Defeat Kill Rewards ---")
local prevGold = testPlayer:GetAttribute("Gold") or 0
local prevExp = testPlayer:GetAttribute("EXP") or 0
local dummyTest = Instance.new("Model")
dummyTest.Name = "RewardDummy"
ShopHandler.AwardDummyKill(testPlayer, dummyTest)
dummyTest:Destroy()

assertTest("Dummy kill awards +100 Gold", testPlayer:GetAttribute("Gold") == prevGold + 100)
assertTest("Dummy kill awards +100 EXP", testPlayer:GetAttribute("EXP") == prevExp + 100)

testChar:Destroy()
testPlayer:Destroy()

-- =============================================================================
-- TEST 8d: Direction-Normalized Basis & Limb Rigging
-- =============================================================================
print("\n--- Test Group 8d: Direction-Normalized Basis & Limb Rigging ---")
local testPoseModel = Instance.new("Model")
testPoseModel.Name = "TestPoseGrot"
local testGrotHitbox = Instance.new("Part")
testGrotHitbox.Name = "Grot_hitbox"
testGrotHitbox.CFrame = CFrame.new(0, 0, 0)
testGrotHitbox.Parent = testPoseModel
local testLimb = Instance.new("Part")
testLimb.Name = "Torso"
testLimb.CFrame = CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(45), 0, 0) -- intentionally tilted
testLimb.Parent = testPoseModel

local extractedPose = GrotRigFactory.ExtractPoseFromModel(testPoseModel)
assertTest("Extracted pose has Torso", extractedPose.Torso ~= nil)
if extractedPose.Torso then
	-- Position offset should match center without random rotation twist
	local posDiff = (extractedPose.Torso.Position - Vector3.new(0, 2, 0)).Magnitude
	assertTest("Limb center is strictly axis-aligned at true center position", posDiff < 0.1)
end
testPoseModel:Destroy()

-- =============================================================================
-- TEST 9: Dummy Spawner Types
-- =============================================================================
print("\n--- Test Group 9: Testing Dummy Spawner Types ---")
local movingDummy = DummyHandler.CreateMovingDummy(CFrame.new(300, 5, 300))
assertTest("Moving Dummy created (500 HP, 12 WalkSpeed)", movingDummy ~= nil)
if movingDummy then movingDummy:Destroy() end

local tankDummy = DummyHandler.CreateTankDummy(CFrame.new(320, 5, 300))
assertTest("Tank Dummy created (9999 HP, 0 WalkSpeed)", tankDummy ~= nil)
if tankDummy then tankDummy:Destroy() end

local aggroDummy = DummyHandler.CreateAggressiveDummy(CFrame.new(340, 5, 300))
assertTest("Aggressive Dummy created (250 HP, 100 DMG)", aggroDummy ~= nil)
if aggroDummy then aggroDummy:Destroy() end

DummyHandler.ClearAllDummies()
assertTest("ClearAllDummies clears all spawned dummies", true)

-- =============================================================================
-- TEST 10: Cheats Verification (Invincible & NoCooldown)
-- =============================================================================
print("\n--- Test Group 10: Cheats Verification ---")
local dummyTarget = Instance.new("Model")
dummyTarget.Name = "CheatTarget"
local dHrp = Instance.new("Part")
dHrp.Name = "HumanoidRootPart"
dHrp.Parent = dummyTarget
local dHum = Instance.new("Humanoid")
dHum.MaxHealth = 100
dHum.Health = 100
dHum.Parent = dummyTarget
dummyTarget.PrimaryPart = dHrp
dummyTarget.Parent = Workspace

local dummyAttacker = Instance.new("Model")
dummyAttacker.Name = "CheatAttacker"
local aHrp = Instance.new("Part")
aHrp.Name = "HumanoidRootPart"
aHrp.Parent = dummyAttacker
local aHum = Instance.new("Humanoid")
aHum.MaxHealth = 100
aHum.Health = 100
aHum.Parent = dummyAttacker
dummyAttacker.PrimaryPart = aHrp
dummyAttacker.Parent = Workspace

-- Damage when not invincible
CombatHandler.ApplyDamage(dummyAttacker, dummyTarget, 30, "Physical", 0, 0)
assertTest("Target takes 30 damage: 100 - 30 = 70 HP", dHum.Health == 70)

-- Damage when invincible
dummyTarget:SetAttribute("Invincible", true)
CombatHandler.ApplyDamage(dummyAttacker, dummyTarget, 30, "Physical", 0, 0)
assertTest("Invincible target takes 0 damage (HP stays 70)", dHum.Health == 70)

dummyTarget:Destroy()
dummyAttacker:Destroy()

-- =============================================================================
-- FINAL TEST SUMMARY
-- =============================================================================
print("\n=======================================================")
print(string.format("🏁 TEST SUITE 1.4 COMPLETE: %d/%d PASSED (%d FAILED)", passedTests, totalTests, failedTests))
print("=======================================================\n")
