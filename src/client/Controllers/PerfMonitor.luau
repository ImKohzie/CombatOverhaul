--!strict
-- Client performance report: average / 1%-low FPS and effect instance
-- counts, printed to the output 20s after joining and every 5 minutes.

local RunService = game:GetService("RunService")

local PerfMonitor = {}

local frames: { number } = {}

local function report()
	if #frames == 0 then
		return
	end
	local sorted = table.clone(frames)
	table.sort(sorted, function(a, b)
		return a > b
	end)
	local total = 0
	for _, dt in frames do
		total += dt
	end
	local average = #frames / total
	local worst = sorted[math.max(1, math.floor(#sorted * 0.01))]
	local fx = workspace:FindFirstChild("ApexClientEffects")
	local debris = workspace:FindFirstChild("ApexDebris")
	print(string.format(
		"[Perf/Client] avg %.0f FPS, 1%% low %.0f FPS | client FX instances %d | server debris %d | parts streamed in %d",
		average,
		1 / worst,
		if fx then #fx:GetChildren() else 0,
		if debris then #debris:GetChildren() else 0,
		workspace:GetAttribute("ApexClientPartCount") or 0
	))
	table.clear(frames)
end

function PerfMonitor.init()
	RunService.RenderStepped:Connect(function(dt)
		table.insert(frames, dt)
		if #frames > 6000 then
			table.remove(frames, 1)
		end
	end)
	task.delay(20, function()
		report()
		while true do
			task.wait(300)
			report()
		end
	end)
end

return PerfMonitor
