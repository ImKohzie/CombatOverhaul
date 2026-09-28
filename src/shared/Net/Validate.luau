--!strict
-- Payload validators for remote arguments. Every client -> server remote
-- declares a schema (a list of checks, one per argument). Never trust types
-- coming from the client: NaN, inf, huge strings and wrong types are rejected.

export type Check = (value: any) -> boolean

local Validate = {}

local function isFiniteNumber(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Validate.number(min: number, max: number): Check
	return function(value: any): boolean
		return isFiniteNumber(value) and value >= min and value <= max
	end
end

function Validate.boolean(): Check
	return function(value: any): boolean
		return type(value) == "boolean"
	end
end

function Validate.string(maxLength: number): Check
	return function(value: any): boolean
		return type(value) == "string" and #value <= maxLength
	end
end

function Validate.enum(options: { any }): Check
	local set: { [string]: boolean } = {}
	for _, option in options do
		set[option] = true
	end
	return function(value: any): boolean
		return type(value) == "string" and set[value] == true
	end
end

function Validate.vector3(maxMagnitude: number): Check
	return function(value: any): boolean
		if typeof(value) ~= "Vector3" then
			return false
		end
		local v = value :: Vector3
		return isFiniteNumber(v.X) and isFiniteNumber(v.Y) and isFiniteNumber(v.Z) and v.Magnitude <= maxMagnitude
	end
end

function Validate.optional(check: Check): Check
	return function(value: any): boolean
		return value == nil or check(value)
	end
end

-- Validates a packed argument list against a schema. Extra arguments fail.
function Validate.args(schema: { Check }, args: { any }, count: number): (boolean, string?)
	if count > #schema then
		return false, "too many arguments"
	end
	for index, check in schema do
		if not check(args[index]) then
			return false, "bad argument #" .. index
		end
	end
	return true, nil
end

Validate.isFiniteNumber = isFiniteNumber

return Validate
