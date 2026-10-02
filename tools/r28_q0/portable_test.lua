-- Round 28 Lane Q0 portable test: the level range of each objective's
-- targets in the quest log and the offer dialogue. Loads the REAL
-- grug_quests files under a minimal `core` stub and checks:
--   1. the range each source gives, cached on the registered objectives at
--      load: an area kind (only the objective's roles), a camp, a leader,
--      the recipe zone's kinds without an area, a catalogue role and a base
--      mob in a zone without a recipe, a legacy zone filter, a quest-drop
--      item, an item naming its source roles, and items without a range;
--   2. the text in the quest log and the dialogue; the HUD tracker line
--      stays as it was;
--   3. rendering reads the cache: with every world seam broken after load
--      the texts do not change;
--   4. load-time validation of an item's source roles;
--   5. the shipped quest files with the shipped recipes and catalogue: how
--      many objectives get a range, and how many HUD tracker lines would
--      exceed the tracker width with the range added (the HUD decision).
--
-- Usage (repo root): luajit tools/r28_q0/portable_test.lua
local json = dofile("tools/r28_b4_quests/json.lua")
local FIXTURE = "tools/r28_q0/fixture"
local DASH = "\226\128\147" -- the en dash of "level 1–4"

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. ("%q"):format(part) .. " in " .. ("%q"):format(tostring(text)) .. ")")
end

local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy

local function read_json(path)
	local handle = io.open(path)
	if not handle then return nil end
	local data = json.decode(handle:read("*a"))
	handle:close()
	return data
end

------------------------------------------------------------------------------
-- Engine and game surface (only what grug_quests touches here).
------------------------------------------------------------------------------
function ItemStack(item)
	local name, count = "", 0
	if type(item) == "table" and item.get_name then
		name, count = item:get_name(), item:get_count()
	elseif type(item) == "string" then
		local n, c = item:match("^(%S*)%s*(%d*)")
		name, count = n, tonumber(c) or (n == "" and 0 or 1)
	end
	local stack = {}
	function stack:get_name() return count > 0 and name or "" end
	function stack:get_count() return name ~= "" and count or 0 end
	function stack:is_empty() return name == "" or count <= 0 end
	return stack
end

local mod_paths, shown, pages = {}, {}, {}
local DISPOSITION = {wild_turkey = "critter", guard_accord = false, guard_throng = false}
core = {
	registered_items = {}, registered_aliases = {}, registered_entities = {},
	get_modpath = function(name) return mod_paths[name] end,
	get_current_modname = function() return "grug_quests" end,
	get_dir_list = function(path)
		local handle = io.popen('ls "' .. path .. '" 2>/dev/null')
		local out = {}
		for line in handle:lines() do out[#out + 1] = line end
		handle:close()
		return out
	end,
	parse_json = function(text) return (json.decode(text)) end,
	serialize = function(value) return value end,
	deserialize = function(value) return value ~= "" and deep_copy(value) or nil end,
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	formspec_escape = function(text) return text end,
	show_formspec = function(_, _, form) shown[#shown + 1] = form end,
	log = function() end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {distance = function() return 1 end}
grug_core = {register_tag_visibility = function() end,
	hud_layout = {side_text_width = function() return 38 end, QUEST_WRAP = 38, anchors = {quest_list = {}}}}
dofile("mods/CORE/grug_core/item_names.lua")
grug_xp = {get_level = function() return 60 end,
	quest_reward = function(level, weight) return weight * 10 * level end}
grug_money = {MAX = 1000000, format = function(copper) return copper .. " copper" end}
grug_factions = {get_faction = function() return "accord" end}
grug_classes = {get_race = function() return "human" end}
grug_inventory = {BAG_COUNT = 0, wrap_text = function(text) return text end}
sfinv = {register_page = function(name, def) pages[name] = def end,
	make_formspec = function(_, _, content) return content end, get_page = function() return "" end,
	pages = pages, pages_unordered = {}}

-- The zone records' level bands (wp40 simple map, as grug_zones serves them).
local BANDS = {}
local MAP_SOURCE = dofile("mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
for _, row in ipairs(MAP_SOURCE.zones) do
	BANDS[row.id] = {level_min = row.level_min, level_max = row.level_max}
end

-- grug_mobs and grug_zones over `mobs_root`'s recipes and catalogue, parsed
-- by the real spawn_regions_core.lua with the catalogue's levels and leaders
-- (as spawn_regions.lua's recipe context).
local function install_world(mobs_root)
	local regions_core = dofile("mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
	local catalogue = {}
	for _, row in ipairs(read_json(mobs_root .. "/data/subtypes.json")) do catalogue[row.role] = row end
	local recipes, leaders = {}, {}
	for _, name in ipairs(core.get_dir_list(mobs_root .. "/data/zones")) do
		local zone = name:match("^(.+)%.spawns%.json$")
		local data = zone and read_json(mobs_root .. "/data/zones/" .. name)
		if data and data.recipe then
			recipes[zone] = regions_core.parse_recipe(zone, data.recipe, {
				band = {BANDS[zone].level_min, BANDS[zone].level_max},
				-- The zone's camp POIs (a recipe camp may stand on one, Round 28 S2).
				pois = function(id) return regions_core.zone_pois(MAP_SOURCE, id) end,
				role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
				leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
			})
			for _, leader in ipairs(recipes[zone].leaders) do
				leaders[leader.role] = {zone = zone, level = leader.level, respawn = leader.respawn}
			end
		end
	end
	local seams = {}
	function seams.get_area(zone, id)
		local r = recipes[zone]
		return r and (r.kind_by_id[id] or r.camp_by_id[id]) or nil
	end
	function seams.area_roles(zone, id)
		local unit = seams.get_area(zone, id)
		return unit and deep_copy(unit.roles) or nil
	end
	function seams.zone_area_ids(zone)
		local r, out = recipes[zone], {}
		for _, kind in ipairs(r and r.kinds or {}) do out[#out + 1] = kind.id end
		for _, camp in ipairs(r and r.camps or {}) do out[#out + 1] = camp.id end
		return out
	end
	function seams.leader(role) return leaders[role] end
	grug_mobs = {
		register_on_eligible_kill = function() end,
		register_participant_drop_hook = function() end,
		disposition = function(name)
			local role = name:match("^grug_mobs:(.+)$") or name
			if DISPOSITION[role] ~= nil then return DISPOSITION[role] or nil end
			return "aggressive"
		end,
		spawn_regions = seams,
	}
	grug_zones = {get = function(zone) return BANDS[zone] end, id_at = function() return "elandor_dawnmere_fields" end}
	mod_paths.grug_mobs = mobs_root
	return catalogue
end

-- Every mob and item the quest files name exists (the registries are not
-- what this lane tests).
local function register_named(quest_root)
	for _, name in ipairs(core.get_dir_list(quest_root .. "/data/zones")) do
		for _, quest in ipairs(read_json(quest_root .. "/data/zones/" .. name).quests or {}) do
			local function mobs(row)
				for _, role in ipairs(row.roles or {}) do core.registered_entities["grug_mobs:" .. role] = {} end
				for _, mob in ipairs(row.mobs or {}) do core.registered_entities[mob] = {} end
			end
			for _, objective in ipairs(quest.objectives) do
				mobs(objective)
				if objective.item then
					core.registered_items[objective.item] = core.registered_items[objective.item] or
						{description = objective.item}
				end
			end
			for _, drop in ipairs(quest.quest_drops or {}) do mobs(drop) end
			for _, item in ipairs(quest.rewards.items or {}) do
				core.registered_items[item.item] = core.registered_items[item.item] or {description = item.item}
			end
		end
	end
end

-- Load grug_quests from `quest_root` (its data/zones are the quest files)
-- over `mobs_root`'s spawn data, then the on_mods_loaded checks.
local function load_quests(quest_root, mobs_root)
	grug_quests = {}
	install_world(mobs_root)
	register_named(quest_root)
	mod_paths.grug_quests = quest_root
	local base = "mods/PLAYER/grug_quests/"
	for _, file in ipairs({"registry", "state", "labels", "npc", "npcs", "validate", "loader", "ui", "hud"}) do
		dofile(base .. file .. ".lua")
	end
	local ok, err = pcall(grug_quests.validate_quest_data)
	check(ok, quest_root .. ": the load-time world checks pass: " .. tostring(err))
	return grug_quests
end

------------------------------------------------------------------------------
-- 1. The range each source gives, cached at load.
------------------------------------------------------------------------------
core.registered_items["default:cobble"] = {description = "Cobblestone"}
core.registered_items["default:tree"] = {description = "Apple Tree", groups = {tree = 1}}
core.registered_items["grug_mobs:ledger_page"] = {description = "Ledger Page"}
core.registered_items["grug_mobs:boar_tusk"] = {description = "Boar Tusk"}
local Q = load_quests(FIXTURE .. "/grug_quests", FIXTURE .. "/grug_mobs")
for role, label in pairs({small_boar = "Small Boar", aggressive_fox = "Aggressive Fox",
		confused_bandit = "Confused Bandit", confused_bandit_chief = "Confused Bandit Chief",
		young_boar = "Young Boar", boar = "Boar", ridge_boar = "Ridge Boar"}) do
	core.registered_entities["grug_mobs:" .. role].description = label
end

local function range(id, index)
	local levels = Q.registered_quests[id].objectives[index or 1].levels
	return levels and (levels[1] .. "-" .. levels[2]) or "none"
end
eq(range("q0_area_kind"), "1-4", "area kind: the role's levels in the kind")
eq(range("q0_area_minor"), "6-8", "area kind: only the objective's roles (the kind is 5-8)")
eq(range("q0_camp", 1), "9-10", "camp: catalogue 8-10 within the camp's belt 9-10")
eq(range("q0_camp", 2), "9-10", "quest-drop item: its dropping targets' levels")
eq(range("q0_leader"), "10-10", "leader: its fixed level")
eq(range("q0_zone_roles"), "5-8", "no area in a recipe zone: the zone's kinds hosting the role")
eq(range("q0_legacy_base"), "1-4", "base mob in a recipe zone adds nothing; its sub-type gives 1-4")
eq(range("q0_legacy_filter"), "11-15", "legacy zone filter: the filter zone's band 11-20 within 12 +-3")
eq(range("q0_tusks"), "1-4", "item naming its source roles")
eq(range("q0_plain", 1), "none", "plain item: no range")
eq(range("q0_plain", 2), "none", "group item: no range")
eq(range("q0_catalogue"), "12-15", "no recipe: catalogue 12-15 within 14 +-3")
eq(range("q0_base"), "15-20", "base mob without a recipe: the zone band 11-20 within 18 +-3")

------------------------------------------------------------------------------
-- 2. Quest log, dialogue and HUD.
------------------------------------------------------------------------------
local meta = {}
local main = {}
for i = 1, 8 do main[i] = ItemStack("") end
local player = {}
function player:get_player_name() return "ann" end
function player:is_player() return true end
function player:get_hp() return 20 end
function player:get_pos() return {x = 0, y = 0, z = 0} end
function player:get_meta()
	return {get_string = function(_, k) return meta[k] or "" end, set_string = function(_, k, v) meta[k] = v end}
end
function player:get_inventory()
	return {get_list = function(_, list) return list == "main" and main or nil end}
end
local function npc_entity(npc)
	local def = Q.registered_npcs[npc]
	return {_grug_start = def.settlement, _grug_socket = def.socket, object = {
		is_valid = function() return true end, get_pos = function() return {x = 0, y = 0, z = 0} end}}
end
local function dialogue(npc, id)
	for index, row in ipairs(Q.npc_quests(player, npc)) do
		if row.id == id then
			shown = {}
			Q.open_npc(player, npc_entity(npc), index)
			return shown[1] or ""
		end
	end
	return ""
end
local function log(id) return pages["grug_quests:quests"].get(nil, player, {grug_quest_selected = id}) end
local function hud(id)
	for _, row in ipairs(Q.journal(player).quests) do
		if row.id == id then return Q.hud_line(row, 38) end
	end
end

local function offers()
	return {
		dialogue_kind = dialogue("r14_human_elder", "q0_area_kind"),
		dialogue_camp = dialogue("r14_human_elder", "q0_camp"),
		dialogue_leader = dialogue("r14_human_elder", "q0_leader"),
		dialogue_plain = dialogue("r20_human_start_cook", "q0_plain"),
	}
end
local offered = offers()
has(offered.dialogue_kind, "Defeat Small Boar × 8 (level 1" .. DASH .. "4)\n", "offer dialogue: kill range")
has(offered.dialogue_camp, "Defeat Confused Bandit × 5 (level 9" .. DASH .. "10)\n" ..
	"Bring Ledger Page × 3 (level 9" .. DASH .. "10)\n", "offer dialogue: camp kill and quest-drop item")
has(offered.dialogue_leader, "Defeat Confused Bandit Chief × 1 (level 10)\n", "offer dialogue: one level")
has(offered.dialogue_plain, "Bring Cobblestone × 10\nBring Any Tree × 5\n", "offer dialogue: items without a range")

for _, id in ipairs({"q0_area_kind", "q0_camp", "q0_leader", "q0_tusks", "q0_plain"}) do
	check(Q.accept(player, id), "accept " .. id)
end
-- Every text that shows an objective, with the quests active.
local function render()
	local out = offers()
	for _, id in ipairs({"q0_area_kind", "q0_camp", "q0_leader", "q0_tusks", "q0_plain"}) do
		out["log_" .. id], out["hud_" .. id] = log(id), hud(id)
	end
	return out
end
local before = render()
has(before.log_q0_area_kind, "Defeat Small Boar: 0/8 (level 1" .. DASH .. "4)", "quest log: kill range")
has(before.log_q0_camp, "Defeat Confused Bandit: 0/5 (level 9" .. DASH .. "10)\nBring Ledger Page: 0/3 (level 9" ..
	DASH .. "10)", "quest log: camp kill and quest-drop item")
has(before.log_q0_leader, "Defeat Confused Bandit Chief: 0/1 (level 10)", "quest log: one level")
has(before.log_q0_tusks, "Bring Boar Tusk: 0/4 (level 1" .. DASH .. "4)", "quest log: item naming its source")
has(before.log_q0_plain, "Bring Cobblestone: 0/10\nBring Any Tree: 0/5]", "quest log: items without a range")
has(before.dialogue_kind, "Defeat Small Boar × 8 (level 1" .. DASH .. "4)\n", "active quest's dialogue: kill range")
eq(before.hud_q0_area_kind, "0/8 Defeat Small Boar", "HUD tracker line unchanged (no range)")
eq(before.hud_q0_camp, "Confused Bandit 0/5, Ledger Page 0/3", "compact HUD line unchanged (no range)")

------------------------------------------------------------------------------
-- 3. Rendering reads the cache, never the world.
------------------------------------------------------------------------------
local function broken() error("world seam read after load") end
for key in pairs(grug_mobs.spawn_regions) do grug_mobs.spawn_regions[key] = broken end
grug_zones.get = broken
local after = render()
for key, text in pairs(before) do eq(after[key], text, "same text without the world: " .. key) end

------------------------------------------------------------------------------
-- 4. Load-time validation of an item's source roles.
------------------------------------------------------------------------------
Q = load_quests(FIXTURE .. "/grug_quests", FIXTURE .. "/grug_mobs")
local V = Q.validate
core.registered_entities["grug_mobs:wild_turkey"] = {}
local base_files = deep_copy(Q.quest_files)
local npcs_before = Q.registered_npcs
local world
do
	local real = V.world
	V.world = function(f, w) world = w; return real(f, w) end
	Q.validate_quest_data()
	V.world = real
end
local function tusks(files)
	for _, file in ipairs(files) do
		for _, quest in ipairs(file.data.quests) do
			if quest.id == "q0_tusks" then return quest.objectives[1] end
		end
	end
end
eq(#V.structure(deep_copy(base_files), npcs_before), 0, "fixture structure is clean")
eq(#V.world(deep_copy(base_files), world), 0, "fixture world checks are clean")
for _, case in ipairs({
	{"empty source roles", "E-objective", function(o) o.roles = {} end},
	{"source area without roles", "E-area", function(o) o.roles = nil; o.area = "home_fields" end},
	{"unknown source role", "E-unknown-role", function(o) o.roles = {"no_such_role"} end},
	{"source role not in the area", "E-role-not-in-area", function(o) o.area = "woods" end},
	{"critter as the source", "E-critter-target", function(o) o.roles = {"wild_turkey"} end},
	{"source levels do not fit the quest level", "E-level-fit", function(o) o.roles = {"confused_bandit"} end},
}) do
	local files = deep_copy(base_files)
	case[3](tusks(files))
	local found = V.structure(files, npcs_before)
	if #found == 0 then found = V.world(files, world) end
	local hit
	for _, message in ipairs(found) do
		if message:find("[" .. case[2] .. "]", 1, true) and message:find("quest q0_tusks", 1, true) then hit = message end
	end
	check(hit ~= nil, case[1] .. ": " .. case[2] .. " expected, got: " .. table.concat(found, " | "))
end

------------------------------------------------------------------------------
-- 5. The shipped quest files over the shipped recipes and catalogue.
------------------------------------------------------------------------------
core.registered_entities = {}
Q = load_quests("mods/PLAYER/grug_quests", "mods/ENTITIES/grug_mobs")
local function visible(text)
	local n = 0
	for i = 1, #text do
		local byte = text:byte(i)
		if byte < 0x80 or byte >= 0xC0 then n = n + 1 end
	end
	return n
end
local kills, ranged_kills, items, ranged_items, lines, over_without, over_with = 0, 0, 0, 0, 0, 0, 0
local ids = {}
for id in pairs(Q.registered_quests) do ids[#ids + 1] = id end
table.sort(ids)
for _, id in ipairs(ids) do
	local def = Q.registered_quests[id]
	local rows = {}
	for index, objective in ipairs(def.objectives) do
		if objective.type == "kill" then
			kills = kills + 1
			if objective.levels then ranged_kills = ranged_kills + 1 end
		elseif objective.type == "item" then
			items = items + 1
			if objective.levels then ranged_items = ranged_items + 1 end
		end
		rows[index] = {type = objective.type, item = objective.item, group = objective.group,
			mobs = objective.mobs, npc = objective.npc, count = 0, required = objective.count,
			levels = objective.levels}
	end
	if not Q.is_travel(def) then
		-- The tracker line at 0 progress, without and with each range.
		local plain, ranged
		if #rows > 1 then
			plain = Q.compact_text({objectives = rows})
			local parts = {}
			for _, row in ipairs(rows) do
				parts[#parts + 1] = ("%s %d/%d%s"):format(Q.objective_subject(row), 0, row.required,
					Q.objective_levels_text(row))
			end
			ranged = table.concat(parts, ", ")
		else
			plain = ("%d/%d %s"):format(0, rows[1].required, Q.objective_action(rows[1]))
			ranged = plain .. Q.objective_levels_text(rows[1])
		end
		if def.repeatable then plain, ranged = "Repeatable: " .. plain, "Repeatable: " .. ranged end
		lines = lines + 1
		if visible(plain) > 38 then over_without = over_without + 1 end
		if visible(ranged) > 38 then over_with = over_with + 1 end
	end
end
check(ranged_kills > 0 and ranged_kills <= kills, "shipped kill objectives get ranges")
-- What the one-time computation costs at load (reported, not a target).
do
	local world, real = nil, Q.validate.world
	Q.validate.world = function(f, w) world = w; return real(f, w) end
	local t0 = os.clock()
	Q.validate_quest_data()
	local with_ranges = os.clock() - t0
	Q.validate.world = real
	t0 = os.clock()
	for _ = 1, 100 do
		for _, row in ipairs(Q.validate.each_quest(Q.quest_files)) do
			for _, objective in ipairs(row.quest.objectives) do
				Q.validate.objective_levels(world, row.file.zone, row.quest, objective)
			end
		end
	end
	print(("load: world checks + ranges %.1f ms; the ranges alone %.2f ms (LuaJIT, stubbed seams)")
		:format(with_ranges * 1000, (os.clock() - t0) * 10))
end
print(("shipped: %d quests; kill objectives with a range %d/%d; item objectives with a range %d/%d")
	:format(#ids, ranged_kills, kills, ranged_items, items))
print(("HUD tracker lines over 38 characters: %d/%d today, %d/%d with the range added")
	:format(over_without, lines, over_with, lines))
for _, id in ipairs({"r14_human_01_boars_beyond_the_fence", "r14_human_04_shapes_by_lanternlight",
		"r14_human_05_the_missing_flock"}) do
	local objective = Q.registered_quests[id] and Q.registered_quests[id].objectives[1]
	if objective then
		print(("  %s: %s%s"):format(id, Q.objective_action(objective), Q.objective_levels_text(objective)))
	end
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then os.exit(1) end
print("R28 Q0 PORTABLE PASS checks=" .. checks)
