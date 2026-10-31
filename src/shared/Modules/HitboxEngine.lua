--[[
    HitboxEngine.lua
    Universal spatial query hitbox generator.
    Guarantees server-authoritative hit detection and strictly prevents self-damage.
--]]

local Workspace = game:GetService("Workspace")

local HitboxEngine = {}

--[[
    Helper to find the root character Model with a Humanoid from any descendant part.
--]]
local function getCharacterFromPart(part: BasePart): Model?
	local current = part.Parent
	while current and current ~= Workspace do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			return current
		end
		current = current.Parent
	end
	return nil
end

--[[
    Spatial query using GetPartBoundsInBox.
    Strictly excludes the attackerModel to prevent self-hit.
--]]
function HitboxEngine.GetTargetsInBox(attackerModel: Model, cframe: CFrame, size: Vector3): {Model}
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { attackerModel }
	overlapParams.MaxParts = 80

	local partsInBox = Workspace:GetPartBoundsInBox(cframe, size, overlapParams)
	local hitCharacters = {}
	local hitSet = {}

	for _, part in ipairs(partsInBox) do
		local character = getCharacterFromPart(part)
		if character and character ~= attackerModel and not character:IsDescendantOf(attackerModel) then
			if not hitSet[character] then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					hitSet[character] = true
					table.insert(hitCharacters, character)
				end
			end
		end
	end

	return hitCharacters
end

--[[
    Spatial query using GetPartsInPart.
    Strictly excludes the attackerModel to prevent self-hit.
--]]
function HitboxEngine.GetTargetsInPart(attackerModel: Model, part: BasePart): {Model}
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { attackerModel }
	overlapParams.MaxParts = 80

	local partsInBox = Workspace:GetPartsInPart(part, overlapParams)
	local hitCharacters = {}
	local hitSet = {}

	for _, p in ipairs(partsInBox) do
		local character = getCharacterFromPart(p)
		if character and character ~= attackerModel and not character:IsDescendantOf(attackerModel) then
			if not hitSet[character] then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					hitSet[character] = true
					table.insert(hitCharacters, character)
				end
			end
		end
	end

	return hitCharacters
end

return HitboxEngine
