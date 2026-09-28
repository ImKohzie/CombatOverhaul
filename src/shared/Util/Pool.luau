--!strict
-- Tiny object pool for frequently spawned VFX instances (damage numbers,
-- spark emitters). Released objects are parked out of the world.

export type Pool<T> = {
	acquire: (self: Pool<T>) -> T,
	release: (self: Pool<T>, item: T) -> (),
}

local Pool = {}

function Pool.new<T>(create: () -> T, reset: ((T) -> ())?, maxSize: number?): Pool<T>
	local free: { T } = {}
	local limit = maxSize or 64
	local self = {} :: Pool<T>

	function self.acquire(_: Pool<T>): T
		local item = table.remove(free)
		if item ~= nil then
			return item
		end
		return create()
	end

	function self.release(_: Pool<T>, item: T)
		if reset then
			reset(item)
		end
		if #free < limit then
			table.insert(free, item)
		elseif typeof(item) == "Instance" then
			(item :: any):Destroy()
		end
	end

	return self
end

return Pool
