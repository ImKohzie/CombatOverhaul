--!strict
-- Extra velocity other systems want applied to the local character (map
-- border pushback, wind zones...). FlightController adds it to its flight
-- velocity; on foot it's applied as a gentle nudge.

local MotionModifiers = {}

local pushes: { [string]: Vector3 } = {}

function MotionModifiers.set(name: string, velocity: Vector3?)
	if velocity then
		pushes[name] = velocity
	else
		pushes[name] = nil
	end
end

function MotionModifiers.total(): Vector3
	local sum = Vector3.zero
	for _, v in pushes do
		sum += v
	end
	return sum
end

return MotionModifiers
