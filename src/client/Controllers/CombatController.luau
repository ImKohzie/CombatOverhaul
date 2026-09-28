--!strict
-- Client melee input. Sends intents only; the server times hitboxes and
-- validates everything.
--   M1 tap        -> "Light"  (combo / aerial)
--   M1 hold+release after HeavyChargeTime -> "Heavy" (heavy / dive slam)
--   F on the ground -> block (hold)
--   V -> emote
-- The local character's swing poses play instantly for responsiveness;
-- other players see them via the server's Swing effect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local InputConfig = require(Shared.Config.InputConfig)
local Remotes = require(Shared.Net.Remotes)

local CameraController = require(script.Parent.CameraController)
local FlightController = require(script.Parent.FlightController)
local InputController = require(script.Parent.InputController)
local PoseController = require(script.Parent.PoseController)
local SoundLibrary = require(script.Parent.SoundLibrary)

local player = Players.LocalPlayer

local CombatController = {}

local combatRemote: RemoteEvent
local chargeToken = 0
local localCombo = 0
local lastLocalSwing = 0
local blocking = false

local function character(): (Model?, Humanoid?)
	local c = player.Character
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	return c, humanoid
end

local function canAct(): boolean
	local c, humanoid = character()
	if not c or not humanoid or humanoid.Health <= 0 then
		return false
	end
	return c:GetAttribute("ApexStunned") ~= true and c:GetAttribute("ApexServerMotion") ~= true and not CameraController.isCinematic()
end

local function airborne(): boolean
	local _, humanoid = character()
	return humanoid ~= nil and (humanoid.FloorMaterial == Enum.Material.Air or FlightController.isFlying())
end

-- Predict the local swing pose (the server decides if it lands).
local function predictSwing(kind: "Light" | "Heavy")
	local c = player.Character
	if not c then
		return
	end
	local melee = BalanceConfig.Melee
	if kind == "Heavy" then
		PoseController.play(c, if airborne() then "DiveSlam" else "Heavy")
		localCombo = 0
	elseif airborne() then
		PoseController.play(c, "Aerial")
	else
		if os.clock() - lastLocalSwing > melee.ComboInputWindow + 0.45 or localCombo >= #melee.ComboSteps then
			localCombo = 0
		end
		localCombo += 1
		PoseController.play(c, "Combo" .. localCombo)
	end
	lastLocalSwing = os.clock()
	SoundLibrary.play("Sound.Whoosh", { Volume = 0.25, Pitch = if kind == "Heavy" then 0.7 else 1.4 + math.random() * 0.2 })
end

local function setBlocking(on: boolean)
	if on == blocking then
		return
	end
	blocking = on
	combatRemote:FireServer(if on then "BlockDown" else "BlockUp")
end

function CombatController.isBlocking(): boolean
	return blocking
end

function CombatController.init()
	combatRemote = Remotes.event("CombatInput")

	InputController.Began:Connect(function(action: string)
		if action == "Attack" then
			if not canAct() then
				return
			end
			if blocking then
				setBlocking(false)
			end
			combatRemote:FireServer("M1Down")
			chargeToken += 1
			local token = chargeToken
			-- Show a wind-up pose once the press becomes a charge
			task.delay(InputConfig.HoldThreshold, function()
				local c = player.Character
				if token == chargeToken and InputController.isHeld("Attack") and c then
					PoseController.play(c, "Charge", { Loop = true })
				end
			end)
		elseif action == "FlightOrBlock" then
			-- Grounded F blocks; airborne F toggles flight (FlightController)
			if not airborne() and canAct() then
				setBlocking(true)
			end
		elseif action == "Emote" then
			local c = player.Character
			if c and canAct() and not airborne() then
				combatRemote:FireServer("Emote")
				PoseController.play(c, "Emote")
			end
		end
	end)

	InputController.Ended:Connect(function(action: string, heldFor: number)
		if action == "Attack" then
			chargeToken += 1
			if not canAct() then
				return
			end
			local c = player.Character
			if c and PoseController.isPlaying(c, "Charge") then
				PoseController.stop(c)
			end
			if heldFor >= BalanceConfig.Melee.HeavyChargeTime then
				combatRemote:FireServer("Heavy")
				predictSwing("Heavy")
			else
				combatRemote:FireServer("Light")
				predictSwing("Light")
			end
		elseif action == "FlightOrBlock" then
			setBlocking(false)
		end
	end)

	-- Lose the guard when stunned / guard broken server-side
	player.CharacterAdded:Connect(function()
		blocking = false
		localCombo = 0
	end)
end

return CombatController
