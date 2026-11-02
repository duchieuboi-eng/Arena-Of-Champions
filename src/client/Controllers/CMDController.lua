--[[
    CMDController.lua
    Client controller for the Forsaken / Item Asylum style Testing CMD Panel:
    - Screen toggle button "[ CMD ]" in top-right + '~' key toggle
    - Cheats / Toggles: No Cooldown and Invincible
    - Live Stat Editor: Target player selector, 12-stat input grid, [ Apply ] button
    - Dummy Spawner: Moving Dummy (500 HP), Tank Dummy (9999 HP), Aggressive Dummy (250 HP), and [ Clear All Dummies ]
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteManager = require(Shared.Modules.RemoteManager)

local CMDController = {}

local toggleCheatRemote = RemoteManager.GetRemoteEvent("CMD_ToggleCheat")
local applyStatsRemote = RemoteManager.GetRemoteEvent("CMD_ApplyStats")
local spawnDummyRemote = RemoteManager.GetRemoteEvent("CMD_SpawnDummy")
local clearDummiesRemote = RemoteManager.GetRemoteEvent("CMD_ClearDummies")

local LocalPlayer = Players.LocalPlayer

local screenGui: ScreenGui
local mainFrame: Frame
local toggleButton: TextButton
local isOpen = false

-- Cheats State
local cheatStates = {
	NoCooldown = false,
	Invincible = false,
}
local cheatButtons = {}

-- Stat Inputs Dictionary
local statInputs = {}
local targetPlayerBox: TextBox
local feedbackLabel: TextLabel

local STAT_FIELDS = {
	{ key = "HP", label = "HP", default = 250 },
	{ key = "Regen", label = "Regen", default = 2.5 },
	{ key = "Stamina", label = "Stamina", default = 75 },
	{ key = "Recovery", label = "Recovery", default = 10 },
	{ key = "Walk", label = "Walk", default = 14 },
	{ key = "Sprint", label = "Sprint", default = 18 },
	{ key = "Jump", label = "Jump", default = 50 },
	{ key = "Physical", label = "Physical", default = 25 },
	{ key = "Magic", label = "Magic", default = 10 },
	{ key = "DEF", label = "DEF", default = 15 },
	{ key = "Crit", label = "Crit (%)", default = 0 },
	{ key = "CritDMG", label = "Crit DMG (%)", default = 100 },
}

local function showFeedback(msg: string, isError: boolean?)
	if not feedbackLabel then return end
	feedbackLabel.Text = msg
	feedbackLabel.TextColor3 = isError and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(46, 204, 113)
	feedbackLabel.Visible = true

	task.delay(2.5, function()
		if feedbackLabel and feedbackLabel.Text == msg then
			feedbackLabel.Visible = false
		end
	end)
end

function CMDController.Init()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	-- 1. ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TestingCMDScreenGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	screenGui.Parent = playerGui

	-- 2. Top-Right Screen Toggle Button "[ CMD ]"
	toggleButton = Instance.new("TextButton")
	toggleButton.Name = "CMDToggleButton"
	toggleButton.Size = UDim2.new(0, 85, 0, 32)
	toggleButton.Position = UDim2.new(1, -100, 0, 16)
	toggleButton.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
	toggleButton.BackgroundTransparency = 0.2
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.Text = "🛠️ [ CMD ]"
	toggleButton.TextColor3 = Color3.fromRGB(0, 220, 255)
	toggleButton.TextSize = 12
	toggleButton.BorderSizePixel = 0
	toggleButton.Parent = screenGui

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = toggleButton

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(0, 180, 220)
	btnStroke.Thickness = 1.2
	btnStroke.Parent = toggleButton

	toggleButton.MouseButton1Click:Connect(function()
		CMDController.Toggle()
	end)

	-- 3. Main CMD Window (Dark Glassmorphic Panel)
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "CMDMainPanel"
	mainFrame.Size = UDim2.new(0, 520, 0, 560)
	mainFrame.Position = UDim2.new(0.5, -260, 0.5, -280)
	mainFrame.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
	mainFrame.BackgroundTransparency = 0.1
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 12)
	mainCorner.Parent = mainFrame

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = Color3.fromRGB(60, 90, 150)
	mainStroke.Thickness = 1.5
	mainStroke.Parent = mainFrame

	-- Header Bar
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(1, 0, 0, 42)
	headerFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	headerFrame.BorderSizePixel = 0
	headerFrame.Parent = mainFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = headerFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -50, 1, 0)
	titleLabel.Position = UDim2.new(0, 14, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "⚔️ ARENA TESTING CMD PANEL"
	titleLabel.TextColor3 = Color3.fromRGB(0, 225, 255)
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = headerFrame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 28, 0, 28)
	closeBtn.Position = UDim2.new(1, -36, 0, 7)
	closeBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
	closeBtn.TextSize = 13
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = headerFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		CMDController.Close()
	end)

	-- Subtitle Info
	local subInfo = Instance.new("TextLabel")
	subInfo.Name = "SubInfo"
	subInfo.Size = UDim2.new(1, -28, 0, 16)
	subInfo.Position = UDim2.new(0, 14, 0, 48)
	subInfo.BackgroundTransparency = 1
	subInfo.Font = Enum.Font.Gotham
	subInfo.Text = "Forsaken / Item Asylum Style Debug Controls • Press [~] or click [CMD] to toggle"
	subInfo.TextColor3 = Color3.fromRGB(140, 155, 180)
	subInfo.TextSize = 10
	subInfo.TextXAlignment = Enum.TextXAlignment.Left
	subInfo.Parent = mainFrame

	-- Scroll Container
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ContentScroll"
	scrollFrame.Size = UDim2.new(1, -20, 1, -85)
	scrollFrame.Position = UDim2.new(0, 10, 0, 70)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 570)
	scrollFrame.ScrollBarThickness = 5
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 90, 150)
	scrollFrame.Parent = mainFrame

	-- =========================================================================
	-- SECTION 1: CHEATS / TOGGLES
	-- =========================================================================
	local cheatSectionTitle = Instance.new("TextLabel")
	cheatSectionTitle.Size = UDim2.new(1, 0, 0, 20)
	cheatSectionTitle.Position = UDim2.new(0, 4, 0, 0)
	cheatSectionTitle.BackgroundTransparency = 1
	cheatSectionTitle.Font = Enum.Font.GothamBold
	cheatSectionTitle.Text = "⚡ CHEATS / TOGGLES"
	cheatSectionTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
	cheatSectionTitle.TextSize = 12
	cheatSectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	cheatSectionTitle.Parent = scrollFrame

	local cheatContainer = Instance.new("Frame")
	cheatContainer.Size = UDim2.new(1, -8, 0, 44)
	cheatContainer.Position = UDim2.new(0, 4, 0, 24)
	cheatContainer.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	cheatContainer.BorderSizePixel = 0
	cheatContainer.Parent = scrollFrame

	local cheatCorner = Instance.new("UICorner")
	cheatCorner.CornerRadius = UDim.new(0, 8)
	cheatCorner.Parent = cheatContainer

	local function createCheatToggle(name: string, cheatKey: string, xPos: number, width: number)
		local btn = Instance.new("TextButton")
		btn.Name = cheatKey .. "Btn"
		btn.Size = UDim2.new(0, width, 0, 32)
		btn.Position = UDim2.new(0, xPos, 0, 6)
		btn.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
		btn.Font = Enum.Font.GothamBold
		btn.Text = name .. ": OFF"
		btn.TextColor3 = Color3.fromRGB(200, 200, 200)
		btn.TextSize = 11
		btn.BorderSizePixel = 0
		btn.Parent = cheatContainer

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(70, 80, 105)
		stroke.Thickness = 1
		stroke.Parent = btn

		cheatButtons[cheatKey] = btn

		btn.MouseButton1Click:Connect(function()
			cheatStates[cheatKey] = not cheatStates[cheatKey]
			local active = cheatStates[cheatKey]

			toggleCheatRemote:FireServer(cheatKey, active)

			if active then
				btn.BackgroundColor3 = Color3.fromRGB(30, 75, 45)
				btn.TextColor3 = Color3.fromRGB(46, 204, 113)
				btn.Text = name .. ": ON"
				stroke.Color = Color3.fromRGB(46, 204, 113)
				showFeedback(name .. " enabled!")
			else
				btn.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
				btn.TextColor3 = Color3.fromRGB(200, 200, 200)
				btn.Text = name .. ": OFF"
				stroke.Color = Color3.fromRGB(70, 80, 105)
				showFeedback(name .. " disabled.")
			end
		end)
	end

	createCheatToggle("NO COOLDOWN", "NoCooldown", 10, 220)
	createCheatToggle("INVINCIBLE", "Invincible", 242, 220)

	-- =========================================================================
	-- SECTION 2: LIVE STAT EDITOR
	-- =========================================================================
	local statSectionTitle = Instance.new("TextLabel")
	statSectionTitle.Size = UDim2.new(1, 0, 0, 20)
	statSectionTitle.Position = UDim2.new(0, 4, 0, 80)
	statSectionTitle.BackgroundTransparency = 1
	statSectionTitle.Font = Enum.Font.GothamBold
	statSectionTitle.Text = "📊 LIVE STAT EDITOR"
	statSectionTitle.TextColor3 = Color3.fromRGB(0, 220, 255)
	statSectionTitle.TextSize = 12
	statSectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	statSectionTitle.Parent = scrollFrame

	local statCard = Instance.new("Frame")
	statCard.Size = UDim2.new(1, -8, 0, 260)
	statCard.Position = UDim2.new(0, 4, 0, 104)
	statCard.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	statCard.BorderSizePixel = 0
	statCard.Parent = scrollFrame

	local statCorner = Instance.new("UICorner")
	statCorner.CornerRadius = UDim.new(0, 8)
	statCorner.Parent = statCard

	-- Target Player Selection
	local targetLabel = Instance.new("TextLabel")
	targetLabel.Size = UDim2.new(0, 90, 0, 24)
	targetLabel.Position = UDim2.new(0, 10, 0, 8)
	targetLabel.BackgroundTransparency = 1
	targetLabel.Font = Enum.Font.GothamBold
	targetLabel.Text = "Target Player:"
	targetLabel.TextColor3 = Color3.fromRGB(180, 195, 220)
	targetLabel.TextSize = 11
	targetLabel.TextXAlignment = Enum.TextXAlignment.Left
	targetLabel.Parent = statCard

	targetPlayerBox = Instance.new("TextBox")
	targetPlayerBox.Name = "TargetPlayerBox"
	targetPlayerBox.Size = UDim2.new(0, 180, 0, 24)
	targetPlayerBox.Position = UDim2.new(0, 105, 0, 8)
	targetPlayerBox.BackgroundColor3 = Color3.fromRGB(26, 32, 45)
	targetPlayerBox.Font = Enum.Font.GothamMedium
	targetPlayerBox.Text = LocalPlayer.Name
	targetPlayerBox.TextColor3 = Color3.fromRGB(240, 245, 255)
	targetPlayerBox.TextSize = 11
	targetPlayerBox.BorderSizePixel = 0
	targetPlayerBox.ClearTextOnFocus = false
	targetPlayerBox.Parent = statCard

	local tpCorner = Instance.new("UICorner")
	tpCorner.CornerRadius = UDim.new(0, 4)
	tpCorner.Parent = targetPlayerBox

	local loadCurrentBtn = Instance.new("TextButton")
	loadCurrentBtn.Name = "LoadCurrentBtn"
	loadCurrentBtn.Size = UDim2.new(0, 170, 0, 24)
	loadCurrentBtn.Position = UDim2.new(0, 295, 0, 8)
	loadCurrentBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 65)
	loadCurrentBtn.Font = Enum.Font.GothamBold
	loadCurrentBtn.Text = "🔄 Load Current Stats"
	loadCurrentBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
	loadCurrentBtn.TextSize = 10
	loadCurrentBtn.BorderSizePixel = 0
	loadCurrentBtn.Parent = statCard

	local loadCorner = Instance.new("UICorner")
	loadCorner.CornerRadius = UDim.new(0, 4)
	loadCorner.Parent = loadCurrentBtn

	-- 12-Stat Grid: 4 columns x 3 rows
	local colWidth = 110
	local colSpacing = 8
	local rowHeight = 44
	local startY = 40

	for i, field in ipairs(STAT_FIELDS) do
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)

		local x = 10 + col * (colWidth + colSpacing)
		local y = startY + row * (rowHeight + 4)

		local boxContainer = Instance.new("Frame")
		boxContainer.Size = UDim2.new(0, colWidth, 0, rowHeight)
		boxContainer.Position = UDim2.new(0, x, 0, y)
		boxContainer.BackgroundColor3 = Color3.fromRGB(23, 28, 40)
		boxContainer.BorderSizePixel = 0
		boxContainer.Parent = statCard

		local bcCorner = Instance.new("UICorner")
		bcCorner.CornerRadius = UDim.new(0, 4)
		bcCorner.Parent = boxContainer

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -6, 0, 16)
		lbl.Position = UDim2.new(0, 4, 0, 2)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamMedium
		lbl.Text = field.label
		lbl.TextColor3 = Color3.fromRGB(160, 175, 200)
		lbl.TextSize = 9
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = boxContainer

		local valBox = Instance.new("TextBox")
		valBox.Name = field.key .. "Box"
		valBox.Size = UDim2.new(1, -8, 0, 20)
		valBox.Position = UDim2.new(0, 4, 0, 19)
		valBox.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
		valBox.Font = Enum.Font.GothamBold
		valBox.Text = tostring(field.default)
		valBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		valBox.TextSize = 11
		valBox.BorderSizePixel = 0
		valBox.ClearTextOnFocus = false
		valBox.Parent = boxContainer

		local vbCorner = Instance.new("UICorner")
		vbCorner.CornerRadius = UDim.new(0, 3)
		vbCorner.Parent = valBox

		statInputs[field.key] = valBox
	end

	-- Function to populate inputs from character attributes
	local function populateFromTargetCharacter()
		local tPlayer = Players:FindFirstChild(targetPlayerBox.Text) or LocalPlayer
		local char = tPlayer and tPlayer.Character
		if not char then
			showFeedback("Target character not found!", true)
			return
		end

		for _, field in ipairs(STAT_FIELDS) do
			local attrVal = char:GetAttribute(field.key)
			if attrVal ~= nil then
				statInputs[field.key].Text = tostring(attrVal)
			end
		end
		showFeedback("Loaded stats for " .. tPlayer.Name)
	end

	loadCurrentBtn.MouseButton1Click:Connect(populateFromTargetCharacter)

	-- Apply Button
	local applyBtn = Instance.new("TextButton")
	applyBtn.Name = "ApplyStatsButton"
	applyBtn.Size = UDim2.new(1, -20, 0, 32)
	applyBtn.Position = UDim2.new(0, 10, 1, -40)
	applyBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
	applyBtn.Font = Enum.Font.GothamBold
	applyBtn.Text = "⚡ APPLY STATS TO TARGET"
	applyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	applyBtn.TextSize = 12
	applyBtn.BorderSizePixel = 0
	applyBtn.Parent = statCard

	local applyCorner = Instance.new("UICorner")
	applyCorner.CornerRadius = UDim.new(0, 6)
	applyCorner.Parent = applyBtn

	applyBtn.MouseButton1Click:Connect(function()
		local payload = {}
		for _, field in ipairs(STAT_FIELDS) do
			local num = tonumber(statInputs[field.key].Text)
			if num ~= nil then
				payload[field.key] = num
			end
		end

		applyStatsRemote:FireServer(targetPlayerBox.Text, payload)
		showFeedback("Applied stats successfully!")
	end)

	-- =========================================================================
	-- SECTION 3: DUMMY SPAWNER
	-- =========================================================================
	local dummySectionTitle = Instance.new("TextLabel")
	dummySectionTitle.Size = UDim2.new(1, 0, 0, 20)
	dummySectionTitle.Position = UDim2.new(0, 4, 0, 375)
	dummySectionTitle.BackgroundTransparency = 1
	dummySectionTitle.Font = Enum.Font.GothamBold
	dummySectionTitle.Text = "🤖 DUMMY SPAWNER"
	dummySectionTitle.TextColor3 = Color3.fromRGB(46, 204, 113)
	dummySectionTitle.TextSize = 12
	dummySectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	dummySectionTitle.Parent = scrollFrame

	local dummyCard = Instance.new("Frame")
	dummyCard.Size = UDim2.new(1, -8, 0, 155)
	dummyCard.Position = UDim2.new(0, 4, 0, 400)
	dummyCard.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	dummyCard.BorderSizePixel = 0
	dummyCard.Parent = scrollFrame

	local dummyCorner = Instance.new("UICorner")
	dummyCorner.CornerRadius = UDim.new(0, 8)
	dummyCorner.Parent = dummyCard

	local function createDummyBtn(title: string, sub: string, dummyType: string, xPos: number, yPos: number, color: Color3)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 225, 0, 44)
		btn.Position = UDim2.new(0, xPos, 0, yPos)
		btn.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.Parent = dummyCard

		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 6)
		bc.Parent = btn

		local bStroke = Instance.new("UIStroke")
		bStroke.Color = color
		bStroke.Thickness = 1
		bStroke.Parent = btn

		local tLabel = Instance.new("TextLabel")
		tLabel.Size = UDim2.new(1, -8, 0, 20)
		tLabel.Position = UDim2.new(0, 6, 0, 3)
		tLabel.BackgroundTransparency = 1
		tLabel.Font = Enum.Font.GothamBold
		tLabel.Text = title
		tLabel.TextColor3 = color
		tLabel.TextSize = 11
		tLabel.TextXAlignment = Enum.TextXAlignment.Left
		tLabel.Parent = btn

		local sLabel = Instance.new("TextLabel")
		sLabel.Size = UDim2.new(1, -8, 0, 16)
		sLabel.Position = UDim2.new(0, 6, 0, 22)
		sLabel.BackgroundTransparency = 1
		sLabel.Font = Enum.Font.Gotham
		sLabel.Text = sub
		sLabel.TextColor3 = Color3.fromRGB(150, 165, 190)
		sLabel.TextSize = 9
		sLabel.TextXAlignment = Enum.TextXAlignment.Left
		sLabel.Parent = btn

		btn.MouseButton1Click:Connect(function()
			spawnDummyRemote:FireServer(dummyType)
			showFeedback("Spawned " .. title)
		end)
	end

	-- 1. Moving Dummy (500 HP, runs 25 studs then circles R=25 studs at 12 WalkSpeed)
	createDummyBtn(
		"🏃 Moving Dummy",
		"500 HP • Circles R=25 @ 12 Spd",
		"Moving",
		10, 10,
		Color3.fromRGB(52, 152, 219)
	)

	-- 2. Tank Dummy (9999 HP, stationary avatar statue)
	createDummyBtn(
		"🛡️ Tank Dummy",
		"9999 HP • Stationary Statue",
		"Tank",
		245, 10,
		Color3.fromRGB(241, 196, 15)
	)

	-- 3. Aggressive Dummy (250 HP, 10 DMG every 1.0s)
	createDummyBtn(
		"⚔️ Aggressive Dummy",
		"250 HP • Attacks 1.0s (10 DMG)",
		"Aggressive",
		10, 62,
		Color3.fromRGB(231, 76, 60)
	)

	-- 4. Clear All Dummies
	local clearBtn = Instance.new("TextButton")
	clearBtn.Name = "ClearDummiesBtn"
	clearBtn.Size = UDim2.new(0, 225, 0, 44)
	clearBtn.Position = UDim2.new(0, 245, 0, 62)
	clearBtn.BackgroundColor3 = Color3.fromRGB(45, 25, 30)
	clearBtn.BorderSizePixel = 0
	clearBtn.Font = Enum.Font.GothamBold
	clearBtn.Text = "🗑️ CLEAR ALL DUMMIES"
	clearBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	clearBtn.TextSize = 11
	clearBtn.Parent = dummyCard

	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = UDim.new(0, 6)
	clearCorner.Parent = clearBtn

	local clearStroke = Instance.new("UIStroke")
	clearStroke.Color = Color3.fromRGB(255, 75, 75)
	clearStroke.Thickness = 1
	clearStroke.Parent = clearBtn

	clearBtn.MouseButton1Click:Connect(function()
		clearDummiesRemote:FireServer()
		showFeedback("Cleared all spawned dummies!")
	end)

	-- Footer Feedback Label
	feedbackLabel = Instance.new("TextLabel")
	feedbackLabel.Name = "FeedbackLabel"
	feedbackLabel.Size = UDim2.new(1, -20, 0, 20)
	feedbackLabel.Position = UDim2.new(0, 10, 0, 120)
	feedbackLabel.BackgroundTransparency = 1
	feedbackLabel.Font = Enum.Font.GothamBold
	feedbackLabel.Text = ""
	feedbackLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
	feedbackLabel.TextSize = 10
	feedbackLabel.Visible = false
	feedbackLabel.Parent = dummyCard
end

function CMDController.Toggle()
	if isOpen then
		CMDController.Close()
	else
		CMDController.Open()
	end
end

function CMDController.Open()
	if not mainFrame then return end
	isOpen = true
	mainFrame.Visible = true

	-- Smooth open animation
	mainFrame.Size = UDim2.new(0, 500, 0, 540)
	TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 520, 0, 560)
	}):Play()
end

function CMDController.Close()
	if not mainFrame then return end
	isOpen = false
	mainFrame.Visible = false
end

function CMDController.IsOpen(): boolean
	return isOpen
end

return CMDController
