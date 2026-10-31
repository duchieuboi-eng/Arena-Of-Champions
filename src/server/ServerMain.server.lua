--[[
    ServerMain.server.lua
    Server Entry Point for Arena of Champions.
--]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GrotRigFactory = require(Shared.Modules.GrotRigFactory)

local CharacterHandler = require(ServerScriptService.Handlers.CharacterHandler)
local CombatHandler = require(ServerScriptService.Handlers.CombatHandler)
local DummyHandler = require(ServerScriptService.Handlers.DummyHandler)
local MorphStandHandler = require(ServerScriptService.Handlers.MorphStandHandler)

-- 1. Organize Grot reference models from Workspace into ReplicatedStorage.GrotAssets
GrotRigFactory.InitAssets()

-- 2. Initialize Handlers
CharacterHandler.Init()
CombatHandler.Init()
DummyHandler.Init()
MorphStandHandler.Init()

print("[ArenaOfChampions] Server initialized successfully with Grot & Blocky morphs, 11-stat system, and testing dummy spawner.")
