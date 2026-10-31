--[[
    BlockyRigFactory.lua
    Procedural factory for creating the custom "Blocky" character rig,
    and handling player morphing with persistent state across deaths.
--]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared.Configs.CharacterConfig)
local RemoteManager = require(Shared.Modules.RemoteManager)

local BlockyRigFactory = {}

-- Visual styling constants for Blocky
local COLOR_HEAD = Color3.fromRGB(245, 205, 47)       -- Classic golden blocky head
local COLOR_TORSO = Color3.fromRGB(28, 35, 48)        -- Midnight carbon armor torso
local COLOR_ARM = Color3.fromRGB(36, 44, 60)          -- Steel slate arms
local COLOR_LEG = Color3.fromRGB(22, 26, 36)          -- Dark graphite legs
local COLOR_ACCENT = Color3.fromRGB(0, 215, 255)      -- Cyber cyan glowing accents

--[[
    Creates a standard, beautifully stylized R6 Blocky character model.
--]]
function BlockyRigFactory.CreateBlockyModel(): Model
	local config = CharacterConfig.Blocky

	local model = Instance.new("Model")
	model.Name = "Blocky"

	-- 1. HumanoidRootPart (Invisible root collider)
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.RootPriority = 1
	hrp.Parent = model

	-- 2. Torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = COLOR_TORSO
	torso.Material = Enum.Material.SmoothPlastic
	torso.CanCollide = true
	torso.Parent = model

	-- Glowing chest core for Blocky aesthetic
	local chestCore = Instance.new("Part")
	chestCore.Name = "ChestCore"
	chestCore.Size = Vector3.new(0.6, 0.6, 0.1)
	chestCore.Color = COLOR_ACCENT
	chestCore.Material = Enum.Material.Neon
	chestCore.CanCollide = false
	chestCore.Parent = model

	local coreWeld = Instance.new("WeldConstraint")
	coreWeld.Part0 = torso
	coreWeld.Part1 = chestCore
	coreWeld.Parent = chestCore
	chestCore.CFrame = torso.CFrame * CFrame.new(0, 0.2, -0.52)

	-- 3. Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.25, 1.25, 1.25)
	head.Color = COLOR_HEAD
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = true
	head.Parent = model

	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	-- 4. Left Arm
	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.Color = COLOR_ARM
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.CanCollide = false
	leftArm.Parent = model

	local leftAccent = Instance.new("Part")
	leftAccent.Name = "LeftAccent"
	leftAccent.Size = Vector3.new(1.05, 0.2, 1.05)
	leftAccent.Color = COLOR_ACCENT
	leftAccent.Material = Enum.Material.Neon
	leftAccent.CanCollide = false
	leftAccent.Parent = model

	local lWeld = Instance.new("WeldConstraint")
	lWeld.Part0 = leftArm
	lWeld.Part1 = leftAccent
	lWeld.Parent = leftAccent
	leftAccent.CFrame = leftArm.CFrame * CFrame.new(0, -0.6, 0)

	-- 5. Right Arm (Primary M1 Punch arm)
	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.Color = COLOR_ARM
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.CanCollide = false
	rightArm.Parent = model

	local rightAccent = Instance.new("Part")
	rightAccent.Name = "RightAccent"
	rightAccent.Size = Vector3.new(1.05, 0.2, 1.05)
	rightAccent.Color = COLOR_ACCENT
	rightAccent.Material = Enum.Material.Neon
	rightAccent.CanCollide = false
	rightAccent.Parent = model

	local rWeld = Instance.new("WeldConstraint")
	rWeld.Part0 = rightArm
	rWeld.Part1 = rightAccent
	rWeld.Parent = rightAccent
	rightAccent.CFrame = rightArm.CFrame * CFrame.new(0, -0.6, 0)

	-- 6. Left Leg
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.Color = COLOR_LEG
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.CanCollide = false
	leftLeg.Parent = model

	-- 7. Right Leg
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.Color = COLOR_LEG
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.CanCollide = false
	rightLeg.Parent = model

	-- Create standard R6 Motor6D joints
	local function createJoint(name, part0, part1, c0, c1)
		local m6d = Instance.new("Motor6D")
		m6d.Name = name
		m6d.Part0 = part0
		m6d.Part1 = part1
		m6d.C0 = c0
		m6d.C1 = c1
		m6d.Parent = part0
		return m6d
	end

	createJoint("RootJoint", hrp, torso,
		CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	)

	createJoint("Neck", torso, head,
		CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	)

	createJoint("Right Shoulder", torso, rightArm,
		CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	)

	createJoint("Left Shoulder", torso, leftArm,
		CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	)

	createJoint("Right Hip", torso, rightLeg,
		CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	)

	createJoint("Left Hip", torso, leftLeg,
		CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	)

	-- Humanoid configuration (111 MaxHealth / 111 Health / 16 WalkSpeed)
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.MaxHealth = config.HP
	humanoid.Health = config.HP
	humanoid.WalkSpeed = config.Walk
	humanoid.UseJumpPower = true
	humanoid.JumpPower = config.Jump or 111
	humanoid.DisplayName = "Blocky"
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	-- Set PrimaryPart
	model.PrimaryPart = hrp

	-- Mark as Blocky model with all 12 stats
	model:SetAttribute("IsBlockyRig", true)
	model:SetAttribute("CharacterId", "Blocky")
	model:SetAttribute("CharacterName", "Blocky")
	model:SetAttribute("MaxHealth", config.HP)
	model:SetAttribute("Health", config.HP)
	model:SetAttribute("HP", config.HP)
	model:SetAttribute("Regen", config.Regen)
	model:SetAttribute("MaxStamina", config.Stamina)
	model:SetAttribute("Stamina", config.Stamina)
	model:SetAttribute("Recovery", config.Recovery)
	model:SetAttribute("Walk", config.Walk)
	model:SetAttribute("Sprint", config.Sprint)
	model:SetAttribute("Jump", config.Jump or 111)
	model:SetAttribute("Physical", config.Physical)
	model:SetAttribute("Magic", config.Magic)
	model:SetAttribute("DEF", config.DEF)
	model:SetAttribute("Crit", config.Crit)
	model:SetAttribute("CritDMG", config.CritDMG)
	model:SetAttribute("IsSprinting", false)
	model:SetAttribute("IsAttacking", false)

	return model
end

--[[
    Morphs a given player into the Blocky character model.
    Transfers CFrame seamlessly, ensures network ownership, and resets camera.
--]]
function BlockyRigFactory.MorphPlayer(player: Player): Model
	local oldChar = player.Character
	local spawnCFrame = CFrame.new(0, 5, 0)

	if oldChar and oldChar.PrimaryPart then
		spawnCFrame = oldChar.PrimaryPart.CFrame
	elseif oldChar and oldChar:FindFirstChild("HumanoidRootPart") then
		spawnCFrame = oldChar.HumanoidRootPart.CFrame
	end

	-- Create new blocky model
	local blockyModel = BlockyRigFactory.CreateBlockyModel()
	blockyModel.Name = player.Name
	blockyModel:PivotTo(spawnCFrame)

	-- Parent to workspace BEFORE assigning to player.Character
	blockyModel.Parent = Workspace

	local hrp = blockyModel:FindFirstChild("HumanoidRootPart") :: BasePart
	if hrp then
		pcall(function()
			hrp:SetNetworkOwner(player)
		end)
	end

	local humanoid = blockyModel:FindFirstChild("Humanoid") :: Humanoid
	if humanoid then
		humanoid.HealthChanged:Connect(function(newHealth)
			blockyModel:SetAttribute("Health", math.clamp(newHealth, 0, 111))
		end)

		-- Connect Humanoid.Died to respawn the player after 3s (prevents softlock)
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

	-- Set persistent attribute on the Player object
	player:SetAttribute("SelectedCharacterId", "Blocky")

	-- Assign character
	player.Character = blockyModel

	-- Fire Camera reset remote to immediately fix client camera
	local cameraResetRemote = RemoteManager.GetRemoteEvent("ResetCameraSubject")
	cameraResetRemote:FireClient(player, blockyModel)

	-- Destroy old character safely
	if oldChar and oldChar ~= blockyModel then
		task.delay(0.1, function()
			pcall(function()
				oldChar:Destroy()
			end)
		end)
	end

	return blockyModel
end

return BlockyRigFactory
