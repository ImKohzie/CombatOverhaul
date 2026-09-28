--!strict
-- Swarm R: Decoy Mass. Two nanite clones form beside you and mimic your
-- movement for 8s. They can be hit and destroyed.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local CostumeService = require(script.Parent.Parent.Parent.Services.CostumeService)
local DamageService = require(script.Parent.Parent.Parent.Services.DamageService)
local NPCService = require(script.Parent.Parent.Parent.Services.NPCService)

local CLONE_HEALTH = 150

local DecoyMass: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 8
		local count = AbilityKit.param(ctx, "Clones", 2)
		local clones: { Model } = {}
		for i = 1, count do
			local side = if i % 2 == 0 then 1 else -1
			local clone = NPCService.createRig(ctx.Player.DisplayName)
			if clone then
				local humanoid = clone:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.MaxHealth = CLONE_HEALTH
					humanoid.Health = CLONE_HEALTH
					humanoid.WalkSpeed = ctx.Humanoid.WalkSpeed
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					humanoid.BreakJointsOnDeath = false
				end
				clone:SetAttribute("ApexNPC", true)
				clone:SetAttribute("ApexClone", true)
				clone:SetAttribute("ApexCharacter", "Swarm")
				clone:PivotTo(ctx.Root.CFrame * CFrame.new(side * 5, 0, 1))
				clone.Parent = NPCService.folder()
				CostumeService.apply(clone, "Swarm")
				DamageService.watch(clone)
				table.insert(clones, clone)
				Debris:AddItem(clone, duration)
				AbilityKit.fx("Explosion", clone:GetPivot().Position, { Position = clone:GetPivot().Position, Radius = 4, Kind = "Electric", Color = Color3.fromRGB(170, 175, 185) })
			end
		end
		-- Mimic the owner's movement direction and jumps
		local connection: RBXScriptConnection
		local elapsed = 0
		connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= duration or not AbilityKit.isAlive(ctx.Character) then
				connection:Disconnect()
				return
			end
			local velocity = ctx.Root.AssemblyLinearVelocity
			local flat = Vector3.new(velocity.X, 0, velocity.Z)
			for _, clone in clones do
				local humanoid = clone:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					humanoid:Move(if flat.Magnitude > 2 then flat.Unit else Vector3.zero, false)
					if ctx.Humanoid.FloorMaterial == Enum.Material.Air and velocity.Y > 10 then
						humanoid.Jump = true
					end
				end
			end
		end)
		return #clones > 0
	end,
}

return DecoyMass
