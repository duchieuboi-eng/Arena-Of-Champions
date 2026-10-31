--[[
    HUDController.lua
    Forsaken-inspired HUD UI for Health & Stamina display, M1 skill slot,
    and the wide sliding drawer handle bar for the 11-stat viewer panel.
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local HUDController = {}

local screenGui: ScreenGui
local hudFrame: Frame
local healthFill: Frame
local healthText: TextLabel
local staminaFill: Frame
local staminaText: TextLabel
local nameLabel: TextLabel
local avatarImage: ImageLabel

-- Skill UI References
local skillSlotFrame: Frame
local skillIconBox: Frame
local skillIconStroke: UIStroke
local skillIconSymbol: TextLabel
local skillNameLabel: TextLabel
local cooldownOverlay: Frame
local cooldownText: TextLabel
local skillKeyLabel: TextLabel
local currentCooldownThread: thread?

-- Sliding Drawer Handle Bar & Panel References
local drawerHandleBar: TextButton
local drawerArrowLabel: TextLabel
local statPanel: Frame
local isStatPanelOpen = false
local statValueLabels = {}
local activeDrawerTweens = {}

local BAR_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local DRAWER_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- Positions for drawer closed and open states
local CLOSED_HANDLE_POS = UDim2.new(0, 30, 1, -160)
local OPEN_HANDLE_POS = UDim2.new(0, 30, 1, -348)
local PANEL_BOTTOM_POS = UDim2.new(0, 30, 1, -138)
local PANEL_OPEN_HEIGHT = 185

local STAT_DISPLAY_LIST = {
	{ key = "HP", label = "HP", suffix = "" },
	{ key = "Regen", label = "Regen", suffix = "/s" },
	{ key = "Stamina", label = "Stamina", suffix = "" },
	{ key = "Recovery", label = "Recovery", suffix = "/s" },
	{ key = "Walk", label = "Walk", suffix = "" },
	{ key = "Sprint", label = "Sprint", suffix = "" },
	{ key = "Jump", label = "Jump", suffix = "" },
	{ key = "Physical", label = "Physical", suffix = "" },
	{ key = "Magic", label = "Magic", suffix = "" },
	{ key = "DEF", label = "DEF", suffix = "" },
	{ key = "Crit", label = "Crit", suffix = "%" },
	{ key = "CritDMG", label = "Crit DMG", suffix = "%" },
}

function HUDController.Init()
	HUDController.BuildUI()

	LocalPlayer.CharacterAdded:Connect(HUDController.BindCharacter)
	if LocalPlayer.Character then
		HUDController.BindCharacter(LocalPlayer.Character)
	end
end

function HUDController.BuildUI()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ArenaHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = PlayerGui

	-- =========================================================================
	-- 1. MAIN HUD CONTAINER (Bottom-Left aligned)
	-- =========================================================================
	hudFrame = Instance.new("Frame")
	hudFrame.Name = "HUDFrame"
	hudFrame.Size = UDim2.new(0, 380, 0, 105)
	hudFrame.Position = UDim2.new(0, 30, 1, -135)
	hudFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
	hudFrame.BackgroundTransparency = 0.25
	hudFrame.BorderSizePixel = 0
	hudFrame.Parent = screenGui

	local hudCorner = Instance.new("UICorner")
	hudCorner.CornerRadius = UDim.new(0, 12)
	hudCorner.Parent = hudFrame

	local hudStroke = Instance.new("UIStroke")
	hudStroke.Color = Color3.fromRGB(45, 50, 65)
	hudStroke.Thickness = 1.5
	hudStroke.Transparency = 0.3
	hudStroke.Parent = hudFrame

	-- Avatar / Portrait Box
	local avatarFrame = Instance.new("Frame")
	avatarFrame.Name = "AvatarFrame"
	avatarFrame.Size = UDim2.new(0, 80, 0, 80)
	avatarFrame.Position = UDim2.new(0, 12, 0.5, -40)
	avatarFrame.BackgroundColor3 = Color3.fromRGB(22, 26, 35)
	avatarFrame.BorderSizePixel = 0
	avatarFrame.Parent = hudFrame

	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0, 10)
	avatarCorner.Parent = avatarFrame

	local avatarStroke = Instance.new("UIStroke")
	avatarStroke.Color = Color3.fromRGB(70, 78, 100)
	avatarStroke.Thickness = 1.5
	avatarStroke.Parent = avatarFrame

	avatarImage = Instance.new("ImageLabel")
	avatarImage.Name = "PortraitImage"
	avatarImage.Size = UDim2.new(1, -6, 1, -6)
	avatarImage.Position = UDim2.new(0, 3, 0, 3)
	avatarImage.BackgroundTransparency = 1
	avatarImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	avatarImage.ScaleType = Enum.ScaleType.Fit
	avatarImage.Parent = avatarFrame

	local avatarImgCorner = Instance.new("UICorner")
	avatarImgCorner.CornerRadius = UDim.new(0, 8)
	avatarImgCorner.Parent = avatarImage

	-- Character Name Label
	nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0, 260, 0, 20)
	nameLabel.Position = UDim2.new(0, 105, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = "UNMORPHED"
	nameLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
	nameLabel.TextSize = 14
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = hudFrame

	-- Health Bar Container
	local healthBg = Instance.new("Frame")
	healthBg.Name = "HealthBackground"
	healthBg.Size = UDim2.new(0, 260, 0, 26)
	healthBg.Position = UDim2.new(0, 105, 0, 34)
	healthBg.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	healthBg.BorderSizePixel = 0
	healthBg.ClipsDescendants = true
	healthBg.Parent = hudFrame

	local healthBgCorner = Instance.new("UICorner")
	healthBgCorner.CornerRadius = UDim.new(0, 6)
	healthBgCorner.Parent = healthBg

	local healthBgStroke = Instance.new("UIStroke")
	healthBgStroke.Color = Color3.fromRGB(40, 45, 58)
	healthBgStroke.Thickness = 1
	healthBgStroke.Parent = healthBg

	healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBg

	local healthGradient = Instance.new("UIGradient")
	healthGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(39, 174, 96)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(46, 204, 113))
	})
	healthGradient.Parent = healthFill

	local healthFillCorner = Instance.new("UICorner")
	healthFillCorner.CornerRadius = UDim.new(0, 6)
	healthFillCorner.Parent = healthFill

	healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Font = Enum.Font.GothamBold
	healthText.Text = "100 / 100"
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.TextSize = 12
	healthText.ZIndex = 3
	healthText.Parent = healthBg

	local healthTextStroke = Instance.new("UIStroke")
	healthTextStroke.Color = Color3.fromRGB(0, 0, 0)
	healthTextStroke.Thickness = 1.2
	healthTextStroke.Transparency = 0.3
	healthTextStroke.Parent = healthText

	-- Stamina Bar Container
	local staminaBg = Instance.new("Frame")
	staminaBg.Name = "StaminaBackground"
	staminaBg.Size = UDim2.new(0, 260, 0, 22)
	staminaBg.Position = UDim2.new(0, 105, 0, 68)
	staminaBg.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	staminaBg.BorderSizePixel = 0
	staminaBg.ClipsDescendants = true
	staminaBg.Parent = hudFrame

	local staminaBgCorner = Instance.new("UICorner")
	staminaBgCorner.CornerRadius = UDim.new(0, 6)
	staminaBgCorner.Parent = staminaBg

	local staminaBgStroke = Instance.new("UIStroke")
	staminaBgStroke.Color = Color3.fromRGB(40, 45, 58)
	staminaBgStroke.Thickness = 1
	staminaBgStroke.Parent = staminaBg

	staminaFill = Instance.new("Frame")
	staminaFill.Name = "StaminaFill"
	staminaFill.Size = UDim2.new(1, 0, 1, 0)
	staminaFill.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
	staminaFill.BorderSizePixel = 0
	staminaFill.Parent = staminaBg

	local staminaGradient = Instance.new("UIGradient")
	staminaGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(41, 128, 185)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(52, 152, 219))
	})
	staminaGradient.Parent = staminaFill

	local staminaFillCorner = Instance.new("UICorner")
	staminaFillCorner.CornerRadius = UDim.new(0, 6)
	staminaFillCorner.Parent = staminaFill

	staminaText = Instance.new("TextLabel")
	staminaText.Name = "StaminaText"
	staminaText.Size = UDim2.new(1, 0, 1, 0)
	staminaText.BackgroundTransparency = 1
	staminaText.Font = Enum.Font.GothamBold
	staminaText.Text = "100 / 100"
	staminaText.TextColor3 = Color3.fromRGB(255, 255, 255)
	staminaText.TextSize = 11
	staminaText.ZIndex = 3
	staminaText.Parent = staminaBg

	local staminaTextStroke = Instance.new("UIStroke")
	staminaTextStroke.Color = Color3.fromRGB(0, 0, 0)
	staminaTextStroke.Thickness = 1.2
	staminaTextStroke.Transparency = 0.3
	staminaTextStroke.Parent = staminaText

	-- =========================================================================
	-- 2. SKILL BAR CONTAINER (M1 Slot)
	-- =========================================================================
	skillSlotFrame = Instance.new("Frame")
	skillSlotFrame.Name = "SkillSlot_M1"
	skillSlotFrame.Size = UDim2.new(0, 95, 0, 105)
	skillSlotFrame.Position = UDim2.new(0, 420, 1, -135)
	skillSlotFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
	skillSlotFrame.BackgroundTransparency = 0.25
	skillSlotFrame.BorderSizePixel = 0
	skillSlotFrame.Parent = screenGui

	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 12)
	slotCorner.Parent = skillSlotFrame

	local slotStroke = Instance.new("UIStroke")
	slotStroke.Color = Color3.fromRGB(45, 50, 65)
	slotStroke.Thickness = 1.5
	slotStroke.Transparency = 0.3
	slotStroke.Parent = skillSlotFrame

	skillKeyLabel = Instance.new("TextLabel")
	skillKeyLabel.Name = "KeyLabel"
	skillKeyLabel.Size = UDim2.new(1, 0, 0, 18)
	skillKeyLabel.Position = UDim2.new(0, 0, 0, 5)
	skillKeyLabel.BackgroundTransparency = 1
	skillKeyLabel.Font = Enum.Font.GothamBlack
	skillKeyLabel.Text = "[ M1 ]"
	skillKeyLabel.TextColor3 = Color3.fromRGB(0, 215, 255)
	skillKeyLabel.TextSize = 12
	skillKeyLabel.Parent = skillSlotFrame

	local keyStroke = Instance.new("UIStroke")
	keyStroke.Color = Color3.fromRGB(0, 0, 0)
	keyStroke.Thickness = 1
	keyStroke.Parent = skillKeyLabel

	skillIconBox = Instance.new("Frame")
	skillIconBox.Name = "IconBox"
	skillIconBox.Size = UDim2.new(0, 52, 0, 52)
	skillIconBox.Position = UDim2.new(0.5, -26, 0, 24)
	skillIconBox.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	skillIconBox.BorderSizePixel = 0
	skillIconBox.ClipsDescendants = true
	skillIconBox.Parent = skillSlotFrame

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 8)
	iconCorner.Parent = skillIconBox

	skillIconStroke = Instance.new("UIStroke")
	skillIconStroke.Color = Color3.fromRGB(60, 72, 95)
	skillIconStroke.Thickness = 1.5
	skillIconStroke.Parent = skillIconBox

	skillIconSymbol = Instance.new("TextLabel")
	skillIconSymbol.Name = "IconSymbol"
	skillIconSymbol.Size = UDim2.new(1, 0, 1, 0)
	skillIconSymbol.BackgroundTransparency = 1
	skillIconSymbol.Font = Enum.Font.GothamBlack
	skillIconSymbol.Text = "🔒"
	skillIconSymbol.TextSize = 24
	skillIconSymbol.Parent = skillIconBox

	cooldownOverlay = Instance.new("Frame")
	cooldownOverlay.Name = "CooldownOverlay"
	cooldownOverlay.Size = UDim2.new(1, 0, 0, 0)
	cooldownOverlay.Position = UDim2.new(0, 0, 1, 0)
	cooldownOverlay.AnchorPoint = Vector2.new(0, 1)
	cooldownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cooldownOverlay.BackgroundTransparency = 0.45
	cooldownOverlay.BorderSizePixel = 0
	cooldownOverlay.ZIndex = 4
	cooldownOverlay.Parent = skillIconBox

	cooldownText = Instance.new("TextLabel")
	cooldownText.Name = "CooldownText"
	cooldownText.Size = UDim2.new(1, 0, 1, 0)
	cooldownText.BackgroundTransparency = 1
	cooldownText.Font = Enum.Font.GothamBlack
	cooldownText.Text = "2.0s"
	cooldownText.TextColor3 = Color3.fromRGB(255, 255, 255)
	cooldownText.TextSize = 16
	cooldownText.Visible = false
	cooldownText.ZIndex = 5
	cooldownText.Parent = skillIconBox

	local cdStroke = Instance.new("UIStroke")
	cdStroke.Color = Color3.fromRGB(0, 0, 0)
	cdStroke.Thickness = 1.5
	cdStroke.Parent = cooldownText

	skillNameLabel = Instance.new("TextLabel")
	skillNameLabel.Name = "SkillName"
	skillNameLabel.Size = UDim2.new(1, 0, 0, 18)
	skillNameLabel.Position = UDim2.new(0, 0, 1, -22)
	skillNameLabel.BackgroundTransparency = 1
	skillNameLabel.Font = Enum.Font.GothamBold
	skillNameLabel.Text = "LOCKED"
	skillNameLabel.TextColor3 = Color3.fromRGB(150, 165, 190)
	skillNameLabel.TextSize = 10
	skillNameLabel.Parent = skillSlotFrame

	-- =========================================================================
	-- 3. SLIDING DRAWER HANDLE BAR & STAT PANEL
	-- =========================================================================
	-- Wide horizontal handle bar that spans the full width of the main HUD container (380px)
	drawerHandleBar = Instance.new("TextButton")
	drawerHandleBar.Name = "DrawerHandleBar"
	drawerHandleBar.Size = UDim2.new(0, 380, 0, 22)
	drawerHandleBar.Position = CLOSED_HANDLE_POS
	drawerHandleBar.BackgroundColor3 = Color3.fromRGB(20, 25, 36)
	drawerHandleBar.BackgroundTransparency = 0.2
	drawerHandleBar.BorderSizePixel = 0
	drawerHandleBar.Text = ""
	drawerHandleBar.AutoButtonColor = false
	drawerHandleBar.Parent = screenGui

	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(0, 8)
	handleCorner.Parent = drawerHandleBar

	local handleStroke = Instance.new("UIStroke")
	handleStroke.Color = Color3.fromRGB(50, 62, 85)
	handleStroke.Thickness = 1.2
	handleStroke.Parent = drawerHandleBar

	drawerArrowLabel = Instance.new("TextLabel")
	drawerArrowLabel.Name = "ArrowLabel"
	drawerArrowLabel.Size = UDim2.new(1, 0, 1, 0)
	drawerArrowLabel.BackgroundTransparency = 1
	drawerArrowLabel.Font = Enum.Font.GothamBlack
	drawerArrowLabel.Text = "^"
	drawerArrowLabel.TextColor3 = Color3.fromRGB(0, 215, 255)
	drawerArrowLabel.TextSize = 14
	drawerArrowLabel.Parent = drawerHandleBar

	-- Dropdown Panel Container (Anchored at bottom, expands upward between handle and HUD)
	statPanel = Instance.new("Frame")
	statPanel.Name = "StatDropdownPanel"
	statPanel.Size = UDim2.new(0, 380, 0, 0)
	statPanel.Position = PANEL_BOTTOM_POS
	statPanel.AnchorPoint = Vector2.new(0, 1)
	statPanel.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
	statPanel.BackgroundTransparency = 0.15
	statPanel.BorderSizePixel = 0
	statPanel.Visible = false
	statPanel.ClipsDescendants = true
	statPanel.Parent = screenGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = statPanel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(45, 55, 75)
	panelStroke.Thickness = 1.5
	panelStroke.Parent = statPanel

	local panelHeader = Instance.new("TextLabel")
	panelHeader.Name = "Header"
	panelHeader.Size = UDim2.new(1, -20, 0, 22)
	panelHeader.Position = UDim2.new(0, 10, 0, 6)
	panelHeader.BackgroundTransparency = 1
	panelHeader.Font = Enum.Font.GothamBlack
	panelHeader.Text = "📊 CHARACTER STATS"
	panelHeader.TextColor3 = Color3.fromRGB(0, 215, 255)
	panelHeader.TextSize = 12
	panelHeader.TextXAlignment = Enum.TextXAlignment.Left
	panelHeader.Parent = statPanel

	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "GridContainer"
	gridFrame.Size = UDim2.new(1, -16, 1, -36)
	gridFrame.Position = UDim2.new(0, 8, 0, 30)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = statPanel

	local uigrid = Instance.new("UIGridLayout")
	uigrid.CellSize = UDim2.new(0, 115, 0, 30)
	uigrid.CellPadding = UDim2.new(0, 6, 0, 6)
	uigrid.SortOrder = Enum.SortOrder.LayoutOrder
	uigrid.Parent = gridFrame

	for index, statInfo in ipairs(STAT_DISPLAY_LIST) do
		local card = Instance.new("Frame")
		card.Name = "StatCard_" .. statInfo.key
		card.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
		card.BorderSizePixel = 0
		card.LayoutOrder = index
		card.Parent = gridFrame

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 5)
		cardCorner.Parent = card

		local lbl = Instance.new("TextLabel")
		lbl.Name = "Label"
		lbl.Size = UDim2.new(0.55, 0, 1, 0)
		lbl.Position = UDim2.new(0, 6, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.Text = statInfo.label .. ":"
		lbl.TextColor3 = Color3.fromRGB(150, 170, 200)
		lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = card

		local val = Instance.new("TextLabel")
		val.Name = "Value"
		val.Size = UDim2.new(0.45, -8, 1, 0)
		val.Position = UDim2.new(0.55, 0, 0, 0)
		val.BackgroundTransparency = 1
		val.Font = Enum.Font.GothamBlack
		val.Text = "0" .. statInfo.suffix
		val.TextColor3 = Color3.fromRGB(255, 255, 255)
		val.TextSize = 11
		val.TextXAlignment = Enum.TextXAlignment.Right
		val.Parent = card

		statValueLabels[statInfo.key] = { label = val, suffix = statInfo.suffix }
	end

	-- Connect Sliding Drawer Open / Close Animation
	drawerHandleBar.MouseButton1Click:Connect(function()
		for _, tween in pairs(activeDrawerTweens) do
			tween:Cancel()
		end
		activeDrawerTweens = {}

		if not isStatPanelOpen then
			-- OPEN DRAWER: Slide handle bar upward and expand stat panel
			isStatPanelOpen = true
			statPanel.Visible = true
			drawerArrowLabel.Text = "v"

			local handleTween = TweenService:Create(drawerHandleBar, DRAWER_TWEEN_INFO, {
				Position = OPEN_HANDLE_POS
			})
			local panelTween = TweenService:Create(statPanel, DRAWER_TWEEN_INFO, {
				Size = UDim2.new(0, 380, 0, PANEL_OPEN_HEIGHT)
			})

			activeDrawerTweens.handle = handleTween
			activeDrawerTweens.panel = panelTween

			handleTween:Play()
			panelTween:Play()
		else
			-- CLOSE DRAWER: Slide handle bar back down and collapse stat panel
			isStatPanelOpen = false
			drawerArrowLabel.Text = "^"

			local handleTween = TweenService:Create(drawerHandleBar, DRAWER_TWEEN_INFO, {
				Position = CLOSED_HANDLE_POS
			})
			local panelTween = TweenService:Create(statPanel, DRAWER_TWEEN_INFO, {
				Size = UDim2.new(0, 380, 0, 0)
			})

			activeDrawerTweens.handle = handleTween
			activeDrawerTweens.panel = panelTween

			handleTween:Play()
			panelTween:Play()

			panelTween.Completed:Connect(function()
				if not isStatPanelOpen then
					statPanel.Visible = false
				end
			end)
		end
	end)
end

--[[
    Triggers the animated cooldown sweep on the M1 skill icon.
    Starts immediately upon click and never blocks inputs.
--]]
function HUDController.TriggerSkillCooldown(skillId: string, duration: number)
	if currentCooldownThread then
		task.cancel(currentCooldownThread)
		currentCooldownThread = nil
	end

	currentCooldownThread = task.spawn(function()
		cooldownText.Visible = true
		local startTime = os.clock()

		while true do
			local elapsed = os.clock() - startTime
			local remaining = math.max(0, duration - elapsed)

			cooldownText.Text = string.format("%.1fs", remaining)
			local ratio = remaining / duration
			cooldownOverlay.Size = UDim2.new(1, 0, ratio, 0)

			if remaining <= 0 then break end
			task.wait(0.03)
		end

		cooldownText.Visible = false
		cooldownOverlay.Size = UDim2.new(1, 0, 0, 0)

		-- Asynchronous ready pulse (does NOT block input)
		TweenService:Create(skillIconStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Color3.fromRGB(0, 255, 255),
			Thickness = 2.5
		}):Play()

		task.delay(0.20, function()
			TweenService:Create(skillIconStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = Color3.fromRGB(60, 72, 95),
				Thickness = 1.5
			}):Play()
		end)
	end)
end

--[[
    Binds the HUD to a character model, updating bars and all 11 stats dynamically.
--]]
function HUDController.BindCharacter(character: Model)
	local function UpdateHealth()
		local hp = character:GetAttribute("Health") or 100
		local maxHp = character:GetAttribute("MaxHealth") or 100
		local ratio = math.clamp(hp / maxHp, 0, 1)

		TweenService:Create(healthFill, BAR_TWEEN_INFO, {
			Size = UDim2.new(ratio, 0, 1, 0)
		}):Play()

		healthText.Text = string.format("%d / %d", math.ceil(hp), math.ceil(maxHp))
	end

	local function UpdateStamina()
		local stamina = character:GetAttribute("Stamina") or 100
		local maxStamina = character:GetAttribute("MaxStamina") or 100
		local ratio = math.clamp(stamina / maxStamina, 0, 1)

		TweenService:Create(staminaFill, BAR_TWEEN_INFO, {
			Size = UDim2.new(ratio, 0, 1, 0)
		}):Play()

		staminaText.Text = string.format("%d / %d", math.ceil(stamina), math.ceil(maxStamina))
	end

	local function UpdateStatsPanel()
		for _, statInfo in ipairs(STAT_DISPLAY_LIST) do
			local ref = statValueLabels[statInfo.key]
			if ref then
				local val: any
				if statInfo.key == "HP" then
					val = character:GetAttribute("MaxHealth") or character:GetAttribute("HP") or 100
				elseif statInfo.key == "Stamina" then
					-- Strictly bind to MaxStamina (75 for Grot) so live sprint drain does not flicker in stat viewer
					val = character:GetAttribute("MaxStamina") or character:GetAttribute("Stamina") or 100
				else
					val = character:GetAttribute(statInfo.key)
				end

				if val == nil then
					val = 0
				end

				if type(val) == "number" then
					if statInfo.key == "Regen" or statInfo.key == "Recovery" then
						if val % 1 == 0 then
							ref.label.Text = string.format("%d%s", val, ref.suffix)
						else
							ref.label.Text = string.format("%.1f%s", val, ref.suffix)
						end
					else
						ref.label.Text = string.format("%d%s", math.round(val), ref.suffix)
					end
				else
					ref.label.Text = tostring(val) .. ref.suffix
				end
			end
		end
	end

	local function UpdateCharacterInfo()
		local charId = character:GetAttribute("CharacterId") or "Unmorphed"
		local charName = character:GetAttribute("CharacterName") or charId
		nameLabel.Text = string.upper(charName)

		if charId == "Unmorphed" then
			skillKeyLabel.Text = "[ M1 ]"
			skillIconSymbol.Text = "🔒"
			skillNameLabel.Text = "LOCKED"
			skillIconBox.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
		elseif charId == "Blocky" then
			skillKeyLabel.Text = "[ M1 ]"
			skillIconSymbol.Text = "👊"
			skillNameLabel.Text = "25 DMG"
			skillIconBox.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
		elseif charId == "Grot" then
			skillKeyLabel.Text = "[ M1 ]"
			skillIconSymbol.Text = "🌱"
			skillNameLabel.Text = "Sprout grows"
			skillIconBox.BackgroundColor3 = Color3.fromRGB(20, 32, 24)
		end

		UpdateStatsPanel()
	end

	UpdateHealth()
	UpdateStamina()
	UpdateCharacterInfo()

	character:GetAttributeChangedSignal("Health"):Connect(UpdateHealth)
	character:GetAttributeChangedSignal("MaxHealth"):Connect(function()
		UpdateHealth()
		UpdateStatsPanel()
	end)
	character:GetAttributeChangedSignal("Stamina"):Connect(UpdateStamina)
	character:GetAttributeChangedSignal("MaxStamina"):Connect(function()
		UpdateStamina()
		UpdateStatsPanel()
	end)
	character:GetAttributeChangedSignal("CharacterId"):Connect(UpdateCharacterInfo)
	character:GetAttributeChangedSignal("CharacterName"):Connect(UpdateCharacterInfo)

	for _, statInfo in ipairs(STAT_DISPLAY_LIST) do
		character:GetAttributeChangedSignal(statInfo.key):Connect(UpdateStatsPanel)
	end
end

return HUDController
