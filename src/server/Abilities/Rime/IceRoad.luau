--!strict
-- Rime Q: Ice Road. While held, lay an ice slide ahead of you (even in the
-- air, following your aim) and skate along it at speed.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local SEGMENT_INTERVAL = 0.08
local SEGMENT_LENGTH = 7
local LIFETIME = 5

local active: { [Player]: boolean } = {}

local IceRoad: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 6
		active[ctx.Player] = true
		AbilityKit.Status.apply(ctx.Character, "Skating", "Flag", duration)
		AbilityKit.Status.apply(ctx.Character, "SkateSpeed", "Speed", duration, AbilityKit.param(ctx, "SkateSpeed", 70) / 19)
		MovementService.exempt(ctx.Player, duration + 1)
		local AbilityService = require(script.Parent.Parent.Parent.Services.AbilityService) :: any
		task.spawn(function()
			local elapsed = 0
			local accumulator = SEGMENT_INTERVAL
			local humanoid = ctx.Humanoid
			local lastTop: Vector3? = nil
			while active[ctx.Player] and elapsed < duration and AbilityKit.isAlive(ctx.Character) do
				local dt = RunService.Heartbeat:Wait()
				elapsed += dt
				accumulator += dt
				if accumulator < SEGMENT_INTERVAL then
					continue
				end
				accumulator = 0
				-- Direction from the latest aim (pitch lets the road climb/dive)
				local live = AbilityService.getActive(ctx.Player, ctx.Slot)
				local aimPoint = if live then live.AimPoint else ctx.AimPoint
				local aimOrigin = if live then live.AimOrigin else ctx.AimOrigin
				local dir = aimPoint - aimOrigin
				dir = if dir.Magnitude > 1e-3 then dir.Unit else ctx.Root.CFrame.LookVector
				local pitch = math.clamp(dir.Y, -0.35, 0.35)
				local flat = Vector3.new(dir.X, 0, dir.Z)
				flat = if flat.Magnitude > 1e-3 then flat.Unit else ctx.Root.CFrame.LookVector
				local feetY = ctx.Root.Position.Y - ctx.Root.Size.Y / 2 - humanoid.HipHeight
				local start = lastTop or Vector3.new(ctx.Root.Position.X, feetY - 0.3, ctx.Root.Position.Z)
				-- Keep the road near the skater
				if (start - ctx.Root.Position).Magnitude > 14 then
					start = Vector3.new(ctx.Root.Position.X, feetY - 0.3, ctx.Root.Position.Z)
				end
				local finish = start + flat * SEGMENT_LENGTH + Vector3.new(0, pitch * SEGMENT_LENGTH, 0)
				local segment = AbilityKit.serverPart(
					Vector3.new(6, 0.6, (finish - start).Magnitude + 1),
					CFrame.lookAt(start:Lerp(finish, 0.5), finish),
					Color3.fromRGB(190, 235, 255),
					Enum.Material.Ice,
					true
				)
				segment.Name = "ApexIceRoad"
				segment.Transparency = 0.2
				segment.CustomPhysicalProperties = PhysicalProperties.new(0.9, 0, 0, 100, 1)
				Debris:AddItem(segment, LIFETIME)
				lastTop = finish
			end
			active[ctx.Player] = nil
			AbilityKit.Status.remove(ctx.Character, "Skating")
			AbilityKit.Status.remove(ctx.Character, "SkateSpeed")
		end)
		return true
	end,
	End = function(ctx)
		active[ctx.Player] = nil
	end,
}

return IceRoad
