--!strict
-- Client-side event bus between gameplay controllers and the HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("ApexCity").Util.Signal)

local HudEvents = {
	KillFeed = Signal.new(), -- (killer: string?, victim: string, tag: string?)
	HitMarker = Signal.new(), -- (amount: number, heavy: boolean)
	Notify = Signal.new(), -- (text: string)
	DamageTaken = Signal.new(), -- (amount: number, fromPosition: Vector3?)
}

return HudEvents
