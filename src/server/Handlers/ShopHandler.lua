--[[
    ShopHandler.lua
    Manages Player Gold Economy, 3-slot Tier I Item Shop, buying/selling,
    and awarding +100 Gold & +100 EXP on dummy kills.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared.Configs.EconomyConfig)
local RemoteManager = require(Shared.Modules.RemoteManager)
local LevelHandler = require(script.Parent.LevelHandler)

local ShopHandler = {}

local buyItemRemote = RemoteManager.GetRemoteEvent("Shop_BuyItem")
local sellItemRemote = RemoteManager.GetRemoteEvent("Shop_SellItem")
local rewardPopupRemote = RemoteManager.GetRemoteEvent("RewardPopupNotification")

function ShopHandler.Init()
	Players.PlayerAdded:Connect(ShopHandler.OnPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		ShopHandler.OnPlayerAdded(player)
	end

	-- Buy Item Request
	buyItemRemote.OnServerEvent:Connect(function(player: Player, itemId: string)
		ShopHandler.HandleBuyItem(player, itemId)
	end)

	-- Sell Item Request
	sellItemRemote.OnServerEvent:Connect(function(player: Player, slotIndex: number)
		ShopHandler.HandleSellItem(player, slotIndex)
	end)
end

function ShopHandler.OnPlayerAdded(player: Player)
	if not player:GetAttribute("Gold") then
		player:SetAttribute("Gold", 0)
	end
	for i = 1, EconomyConfig.MaxInventorySlots do
		if not player:GetAttribute("ItemSlot" .. tostring(i)) then
			player:SetAttribute("ItemSlot" .. tostring(i), "")
		end
	end

	player.CharacterAdded:Connect(function(character)
		ShopHandler.SyncToCharacter(player, character)
	end)
	player:GetPropertyChangedSignal("Character"):Connect(function()
		if player.Character then
			ShopHandler.SyncToCharacter(player, player.Character)
		end
	end)

	if player.Character then
		ShopHandler.SyncToCharacter(player, player.Character)
	end
end

--[[
    Applies equipped item stat bonuses to new character when morphing or respawning.
--]]
function ShopHandler.SyncToCharacter(player: Player, character: Model)
	local gold = player:GetAttribute("Gold") or 0
	character:SetAttribute("Gold", gold)

	for i = 1, EconomyConfig.MaxInventorySlots do
		local itemId = player:GetAttribute("ItemSlot" .. tostring(i))
		character:SetAttribute("ItemSlot" .. tostring(i), itemId or "")

		if itemId and itemId ~= "" and EconomyConfig.Items[itemId] then
			local item = EconomyConfig.Items[itemId]
			for statKey, bonus in pairs(item.Stats) do
				local cur = character:GetAttribute(statKey) or 0
				character:SetAttribute(statKey, cur + bonus)
			end
		end
	end
end

function ShopHandler.HandleBuyItem(player: Player, itemId: string)
	local item = EconomyConfig.Items[itemId]
	if not item then return end

	local currentGold = player:GetAttribute("Gold") or 0
	if currentGold < item.Cost then
		return
	end

	-- Find first free slot (1..3)
	local targetSlot = nil
	for i = 1, EconomyConfig.MaxInventorySlots do
		local slotVal = player:GetAttribute("ItemSlot" .. tostring(i))
		if not slotVal or slotVal == "" then
			targetSlot = i
			break
		end
	end

	if not targetSlot then
		return -- Inventory full
	end

	-- Deduct Gold & equip item
	player:SetAttribute("Gold", currentGold - item.Cost)
	player:SetAttribute("ItemSlot" .. tostring(targetSlot), itemId)

	local character = player.Character
	if character then
		character:SetAttribute("Gold", player:GetAttribute("Gold"))
		character:SetAttribute("ItemSlot" .. tostring(targetSlot), itemId)

		-- Apply live stat bonuses
		for statKey, bonus in pairs(item.Stats) do
			local cur = character:GetAttribute(statKey) or 0
			character:SetAttribute(statKey, cur + bonus)
		end
	end
end

function ShopHandler.HandleSellItem(player: Player, slotIndex: number)
	if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > EconomyConfig.MaxInventorySlots then
		return
	end

	local slotKey = "ItemSlot" .. tostring(slotIndex)
	local itemId = player:GetAttribute(slotKey)
	if not itemId or itemId == "" then return end

	local item = EconomyConfig.Items[itemId]
	if not item then return end

	local currentGold = player:GetAttribute("Gold") or 0
	player:SetAttribute("Gold", currentGold + item.SellPrice)
	player:SetAttribute(slotKey, "")

	local character = player.Character
	if character then
		character:SetAttribute("Gold", player:GetAttribute("Gold"))
		character:SetAttribute(slotKey, "")

		-- Deduct live stat bonuses
		for statKey, bonus in pairs(item.Stats) do
			local cur = character:GetAttribute(statKey) or 0
			character:SetAttribute(statKey, math.max(0, cur - bonus))
		end
	end
end

--[[
    Awards +100 Gold and +100 EXP when defeating any dummy.
--]]
function ShopHandler.AwardDummyKill(player: Player, dummyModel: Model)
	if not player or not player.Parent then return end

	local goldReward = EconomyConfig.DummyRewards.Gold or 100
	local expReward = EconomyConfig.DummyRewards.EXP or 100

	local curGold = player:GetAttribute("Gold") or 0
	player:SetAttribute("Gold", curGold + goldReward)

	if player.Character then
		player.Character:SetAttribute("Gold", curGold + goldReward)
	end

	LevelHandler.AddExp(player, expReward)

	-- Fire floating reward notification
	rewardPopupRemote:FireClient(player, goldReward, expReward)
end

return ShopHandler
