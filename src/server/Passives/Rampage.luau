--!strict
-- Rampage passive: Rage. Damage taken fills rage (0-100) which decays over
-- time. Rage grows the body (up to +20%), adds damage and knockback
-- resistance. Exposed as ApexRage / ApexDamageBonus / ApexKnockbackResist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)

local DamageService = require(script.Parent.Parent.Services.DamageService)

local BASE_SCALE = 1.3 -- matches the costume scale

local Rampage = {}

function Rampage.onCharacter(_player: Player, character: Model): () -> ()
	local rage = 0
	local appliedScale = BASE_SCALE
	local cfg = BalanceConfig.Rage

	local function apply()
		local t = rage / 100
		character:SetAttribute("ApexRage", math.floor(rage))
		character:SetAttribute("ApexDamageBonus", cfg.MaxDamageBonus * t)
		character:SetAttribute("ApexKnockbackResist", cfg.MaxKnockbackResistBonus * t)
		local target = BASE_SCALE * (1 + cfg.MaxScaleBonus * t)
		-- Only rescale in visible steps to avoid constant physics churn.
		if math.abs(target - appliedScale) > 0.03 and character:GetAttribute("ApexColossal") ~= true then
			appliedScale = target
			pcall(function()
				character:ScaleTo(target)
			end)
		end
	end

	local damaged = DamageService.Damaged:Connect(function(victim: Model, _info: any, dealt: number)
		if victim == character and dealt > 0 then
			rage = math.min(100, rage + dealt * cfg.GainPerDamageTaken)
			apply()
		end
	end)
	local accumulator = 0
	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		if rage <= 0 then
			return
		end
		rage = math.max(0, rage - cfg.DecayPerSecond * dt)
		accumulator += dt
		if accumulator >= 0.5 then
			accumulator = 0
			apply()
		end
	end)
	apply()

	return function()
		damaged:Disconnect()
		heartbeat:Disconnect()
	end
end

return Rampage
