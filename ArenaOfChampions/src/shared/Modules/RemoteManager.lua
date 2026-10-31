--[[
    RemoteManager.lua
    Ensures network RemoteEvents exist in ReplicatedStorage for Client-Server communication.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteManager = {}
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")

if not RemotesFolder then
	if RunService:IsServer() then
		RemotesFolder = Instance.new("Folder")
		RemotesFolder.Name = "Remotes"
		RemotesFolder.Parent = ReplicatedStorage
	else
		RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
	end
end

function RemoteManager.GetRemoteEvent(name: string): RemoteEvent
	local remote = RemotesFolder:FindFirstChild(name)
	if not remote and RunService:IsServer() then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = RemotesFolder
	elseif not remote then
		remote = RemotesFolder:WaitForChild(name, 10) :: RemoteEvent
	end
	return remote
end

return RemoteManager
