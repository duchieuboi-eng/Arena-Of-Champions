--[[
    GrotRigFactory.lua
    Manages Grot reference models, asset organization in ReplicatedStorage,
    bounding-box-centered limb rigging with zero floating/stretching,
    forward orientation calibration, HipHeight floor leveling, and M1 hitbox offset calculation.
--]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared.Configs.CharacterConfig)
local RemoteManager = require(Shared.Modules.RemoteManager)

local GrotRigFactory = {}

local LIMB_NAMES = {
	"Brown arm",
	"Brown leg",
	"Head",
	"Orange arm",
	"Orange leg",
	"Torso",
}

local ASSET_NAMES = {
	-- Base & Movement
	"Grot_model",
	"Grot_walk1",
	"Grot_walk2",
	"Grot_sprint1",
	"Grot_sprint2",
	"Grot_walk",
	"Grot_sprint",

	-- M1 Frames & Hitboxes
	"Grot_M1frame1",
	"Grot_M1frame2",
	"Grot_M1frame3",
	"Grot_M1hitbox",
	"Grot_M1interhitbox",

	-- Skill 1 ("Vine") Frames, Visuals & Hitboxes
	"Grot_S1frame1",
	"Grot_S1frame2",
	"Grot_S1frame3",
	"Grot_S1frame4",
	"Grot_S1frame5",
	"Skill area",
	"Grot_S1hitbox",
	"Grot_S1interhitbox",
}

-- Cached extracted poses and hitbox offsets
local cachedPoses = {}
local cachedHitboxData = nil
local cachedS1HitboxData = nil

--[[
    Ensures Grot reference models are retrieved from Workspace on startup
    (checking Workspace.Grot first, then Workspace root) and moved/organized
    into ReplicatedStorage.GrotAssets so they don't litter the map floor.
--]]
function GrotRigFactory.InitAssets(): Folder
	local grotFolder = ReplicatedStorage:FindFirstChild("GrotAssets")
	if not grotFolder then
		grotFolder = Instance.new("Folder")
		grotFolder.Name = "GrotAssets"
		grotFolder.Parent = ReplicatedStorage
	end

	-- 1. Check if assets are grouped inside Workspace.Grot
	local workspaceGrotGroup = Workspace:FindFirstChild("Grot")
	if workspaceGrotGroup then
		for _, child in ipairs(workspaceGrotGroup:GetChildren()) do
			child.Parent = grotFolder
		end
	end

	-- 2. Also check loose assets in Workspace root for backwards compatibility
	for _, assetName in ipairs(ASSET_NAMES) do
		local inWorkspace = Workspace:FindFirstChild(assetName)
		if inWorkspace then
			inWorkspace.Parent = grotFolder
		end
	end

	GrotRigFactory.ExtractAllPoses()
	GrotRigFactory.ExtractHitboxData()
	GrotRigFactory.ExtractS1HitboxData()

	return grotFolder
end

--[[
    Computes a limb's true geometric center CFrame using GetBoundingBox().
    Guarantees consistent, deterministic center alignment across all reference poses.
--]]
local function getLimbBoundingBox(limb: Instance): (CFrame, Vector3)
	if limb:IsA("Model") then
		return limb:GetBoundingBox()
	elseif limb:IsA("BasePart") then
		return limb.CFrame, limb.Size
	end
	return CFrame.identity, Vector3.one
end

local function getInstanceCFrame(inst: Instance): CFrame
	if inst:IsA("BasePart") then
		return inst.CFrame
	elseif inst:IsA("Model") then
		return (select(1, inst:GetBoundingBox()))
	end
	return CFrame.identity
end

local function getInstanceSize(inst: Instance): Vector3
	if inst:IsA("BasePart") then
		return inst.Size
	elseif inst:IsA("Model") then
		local _, size = inst:GetBoundingBox()
		return size
	end
	return Vector3.new(4, 5, 5)
end

--[[
    Extracts the relative CFrame offsets of the 6 body parts relative to Grot_hitbox
    using true bounding box centers. Guarantees 0 floating or stretching.
--]]
function GrotRigFactory.ExtractPoseFromModel(model: Instance): { [string]: CFrame }
	local pose = {}
	if not model then return pose end

	local rootPart = model:FindFirstChild("Grot_hitbox", true) :: BasePart?
	if not rootPart then
		rootPart = model:FindFirstChild("HumanoidRootPart", true) or model.PrimaryPart
	end

	local rootCFrame = rootPart and rootPart.CFrame or model:GetPivot()

	for _, limbName in ipairs(LIMB_NAMES) do
		local limb = model:FindFirstChild(limbName, true)
		if limb then
			local limbCF = getLimbBoundingBox(limb)
			pose[limbName] = rootCFrame:ToObjectSpace(limbCF)
		else
			pose[limbName] = CFrame.identity
		end
	end

	return pose
end

--[[
    Extracts and caches all movement, M1, and Skill 1 ("Vine") animation poses.
--]]
function GrotRigFactory.ExtractAllPoses()
	local folder = ReplicatedStorage:FindFirstChild("GrotAssets") or Workspace

	local modelRefs = {
		Idle = folder:FindFirstChild("Grot_model"),
		Walk = folder:FindFirstChild("Grot_walk1") or folder:FindFirstChild("Grot_walk"),
		Walk1 = folder:FindFirstChild("Grot_walk1") or folder:FindFirstChild("Grot_walk"),
		Walk2 = folder:FindFirstChild("Grot_walk2") or folder:FindFirstChild("Grot_walk"),
		Sprint = folder:FindFirstChild("Grot_sprint1") or folder:FindFirstChild("Grot_sprint"),
		Sprint1 = folder:FindFirstChild("Grot_sprint1") or folder:FindFirstChild("Grot_sprint"),
		Sprint2 = folder:FindFirstChild("Grot_sprint2") or folder:FindFirstChild("Grot_sprint"),
		M1Frame1 = folder:FindFirstChild("Grot_M1frame1"),
		M1Frame2 = folder:FindFirstChild("Grot_M1frame2"),
		M1Frame3 = folder:FindFirstChild("Grot_M1frame3"),
		S1Frame1 = folder:FindFirstChild("Grot_S1frame1"),
		S1Frame2 = folder:FindFirstChild("Grot_S1frame2"),
		S1Frame3 = folder:FindFirstChild("Grot_S1frame3"),
		S1Frame4 = folder:FindFirstChild("Grot_S1frame4"),
		S1Frame5 = folder:FindFirstChild("Grot_S1frame5"),
	}

	for poseName, refModel in pairs(modelRefs) do
		if refModel then
			cachedPoses[poseName] = GrotRigFactory.ExtractPoseFromModel(refModel)
		end
	end

	return cachedPoses
end

function GrotRigFactory.GetCachedPoses()
	if not next(cachedPoses) then
		GrotRigFactory.ExtractAllPoses()
	end
	return cachedPoses
end

--[[
    Calculates the relative offset and size between Grot_M1interhitbox and Grot_M1hitbox.
    Strictly forces the Z offset to negative local space (-math.abs) so the attack
    ALWAYS spawns directly in front of the character along HumanoidRootPart.LookVector.
--]]
function GrotRigFactory.ExtractHitboxData(): { Offset: CFrame, Size: Vector3 }
	if cachedHitboxData then return cachedHitboxData end

	local folder = ReplicatedStorage:FindFirstChild("GrotAssets") or Workspace
	local interhitbox = folder:FindFirstChild("Grot_M1interhitbox")
	local hitbox = folder:FindFirstChild("Grot_M1hitbox")

	local offset = CFrame.new(0, 0, -4.5)
	local size = Vector3.new(5, 5, 5)

	if interhitbox and hitbox then
		local centerCFrame = getInstanceCFrame(interhitbox)
		local attackCFrame = getInstanceCFrame(hitbox)
		local rawOffset = centerCFrame:ToObjectSpace(attackCFrame)
		size = getInstanceSize(hitbox)

		-- Ensure forward offset along LookVector is strictly negative Z (in front of character)
		local forwardDist = math.abs(rawOffset.Z)
		if forwardDist < 3.5 then
			forwardDist = 4.5
		end
		offset = CFrame.new(rawOffset.X, rawOffset.Y, -forwardDist)
	end

	cachedHitboxData = {
		Offset = offset,
		Size = size,
	}
	return cachedHitboxData
end

--[[
    Calculates the relative offset and size between Grot_S1interhitbox and Grot_S1hitbox.
    Used for Skill 1 ("Vine") line area in front of Grot.
--]]
function GrotRigFactory.ExtractS1HitboxData(): { Offset: CFrame, Size: Vector3 }
	if cachedS1HitboxData then return cachedS1HitboxData end

	local folder = ReplicatedStorage:FindFirstChild("GrotAssets") or Workspace
	local interhitbox = folder:FindFirstChild("Grot_S1interhitbox")
	local hitbox = folder:FindFirstChild("Grot_S1hitbox")

	local offset = CFrame.new(0, 0, -8.0)
	local size = Vector3.new(6, 6, 16)

	if interhitbox and hitbox then
		local centerCFrame = getInstanceCFrame(interhitbox)
		local attackCFrame = getInstanceCFrame(hitbox)
		local rawOffset = centerCFrame:ToObjectSpace(attackCFrame)
		size = getInstanceSize(hitbox)

		-- Ensure forward offset along LookVector is strictly negative Z
		local forwardDist = math.abs(rawOffset.Z)
		if forwardDist < 4.0 then
			forwardDist = 8.0
		end
		offset = CFrame.new(rawOffset.X, rawOffset.Y, -forwardDist)
	end

	cachedS1HitboxData = {
		Offset = offset,
		Size = size,
	}
	return cachedS1HitboxData
end

-- Cached frame-specific Skill area part offset tables
local cachedSkillAreaFrames = {}

--[[
    Extracts the REAL "Skill area" model data inside Grot_S1frame1..5 (or Grot["Skill area"]).
    Computes exact relative CFrames for all BasePart descendants relative to frame Grot_hitbox.
--]]
function GrotRigFactory.ExtractSkillAreaFrameData(frameIndex: number)
	if cachedSkillAreaFrames[frameIndex] then
		return cachedSkillAreaFrames[frameIndex]
	end

	local folder = ReplicatedStorage:FindFirstChild("GrotAssets") or Workspace:FindFirstChild("Grot") or Workspace
	local frameModel = folder:FindFirstChild("Grot_S1frame" .. tostring(frameIndex))
	if not frameModel then
		local wsGrot = Workspace:FindFirstChild("Grot")
		if wsGrot then
			frameModel = wsGrot:FindFirstChild("Grot_S1frame" .. tostring(frameIndex))
		end
	end

	local skillAreaModel = frameModel and frameModel:FindFirstChild("Skill area", true)
	if not skillAreaModel then
		skillAreaModel = folder:FindFirstChild("Skill area")
		if not skillAreaModel then
			local wsGrot = Workspace:FindFirstChild("Grot")
			if wsGrot then
				skillAreaModel = wsGrot:FindFirstChild("Skill area")
			end
		end
	end

	if not skillAreaModel then
		return nil
	end

	local frameGrotHitbox = frameModel and frameModel:FindFirstChild("Grot_hitbox", true) :: BasePart?
	if not frameGrotHitbox then
		frameGrotHitbox = frameModel and frameModel:FindFirstChild("HumanoidRootPart", true) :: BasePart?
	end
	local refCFrame = frameGrotHitbox and frameGrotHitbox.CFrame or skillAreaModel:GetPivot()

	local partsData = {}
	for _, desc in ipairs(skillAreaModel:GetDescendants()) do
		if desc:IsA("BasePart") then
			local relCF = refCFrame:ToObjectSpace(desc.CFrame)
			table.insert(partsData, {
				Name = desc.Name,
				Template = desc,
				RelCFrame = relCF,
				Size = desc.Size,
				Color = desc.Color,
				Material = desc.Material,
				Transparency = desc.Transparency,
			})
		end
	end

	cachedSkillAreaFrames[frameIndex] = {
		Model = skillAreaModel,
		PartsData = partsData,
		RefCFrame = refCFrame,
	}
	return cachedSkillAreaFrames[frameIndex]
end

--[[
    Spawns the REAL "Skill area" model for a specific frame (1..5),
    positioning each BasePart descendant in front of Grot along HumanoidRootPart.LookVector.
    Returns the spawned Model and a table of part relative offsets for live spin/aim tracking.
--]]
function GrotRigFactory.SpawnSkillAreaForFrame(frameIndex: number, character: Model): (Model?, { [BasePart]: CFrame }?)
	local frameData = GrotRigFactory.ExtractSkillAreaFrameData(frameIndex)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local grotHitbox = character:FindFirstChild("Grot_hitbox") :: BasePart? or hrp
	if not hrp or not grotHitbox then return nil, nil end

	if not frameData or not frameData.Model or #frameData.PartsData == 0 then
		-- Fallback to cloning standalone Skill area if frame model wasn't populated
		local folder = ReplicatedStorage:FindFirstChild("GrotAssets") or Workspace:FindFirstChild("Grot") or Workspace
		local fallbackModel = folder:FindFirstChild("Skill area")
		if fallbackModel and fallbackModel:IsA("Model") then
			local clone = fallbackModel:Clone()
			clone.Name = "SkillArea_Frame" .. tostring(frameIndex)
			local partOffsets = {}
			local refCF = fallbackModel:GetPivot()
			for _, p in ipairs(clone:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CanCollide = false
					p.CanTouch = false
					p.CanQuery = false
					local rel = refCF:ToObjectSpace(p.CFrame)
					-- Account for Grot facing
					local forwardRel = CFrame.new(rel.X, rel.Y, -math.abs(rel.Z))
					partOffsets[p] = forwardRel
					p.CFrame = hrp.CFrame * forwardRel
				end
			end
			clone.Parent = Workspace
			return clone, partOffsets
		end
		return nil, nil
	end

	local clone = frameData.Model:Clone()
	clone.Name = "SkillArea_Frame" .. tostring(frameIndex)

	-- Check forward orientation: ensure visual extends in front of HumanoidRootPart.LookVector
	local needsFlip = false
	if #frameData.PartsData > 0 then
		local sampleRel = frameData.PartsData[1].RelCFrame
		local samplePos = (grotHitbox.CFrame * sampleRel).Position
		if (samplePos - hrp.Position):Dot(hrp.CFrame.LookVector) < 0 then
			needsFlip = true
		end
	end

	local partOffsets = {}
	for _, partInfo in ipairs(frameData.PartsData) do
		local partInstance = clone:FindFirstChild(partInfo.Name, true) :: BasePart?
		if partInstance and partInstance:IsA("BasePart") then
			partInstance.Anchored = true
			partInstance.CanCollide = false
			partInstance.CanTouch = false
			partInstance.CanQuery = false

			local finalRel = partInfo.RelCFrame
			if needsFlip then
				finalRel = CFrame.Angles(0, math.pi, 0) * finalRel
			end
			partOffsets[partInstance] = finalRel
			partInstance.CFrame = grotHitbox.CFrame * finalRel
		end
	end

	clone.Parent = Workspace
	return clone, partOffsets
end

--[[
    Creates or retrieves the Skill area vine visual for Grot's S1 skill.
    Can extract frame-specific visual stage from Grot_S1frameX or base "Skill area".
--]]
function GrotRigFactory.CreateSkillAreaVisual(frameIndex: number?): Instance
	local folder = ReplicatedStorage:FindFirstChild("GrotAssets") or Workspace:FindFirstChild("Grot") or Workspace

	local targetVisual: Instance? = nil
	if frameIndex then
		local frameModel = folder:FindFirstChild("Grot_S1frame" .. tostring(frameIndex))
		if frameModel then
			targetVisual = frameModel:FindFirstChild("Skill area", true)
		end
	end

	if not targetVisual then
		targetVisual = folder:FindFirstChild("Skill area")
	end

	if targetVisual then
		local clone = targetVisual:Clone()
		clone.Name = "SkillAreaVisual"
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			end
		end
		if clone:IsA("BasePart") then
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanTouch = false
			clone.CanQuery = false
		end
		return clone
	end

	return Instance.new("Model")
end

--[[
    Creates a fully functional, rigged Grot character Model using bounding-box proxy parts
    and calibrated HumanoidRootPart orientation/HipHeight.
--]]
function GrotRigFactory.CreateGrotModel(): Model
	local config = CharacterConfig.Grot
	local poses = GrotRigFactory.GetCachedPoses()
	local idlePose = poses.Idle or {}

	local folder = ReplicatedStorage:FindFirstChild("GrotAssets") or Workspace
	local baseModel = folder:FindFirstChild("Grot_model")

	local model: Model
	if baseModel and baseModel:IsA("Model") then
		model = baseModel:Clone()
	else
		model = Instance.new("Model")
		local fallbackBox = Instance.new("Part")
		fallbackBox.Name = "Grot_hitbox"
		fallbackBox.Size = Vector3.new(4, 5, 3)
		fallbackBox.Color = Color3.fromRGB(46, 204, 113)
		fallbackBox.Parent = model
	end

	model.Name = "Grot"

	-- Remove "Skill area" if present in cloned model so it is NEVER welded as a body limb
	for _, child in ipairs(model:GetDescendants()) do
		if child.Name == "Skill area" then
			child:Destroy()
		end
	end

	-- 1. Find or create Grot_hitbox as the main hurtbox part
	local grotHitbox = model:FindFirstChild("Grot_hitbox", true) :: BasePart
	if not grotHitbox or not grotHitbox:IsA("BasePart") then
		grotHitbox = Instance.new("Part")
		grotHitbox.Name = "Grot_hitbox"
		grotHitbox.Size = Vector3.new(4, 5, 3)
		grotHitbox.Color = Color3.fromRGB(46, 204, 113)
		grotHitbox.Parent = model
	end

	grotHitbox.Anchored = false
	grotHitbox.CanCollide = true
	grotHitbox.RootPriority = 1
	grotHitbox.Material = Enum.Material.ForceField
	grotHitbox.Transparency = 0.75
	grotHitbox.Color = Color3.fromRGB(46, 204, 113)

	-- 2. HumanoidRootPart orientation calibration:
	-- Grot_hitbox was modeled facing +Z in Studio. Rotating HumanoidRootPart 180 degrees around Y
	-- aligns HumanoidRootPart.LookVector with Grot's visual front face so Grot walks FORWARD.
	local hrpCFrame = grotHitbox.CFrame * CFrame.Angles(0, math.pi, 0)

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.CFrame = hrpCFrame
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.Massless = true
	hrp.RootPriority = 2
	hrp.Parent = model

	local rootWeld = Instance.new("WeldConstraint")
	rootWeld.Part0 = hrp
	rootWeld.Part1 = grotHitbox
	rootWeld.Parent = hrp

	model.PrimaryPart = hrp

	-- 3. Rig the 6 Limbs using true Bounding Box proxy parts (LimbPivot)
	for _, limbName in ipairs(LIMB_NAMES) do
		local limb = model:FindFirstChild(limbName, true)
		if limb then
			local limbCF, _ = getLimbBoundingBox(limb)

			-- Create invisible proxy Part positioned at exact bounding box center
			local limbPivot = Instance.new("Part")
			limbPivot.Name = limbName .. "_Pivot"
			limbPivot.Size = Vector3.new(0.2, 0.2, 0.2)
			limbPivot.CFrame = limbCF
			limbPivot.Transparency = 1
			limbPivot.CanCollide = false
			limbPivot.CanTouch = false
			limbPivot.CanQuery = false
			limbPivot.Massless = true
			limbPivot.Parent = limb

			-- Weld all voxel sub-parts cleanly to limbPivot
			for _, desc in ipairs(limb:GetDescendants()) do
				if desc:IsA("BasePart") and desc ~= limbPivot then
					desc.Anchored = false
					desc.CanCollide = false
					desc.Massless = true

					local weld = Instance.new("WeldConstraint")
					weld.Part0 = limbPivot
					weld.Part1 = desc
					weld.Parent = limbPivot
				end
			end

			-- Connect Grot_hitbox (Part0) to limbPivot (Part1) via Motor6D
			local motor = Instance.new("Motor6D")
			motor.Name = limbName
			motor.Part0 = grotHitbox
			motor.Part1 = limbPivot
			motor.C0 = idlePose[limbName] or grotHitbox.CFrame:ToObjectSpace(limbCF)
			motor.C1 = CFrame.identity
			motor.Parent = grotHitbox
		end
	end

	-- 4. Humanoid setup with calibrated HipHeight so feet touch the floor cleanly
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
	end

	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = config.HP
	humanoid.Health = config.HP
	humanoid.WalkSpeed = config.Walk
	humanoid.UseJumpPower = true
	humanoid.JumpPower = config.Jump or 44
	humanoid.DisplayName = "Grot"
	humanoid.BreakJointsOnDeath = false

	-- Floor calibration: calculate feet distance from bounding box
	local modelCF, modelSize = model:GetBoundingBox()
	local feetY = modelCF.Position.Y - (modelSize.Y / 2)
	local footDistance = hrp.Position.Y - feetY
	humanoid.HipHeight = math.max(1.8, footDistance - (hrp.Size.Y / 2))

	-- 5. Set attributes matching all 12 stats
	model:SetAttribute("IsGrotRig", true)
	model:SetAttribute("CharacterId", "Grot")
	model:SetAttribute("CharacterName", "Grot")
	model:SetAttribute("MaxHealth", config.HP)
	model:SetAttribute("Health", config.HP)
	model:SetAttribute("HP", config.HP)
	model:SetAttribute("Regen", config.Regen)
	model:SetAttribute("MaxStamina", config.Stamina)
	model:SetAttribute("Stamina", config.Stamina)
	model:SetAttribute("Recovery", config.Recovery)
	model:SetAttribute("Walk", config.Walk)
	model:SetAttribute("Sprint", config.Sprint)
	model:SetAttribute("Jump", config.Jump or 44)
	model:SetAttribute("Physical", config.Physical)
	model:SetAttribute("Magic", config.Magic)
	model:SetAttribute("DEF", config.DEF)
	model:SetAttribute("Crit", config.Crit)
	model:SetAttribute("CritDMG", config.CritDMG)
	model:SetAttribute("IsSprinting", false)
	model:SetAttribute("IsAttacking", false)

	return model
end

--[[
    Creates an anchored showcase preview model of Grot for the Morph Stand.
--]]
function GrotRigFactory.CreatePreviewModel(): Model
	local model = GrotRigFactory.CreateGrotModel()
	model.Name = "GrotPreview"
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
	return model
end

--[[
    Morphs a given player into the Grot character model.
--]]
function GrotRigFactory.MorphPlayer(player: Player): Model
	local oldChar = player.Character
	local spawnCFrame = CFrame.new(0, 5, 0)

	if oldChar and oldChar.PrimaryPart then
		spawnCFrame = oldChar.PrimaryPart.CFrame
	elseif oldChar and oldChar:FindFirstChild("HumanoidRootPart") then
		spawnCFrame = oldChar.HumanoidRootPart.CFrame
	end

	local grotModel = GrotRigFactory.CreateGrotModel()
	grotModel.Name = player.Name
	grotModel:PivotTo(spawnCFrame)

	grotModel.Parent = Workspace

	local hrp = grotModel:FindFirstChild("HumanoidRootPart") :: BasePart
	local grotHitbox = grotModel:FindFirstChild("Grot_hitbox") :: BasePart
	if hrp then
		pcall(function()
			hrp:SetNetworkOwner(player)
		end)
	end
	if grotHitbox then
		pcall(function()
			grotHitbox:SetNetworkOwner(player)
		end)
	end

	local humanoid = grotModel:FindFirstChild("Humanoid") :: Humanoid
	if humanoid then
		humanoid.HealthChanged:Connect(function(newHealth)
			grotModel:SetAttribute("Health", math.clamp(newHealth, 0, 250))
		end)

		local hasDied = false
		humanoid.Died:Connect(function()
			if hasDied then return end
			hasDied = true
			task.wait(3)
			if player and player.Parent then
				player:SetAttribute("SelectedCharacterId", "Unmorphed")
				player:LoadCharacter()
			end
		end)
	end

	player:SetAttribute("SelectedCharacterId", "Grot")

	if player:GetAttribute("Invincible") then
		grotModel:SetAttribute("Invincible", true)
	end
	if player:GetAttribute("NoCooldown") then
		grotModel:SetAttribute("NoCooldown", true)
	end

	player.Character = grotModel

	local cameraResetRemote = RemoteManager.GetRemoteEvent("ResetCameraSubject")
	cameraResetRemote:FireClient(player, grotModel)

	if oldChar and oldChar ~= grotModel then
		task.delay(0.1, function()
			pcall(function()
				oldChar:Destroy()
			end)
		end)
	end

	return grotModel
end

return GrotRigFactory
