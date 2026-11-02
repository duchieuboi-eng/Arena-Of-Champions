--[[
    ServerMain.server.lua
    Server Entry Point for Arena of Champions.
--]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

-- Strictly disable Roblox built-in Shift-Lock engine option
StarterPlayer.EnableMouseLockOption = false

local function enforcePlayerSettings(player: Player)
	player.DevEnableMouseLock = false
end

Players.PlayerAdded:Connect(enforcePlayerSettings)
for _, player in ipairs(Players:GetPlayers()) do
	enforcePlayerSettings(player)
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GrotRigFactory = require(Shared.Modules.GrotRigFactory)

local CharacterHandler = require(ServerScriptService.Handlers.CharacterHandler)
local CombatHandler = require(ServerScriptService.Handlers.CombatHandler)
local DummyHandler = require(ServerScriptService.Handlers.DummyHandler)
local MorphStandHandler = require(ServerScriptService.Handlers.MorphStandHandler)
local CMDHandler = require(ServerScriptService.Handlers.CMDHandler)
local LevelHandler = require(ServerScriptService.Handlers.LevelHandler)
local ShopHandler = require(ServerScriptService.Handlers.ShopHandler)

-- 1. Organize Grot reference models from Workspace into ReplicatedStorage.GrotAssets
GrotRigFactory.InitAssets()

-- 2. Initialize Handlers
CharacterHandler.Init()
CombatHandler.Init()
DummyHandler.Init()
MorphStandHandler.Init()
CMDHandler.Init()
LevelHandler.Init()
ShopHandler.Init()

print("[ArenaOfChampions] Server initialized successfully with Grot & Blocky morphs, 11-stat system, and testing dummy spawner.")
