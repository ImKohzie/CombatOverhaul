--!strict
-- Time-to-kill simulator. Plays each character's full rotation (abilities
-- on cooldown, M1 combo in between) against every health tier and prints a
-- matrix, plus rule checks for BalanceConfig. Pure logic: takes the
-- BalanceConfig table so it also runs outside Roblox.

local BalanceSim = {}

type Row = { attacker: string, noUlt: { [string]: number }, withUlt: { [string]: number } }

local TIERS = { "Tank", "Bruiser", "Balanced", "Agile" }
local MAX_TIME = 120
local STEP = 0.05

local function simulate(config: any, characterId: string, tier: string, useUlt: boolean): number
	local role = config.Roles[tier]
	local hp = role.Health
	local reduction = role.DamageReduction
	local abilities = config.Abilities[characterId]
	local melee = config.Melee
	local readyAt: { [string]: number } = { Ability1 = 0, Ability2 = 0, Ability3 = 0, Ultimate = if useUlt then 0 else math.huge }
	local pending: { { time: number, damage: number } } = {}
	local t = 0
	local busyUntil = 0
	local comboStep = 0
	local dealt = 0
	while t < MAX_TIME do
		-- Resolve damage that lands now
		for i = #pending, 1, -1 do
			if pending[i].time <= t then
				dealt += pending[i].damage * (1 - reduction)
				table.remove(pending, i)
			end
		end
		if dealt >= hp then
			return t
		end
		if t >= busyUntil then
			local used = false
			for _, slot in { "Ultimate", "Ability3", "Ability1", "Ability2" } do
				local ability = abilities[slot]
				if ability and ability.Damage > 0 and t >= readyAt[slot] then
					local windUp = ability.WindUp or 0.2
					local duration = math.min(ability.Duration or 0, 4)
					if ability.Channel then
						-- Caster is committed; damage lands across the channel.
						busyUntil = t + windUp + math.max(duration, 0.3)
					else
						busyUntil = t + windUp + 0.3
					end
					-- Damage over time arrives on average halfway through.
					table.insert(pending, { time = t + windUp + duration * 0.5, damage = ability.Damage })
					readyAt[slot] = if slot == "Ultimate" then math.huge else t + ability.Cooldown
					used = true
					break
				end
			end
			if not used then
				comboStep = (comboStep % #melee.ComboSteps) + 1
				local timing = melee.ComboSteps[comboStep]
				busyUntil = t + timing.WindUp + timing.Active + timing.Recovery
				if comboStep == #melee.ComboSteps then
					busyUntil += melee.ComboInputWindow * 0.5 -- reset gap between chains
				end
				table.insert(pending, { time = t + timing.WindUp, damage = melee.ComboDamage[comboStep] })
			end
		end
		t += STEP
	end
	return MAX_TIME
end

-- Returns rows and prints a formatted report.
function BalanceSim.run(config: any, characterIds: { string }, print: (string) -> ()): { Row }
	local rows: { Row } = {}
	for _, id in characterIds do
		if config.Abilities[id] then
			local row: Row = { attacker = id, noUlt = {}, withUlt = {} }
			for _, tier in TIERS do
				row.noUlt[tier] = simulate(config, id, tier, false)
				row.withUlt[tier] = simulate(config, id, tier, true)
			end
			table.insert(rows, row)
		end
	end

	local function line(cells: { string }): string
		local out = {}
		for i, cell in cells do
			table.insert(out, if i == 1 then string.format("%-16s", cell) else string.format("%9s", cell))
		end
		return table.concat(out, " ")
	end

	print("================ APEX CITY balance matrix (TTK seconds) ================")
	print("Full rotation: abilities on cooldown + 4-hit M1 chains in between.")
	print("Columns = defender tier HP (Tank has 15% damage reduction).")
	for _, mode in { "noUlt", "withUlt" } do
		print("")
		print(if mode == "noUlt" then "-- Without ultimate --" else "-- Opening with a full ultimate --")
		print(line({ "Attacker", "Tank", "Bruiser", "Balanced", "Agile", "Avg" }))
		local columnTotals: { [string]: number } = {}
		local grand = 0
		for _, row in rows do
			local values = (row :: any)[mode] :: { [string]: number }
			local sum = 0
			local cells = { row.attacker }
			for _, tier in TIERS do
				sum += values[tier]
				columnTotals[tier] = (columnTotals[tier] or 0) + values[tier]
				table.insert(cells, string.format("%.1f", values[tier]))
			end
			grand += sum / #TIERS
			table.insert(cells, string.format("%.1f", sum / #TIERS))
			print(line(cells))
		end
		local avgCells = { "Average" }
		for _, tier in TIERS do
			table.insert(avgCells, string.format("%.1f", columnTotals[tier] / #rows))
		end
		table.insert(avgCells, string.format("%.1f", grand / #rows))
		print(line(avgCells))

		-- Outliers: attackers more than 20% faster / slower than average
		local mean = grand / #rows
		for _, row in rows do
			local values = (row :: any)[mode] :: { [string]: number }
			local avg = 0
			for _, tier in TIERS do
				avg += values[tier]
			end
			avg /= #TIERS
			local diff = (avg - mean) / mean
			if math.abs(diff) > 0.2 then
				print(string.format("  ! %s kills %s than average (%+.0f%% TTK)", row.attacker, if diff < 0 then "faster" else "slower", diff * 100))
			end
		end
	end

	-- Rule checks
	print("")
	print("-- Rule checks --")
	local problems = 0
	local balancedHp = config.Roles.Balanced.Health
	for _, id in characterIds do
		local set = config.Abilities[id]
		if set then
			local ult = set.Ultimate
			if ult and (ult.Damage < 350 or ult.Damage > 480) then
				print(string.format("  ! %s ultimate damage %d outside 350-480", id, ult.Damage))
				problems += 1
			end
			if ult and ult.Damage >= balancedHp then
				print(string.format("  ! %s ultimate can kill a full-HP Balanced character", id))
				problems += 1
			end
			for _, slot in { "Ability1", "Ability2", "Ability3" } do
				local ability = set[slot]
				if ability then
					if ability.Damage > 190 then
						print(string.format("  ! %s %s damage %d above 190", id, slot, ability.Damage))
						problems += 1
					end
					if ability.Cooldown < 6 or ability.Cooldown > 14 then
						print(string.format("  ! %s %s cooldown %.1fs outside 6-14s", id, slot, ability.Cooldown))
						problems += 1
					end
				end
			end
		end
	end
	local combo = 0
	for _, value in config.Melee.ComboDamage do
		combo += value
	end
	print(string.format("  M1 hit %d (target ~35), full combo %d (target ~160)", config.Melee.ComboDamage[1], combo))
	print(if problems == 0 then "  All ability/ultimate rules pass." else string.format("  %d rule problem(s).", problems))
	print("=========================================================================")
	return rows
end

return BalanceSim
