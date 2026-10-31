--[[
    MorphStandHandler.lua
    Spawns and manages both the Blocky Morph Stand and the Grot Morph Stand.
    Players stepping on a morph stand are transformed into that character,
    updating health, stamina, speeds, DEF, and unlocking their respective M1 ability.
--]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockyRigFactory = require(Shared.Modules.BlockyRigFactory)
local GrotRigFactory = require(Shared.Modules.GrotRigFactory)

local MorphStandHandler = {}

local BLOCKY_STAND_POS = Vector3.new(16, 0.4, 0)
local GROT_STAND_POS = Vector3.new(30, 0.4, 0)

local touchDebounces = {}

function MorphStandHandler.Init()
	MorphStandHandler.BuildBlockyStand()
	MorphStandHandler.BuildGrotStand()
end

--[[
    Builds the Blocky Morph Stand.
--]]
function MorphStandHandler.BuildBlockyStand(): Model
	local existing = Workspace:FindFirstChild("BlockyMorphStand")
	if existing then existing:Destroy() end

	local standModel = Instance.new("Model")
	standModel.Name = "BlockyMorphStand"

	-- Outer Base
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(9, 0.8, 9)
	base.Position = BLOCKY_STAND_POS
	base.Anchored = true
	base.CanCollide = true
	base.Material = Enum.Material.SmoothPlastic
	base.Color = Color3.fromRGB(25, 30, 42)
	base.Parent = standModel

	local baseCylinder = Instance.new("CylinderMesh")
	baseCylinder.Scale = Vector3.new(1, 1, 1)
	baseCylinder.Parent = base

	-- Glowing Touch Pad
	local pad = Instance.new("Part")
	pad.Name = "MorphPad"
	pad.Size = Vector3.new(7.2, 0.9, 7.2)
	pad.Position = BLOCKY_STAND_POS + Vector3.new(0, 0.05, 0)
	pad.Anchored = true
	pad.CanCollide = true
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromRGB(0, 215, 255)
	pad.Parent = standModel

	local padCylinder = Instance.new("CylinderMesh")
	padCylinder.Scale = Vector3.new(1, 1, 1)
	padCylinder.Parent = pad

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(0, 220, 255), Color3.fromRGB(150, 240, 255))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Rate = 12
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = pad

	-- Billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StandBillboard"
	billboard.Size = UDim2.new(0, 240, 0, 75)
	billboard.StudsOffset = Vector3.new(0, 4.8, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 50
	billboard.Adornee = pad
	billboard.Parent = pad

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = "⚡ BLOCKY MORPH STAND ⚡"
	title.TextColor3 = Color3.fromRGB(0, 225, 255)
	title.TextSize = 14
	title.Parent = billboard

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Thickness = 1.5
	titleStroke.Parent = title

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, 0, 0, 18)
	subtitle.Position = UDim2.new(0, 0, 0, 24)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = "Step here to morph into Blocky"
	subtitle.TextColor3 = Color3.fromRGB(240, 245, 255)
	subtitle.TextSize = 12
	subtitle.Parent = billboard

	local subStroke = Instance.new("UIStroke")
	subStroke.Color = Color3.fromRGB(0, 0, 0)
	subStroke.Thickness = 1.2
	subStroke.Parent = subtitle

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Size = UDim2.new(1, 0, 0, 16)
	statsLabel.Position = UDim2.new(0, 0, 0, 44)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.Text = "111 HP • 111 Stamina • 1.5s M1 (25 DMG)"
	statsLabel.TextColor3 = Color3.fromRGB(180, 230, 255)
	statsLabel.TextSize = 10
	statsLabel.Parent = billboard

	-- Preview Model
	local previewModel = BlockyRigFactory.CreateBlockyModel()
	previewModel.Name = "BlockyPreview"
	for _, part in ipairs(previewModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	local previewCFrame = CFrame.new(BLOCKY_STAND_POS + Vector3.new(0, 2.8, 0))
	previewModel:PivotTo(previewCFrame)
	previewModel.Parent = standModel

	local rotationAngle = 0
	RunService.Heartbeat:Connect(function(dt)
		if previewModel and previewModel.PrimaryPart then
			rotationAngle = (rotationAngle + dt * 45) % 360
			previewModel:PivotTo(previewCFrame * CFrame.Angles(0, math.rad(rotationAngle), 0))
		end
	end)

	-- Touch Morph Detection
	pad.Touched:Connect(function(hitPart)
		local char = hitPart.Parent
		if not char then return end

		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end

		local now = os.clock()
		if touchDebounces[player] and (now - touchDebounces[player]) < 1.2 then return end
		touchDebounces[player] = now

		BlockyRigFactory.MorphPlayer(player)
	end)

	standModel.Parent = Workspace
	return standModel
end

--[[
    Builds the Grot Morph Stand next to Blocky Morph Stand.
--]]
function MorphStandHandler.BuildGrotStand(): Model
	local existing = Workspace:FindFirstChild("GrotMorphStand")
	if existing then existing:Destroy() end

	local standModel = Instance.new("Model")
	standModel.Name = "GrotMorphStand"

	-- Outer Base
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(9, 0.8, 9)
	base.Position = GROT_STAND_POS
	base.Anchored = true
	base.CanCollide = true
	base.Material = Enum.Material.SmoothPlastic
	base.Color = Color3.fromRGB(20, 32, 24)
	base.Parent = standModel

	local baseCylinder = Instance.new("CylinderMesh")
	baseCylinder.Scale = Vector3.new(1, 1, 1)
	baseCylinder.Parent = base

	-- Glowing Emerald Touch Pad
	local pad = Instance.new("Part")
	pad.Name = "MorphPad"
	pad.Size = Vector3.new(7.2, 0.9, 7.2)
	pad.Position = GROT_STAND_POS + Vector3.new(0, 0.05, 0)
	pad.Anchored = true
	pad.CanCollide = true
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromRGB(46, 204, 113)
	pad.Parent = standModel

	local padCylinder = Instance.new("CylinderMesh")
	padCylinder.Scale = Vector3.new(1, 1, 1)
	padCylinder.Parent = pad

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(46, 204, 113), Color3.fromRGB(180, 255, 180))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Rate = 12
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = pad

	-- Billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StandBillboard"
	billboard.Size = UDim2.new(0, 240, 0, 75)
	billboard.StudsOffset = Vector3.new(0, 4.8, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 50
	billboard.Adornee = pad
	billboard.Parent = pad

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = "🌿 GROT MORPH STAND 🌿"
	title.TextColor3 = Color3.fromRGB(46, 204, 113)
	title.TextSize = 14
	title.Parent = billboard

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Thickness = 1.5
	titleStroke.Parent = title

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, 0, 0, 18)
	subtitle.Position = UDim2.new(0, 0, 0, 24)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = "Step here to morph into Grot"
	subtitle.TextColor3 = Color3.fromRGB(240, 255, 240)
	subtitle.TextSize = 12
	subtitle.Parent = billboard

	local subStroke = Instance.new("UIStroke")
	subStroke.Color = Color3.fromRGB(0, 0, 0)
	subStroke.Thickness = 1.2
	subStroke.Parent = subtitle

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Size = UDim2.new(1, 0, 0, 16)
	statsLabel.Position = UDim2.new(0, 0, 0, 44)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.Text = "250 HP • 75 Stamina • 15 DEF • Sprout Grows"
	statsLabel.TextColor3 = Color3.fromRGB(180, 255, 200)
	statsLabel.TextSize = 10
	statsLabel.Parent = billboard

	-- Preview Model
	local previewModel = GrotRigFactory.CreatePreviewModel()
	local previewCFrame = CFrame.new(GROT_STAND_POS + Vector3.new(0, 2.8, 0))
	previewModel:PivotTo(previewCFrame)
	previewModel.Parent = standModel

	local rotationAngle = 0
	RunService.Heartbeat:Connect(function(dt)
		if previewModel and previewModel.PrimaryPart then
			rotationAngle = (rotationAngle + dt * 45) % 360
			previewModel:PivotTo(previewCFrame * CFrame.Angles(0, math.rad(rotationAngle), 0))
		end
	end)

	-- Touch Morph Detection
	pad.Touched:Connect(function(hitPart)
		local char = hitPart.Parent
		if not char then return end

		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end

		local now = os.clock()
		if touchDebounces[player] and (now - touchDebounces[player]) < 1.2 then return end
		touchDebounces[player] = now

		GrotRigFactory.MorphPlayer(player)
	end)

	standModel.Parent = Workspace
	return standModel
end

return MorphStandHandler
