--!strict
-- APEX CITY server bootstrap. Services start in dependency order.

local Services = script.Parent.Services

local order: { { init: () -> () } } = {
	require(Services.NetService),
	require(Services.PlayerStateService),
	require(Services.CharacterService),
	require(Services.MovementService),
	require(Services.AbilityService),
}

local started = os.clock()
for _, service in order do
	service.init()
end
print(string.format("[APEX CITY] server ready in %.1f ms", (os.clock() - started) * 1000))
