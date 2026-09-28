--!strict
-- Token-bucket rate limiter keyed by any value (usually a Player).

export type RateLimiter = {
	check: (self: RateLimiter, key: any) -> boolean,
	remove: (self: RateLimiter, key: any) -> (),
}

type Bucket = { tokens: number, last: number }

local RateLimiter = {}

function RateLimiter.new(ratePerSecond: number, burst: number): RateLimiter
	local buckets: { [any]: Bucket } = {}
	local self = {} :: RateLimiter

	function self.check(_: RateLimiter, key: any): boolean
		local now = os.clock()
		local bucket = buckets[key]
		if not bucket then
			bucket = { tokens = burst, last = now }
			buckets[key] = bucket
		end
		bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.last) * ratePerSecond)
		bucket.last = now
		if bucket.tokens >= 1 then
			bucket.tokens -= 1
			return true
		end
		return false
	end

	function self.remove(_: RateLimiter, key: any)
		buckets[key] = nil
	end

	return self
end

return RateLimiter
