--!strict
-- Umbra R: Shade Clone. Leave a shadow decoy where you stand and slip away
-- unseen to the aimed spot (up to 60 studs).

local Debris = game:GetService("Debris")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local CostumeService = require(script.Parent.Parent.Parent.Services.CostumeService)
local DamageService = require(script.Parent.Parent.Parent.Services.DamageService)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)
local NPCService = require(script.Parent.Parent.Parent.Services.NPCService)

local SWAP_RANGE = 60

local ShadeClone: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 6
		local decoy = NPCService.createRig(ctx.Player.DisplayName)
		if decoy then
			local humanoid = decoy:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.MaxHealth = 120
				humanoid.Health = 120
				humanoid.WalkSpeed = 0
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				humanoid.BreakJointsOnDeath = false
			end
			decoy:SetAttribute("ApexNPC", true)
			decoy:SetAttribute("ApexClone", true)
			decoy:SetAttribute("ApexCharacter", "Umbra")
			decoy:PivotTo(ctx.Root.CFrame)
			decoy.Parent = NPCService.folder()
			CostumeService.apply(decoy, "Umbra")
			DamageService.watch(decoy)
			Debris:AddItem(decoy, duration)
		end
		-- Slip to the aimed spot, briefly invisible
		local dir = ctx.AimPoint - ctx.Root.Position
		local distance = math.min(dir.Magnitude, SWAP_RANGE)
		local target = ctx.Root.Position + (if dir.Magnitude > 1e-3 then dir.Unit else ctx.Root.CFrame.LookVector) * distance
		local ground = AbilityKit.groundBelow(target + Vector3.new(0, 10, 0), 60)
		local spot = if ground then ground.Position + Vector3.new(0, 3, 0) else target
		AbilityKit.fx("ShadowPuff", ctx.Root.Position, { Position = ctx.Root.Position })
		MovementService.exempt(ctx.Player, 1)
		ctx.Character:PivotTo(CFrame.new(spot) * ctx.Root.CFrame.Rotation)
		AbilityKit.Status.apply(ctx.Character, "Invisible", "Flag", 1.5)
		return true
	end,
}

return ShadeClone
