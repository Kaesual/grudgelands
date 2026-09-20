local root = assert(arg[1], "repository root required")

local function read(path)
	local file = assert(io.open(root .. "/" .. path, "rb"))
	local value = file:read("*a")
	file:close()
	return value
end

local kits = read("mods/PLAYER/grug_abilities/kits.lua")
local core = read("mods/CORE/grug_core/combat.lua")
local stats = read("mods/PLAYER/grug_classes/stats.lua")
local abilities = read("mods/PLAYER/grug_abilities/init.lua")

for _, id in ipairs({"hold_ground", "cinderfall", "glacial_ward",
		"word_of_ruin"}) do
	assert(kits:find('id = "' .. id .. '"', 1, true), "missing ability " .. id)
end
for _, token in ipairs({"taunt_radius", "mighty_blow_cleave",
		"hamstring_root", "fireball_splash", "frost_nova_ranged",
		"control_damage_add", "smite_absorb", "flash_heal_splash",
		"dodge_chance_window", "drain_ratio_override"}) do
	assert(kits:find(token, 1, true), "missing X3 consumer " .. token)
end
assert(core:find("function grug_core.add_absorb", 1, true))
assert(core:find("table.sort(ordered", 1, true), "absorb soak order absent")
assert(stats:find('"crit_cap_override"', 1, true), "crit cap override absent")
assert(kits:find('"whitehot_window", 8', 1, true) and
	kits:find('), 120)', 1, true), "Whitehot trigger absent")
assert(kits:find("and 6 or 0", 1, true), "Whitehot damage absent")

-- Serialized Skills-owner integration gate: the resolved-cost hook must stay
-- present when this package is replayed after the frozen Skills candidate.
local whitehot_cost = abilities:find("whitehot", 1, true) and
	abilities:find("mana_percent", 1, true)
assert(whitehot_cost,
	"INTEGRATION REQUIRED: abilities/init.lua must snapshot Fireball at 3% " ..
	"base mana while the Whitehot window is active, before affordability/spend")

io.write("WP11 X3 contract KAT: OK\n")
