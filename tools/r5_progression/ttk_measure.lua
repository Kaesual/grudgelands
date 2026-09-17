-- Deterministic balance table for round-5 Lane P. The companion KAT loads and
-- validates the real production level/scalar functions; this report then
-- compares them with the exact pre-lane formulas at the requested levels.

local repo = arg[1] or "."
dofile(repo .. "/tools/r5_progression/progression_kat.lua")

local levels = {1, 10, 20, 40, 60}
local sword_damage = { [1] = 5, [10] = 5, [20] = 8, [40] = 15, [60] = 22 }

local function old_mob_hp(level)
	return 15 + 5 * level
end

local function old_mob_damage(level)
	return 2 + 0.4 * level
end

local function player_hp(level, strength_growth)
	local strength = 10 + strength_growth * (level - 1)
	return 20 + 2 * (level - 1) + strength
end

local function warrior_hit(level)
	return sword_damage[level] + math.floor((10 + 3 * (level - 1)) / 10)
end

local function fireball_hit(level)
	return 6 + math.floor((10 + 3 * (level - 1)) / 10)
end

local function smite_hit(level)
	return 4 + math.floor((10 + 2 * (level - 1)) / 10)
end

local function hit_damage(amount, armor_factor)
	return math.max(1, math.floor(amount * armor_factor))
end

local function ttk(hp, amount, armor_factor, interval)
	return math.ceil(hp / hit_damage(amount, armor_factor)) * interval
end

local function pair(old_value, new_value)
	return tostring(old_value) .. "→" .. tostring(new_value)
end

local maximum_ratio = 0
local maximum_label = ""

io.write("Player-to-mob TTK (seconds; deterministic non-crit hits; Warrior " ..
	"sword 1.0 s, Fireball normalized to one cast/s, Smite 2.0 s)\n\n")
io.write("| L | HP normal/elite | Raw DPS W/F/S old→new | Warrior N/E old→new | Fireball N/E old→new | " ..
	"Smite N/E old→new |\n")
io.write("|---:|---:|---:|---:|---:|---:|\n")
for _, level in ipairs(levels) do
	local old_hp = old_mob_hp(level)
	local new_hp = grug_mobs.stats_for(level, "normal")
	local scale = grug_core.level_scale(level)
	local outputs = {
		{name = "Warrior", old = warrior_hit(level), interval = 1},
		{name = "Fireball", old = fireball_hit(level), interval = 1},
		{name = "Smite", old = smite_hit(level), interval = 2},
	}
	local cells = {tostring(level), new_hp .. "/" .. (new_hp * 3)}
	local dps = {}
	for _, output in ipairs(outputs) do
		local new_amount = math.floor(output.old * scale)
		dps[#dps + 1] = pair(string.format("%.1f", output.old / output.interval),
			string.format("%.1f", new_amount / output.interval))
	end
	cells[#cells + 1] = table.concat(dps, "/")
	for _, output in ipairs(outputs) do
		local new_amount = math.floor(output.old * scale)
		local old_normal = ttk(old_hp, output.old, 1, output.interval)
		local new_normal = ttk(new_hp, new_amount, 1, output.interval)
		local old_elite = ttk(old_hp * 3, output.old, 0.8, output.interval)
		local new_elite = ttk(new_hp * 3, new_amount, 0.8, output.interval)
		cells[#cells + 1] = pair(old_normal, new_normal) .. " / " ..
			pair(old_elite, new_elite)
		for _, values in ipairs({{old_normal, new_normal, "normal"},
				{old_elite, new_elite, "elite"}}) do
			local ratio = values[2] / values[1]
			if ratio > maximum_ratio then
				maximum_ratio = ratio
				maximum_label = output.name .. " L" .. level .. " " .. values[3]
			end
		end
	end
	io.write("| ", table.concat(cells, " | "), " |\n")
end
if maximum_ratio > 2 then
	error(string.format("TTK stop criterion exceeded: %.3f at %s",
		maximum_ratio, maximum_label), 0)
end
io.write(string.format("\nMaximum new/old TTK ratio: %.3f at %s (PASS <= 2.000).\n\n",
	maximum_ratio, maximum_label))

io.write("Mob-to-player raw TTD (seconds at one hit/s; before dodge/armor/absorb)\n\n")
io.write("| L | Mob damage N/E old→new | Warrior HP TTD N/E old→new | " ..
	"Mage HP TTD N/E old→new | Priest HP TTD N/E old→new |\n")
io.write("|---:|---:|---:|---:|---:|\n")
for _, level in ipairs(levels) do
	local old_normal = old_mob_damage(level)
	local _, new_normal = grug_mobs.stats_for(level, "normal")
	local old_elite = math.floor(old_normal * 1.8 * 10 + 0.5) / 10
	local _, new_elite = grug_mobs.stats_for(level, "elite")
	local cells = {tostring(level), string.format("%.1f→%.1f / %.1f→%.1f",
		old_normal, new_normal, old_elite, new_elite)}
	for _, class in ipairs({{"Warrior", 3}, {"Mage", 0}, {"Priest", 1}}) do
		local hp = player_hp(level, class[2])
		cells[#cells + 1] = string.format("%d; %.1f→%.1f / %.1f→%.1f", hp,
			hp / old_normal, hp / new_normal, hp / old_elite, hp / new_elite)
	end
	io.write("| ", table.concat(cells, " | "), " |\n")
end

return true
