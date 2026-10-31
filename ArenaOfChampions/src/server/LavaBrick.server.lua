--[[
    LavaBrick.server.lua
    Standalone test script for testing health reduction & HUD updates.
    Creates a lava part named "DMGbrick" in Workspace on server start.
--]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local TOUCH_DAMAGE = 15
local TOUCH_DEBOUNCE_TIME = 0.5
local touchDebounces = {}

-- 1. Create or reference DMGbrick in Workspace
local lavaBrick = Workspace:FindFirstChild("DMGbrick") :: Part

if not lavaBrick then
	lavaBrick = Instance.new("Part")
	lavaBrick.Name = "DMGbrick"
	lavaBrick.Size = Vector3.new(12, 1, 12)
	lavaBrick.Position = Vector3.new(0, 0.5, 10) -- Placed right in front of spawn area
	lavaBrick.Anchored = true
	lavaBrick.CanCollide = true
	lavaBrick.Material = Enum.Material.Neon
	lavaBrick.Color = Color3.fromRGB(255, 60, 0) -- Neon lava orange/red
	lavaBrick.Parent = Workspace
end

-- 2. Damage logic on touch
lavaBrick.Touched:Connect(function(hitPart)
	local character = hitPart.Parent
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
	if not humanoid or humanoid.Health <= 0 then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	-- Debounce per player to avoid instant death in 1 frame
	local currentTime = os.clock()
	if touchDebounces[player] and (currentTime - touchDebounces[player]) < TOUCH_DEBOUNCE_TIME then
		return
	end
	touchDebounces[player] = currentTime

	-- Deal damage
	humanoid:TakeDamage(TOUCH_DAMAGE)

	-- Synchronize Health attribute for custom HUD display
	character:SetAttribute("Health", math.max(0, humanoid.Health))
end)

print("[LavaBrick] DMGbrick test script initialized in Workspace.")
