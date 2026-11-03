--[[
    ShopController.lua
    Client controller for the Arena of Valor (AoV) style Item Shop & Economy:
    - Sleek Shop button on the HUD displaying live Gold count
    - 3-slot Tier I Item Shop:
        * Shortsword (150G | Sell: 75G | +10 Physical)
        * Magic dust (250G | Sell: 125G | +30 Magic)
        * Leather armor (300G | Sell: 150G | +5 DEF)
    - 3 equipped item slots with instant 50% sell-back functionality
    - Floating reward notifications for +100 Gold & +100 EXP
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared.Configs.EconomyConfig)
local RemoteManager = require(Shared.Modules.RemoteManager)

local ShopController = {}

local buyItemRemote = RemoteManager.GetRemoteEvent("Shop_BuyItem")
local sellItemRemote = RemoteManager.GetRemoteEvent("Shop_SellItem")
local rewardPopupRemote = RemoteManager.GetRemoteEvent("RewardPopupNotification")
local levelUpRemote = RemoteManager.GetRemoteEvent("LevelUpNotification")

local LocalPlayer = Players.LocalPlayer

local screenGui: ScreenGui
local shopButton: TextButton
local goldCounterLabel: TextLabel
local shopModal: Frame
local isOpen = false

local slotFrames = {}
local feedbackLabel: TextLabel

local function showShopFeedback(msg: string, isError: boolean?)
	if not feedbackLabel then return end
	feedbackLabel.Text = msg
	feedbackLabel.TextColor3 = isError and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 215, 0)
	feedbackLabel.Visible = true

	task.delay(2.5, function()
		if feedbackLabel and feedbackLabel.Text == msg then
			feedbackLabel.Visible = false
		end
	end)
end

function ShopController.Init()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	-- 1. ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AoVShopScreenGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 90
	screenGui.Parent = playerGui

	-- 2. Sleek AoV Style HUD Shop Button
	-- Placed on the bottom-left of screen directly above HUD drawer showing "🪙 0G - SHOP"
	shopButton = Instance.new("TextButton")
	shopButton.Name = "HUDShopButton"
	shopButton.Size = UDim2.new(0, 150, 0, 32)
	shopButton.Position = UDim2.new(0, 30, 1, -182)
	shopButton.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	shopButton.BackgroundTransparency = 0.15
	shopButton.Font = Enum.Font.GothamBold
	shopButton.Text = "🪙 0G - SHOP"
	shopButton.TextColor3 = Color3.fromRGB(255, 215, 0)
	shopButton.TextSize = 12
	shopButton.BorderSizePixel = 0
	shopButton.Parent = screenGui

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = shopButton

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(255, 200, 50)
	btnStroke.Thickness = 1.2
	btnStroke.Parent = shopButton

	shopButton.MouseButton1Click:Connect(function()
		ShopController.Toggle()
	end)

	-- Update Gold counter whenever player or character attribute changes
	local function updateGoldDisplay()
		local gold = LocalPlayer:GetAttribute("Gold") or 0
		shopButton.Text = string.format("🪙 %dG - SHOP", gold)
	end
	LocalPlayer:GetAttributeChangedSignal("Gold"):Connect(updateGoldDisplay)
	updateGoldDisplay()

	-- =========================================================================
	-- 2b. Compact Arena of Valor 3-Slot Item Inventory Bar on the HUD (next to skills)
	-- =========================================================================
	local hudItemBar = Instance.new("Frame")
	hudItemBar.Name = "HUDItemInventoryBar"
	hudItemBar.Size = UDim2.new(0, 140, 0, 105)
	hudItemBar.Position = UDim2.new(0, 630, 1, -135)
	hudItemBar.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
	hudItemBar.BackgroundTransparency = 0.25
	hudItemBar.BorderSizePixel = 0
	hudItemBar.Parent = screenGui

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 12)
	barCorner.Parent = hudItemBar

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.fromRGB(45, 50, 65)
	barStroke.Thickness = 1.5
	barStroke.Transparency = 0.3
	barStroke.Parent = hudItemBar

	local barTitle = Instance.new("TextLabel")
	barTitle.Name = "BarTitle"
	barTitle.Size = UDim2.new(1, 0, 0, 18)
	barTitle.Position = UDim2.new(0, 0, 0, 5)
	barTitle.BackgroundTransparency = 1
	barTitle.Font = Enum.Font.GothamBlack
	barTitle.Text = "📦 ITEMS (3)"
	barTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
	barTitle.TextSize = 11
	barTitle.Parent = hudItemBar

	local hudSlotsContainer = Instance.new("Frame")
	hudSlotsContainer.Size = UDim2.new(1, -10, 0, 74)
	hudSlotsContainer.Position = UDim2.new(0, 5, 0, 25)
	hudSlotsContainer.BackgroundTransparency = 1
	hudSlotsContainer.Parent = hudItemBar

	local hudSlotsLayout = Instance.new("UIListLayout")
	hudSlotsLayout.FillDirection = Enum.FillDirection.Horizontal
	hudSlotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hudSlotsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hudSlotsLayout.Padding = UDim.new(0, 4)
	hudSlotsLayout.Parent = hudSlotsContainer

	for slotIdx = 1, EconomyConfig.MaxInventorySlots do
		local hudSlotBtn = Instance.new("TextButton")
		hudSlotBtn.Name = "HUDSlot_" .. tostring(slotIdx)
		hudSlotBtn.Size = UDim2.new(0, 40, 0, 70)
		hudSlotBtn.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
		hudSlotBtn.BorderSizePixel = 0
		hudSlotBtn.Text = ""
		hudSlotBtn.AutoButtonColor = true
		hudSlotBtn.Parent = hudSlotsContainer

		local hCorner = Instance.new("UICorner")
		hCorner.CornerRadius = UDim.new(0, 6)
		hCorner.Parent = hudSlotBtn

		local hStroke = Instance.new("UIStroke")
		hStroke.Color = Color3.fromRGB(55, 65, 85)
		hStroke.Thickness = 1
		hStroke.Parent = hudSlotBtn

		local numLabel = Instance.new("TextLabel")
		numLabel.Size = UDim2.new(1, 0, 0, 14)
		numLabel.Position = UDim2.new(0, 0, 0, 2)
		numLabel.BackgroundTransparency = 1
		numLabel.Font = Enum.Font.GothamBold
		numLabel.Text = "[" .. tostring(slotIdx) .. "]"
		numLabel.TextColor3 = Color3.fromRGB(130, 145, 170)
		numLabel.TextSize = 8
		numLabel.Parent = hudSlotBtn

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(1, 0, 0, 28)
		iconLabel.Position = UDim2.new(0, 0, 0, 16)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Font = Enum.Font.GothamBlack
		iconLabel.Text = "+"
		iconLabel.TextColor3 = Color3.fromRGB(70, 85, 110)
		iconLabel.TextSize = 18
		iconLabel.Parent = hudSlotBtn

		local actionLabel = Instance.new("TextLabel")
		actionLabel.Size = UDim2.new(1, 0, 0, 18)
		actionLabel.Position = UDim2.new(0, 0, 1, -20)
		actionLabel.BackgroundTransparency = 1
		actionLabel.Font = Enum.Font.GothamBold
		actionLabel.Text = "SHOP"
		actionLabel.TextColor3 = Color3.fromRGB(100, 120, 150)
		actionLabel.TextSize = 7
		actionLabel.Parent = hudSlotBtn

		hudSlotBtn.MouseButton1Click:Connect(function()
			local currentItemId = LocalPlayer:GetAttribute("ItemSlot" .. tostring(slotIdx))
			if currentItemId and currentItemId ~= "" then
				-- Click owned item to sell back for 50%
				sellItemRemote:FireServer(slotIdx)
				local item = EconomyConfig.Items[currentItemId]
				showShopFeedback(string.format("Sold %s for %dG!", item and item.Name or "item", item and item.SellPrice or 0))
			else
				-- Empty slot: open shop
				ShopController.Open()
			end
		end)

		local function updateHUDSlot()
			local itemId = LocalPlayer:GetAttribute("ItemSlot" .. tostring(slotIdx))
			if itemId and itemId ~= "" and EconomyConfig.Items[itemId] then
				local item = EconomyConfig.Items[itemId]
				iconLabel.Text = item.Icon
				iconLabel.TextSize = 18
				actionLabel.Text = "SELL (" .. tostring(item.SellPrice) .. "G)"
				actionLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
				hStroke.Color = Color3.fromRGB(255, 200, 60)
			else
				iconLabel.Text = "+"
				iconLabel.TextSize = 18
				actionLabel.Text = "SHOP"
				actionLabel.TextColor3 = Color3.fromRGB(100, 120, 150)
				hStroke.Color = Color3.fromRGB(55, 65, 85)
			end
		end

		LocalPlayer:GetAttributeChangedSignal("ItemSlot" .. tostring(slotIdx)):Connect(updateHUDSlot)
		updateHUDSlot()
	end

	-- 3. Main AoV Shop Modal Window
	shopModal = Instance.new("Frame")
	shopModal.Name = "ShopModal"
	shopModal.Size = UDim2.new(0, 520, 0, 460)
	shopModal.Position = UDim2.new(0.5, -260, 0.5, -230)
	shopModal.BackgroundColor3 = Color3.fromRGB(12, 15, 22)
	shopModal.BackgroundTransparency = 0.1
	shopModal.BorderSizePixel = 0
	shopModal.Visible = false
	shopModal.ClipsDescendants = true
	shopModal.Parent = screenGui

	local modalCorner = Instance.new("UICorner")
	modalCorner.CornerRadius = UDim.new(0, 12)
	modalCorner.Parent = shopModal

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Color = Color3.fromRGB(255, 200, 60)
	modalStroke.Thickness = 1.5
	modalStroke.Parent = shopModal

	-- Header Bar
	local headerFrame = Instance.new("Frame")
	headerFrame.Size = UDim2.new(1, 0, 0, 42)
	headerFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	headerFrame.BorderSizePixel = 0
	headerFrame.Parent = shopModal

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = headerFrame

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Size = UDim2.new(1, -50, 1, 0)
	headerTitle.Position = UDim2.new(0, 14, 0, 0)
	headerTitle.BackgroundTransparency = 1
	headerTitle.Font = Enum.Font.GothamBlack
	headerTitle.Text = "⚔️ ARENA OF VALOR ITEM SHOP"
	headerTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
	headerTitle.TextSize = 13
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Parent = headerFrame

	local closeBtn = Instance.new("TextButton")
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
		ShopController.Close()
	end)

	-- =========================================================================
	-- SECTION 1: TIER I ITEMS AVAILABLE FOR PURCHASE
	-- =========================================================================
	local itemsSectionTitle = Instance.new("TextLabel")
	itemsSectionTitle.Size = UDim2.new(1, -28, 0, 20)
	itemsSectionTitle.Position = UDim2.new(0, 14, 0, 50)
	itemsSectionTitle.BackgroundTransparency = 1
	itemsSectionTitle.Font = Enum.Font.GothamBold
	itemsSectionTitle.Text = "📦 TIER I ITEMS (3 SLOTS AVAILABLE)"
	itemsSectionTitle.TextColor3 = Color3.fromRGB(0, 220, 255)
	itemsSectionTitle.TextSize = 11
	itemsSectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	itemsSectionTitle.Parent = shopModal

	local itemListFrame = Instance.new("Frame")
	itemListFrame.Size = UDim2.new(1, -28, 0, 195)
	itemListFrame.Position = UDim2.new(0, 14, 0, 74)
	itemListFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	itemListFrame.BorderSizePixel = 0
	itemListFrame.Parent = shopModal

	local ilCorner = Instance.new("UICorner")
	ilCorner.CornerRadius = UDim.new(0, 8)
	ilCorner.Parent = itemListFrame

	local availableItems = {
		EconomyConfig.Items.Shortsword,
		EconomyConfig.Items.MagicDust,
		EconomyConfig.Items.LeatherArmor,
	}

	for idx, item in ipairs(availableItems) do
		local rowY = 8 + (idx - 1) * 60

		local itemRow = Instance.new("Frame")
		itemRow.Size = UDim2.new(1, -16, 0, 54)
		itemRow.Position = UDim2.new(0, 8, 0, rowY)
		itemRow.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
		itemRow.BorderSizePixel = 0
		itemRow.Parent = itemListFrame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = itemRow

		local iconBox = Instance.new("TextLabel")
		iconBox.Size = UDim2.new(0, 40, 0, 40)
		iconBox.Position = UDim2.new(0, 8, 0, 7)
		iconBox.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
		iconBox.Font = Enum.Font.GothamBold
		iconBox.Text = item.Icon
		iconBox.TextSize = 20
		iconBox.BorderSizePixel = 0
		iconBox.Parent = itemRow

		local ibCorner = Instance.new("UICorner")
		ibCorner.CornerRadius = UDim.new(0, 6)
		ibCorner.Parent = iconBox

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0, 180, 0, 20)
		nameLbl.Position = UDim2.new(0, 56, 0, 7)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.Text = item.Name
		nameLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
		nameLbl.TextSize = 12
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Parent = itemRow

		local descLbl = Instance.new("TextLabel")
		descLbl.Size = UDim2.new(0, 220, 0, 18)
		descLbl.Position = UDim2.new(0, 56, 0, 27)
		descLbl.BackgroundTransparency = 1
		descLbl.Font = Enum.Font.Gotham
		descLbl.Text = item.Description .. " • Sell: " .. tostring(item.SellPrice) .. "G"
		descLbl.TextColor3 = Color3.fromRGB(160, 175, 200)
		descLbl.TextSize = 10
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.Parent = itemRow

		local buyBtn = Instance.new("TextButton")
		buyBtn.Size = UDim2.new(0, 100, 0, 32)
		buyBtn.Position = UDim2.new(1, -108, 0, 11)
		buyBtn.BackgroundColor3 = Color3.fromRGB(210, 160, 20)
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.Text = "BUY " .. tostring(item.Cost) .. "G"
		buyBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
		buyBtn.TextSize = 11
		buyBtn.BorderSizePixel = 0
		buyBtn.Parent = itemRow

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 6)
		bCorner.Parent = buyBtn

		buyBtn.MouseButton1Click:Connect(function()
			local currentGold = LocalPlayer:GetAttribute("Gold") or 0
			if currentGold < item.Cost then
				showShopFeedback("Not enough Gold (" .. tostring(item.Cost) .. "G required)!", true)
				return
			end

			-- Check for free slot
			local hasFreeSlot = false
			for s = 1, EconomyConfig.MaxInventorySlots do
				local sVal = LocalPlayer:GetAttribute("ItemSlot" .. tostring(s))
				if not sVal or sVal == "" then
					hasFreeSlot = true
					break
				end
			end

			if not hasFreeSlot then
				showShopFeedback("Inventory full (3/3 slots used)!", true)
				return
			end

			buyItemRemote:FireServer(item.Id)
			showShopFeedback("Purchased " .. item.Name .. "!")
		end)
	end

	-- =========================================================================
	-- SECTION 2: PLAYER'S 3 INVENTORY SLOTS
	-- =========================================================================
	local invSectionTitle = Instance.new("TextLabel")
	invSectionTitle.Size = UDim2.new(1, -28, 0, 20)
	invSectionTitle.Position = UDim2.new(0, 14, 0, 280)
	invSectionTitle.BackgroundTransparency = 1
	invSectionTitle.Font = Enum.Font.GothamBold
	invSectionTitle.Text = "🎒 EQUIPPED ITEMS (CLICK SELL TO REFUND 50%)"
	invSectionTitle.TextColor3 = Color3.fromRGB(46, 204, 113)
	invSectionTitle.TextSize = 11
	invSectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	invSectionTitle.Parent = shopModal

	local invContainer = Instance.new("Frame")
	invContainer.Size = UDim2.new(1, -28, 0, 115)
	invContainer.Position = UDim2.new(0, 14, 0, 304)
	invContainer.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	invContainer.BorderSizePixel = 0
	invContainer.Parent = shopModal

	local icCorner = Instance.new("UICorner")
	icCorner.CornerRadius = UDim.new(0, 8)
	icCorner.Parent = invContainer

	-- 3 horizontal slot cards
	local slotWidth = 154
	local slotSpacing = 10

	for slotIndex = 1, 3 do
		local xPos = 8 + (slotIndex - 1) * (slotWidth + slotSpacing)

		local slotCard = Instance.new("Frame")
		slotCard.Size = UDim2.new(0, slotWidth, 0, 100)
		slotCard.Position = UDim2.new(0, xPos, 0, 8)
		slotCard.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
		slotCard.BorderSizePixel = 0
		slotCard.Parent = invContainer

		local scCorner = Instance.new("UICorner")
		scCorner.CornerRadius = UDim.new(0, 6)
		scCorner.Parent = slotCard

		local slotTitle = Instance.new("TextLabel")
		slotTitle.Size = UDim2.new(1, 0, 0, 18)
		slotTitle.Position = UDim2.new(0, 0, 0, 4)
		slotTitle.BackgroundTransparency = 1
		slotTitle.Font = Enum.Font.GothamBold
		slotTitle.Text = "SLOT " .. tostring(slotIndex)
		slotTitle.TextColor3 = Color3.fromRGB(160, 175, 200)
		slotTitle.TextSize = 9
		slotTitle.Parent = slotCard

		local itemInfoLabel = Instance.new("TextLabel")
		itemInfoLabel.Size = UDim2.new(1, -8, 0, 32)
		itemInfoLabel.Position = UDim2.new(0, 4, 0, 22)
		itemInfoLabel.BackgroundTransparency = 1
		itemInfoLabel.Font = Enum.Font.GothamMedium
		itemInfoLabel.Text = "[ EMPTY ]"
		itemInfoLabel.TextColor3 = Color3.fromRGB(100, 115, 135)
		itemInfoLabel.TextSize = 10
		itemInfoLabel.TextWrapped = true
		itemInfoLabel.Parent = slotCard

		local sellBtn = Instance.new("TextButton")
		sellBtn.Size = UDim2.new(1, -16, 0, 26)
		sellBtn.Position = UDim2.new(0, 8, 1, -32)
		sellBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 35)
		sellBtn.Font = Enum.Font.GothamBold
		sellBtn.Text = "SELL"
		sellBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
		sellBtn.TextSize = 10
		sellBtn.BorderSizePixel = 0
		sellBtn.Visible = false
		sellBtn.Parent = slotCard

		local sbCorner = Instance.new("UICorner")
		sbCorner.CornerRadius = UDim.new(0, 4)
		sbCorner.Parent = sellBtn

		sellBtn.MouseButton1Click:Connect(function()
			sellItemRemote:FireServer(slotIndex)
			showShopFeedback("Sold item from Slot " .. tostring(slotIndex) .. "!")
		end)

		slotFrames[slotIndex] = {
			info = itemInfoLabel,
			sellBtn = sellBtn,
		}

		-- Listen for slot changes
		local function updateSlot()
			local itemId = LocalPlayer:GetAttribute("ItemSlot" .. tostring(slotIndex))
			if itemId and itemId ~= "" and EconomyConfig.Items[itemId] then
				local item = EconomyConfig.Items[itemId]
				itemInfoLabel.Text = item.Icon .. " " .. item.Name .. "\n" .. item.Description
				itemInfoLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
				sellBtn.Text = "SELL (" .. tostring(item.SellPrice) .. "G)"
				sellBtn.Visible = true
			else
				itemInfoLabel.Text = "[ EMPTY ]"
				itemInfoLabel.TextColor3 = Color3.fromRGB(100, 115, 135)
				sellBtn.Visible = false
			end
		end

		LocalPlayer:GetAttributeChangedSignal("ItemSlot" .. tostring(slotIndex)):Connect(updateSlot)
		updateSlot()
	end

	-- Footer Feedback Label
	feedbackLabel = Instance.new("TextLabel")
	feedbackLabel.Name = "FeedbackLabel"
	feedbackLabel.Size = UDim2.new(1, -28, 0, 20)
	feedbackLabel.Position = UDim2.new(0, 14, 1, -26)
	feedbackLabel.BackgroundTransparency = 1
	feedbackLabel.Font = Enum.Font.GothamBold
	feedbackLabel.Text = ""
	feedbackLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	feedbackLabel.TextSize = 10
	feedbackLabel.Visible = false
	feedbackLabel.Parent = shopModal

	-- Listen for Kill Reward Popups (+100G, +100 EXP)
	rewardPopupRemote.OnClientEvent:Connect(function(goldAmount: number, expAmount: number)
		ShopController.ShowRewardPopup(goldAmount, expAmount)
	end)

	-- Listen for Level Up notifications
	levelUpRemote.OnClientEvent:Connect(function(player: Player, newLevel: number)
		if player == LocalPlayer then
			ShopController.ShowLevelUpPopup(newLevel)
		end
	end)
end

function ShopController.Toggle()
	if isOpen then
		ShopController.Close()
	else
		ShopController.Open()
	end
end

function ShopController.Open()
	if not shopModal then return end
	isOpen = true
	shopModal.Visible = true

	shopModal.Size = UDim2.new(0, 500, 0, 440)
	TweenService:Create(shopModal, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 520, 0, 460)
	}):Play()
end

function ShopController.Close()
	if not shopModal then return end
	isOpen = false
	shopModal.Visible = false
end

--[[
    Shows sleek floating popup on center-screen when defeating a dummy (+100G, +100 EXP).
--]]
function ShopController.ShowRewardPopup(goldAmount: number, expAmount: number)
	if not screenGui then return end

	local rewardBanner = Instance.new("Frame")
	rewardBanner.Size = UDim2.new(0, 220, 0, 40)
	rewardBanner.Position = UDim2.new(0.5, -110, 0.35, 0)
	rewardBanner.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
	rewardBanner.BackgroundTransparency = 0.2
	rewardBanner.BorderSizePixel = 0
	rewardBanner.Parent = screenGui

	local rbCorner = Instance.new("UICorner")
	rbCorner.CornerRadius = UDim.new(0, 8)
	rbCorner.Parent = rewardBanner

	local rbStroke = Instance.new("UIStroke")
	rbStroke.Color = Color3.fromRGB(255, 215, 0)
	rbStroke.Thickness = 1.2
	rbStroke.Parent = rewardBanner

	local textLbl = Instance.new("TextLabel")
	textLbl.Size = UDim2.new(1, 0, 1, 0)
	textLbl.BackgroundTransparency = 1
	textLbl.Font = Enum.Font.GothamBlack
	textLbl.Text = string.format("🪙 +%d GOLD   ⭐ +%d EXP", goldAmount, expAmount)
	textLbl.TextColor3 = Color3.fromRGB(255, 230, 80)
	textLbl.TextSize = 12
	textLbl.Parent = rewardBanner

	local tweenInfo = TweenInfo.new(1.0, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	TweenService:Create(rewardBanner, tweenInfo, {
		Position = rewardBanner.Position + UDim2.new(0, 0, 0, -40),
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(textLbl, tweenInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(rbStroke, tweenInfo, { Transparency = 1 }):Play()

	Debris:AddItem(rewardBanner, 1.1)
end

--[[
    Plays Level Up banner and audio when reaching a new level.
--]]
function ShopController.ShowLevelUpPopup(newLevel: number)
	if not screenGui then return end

	local banner = Instance.new("Frame")
	banner.Size = UDim2.new(0, 280, 0, 52)
	banner.Position = UDim2.new(0.5, -140, 0.25, 0)
	banner.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
	banner.BackgroundTransparency = 0.1
	banner.BorderSizePixel = 0
	banner.Parent = screenGui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 10)
	bCorner.Parent = banner

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(0, 220, 255)
	bStroke.Thickness = 1.8
	bStroke.Parent = banner

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, 0, 0, 26)
	titleLbl.Position = UDim2.new(0, 0, 0, 4)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBlack
	titleLbl.Text = "⭐ LEVEL UP! ⭐"
	titleLbl.TextColor3 = Color3.fromRGB(255, 220, 0)
	titleLbl.TextSize = 14
	titleLbl.Parent = banner

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(1, 0, 0, 18)
	subLbl.Position = UDim2.new(0, 0, 0, 28)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Enum.Font.GothamBold
	subLbl.Text = "REACHED LEVEL " .. tostring(newLevel) .. " (STATS INCREASED!)"
	subLbl.TextColor3 = Color3.fromRGB(0, 240, 255)
	subLbl.TextSize = 11
	subLbl.Parent = banner

	local tweenInfo = TweenInfo.new(1.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(banner, tweenInfo, {
		Position = banner.Position + UDim2.new(0, 0, 0, -30),
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(titleLbl, tweenInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(subLbl, tweenInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(bStroke, tweenInfo, { Transparency = 1 }):Play()

	Debris:AddItem(banner, 1.9)
end

return ShopController
