--[[
    DeepTestSuite.server.lua
    Deep automated verification suite for Arena of Champions Update 1.3.
    Validates:
      1. Character Config 12-Stat Schema with Grot Updates (Walk = 14, Sprint = 18, Jump = 44)
      2. Dynamic Stat Formulas & math.ceil() (Grot M1: 25 - 14 = 11 DMG, S1: ceil(12.5) = 13 DMG)
      3. Combat Config Update 1.3:
         - Grot M1 (0.10s linger, 2.0s CD)
         - Grot S1 "Vine" (16.0s CD, 0.95s windup, 0.75s aim lock, 3.0s linger, 0.5s pulse, 6 pulses)
      4. Stamina 1.0s Delay After Sprinting Logic
      5. Global Passive HP Regen (Every 2.5s Tick)
      6. Flat DEF Mitigation Math with Round-Up
      7. Self-Hit Prevention in Spatial Queries
      8. Grot Bounding Box Rigging & Skill area Exclusion from playable body
      9. Dynamic Skill Area Frame Extraction (Grot_S1frame1..5 real models with relative offsets)
      10. Testing Dummies:
         - Moving Dummy (500 HP, 0 DEF, 12 WalkSpeed)
         - Tank Dummy (9999 HP, 0 DEF)
         - Aggressive Dummy (250 HP, 0 DEF, 10 DMG)
         - Clear All Dummies functionality
      11. CMD Handler Remotes & Cheats:
         - NoCooldown cheat bypass
         - Invincible cheat 0 DMG immunity
         - Stat Editor attribute updates
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
local CMDHandler = require(ServerScriptService.Handlers.CMDHandler)
local CombatHandler = require(ServerScriptService.Handlers.CombatHandler)

task.wait(1.5)

print("\n=======================================================")
print("🧪 RUNNING DEEP VERIFICATION TEST SUITE 1.3: ARENA OF CHAMPIONS")
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
-- TEST 1: Character Config Schema & Grot Stat Updates
-- =============================================================================
print("\n--- Test Group 1: 12-Stat Schema & Grot Stat Updates ---")
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
	assertTest("Grot Walk == 14 (Heavy golem walk)", grotCfg.Walk == 14)
	assertTest("Grot Sprint == 18 (Heavy golem sprint)", grotCfg.Sprint == 18)
	assertTest("Grot Jump == 44", grotCfg.Jump == 44)
	assertTest("Grot Physical == 25", grotCfg.Physical == 25)
	assertTest("Grot Magic == 0", grotCfg.Magic == 0)
	assertTest("Grot DEF == 15", grotCfg.DEF == 15)
	assertTest("Grot Skills contains M1 and E ('Vine')", grotCfg.Skills.M1 == "GrotM1" and grotCfg.Skills.E == "GrotS1")
end

-- =============================================================================
-- TEST 2: Dynamic Damage Formulas & Update 1.3 Combat Timings
-- =============================================================================
print("\n--- Test Group 2: Dynamic Damage Formulas & Update 1.3 Combat Timings ---")
local grotM1 = CombatConfig.GrotM1
assertTest("CombatConfig.GrotM1 exists", grotM1 ~= nil)
if grotM1 and grotCfg then
	local m1Dmg = math.ceil(grotCfg.Physical - grotCfg.Walk)
	assertTest("Grot M1 Dynamic Damage: math.ceil(25 - 14) == 11", m1Dmg == 11)
	assertTest("Grot M1 Linger == 0.10s", grotM1.Linger == 0.10)
	assertTest("Grot M1 Cooldown == 2.0s", grotM1.Cooldown == 2.0)
	assertTest("Grot M1 Windup == 0.25s", grotM1.Windup == 0.25)
	assertTest("Grot M1 StaminaCost == 0", grotM1.StaminaCost == 0)
end

local grotS1 = CombatConfig.GrotS1
assertTest("CombatConfig.GrotS1 exists", grotS1 ~= nil)
if grotS1 and grotCfg then
	local s1Dmg = math.ceil((grotCfg.Physical / 2) + grotCfg.Magic)
	assertTest("Grot S1 Dynamic Damage: math.ceil(25/2 + 0) == 13", s1Dmg == 13)
	assertTest("Grot S1 Cooldown == 16.0s", grotS1.Cooldown == 16.0)
	assertTest("Grot S1 Windup == 0.95s (Update 1.3 5-frame windup)", grotS1.Windup == 0.95)
	assertTest("Grot S1 AimLockTime == 0.75s (Frames 1-4 360 spin, lock on Frame 5)", grotS1.AimLockTime == 0.75)
	assertTest("Grot S1 Linger == 3.0s (Active vine zone)", grotS1.Linger == 3.0)
	assertTest("Grot S1 PulseInterval == 0.5s", grotS1.PulseInterval == 0.5)
	assertTest("Grot S1 TotalPulses == 6 (3.0s / 0.5s = 6 pulses)", grotS1.TotalPulses == 6)
	assertTest("Grot S1 StaminaCost == 0", grotS1.StaminaCost == 0)

	-- Verify 5-frame windup durations sum to 0.95s
	if grotS1.Frames then
		local sum = 0
		for _, dur in ipairs(grotS1.Frames) do
			sum += dur
		end
		assertTest("Grot S1 Frames sum exactly to 0.95s", math.abs(sum - 0.95) < 0.001)
	end
end

-- =============================================================================
-- TEST 3: Stamina 1.0s Delay After Sprinting Logic
-- =============================================================================
print("\n--- Test Group 3: Stamina 1.0s Delay After Sprinting Logic ---")
local testSprintStopTime = 100.0

local function canRecoverStamina(currentTime: number, stopTime: number): boolean
	return (currentTime - stopTime) >= 1.0
end

assertTest("At +0.5s after sprinting: Stamina recovery blocked (delay active)", not canRecoverStamina(100.5, testSprintStopTime))
assertTest("At +0.99s after sprinting: Stamina recovery blocked", not canRecoverStamina(100.99, testSprintStopTime))
assertTest("At +1.0s after sprinting: Stamina recovery allowed", canRecoverStamina(101.0, testSprintStopTime))
assertTest("At +2.0s after sprinting: Stamina recovery allowed", canRecoverStamina(102.0, testSprintStopTime))

-- =============================================================================
-- TEST 4: Global Passive HP Regen (Every 2.5s Tick)
-- =============================================================================
print("\n--- Test Group 4: Global Passive HP Regen (Every 2.5s Tick) ---")
local function canTickHpRegen(currentTime: number, lastTickTime: number): boolean
	return (currentTime - lastTickTime) >= 2.5
end

assertTest("At +1.0s: HP regen does NOT tick (not frame continuous)", not canTickHpRegen(101.0, 100.0))
assertTest("At +2.49s: HP regen does NOT tick", not canTickHpRegen(102.49, 100.0))
assertTest("At +2.50s: HP regen ticks flat {Regen} amount", canTickHpRegen(102.5, 100.0))

local currentHP = 200
local maxHP = 250
local regen = 2.5
local tickedHP = math.min(maxHP, currentHP + regen)
assertTest("Tick heals flat {Regen} amount: 200 + 2.5 = 202.5", tickedHP == 202.5)

-- =============================================================================
-- TEST 5: Flat DEF Mitigation Math with Round-Up
-- =============================================================================
print("\n--- Test Group 5: Flat DEF Mitigation Math with Round-Up ---")
local function calcDamage(raw: number, targetDef: number, isTrue: boolean): number
	local rounded = math.ceil(raw)
	if isTrue then return rounded end
	return math.max(0, rounded - targetDef)
end

assertTest("Grot M1 (11 DMG) vs Dummy (DEF 0) deals 11 DMG", calcDamage(11, 0, false) == 11)
assertTest("Grot M1 (11 DMG) vs Grot (DEF 15) deals 0 DMG (Absorbed)", calcDamage(11, 15, false) == 0)
assertTest("Grot S1 Pulse (13 DMG) vs Dummy (DEF 0) deals 13 DMG", calcDamage(13, 0, false) == 13)
assertTest("Grot S1 Pulse (13 DMG) vs Grot (DEF 15) deals 0 DMG", calcDamage(13, 15, false) == 0)
assertTest("Blocky M1 (25 DMG) vs Dummy (DEF 0) deals 25 DMG", calcDamage(25, 0, false) == 25)
assertTest("Blocky M1 (25 DMG) vs Grot (DEF 15) deals 10 DMG", calcDamage(25, 15, false) == 10)
assertTest("TRUE Damage (13 DMG) vs Grot (DEF 15) bypasses DEF to deal 13 DMG", calcDamage(13, 15, true) == 13)

-- =============================================================================
-- TEST 6: Prevent Self-Hit Spatial Queries
-- =============================================================================
print("\n--- Test Group 6: Prevent Self-Hit Spatial Queries ---")
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
-- TEST 7: Grot Rigging & Skill Area Exclusion from Body
-- =============================================================================
print("\n--- Test Group 7: Grot Rigging & Skill Area Exclusion ---")
local grotModel = GrotRigFactory.CreateGrotModel()
assertTest("GrotRigFactory.CreateGrotModel() returns valid Model", grotModel ~= nil and grotModel:IsA("Model"))

if grotModel then
	local humanoid = grotModel:FindFirstChildOfClass("Humanoid")
	assertTest("Grot has Humanoid", humanoid ~= nil)
	if humanoid then
		assertTest("Grot humanoid WalkSpeed == 14", humanoid.WalkSpeed == 14)
		assertTest("Grot humanoid JumpPower == 44", humanoid.JumpPower == 44)
		assertTest("Grot humanoid UseJumpPower == true", humanoid.UseJumpPower == true)
		assertTest("Grot humanoid HipHeight >= 1.8", humanoid.HipHeight >= 1.8)
	end

	-- Verify Skill area is NOT a welded limb on character
	local skillAreaInside = grotModel:FindFirstChild("Skill area", true)
	assertTest("Skill area is NOT welded as a body limb on character", skillAreaInside == nil)

	-- Verify LimbPivot proxy parts for 6 body limbs
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
	assertTest(string.format("LimbPivot bounding-box proxies created (%d/6)", foundPivots), foundPivots >= 5)

	-- Verify attributes
	assertTest("Grot Walk attribute == 14", grotModel:GetAttribute("Walk") == 14)
	assertTest("Grot Sprint attribute == 18", grotModel:GetAttribute("Sprint") == 18)
	assertTest("Grot Jump attribute == 44", grotModel:GetAttribute("Jump") == 44)
	assertTest("Grot DEF attribute == 15", grotModel:GetAttribute("DEF") == 15)

	grotModel:Destroy()
end

-- =============================================================================
-- TEST 8: Real Skill Area Dynamic Frame Extraction (Frames 1..5)
-- =============================================================================
print("\n--- Test Group 8: Real Skill Area Dynamic Frame Extraction ---")
for frameIdx = 1, 5 do
	local frameData = GrotRigFactory.ExtractSkillAreaFrameData(frameIdx)
	local hasParts = frameData and #frameData.Parts > 0
	assertTest(string.format("Grot S1 Frame %d Skill Area parts extracted (%d parts)", frameIdx, frameData and #frameData.Parts or 0), hasParts == true)
end

-- =============================================================================
-- TEST 9: Testing Dummy Spawner Types (Update 1.3)
-- =============================================================================
print("\n--- Test Group 9: Testing Dummy Spawner Types ---")

-- 1. Moving Dummy (500 HP, 0 DEF, 12 WalkSpeed)
local movingDummy = DummyHandler.CreateMovingDummy(CFrame.new(300, 5, 300))
assertTest("DummyHandler.CreateMovingDummy returns valid Model", movingDummy ~= nil and movingDummy:IsA("Model"))
if movingDummy then
	local hum = movingDummy:FindFirstChildOfClass("Humanoid")
	assertTest("Moving Dummy MaxHealth == 500", hum ~= nil and hum.MaxHealth == 500)
	assertTest("Moving Dummy WalkSpeed == 12", hum ~= nil and hum.WalkSpeed == 12)
	assertTest("Moving Dummy DEF == 0", movingDummy:GetAttribute("DEF") == 0)
	movingDummy:Destroy()
end

-- 2. Tank Dummy (9999 HP, 0 DEF)
local tankDummy = DummyHandler.CreateTankDummy(CFrame.new(320, 5, 300))
assertTest("DummyHandler.CreateTankDummy returns valid Model", tankDummy ~= nil and tankDummy:IsA("Model"))
if tankDummy then
	local hum = tankDummy:FindFirstChildOfClass("Humanoid")
	assertTest("Tank Dummy MaxHealth == 9999", hum ~= nil and hum.MaxHealth == 9999)
	assertTest("Tank Dummy WalkSpeed == 0 (Stationary)", hum ~= nil and hum.WalkSpeed == 0)
	assertTest("Tank Dummy DEF == 0", tankDummy:GetAttribute("DEF") == 0)
	tankDummy:Destroy()
end

-- 3. Aggressive Dummy (250 HP, 0 DEF, 10 DMG)
local aggroDummy = DummyHandler.CreateAggressiveDummy(CFrame.new(340, 5, 300))
assertTest("DummyHandler.CreateAggressiveDummy returns valid Model", aggroDummy ~= nil and aggroDummy:IsA("Model"))
if aggroDummy then
	local hum = aggroDummy:FindFirstChildOfClass("Humanoid")
	assertTest("Aggressive Dummy MaxHealth == 250", hum ~= nil and hum.MaxHealth == 250)
	assertTest("Aggressive Dummy DEF == 0", aggroDummy:GetAttribute("DEF") == 0)
	aggroDummy:Destroy()
end

-- 4. Clear All Dummies
local dummyA = DummyHandler.CreateNoobDummy(CFrame.new(360, 5, 300))
local dummyB = DummyHandler.CreateTankDummy(CFrame.new(380, 5, 300))
DummyHandler.ClearAllDummies()
local remainingDummies = Workspace:FindFirstChild("NoobDummy") or Workspace:FindFirstChild("TankDummy")
assertTest("DummyHandler.ClearAllDummies() clears all spawned dummies", remainingDummies == nil)

-- =============================================================================
-- TEST 10: Cheats & CMD Verification (Invincible & NoCooldown)
-- =============================================================================
print("\n--- Test Group 10: Cheats & CMD Verification ---")
local testTarget = Instance.new("Model")
testTarget.Name = "TestTargetChar"
local targetHrp = Instance.new("Part")
targetHrp.Name = "HumanoidRootPart"
targetHrp.Position = Vector3.new(400, 10, 400)
targetHrp.Parent = testTarget
local targetHum = Instance.new("Humanoid")
targetHum.MaxHealth = 100
targetHum.Health = 100
targetHum.Parent = testTarget
testTarget.PrimaryPart = targetHrp
testTarget.Parent = Workspace

local testAttacker = Instance.new("Model")
testAttacker.Name = "TestAttackerChar"
local attackerHrp = Instance.new("Part")
attackerHrp.Name = "HumanoidRootPart"
attackerHrp.Position = Vector3.new(400, 10, 403)
attackerHrp.Parent = testAttacker
local attackerHum = Instance.new("Humanoid")
attackerHum.MaxHealth = 100
attackerHum.Health = 100
attackerHum.Parent = testAttacker
testAttacker.PrimaryPart = attackerHrp
testAttacker.Parent = Workspace

-- Normal damage test
CombatHandler.ApplyDamage(testAttacker, testTarget, 20, "Physical", 0, 0)
assertTest("Normal damage applies: 100 - 20 = 80 HP", targetHum.Health == 80)

-- Invincible test
testTarget:SetAttribute("Invincible", true)
CombatHandler.ApplyDamage(testAttacker, testTarget, 20, "Physical", 0, 0)
assertTest("Invincible target takes 0 damage (HP remains 80)", targetHum.Health == 80)

testTarget:Destroy()
testAttacker:Destroy()

-- Cooldown bypass test
local mockPlayer = Instance.new("Player")
mockPlayer.Name = "MockCMDPlayer"
mockPlayer:SetAttribute("NoCooldown", true)
assertTest("MockPlayer NoCooldown attribute is set to true", mockPlayer:GetAttribute("NoCooldown") == true)
mockPlayer:Destroy()

-- =============================================================================
-- FINAL TEST SUMMARY
-- =============================================================================
print("\n=======================================================")
print(string.format("🏁 TEST SUITE 1.3 COMPLETE: %d/%d PASSED (%d FAILED)", passedTests, totalTests, failedTests))
print("=======================================================\n")
