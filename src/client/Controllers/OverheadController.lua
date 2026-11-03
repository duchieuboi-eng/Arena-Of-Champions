--[[
    OverheadController.lua
    Client controller managing Arena of Valor (AoV) style floating overhead name tags:
    - Player/Dummy Name & [ Lv. X ]
    - Current EXP bar
    - HP Bar + Current / Max HP numbers + Lost HP indicator (delayed smooth ghost bar)
    - Stamina Bar + Current / Max Stamina numbers + Lost Stamina indicator (delayed smooth ghost bar)
    - Automatically attaches to all players and testing dummies.
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local OverheadController = {}

local activeOverheads = {}

--[[
    Creates and binds an AoV style overhead tag to a character or dummy model.
--]]
function OverheadController.Attach(character: Model)
	if not character or not character:IsA("Model") then return end
	if activeOverheads[character] then return end

	local humanoid = character:WaitForChild("Humanoid", 4) :: Humanoid?
	if not humanoid then return end

	-- Hide Roblox default humanoid name/health display
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	-- Locate Adornee part (Head, Grot_hitbox, or HumanoidRootPart)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		head = character:FindFirstChild("Grot_hitbox") :: BasePart?
	end
	if not head then
		head = character:FindFirstChild("HumanoidRootPart") :: BasePart? or character.PrimaryPart
	end
	if not head then return end

	-- Disable any legacy overhead gui
	local legacy = head:FindFirstChild("DummyOverheadGui") or character:FindFirstChild("DummyOverheadGui", true)
	if legacy and legacy:IsA("BillboardGui") then
		legacy.Enabled = false
	end
	local existingAoV = head:FindFirstChild("AoVOverheadGui")
	if existingAoV then
		existingAoV:Destroy()
	end

	-- 1. BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "AoVOverheadGui"
	billboard.Size = UDim2.new(0, 195, 0, 52)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.Adornee = head
	billboard.Parent = head

	-- Container
	local rootContainer = Instance.new("Frame")
	rootContainer.Size = UDim2.new(1, 0, 1, 0)
	rootContainer.BackgroundTransparency = 1
	rootContainer.Parent = billboard

	-- =========================================================================
	-- TOP ROW: PLAYER / CHARACTER NAME (Centered above the bar)
	-- =========================================================================
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 16)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.Text = character:GetAttribute("CharacterName") or character.Name
	nameLabel.TextColor3 = Color3.fromRGB(245, 245, 250)
	nameLabel.TextSize = 11
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.Parent = rootContainer

	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = Color3.fromRGB(0, 0, 0)
	nameStroke.Thickness = 1.2
	nameStroke.Parent = nameLabel

	-- =========================================================================
	-- LEFT SIDE: LEVEL BADGE & THIN EXP PROGRESS BAR
	-- =========================================================================
	local levelBadgeFrame = Instance.new("Frame")
	levelBadgeFrame.Name = "LevelBadgeFrame"
	levelBadgeFrame.Size = UDim2.new(0, 36, 0, 27)
	levelBadgeFrame.Position = UDim2.new(0, 0, 0, 18)
	levelBadgeFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	levelBadgeFrame.BorderSizePixel = 0
	levelBadgeFrame.Parent = rootContainer

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 4)
	badgeCorner.Parent = levelBadgeFrame

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Color3.fromRGB(255, 215, 0)
	badgeStroke.Thickness = 1.2
	badgeStroke.Parent = levelBadgeFrame

	local levelBadge = Instance.new("TextLabel")
	levelBadge.Name = "LevelBadge"
	levelBadge.Size = UDim2.new(1, 0, 1, -4)
	levelBadge.Position = UDim2.new(0, 0, 0, 0)
	levelBadge.BackgroundTransparency = 1
	levelBadge.Font = Enum.Font.GothamBlack
	levelBadge.Text = "Lv." .. tostring(character:GetAttribute("Level") or 1)
	levelBadge.TextColor3 = Color3.fromRGB(255, 215, 0)
	levelBadge.TextSize = 10
	levelBadge.TextXAlignment = Enum.TextXAlignment.Center
	levelBadge.Parent = levelBadgeFrame

	local lvlStroke = Instance.new("UIStroke")
	lvlStroke.Color = Color3.fromRGB(0, 0, 0)
	lvlStroke.Thickness = 1.2
	lvlStroke.Parent = levelBadge

	-- Thin EXP Progress Bar attached at bottom of the Level Badge
	local expBg = Instance.new("Frame")
	expBg.Name = "EXPBackground"
	expBg.Size = UDim2.new(1, -4, 0, 3)
	expBg.Position = UDim2.new(0, 2, 1, -4)
	expBg.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	expBg.BorderSizePixel = 0
	expBg.ClipsDescendants = true
	expBg.Parent = levelBadgeFrame

	local expCorner = Instance.new("UICorner")
	expCorner.CornerRadius = UDim.new(0, 2)
	expCorner.Parent = expBg

	local expFill = Instance.new("Frame")
	expFill.Name = "EXPFill"
	expFill.Size = UDim2.new(0, 0, 1, 0)
	expFill.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
	expFill.BorderSizePixel = 0
	expFill.Parent = expBg

	local efCorner = Instance.new("UICorner")
	efCorner.CornerRadius = UDim.new(0, 2)
	efCorner.Parent = expFill

	-- =========================================================================
	-- RIGHT SIDE: HP BAR + LOST HP INDICATOR & STAMINA BAR + LOST STAMINA
	-- =========================================================================
	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBackground"
	hpBg.Size = UDim2.new(1, -42, 0, 16)
	hpBg.Position = UDim2.new(0, 42, 0, 18)
	hpBg.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
	hpBg.BorderSizePixel = 0
	hpBg.ClipsDescendants = true
	hpBg.Parent = rootContainer

	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 3)
	hpCorner.Parent = hpBg

	local hpStroke = Instance.new("UIStroke")
	hpStroke.Color = Color3.fromRGB(45, 50, 65)
	hpStroke.Thickness = 1
	hpStroke.Parent = hpBg

	-- Lost HP Ghost Bar (Trails behind active HP fill)
	local hpGhostBar = Instance.new("Frame")
	hpGhostBar.Name = "HPGhostBar"
	hpGhostBar.Size = UDim2.new(1, 0, 1, 0)
	hpGhostBar.BackgroundColor3 = Color3.fromRGB(235, 87, 87)
	hpGhostBar.BorderSizePixel = 0
	hpGhostBar.ZIndex = 1
	hpGhostBar.Parent = hpBg

	local ghostCorner = Instance.new("UICorner")
	ghostCorner.CornerRadius = UDim.new(0, 3)
	ghostCorner.Parent = hpGhostBar

	-- Active Green HP Fill
	local hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	hpFill.BorderSizePixel = 0
	hpFill.ZIndex = 2
	hpFill.Parent = hpBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = hpFill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.new(1, 0, 1, 0)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.GothamBold
	hpText.Text = "100 / 100"
	hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hpText.TextSize = 9
	hpText.ZIndex = 3
	hpText.Parent = hpBg

	local hTextStroke = Instance.new("UIStroke")
	hTextStroke.Color = Color3.fromRGB(0, 0, 0)
	hTextStroke.Thickness = 1
	hTextStroke.Parent = hpText

	-- STAMINA BAR + LOST STAMINA INDICATOR
	local staminaBg = Instance.new("Frame")
	staminaBg.Name = "StaminaBackground"
	staminaBg.Size = UDim2.new(1, -42, 0, 8)
	staminaBg.Position = UDim2.new(0, 42, 0, 37)
	staminaBg.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
	staminaBg.BorderSizePixel = 0
	staminaBg.ClipsDescendants = true
	staminaBg.Parent = rootContainer

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 2)
	sCorner.Parent = staminaBg

	local sStroke = Instance.new("UIStroke")
	sStroke.Color = Color3.fromRGB(40, 50, 70)
	sStroke.Thickness = 1
	sStroke.Parent = staminaBg

	-- Lost Stamina Ghost Bar
	local staminaGhostBar = Instance.new("Frame")
	staminaGhostBar.Name = "StaminaGhostBar"
	staminaGhostBar.Size = UDim2.new(1, 0, 1, 0)
	staminaGhostBar.BackgroundColor3 = Color3.fromRGB(140, 210, 255)
	staminaGhostBar.BorderSizePixel = 0
	staminaGhostBar.ZIndex = 1
	staminaGhostBar.Parent = staminaBg

	local sgCorner = Instance.new("UICorner")
	sgCorner.CornerRadius = UDim.new(0, 2)
	sgCorner.Parent = staminaGhostBar

	-- Active Cyan Stamina Fill
	local staminaFill = Instance.new("Frame")
	staminaFill.Name = "StaminaFill"
	staminaFill.Size = UDim2.new(1, 0, 1, 0)
	staminaFill.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
	staminaFill.BorderSizePixel = 0
	staminaFill.ZIndex = 2
	staminaFill.Parent = staminaBg

	local sfCorner = Instance.new("UICorner")
	sfCorner.CornerRadius = UDim.new(0, 2)
	sfCorner.Parent = staminaFill

	local staminaText = Instance.new("TextLabel")
	staminaText.Name = "StaminaText"
	staminaText.Size = UDim2.new(1, 0, 1, 0)
	staminaText.BackgroundTransparency = 1
	staminaText.Font = Enum.Font.GothamBold
	staminaText.Text = "100 / 100"
	staminaText.TextColor3 = Color3.fromRGB(240, 245, 255)
	staminaText.TextSize = 7
	staminaText.ZIndex = 3
	staminaText.Parent = staminaBg

	local sTextStroke = Instance.new("UIStroke")
	sTextStroke.Color = Color3.fromRGB(0, 0, 0)
	sTextStroke.Thickness = 0.8
	sTextStroke.Parent = staminaText

	-- =========================================================================
	-- DYNAMIC UPDATES & LOST INDICATOR SMOOTH TWEENS
	-- =========================================================================
	local lastHpRatio = 1.0
	local ghostHpTween: Tween? = nil
	local ghostHpDelayThread: thread? = nil

	local function updateHealth(isInstant: boolean?)
		local hp = character:GetAttribute("Health") or humanoid.Health
		local maxHp = character:GetAttribute("MaxHealth") or humanoid.MaxHealth
		if maxHp <= 0 then maxHp = 100 end
		local newRatio = math.clamp(hp / maxHp, 0, 1)

		hpText.Text = string.format("%d / %d", math.ceil(hp), math.ceil(maxHp))

		-- Color modulation
		if newRatio > 0.5 then
			hpFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
		elseif newRatio > 0.25 then
			hpFill.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
		else
			hpFill.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
		end

		if isInstant then
			hpFill.Size = UDim2.new(newRatio, 0, 1, 0)
			hpGhostBar.Size = UDim2.new(newRatio, 0, 1, 0)
			lastHpRatio = newRatio
			return
		end

		-- Active HP bar tweens fast (0.12s)
		TweenService:Create(hpFill, TweenInfo.new(0.12, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Size = UDim2.new(newRatio, 0, 1, 0)
		}):Play()

		if newRatio < lastHpRatio then
			-- DAMAGE TAKEN: Lost HP ghost bar stays behind for 0.3s, then smoothly slides down!
			if ghostHpDelayThread then
				task.cancel(ghostHpDelayThread)
				ghostHpDelayThread = nil
			end
			if ghostHpTween then
				ghostHpTween:Cancel()
				ghostHpTween = nil
			end

			ghostHpDelayThread = task.delay(0.30, function()
				if hpGhostBar and hpGhostBar.Parent then
					ghostHpTween = TweenService:Create(hpGhostBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.new(newRatio, 0, 1, 0)
					})
					ghostHpTween:Play()
				end
			end)
		else
			-- HEALED: Ghost bar matches active fill immediately
			if ghostHpDelayThread then
				task.cancel(ghostHpDelayThread)
				ghostHpDelayThread = nil
			end
			TweenService:Create(hpGhostBar, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
				Size = UDim2.new(newRatio, 0, 1, 0)
			}):Play()
		end

		lastHpRatio = newRatio
	end

	local lastStaminaRatio = 1.0
	local ghostStaminaDelayThread: thread? = nil

	local function updateStamina(isInstant: boolean?)
		local st = character:GetAttribute("Stamina") or 100
		local maxSt = character:GetAttribute("MaxStamina") or 100
		if maxSt <= 0 then maxSt = 100 end
		local newRatio = math.clamp(st / maxSt, 0, 1)

		staminaText.Text = string.format("%d / %d", math.ceil(st), math.ceil(maxSt))

		if isInstant then
			staminaFill.Size = UDim2.new(newRatio, 0, 1, 0)
			staminaGhostBar.Size = UDim2.new(newRatio, 0, 1, 0)
			lastStaminaRatio = newRatio
			return
		end

		TweenService:Create(staminaFill, TweenInfo.new(0.12, Enum.EasingStyle.Cubic), {
			Size = UDim2.new(newRatio, 0, 1, 0)
		}):Play()

		if newRatio < lastStaminaRatio then
			-- Lost Stamina indicator delay
			if ghostStaminaDelayThread then
				task.cancel(ghostStaminaDelayThread)
				ghostStaminaDelayThread = nil
			end
			ghostStaminaDelayThread = task.delay(0.25, function()
				if staminaGhostBar and staminaGhostBar.Parent then
					TweenService:Create(staminaGhostBar, TweenInfo.new(0.30, Enum.EasingStyle.Quad), {
						Size = UDim2.new(newRatio, 0, 1, 0)
					}):Play()
				end
			end)
		else
			TweenService:Create(staminaGhostBar, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
				Size = UDim2.new(newRatio, 0, 1, 0)
			}):Play()
		end

		lastStaminaRatio = newRatio
	end

	local function updateLevelAndExp()
		local lvl = character:GetAttribute("Level") or 1
		local exp = character:GetAttribute("EXP") or 0
		local reqExp = character:GetAttribute("NextLevelEXP") or (lvl * 100 + lvl)

		levelBadge.Text = "[ Lv. " .. tostring(lvl) .. " ]"

		local ratio = 1.0
		if lvl < 10 and reqExp > 0 then
			ratio = math.clamp(exp / reqExp, 0, 1)
		end

		TweenService:Create(expFill, TweenInfo.new(0.25, Enum.EasingStyle.Cubic), {
			Size = UDim2.new(ratio, 0, 1, 0)
		}):Play()
	end

	local function updateName()
		nameLabel.Text = character:GetAttribute("CharacterName") or character.Name
	end

	-- Initial setup
	updateHealth(true)
	updateStamina(true)
	updateLevelAndExp()
	updateName()

	-- Connect attribute listeners
	character:GetAttributeChangedSignal("Health"):Connect(function() updateHealth(false) end)
	character:GetAttributeChangedSignal("MaxHealth"):Connect(function() updateHealth(false) end)
	humanoid.HealthChanged:Connect(function() updateHealth(false) end)

	character:GetAttributeChangedSignal("Stamina"):Connect(function() updateStamina(false) end)
	character:GetAttributeChangedSignal("MaxStamina"):Connect(function() updateStamina(false) end)

	character:GetAttributeChangedSignal("Level"):Connect(updateLevelAndExp)
	character:GetAttributeChangedSignal("EXP"):Connect(updateLevelAndExp)
	character:GetAttributeChangedSignal("NextLevelEXP"):Connect(updateLevelAndExp)
	character:GetAttributeChangedSignal("CharacterName"):Connect(updateName)

	activeOverheads[character] = billboard
end

function OverheadController.Init()
	-- 1. Attach to existing players and characters
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.defer(function()
				OverheadController.Attach(player.Character)
			end)
		end
		player.CharacterAdded:Connect(function(char)
			task.defer(function()
				OverheadController.Attach(char)
			end)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			task.defer(function()
				OverheadController.Attach(char)
			end)
		end)
	end)

	-- 2. Attach to existing testing dummies in Workspace
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Model") and (child:GetAttribute("IsTestingDummy") or string.find(child.Name, "Dummy")) then
			task.defer(function()
				OverheadController.Attach(child)
			end)
		end
	end

	-- 3. Attach to new dummies spawned in Workspace
	Workspace.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.defer(function()
				if child:GetAttribute("IsTestingDummy") or string.find(child.Name, "Dummy") then
					OverheadController.Attach(child)
				end
			end)
		end
	end)
end

return OverheadController
