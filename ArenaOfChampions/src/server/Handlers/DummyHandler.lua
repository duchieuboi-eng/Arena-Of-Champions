--[[
    DummyHandler.lua
    Spawns and manages the 100 HP Noob Test Dummy (DEF = 0).
    Handles client 'B' key request to spawn a Noob dummy 6 studs in front of the player,
    displays overhead health bar and floating damage numbers, and auto-refreshes HP upon death.
--]]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteManager = require(Shared.Modules.RemoteManager)

local DummyHandler = {}

local spawnDummyRemote = RemoteManager.GetRemoteEvent("SpawnTestingDummy")

-- Classic Roblox Noob Color Palette
local COLOR_YELLOW = Color3.fromRGB(245, 205, 47)      -- Head and Arms
local COLOR_BLUE = Color3.fromRGB(13, 105, 172)        -- Torso
local COLOR_GREEN = Color3.fromRGB(164, 189, 71)       -- Legs

local spawnDebounces = {}

function DummyHandler.Init()
	spawnDummyRemote.OnServerEvent:Connect(function(player)
		DummyHandler.SpawnNoobDummyForPlayer(player)
	end)

	-- Spawn an initial arena dummy if none exists
	if not Workspace:FindFirstChild("NoobDummy") and not Workspace:FindFirstChild("TestDummy") then
		DummyHandler.CreateNoobDummy(CFrame.new(0, 3.2, 22))
	end
end

function DummyHandler.SpawnNoobDummyForPlayer(player: Player)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Grot_hitbox") :: BasePart
	if not rootPart then return end

	-- Debounce per player (0.5s)
	local now = os.clock()
	if spawnDebounces[player] and (now - spawnDebounces[player]) < 0.5 then
		return
	end
	spawnDebounces[player] = now

	-- Calculate CFrame 6 studs in front facing the player
	local rootCFrame = rootPart.CFrame
	local spawnPos = rootCFrame.Position + (rootCFrame.LookVector * 6)
	local lookTarget = Vector3.new(rootCFrame.Position.X, spawnPos.Y, rootCFrame.Position.Z)
	local dummyCFrame = CFrame.lookAt(spawnPos, lookTarget)

	DummyHandler.CreateNoobDummy(dummyCFrame)
end

function DummyHandler.CreateNoobDummy(spawnCFrame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "NoobDummy"

	-- 1. HumanoidRootPart
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.RootPriority = 1
	hrp.CFrame = spawnCFrame
	hrp.Parent = model

	-- 2. Torso (Blue)
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = COLOR_BLUE
	torso.Material = Enum.Material.SmoothPlastic
	torso.CanCollide = true
	torso.Parent = model

	-- 3. Head (Yellow)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.25, 1.25, 1.25)
	head.Color = COLOR_YELLOW
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

	-- 4. Limbs
	local function createLimb(name: string, size: Vector3, color: Color3)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.Parent = model
		return part
	end

	local leftArm = createLimb("Left Arm", Vector3.new(1, 2, 1), COLOR_YELLOW)
	local rightArm = createLimb("Right Arm", Vector3.new(1, 2, 1), COLOR_YELLOW)
	local leftLeg = createLimb("Left Leg", Vector3.new(1, 2, 1), COLOR_GREEN)
	local rightLeg = createLimb("Right Leg", Vector3.new(1, 2, 1), COLOR_GREEN)

	-- 5. Standard R6 Joints
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

	-- 6. Humanoid (MaxHealth = 100, Health = 100, DEF = 0)
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayName = "Noob Dummy"
	humanoid.Parent = model

	model.PrimaryPart = hrp
	model:PivotTo(spawnCFrame)

	-- 7. Attributes: MaxHealth = 100, DEF = 0 for easy damage/healing testing
	model:SetAttribute("CharacterName", "Noob Dummy")
	model:SetAttribute("MaxHealth", 100)
	model:SetAttribute("Health", 100)
	model:SetAttribute("HP", 100)
	model:SetAttribute("DEF", 0)
	model:SetAttribute("Regen", 0)

	-- 8. Overhead Health BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DummyOverheadGui"
	billboard.Size = UDim2.new(0, 160, 0, 48)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.Adornee = head
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 18)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.Text = "NOOB DUMMY (DEF: 0)"
	nameLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	nameLabel.TextSize = 12
	nameLabel.Parent = billboard

	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = Color3.fromRGB(0, 0, 0)
	nameStroke.Thickness = 1.2
	nameStroke.Parent = nameLabel

	local healthBg = Instance.new("Frame")
	healthBg.Name = "HealthBackground"
	healthBg.Size = UDim2.new(1, 0, 0, 16)
	healthBg.Position = UDim2.new(0, 0, 0, 22)
	healthBg.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
	healthBg.BorderSizePixel = 0
	healthBg.ClipsDescendants = true
	healthBg.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = healthBg

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = Color3.fromRGB(50, 55, 70)
	bgStroke.Thickness = 1
	bgStroke.Parent = healthBg

	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = healthFill

	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Font = Enum.Font.GothamBold
	healthText.Text = "100 / 100"
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.TextSize = 10
	healthText.ZIndex = 3
	healthText.Parent = healthBg

	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(0, 0, 0)
	textStroke.Thickness = 1
	textStroke.Parent = healthText

	-- Floating numbers and Refresh Logic
	local lastHealth = 100
	local isRefreshing = false

	local function showFloatingNumber(text: string, color: Color3)
		local dmgBillboard = Instance.new("BillboardGui")
		dmgBillboard.Size = UDim2.new(0, 120, 0, 30)
		dmgBillboard.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 2 + math.random(0, 5) / 10, 0)
		dmgBillboard.AlwaysOnTop = true
		dmgBillboard.Adornee = torso
		dmgBillboard.Parent = torso

		local dmgLabel = Instance.new("TextLabel")
		dmgLabel.Size = UDim2.new(1, 0, 1, 0)
		dmgLabel.BackgroundTransparency = 1
		dmgLabel.Font = Enum.Font.GothamBlack
		dmgLabel.Text = text
		dmgLabel.TextColor3 = color
		dmgLabel.TextSize = 18
		dmgLabel.Parent = dmgBillboard

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 1.5
		stroke.Parent = dmgLabel

		local tweenInfo = TweenInfo.new(0.75, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		TweenService:Create(dmgBillboard, tweenInfo, {
			StudsOffset = dmgBillboard.StudsOffset + Vector3.new(0, 2, 0)
		}):Play()
		TweenService:Create(dmgLabel, tweenInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, tweenInfo, { Transparency = 1 }):Play()

		Debris:AddItem(dmgBillboard, 0.8)
	end

	local function refreshDummy()
		if isRefreshing then return end
		isRefreshing = true

		task.delay(0.35, function()
			if not model or not model.Parent then return end

			humanoid.MaxHealth = 100
			humanoid.Health = 100
			model:SetAttribute("Health", 100)
			lastHealth = 100

			humanoid:ChangeState(Enum.HumanoidStateType.Running)

			TweenService:Create(healthFill, TweenInfo.new(0.3, Enum.EasingStyle.Cubic), {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = Color3.fromRGB(46, 204, 113)
			}):Play()
			healthText.Text = "100 / 100"

			showFloatingNumber("+100 (REFRESHED)", Color3.fromRGB(46, 204, 113))

			task.delay(0.2, function()
				isRefreshing = false
			end)
		end)
	end

	humanoid.HealthChanged:Connect(function(newHealth)
		if isRefreshing then return end

		local currentHp = math.clamp(newHealth, 0, 100)
		local diff = lastHealth - currentHp
		lastHealth = currentHp

		model:SetAttribute("Health", currentHp)

		if diff > 0 then
			showFloatingNumber("-" .. tostring(math.round(diff)), Color3.fromRGB(255, 75, 75))
		end

		local ratio = currentHp / 100
		TweenService:Create(healthFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.new(ratio, 0, 1, 0)
		}):Play()

		if ratio > 0.5 then
			healthFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
		elseif ratio > 0.25 then
			healthFill.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
		else
			healthFill.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
		end

		healthText.Text = string.format("%d / 100", math.ceil(currentHp))

		if currentHp <= 0 then
			refreshDummy()
		end
	end)

	humanoid.Died:Connect(function()
		refreshDummy()
	end)

	model.Parent = Workspace
	return model
end

return DummyHandler
