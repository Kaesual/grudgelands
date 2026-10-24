-- Round 57 lane QSYS, the quest part (LuaJIT; run by
-- tools/r57_qsys/portable_test.lua, also alone): the REAL grug_quests
-- (registry, state, labels, npc dialog, npcs, validate, loader, hud), the
-- map window's quest box and grug_mail's starter quest, with the REAL
-- grug_gear and grug_quality for the reward stacks, on the two-zone sample
-- of tools/r57_qsys/samples (Dawnmere Fields of The Accord, Sunscar Flats of
-- The Throng, both reworked):
--   A. the shared quest: one id, a variant per zone, taken in A, counted by
--      A's names only, handed in at A's turn-in, not offered in B
--      afterwards; the variant and the giver in the active state; an old
--      active entry without them; the texts per variant, per race and the
--      completion text; the HUD's "Return to" per variant;
--   B. the role giver with a faction filter;
--   C. story and free play: the story category of the lists, the story
--      marker beside a ready side quest;
--   D. choice rewards: the offer's preview, Complete refused without a
--      pick, the picked item with its fixed enchants, item level and the
--      receiver's tooltip, a full inventory refused;
--   E. the system quest mailbox_visit, turned in without a dialog;
--   F. the load checks: the free-play rules only in reworked files, the
--      reward budget, the requested item, the night count, `repeatable`
--      unknown, the variant shapes, the faction pairing.
--
--   luajit tools/r57_qsys/quest_test.lua [REPO]
-- Prints "R57 QSYS QUESTS PASS checks=<n>" or the failures (exit 1).
local ROOT = arg and arg[1] or "."
grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local json = dofile(ROOT .. "/tools/r28_b4_quests/json.lua")
local SAMPLES = ROOT .. "/tools/r57_qsys/samples"
local D, S = "elandor_dawnmere_fields", "kragmar_sunscar_flats"
local EL, CK, OE = "r14_human_elder", "r20_human_start_cook", "r14_orc_elder"

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
local function lacks(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) == nil,
		label .. " (unexpected " .. ("%q"):format(part) .. ")")
end
local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy

------------------------------------------------------------------------------
-- Engine surface: ItemStack with metadata (the real gear needs it).
------------------------------------------------------------------------------
local registered = {}
local function new_meta(fields)
	local store = {}
	for key, value in pairs(fields or {}) do store[key] = value end
	local meta = {fields = store}
	function meta:get_string(key) return store[key] or "" end
	function meta:set_string(key, value)
		if value == "" then store[key] = nil else store[key] = value end
	end
	function meta:get_int(key) return math.floor(tonumber(store[key]) or 0) end
	function meta:set_int(key, value) self:set_string(key, tostring(value)) end
	function meta:set_tool_capabilities() end
	return meta
end
local function meta_key(meta)
	local keys = {}
	for key in pairs(meta.fields) do keys[#keys + 1] = key end
	table.sort(keys)
	local out = {}
	for _, key in ipairs(keys) do out[#out + 1] = key .. "=" .. tostring(meta.fields[key]) end
	return table.concat(out, ";")
end
function ItemStack(item)
	local name, count, fields = "", 0, nil
	if type(item) == "table" and item.get_name then
		name, count, fields = item:get_name(), item:get_count(), item:get_meta().fields
	elseif type(item) == "string" then
		local n, c = item:match("^(%S*)%s*(%d*)")
		name, count = n, tonumber(c) or (n == "" and 0 or 1)
	end
	local meta = new_meta(fields)
	local stack = {}
	local function max_of(other)
		local def = registered[other]
		return def and def.stack_max or 99
	end
	function stack:get_name() return count > 0 and name or "" end
	function stack:get_count() return name ~= "" and count or 0 end
	function stack:is_empty() return name == "" or count <= 0 end
	function stack:get_meta() return meta end
	function stack:get_definition() return registered[name] or {} end
	function stack:get_wear() return 0 end
	function stack:get_tool_capabilities() return (registered[name] or {}).tool_capabilities end
	function stack:get_description()
		local text = meta:get_string("description")
		return text ~= "" and text or ((registered[name] or {}).description or name)
	end
	function stack:take_item(n)
		n = math.min(n or 1, count)
		local taken = ItemStack(self)
		taken.set_count_raw(n)
		count = count - n
		if count == 0 then name, meta = "", new_meta() end
		return taken
	end
	function stack.set_count_raw(n) count = n end
	function stack:add_item(other)
		other = ItemStack(other)
		if other:is_empty() then return other end
		if self:is_empty() then
			name, count, meta = other:get_name(), 0, new_meta(other:get_meta().fields)
		end
		if name ~= other:get_name() or meta_key(meta) ~= meta_key(other:get_meta()) then return other end
		local move = math.min(max_of(name) - count, other:get_count())
		count = count + move
		local rest = ItemStack(other)
		rest.set_count_raw(other:get_count() - move)
		return rest
	end
	function stack:equals(other)
		return self:get_name() == other:get_name() and self:get_count() == other:get_count() and
			meta_key(meta) == meta_key(other:get_meta())
	end
	function stack:to_string() return self:is_empty() and "" or (name .. " " .. count) end
	return stack
end
PcgRandom = function(seed)
	local state = seed % 2147483647
	if state == 0 then state = 1 end
	local function step() state = (state * 48271) % 2147483647 end
	step(); step(); step()
	return {next = function(_, low, high)
		step()
		return low + state % (high - low + 1)
	end}
end

local mod_paths = {
	grug_gear = ROOT .. "/mods/ITEMS/grug_gear",
	grug_quality = ROOT .. "/mods/ITEMS/grug_quality",
}
local current_mod = "grug_gear"
local serial, players, shown, receive, chat = {}, {}, {}, {}, {}
local fed_items, fed_lines = {}, {}
core = {
	registered_items = registered, registered_aliases = {}, registered_entities = {},
	get_us_time = function() return 1 end,
	get_modpath = function(name) return mod_paths[name] end,
	get_current_modname = function() return current_mod end,
	get_dir_list = function(path)
		local handle = io.popen('ls "' .. path .. '" 2>/dev/null')
		local out = {}
		for line in handle:lines() do out[#out + 1] = line end
		handle:close()
		return out
	end,
	parse_json = function(text) return (json.decode(text)) end,
	serialize = function(value) serial[#serial + 1] = deep_copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and deep_copy(serial[index]) or nil
	end,
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
	override_item = function(name, fields)
		for key, value in pairs(fields) do registered[name][key] = value end
	end,
	register_tool = function(name, def) registered[name] = def end,
	register_craftitem = function(name, def) registered[name] = def end,
	get_player_by_name = function(name) return players[name] end,
	add_item = function() end,
	formspec_escape = function(text) return text end,
	colorize = function(_, text) return text end,
	show_formspec = function(_, _, form) shown[#shown + 1] = form end,
	close_formspec = function() end,
	chat_send_player = function(_, text) chat[#chat + 1] = text end,
	explode_textlist_event = function(value)
		local kind, index = value:match("^(%u+):(%d+)$")
		return {type = kind, index = tonumber(index)}
	end,
	register_on_player_receive_fields = function(fn) receive[#receive + 1] = fn end,
	get_connected_players = function() return {} end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	log = function() end,
}
local joins = {}
core.register_on_joinplayer = function(fn) joins[#joins + 1] = fn end
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {distance = function(a, b)
	local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(x * x + y * y + z * z)
end}

------------------------------------------------------------------------------
-- Game surface.
------------------------------------------------------------------------------
local function permissive(base)
	return setmetatable(base, {__index = function() return function() end end})
end
local faction_of, level_of = {}, {}
grug_core = {register_tag_visibility = function() end, level_scale = function() return 1 end,
	settlement_socket_anchor = function() return nil end,
	hud_layout = {side_text_width = function() return 400 end, QUEST_WRAP = 400, anchors = {quest_list = {}}},
	feed_item = function(player, stack, count)
		fed_items[#fed_items + 1] = player:get_player_name() .. " " .. ItemStack(stack):get_name() .. " " .. count
	end,
	feed = function(_, kind, text) fed_lines[#fed_lines + 1] = kind .. ": " .. text end}
dofile(ROOT .. "/mods/CORE/grug_core/item_names.lua")
local granted_xp = {}
grug_xp = {get_level = function(player) return level_of[player:get_player_name()] or 1 end,
	register_on_level_change = function() end,
	quest_reward = function(level, weight) return math.floor(weight * (25 + 5 * level) + 0.5) end,
	add_xp = function(player, amount) granted_xp[#granted_xp + 1] = player:get_player_name() .. " " .. amount end}
local purse = {}
grug_money = {MAX = 1000000, format = function(copper) return copper .. "c" end,
	get = function(player) return purse[player:get_player_name()] or 0 end,
	add = function(player, copper) purse[player:get_player_name()] = (purse[player:get_player_name()] or 0) + copper end}
grug_factions = {get_faction = function(player) return faction_of[player:get_player_name()] end,
	same_faction = function() return false end,
	display_name = function(id) return id == "accord" and "The Accord" or "The Throng" end}
dofile(ROOT .. "/mods/PLAYER/grug_factions/service.lua")
grug_classes = permissive({
	registered_races = {human = {faction = "accord"}, orc = {faction = "throng"}},
	get_race = function() return "human" end, get_melee_bonus = function() return 0 end,
	pool_percent_amount = function() return 42 end, register_on_arrival = function() end})
grug_inventory = permissive({BAG_COUNT = 0, wrap_text = function(text) return text end,
	give = function(player, stack) return player:get_inventory():add_item("main", stack) end})
local zone_of_anchor = {["0,0"] = D, ["500,500"] = S}
local BANDS = {[D] = {1, 10}, [S] = {1, 10}}
grug_zones = {id_at = function(x, z) return zone_of_anchor[x .. "," .. z] end,
	get = function(zone)
		local band = BANDS[zone]
		return band and {level_min = band[1], level_max = band[2],
			display_name = zone == D and "Dawnmere Fields" or "Sunscar Flats"} or nil
	end}
local pages = {}
sfinv = {register_page = function(name, def) pages[name] = def end,
	make_formspec = function(_, _, content) return content end}

-- grug_mobs: the spawn regions over the sample recipes (the real parser)
-- and the names by slot: each zone names its roles its own way.
local spawn_files = {}
local function spawns(zone)
	if spawn_files[zone] == nil then
		local handle = io.open(SAMPLES .. "/grug_mobs/data/zones/" .. zone .. ".spawns.json")
		spawn_files[zone] = handle and json.decode(handle:read("*a")) or false
		if handle then handle:close() end
	end
	return spawn_files[zone] or nil
end
local DISPOSITION = {small_boar = "neutral", large_rat = "aggressive", giant_crab = "neutral",
	wolf = "aggressive", bear = "aggressive"}
local NAMES = {
	[D] = {small_boar = "Barley Piglet", large_rat = "Barn Rat", giant_crab = "Wreck Snapper",
		wolf = "Hill Wolf", bear = "Ridge Bear"},
	[S] = {small_boar = "Scrub Piglet", large_rat = "Dust Rat", giant_crab = "Salt Snapper",
		wolf = "Dune Wolf", bear = "Rock Bear"},
}
local kill_hooks, drop_hooks = {}, {}
grug_mobs = {
	register_on_eligible_kill = function(fn) kill_hooks[#kill_hooks + 1] = fn end,
	register_participant_drop_hook = function(fn) drop_hooks[#drop_hooks + 1] = fn end,
	register_kill_loot_hook = function() end, register_boss_reward_hook = function() end,
	subtype = function() return nil end,
	disposition = function(name) return DISPOSITION[name:match("^grug_mobs:(.+)$") or name] end,
	spawn_regions = (function()
		local regions_core = dofile(ROOT .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
		local parsed = {}
		local function recipe(zone)
			if parsed[zone] == nil then
				local data = spawns(zone)
				parsed[zone] = data and data.recipe and
					regions_core.parse_recipe(zone, data.recipe, {band = BANDS[zone] or {1, 60}}) or false
			end
			return parsed[zone] or nil
		end
		local seams = {}
		function seams.get_area(zone, id)
			local r = recipe(zone)
			return r and (r.kind_by_id[id] or r.camp_by_id[id]) or nil
		end
		function seams.area_roles(zone, id)
			local unit = seams.get_area(zone, id)
			if not unit then return nil end
			local set = {}
			for role in pairs(unit.roles) do set[role] = true end
			return set
		end
		function seams.zone_area_ids(zone)
			local r, out = recipe(zone), {}
			for _, kind in ipairs(r and r.kinds or {}) do out[#out + 1] = kind.id end
			for _, camp in ipairs(r and r.camps or {}) do out[#out + 1] = camp.id end
			return out
		end
		function seams.leader() return nil end
		function seams.zone_place() return nil end
		function seams.clash_site() return nil end
		function seams.place() return nil end
		-- Every placeholder target reads its area's name, without a
		-- direction (the region maps are not built here).
		function seams.describe() return nil, "no region map in the fixture" end
		return seams
	end)(),
}
do
	local map = {}
	local regions = grug_mobs.spawn_regions
	for _, zone in ipairs({D, S}) do
		for _, id in ipairs(regions.zone_area_ids(zone)) do
			for role, range in pairs(regions.get_area(zone, id).levels_by_role) do
				map[("%s/%s/L%d-%d"):format(zone, role, range[1], range[2])] = NAMES[zone][role]
			end
		end
	end
	grug_mobs.names = dofile(ROOT .. "/tools/r38_b1/names_stub.lua").of(ROOT, map)
end
for role in pairs(DISPOSITION) do
	core.registered_entities["grug_mobs:" .. role] = {description = role}
end

-- The real gear and item quality (the reward stacks), then plain items.
dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
current_mod = "grug_quality"
grug_jobs = {PROFESSIONS = {}, station_info = function(station) return {id = station} end,
	_flatten_inputs = function() return {} end, ingredient_list = function() return {} end}
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")
for name, description in pairs({["fx:healing_potion"] = "Small Healing Potion",
		["fx:mana_potion"] = "Small Mana Potion", ["mobs:meat_raw"] = "Raw Meat",
		["default:cobble"] = "Cobblestone"}) do
	registered[name] = {description = description}
end
registered["default:tree"] = {description = "Apple Tree", groups = {tree = 1}}

-- Settlements: the two start towns (their races give the NPCs' factions)
-- with a socket for every registered quest NPC.
local settlements = {by_key = {}, order = {}}
local function settlement_registry()
	local races = {dawnmere = {"human", 0, 0}, sunscar = {"orc", 500, 500}}
	for key, row in pairs(races) do
		settlements.by_key[key] = {key = key, race_id = row[1], anchor = {x = row[2], y = 0, z = row[3]},
			sockets = {}}
	end
	settlements.order = {settlements.by_key.dawnmere, settlements.by_key.sunscar}
	-- Every other registered NPC's settlement (npcs.lua) stands far off.
	for _, npc in pairs(grug_quests.registered_npcs) do
		local record = settlements.by_key[npc.settlement]
		if not record then
			record = {key = npc.settlement, race_id = "human", anchor = {x = 9000, y = 0, z = 9000}, sockets = {}}
			settlements.by_key[npc.settlement] = record
			settlements.order[#settlements.order + 1] = record
		end
		table.insert(record.sockets, {id = npc.socket, role = "quest", pos = {x = 0, y = 0, z = 0}})
	end
end
grug_core.settlement_socket_settlements = function() return settlements.order end
grug_core.settlement_sockets_at = function(key) return (settlements.by_key[key] or {sockets = {}}).sockets end

-- grug_quests from the samples, with two code-registered NPCs of the role
-- "foreman" (Round 58's camp foremen), one per faction.
current_mod = "grug_quests"
mod_paths.grug_quests = SAMPLES .. "/grug_quests"
mod_paths.grug_mobs = SAMPLES .. "/grug_mobs"
grug_quests = {}
local base = ROOT .. "/mods/PLAYER/grug_quests/"
-- use.lua reads its object kinds from the real mod's data.
grug_quests.use_objects = {}
for _, file in ipairs({"registry", "state", "labels", "npc", "npcs"}) do dofile(base .. file .. ".lua") end
local Q = grug_quests
Q.register_npc("fx_foreman_accord", {settlement = "dawnmere", socket = "foreman_post", title = "Foreman Hale",
	race = "human", role = "foreman"})
Q.register_npc("fx_foreman_throng", {settlement = "sunscar", socket = "foreman_post", title = "Foreman Grask",
	race = "orc", role = "foreman"})
settlement_registry()
for _, file in ipairs({"validate", "loader", "hud"}) do dofile(base .. file .. ".lua") end
Q.resolve_npc_factions()
Q.bind_role_givers()
local ok, err = pcall(Q.validate_quest_data)
check(ok, "the samples pass the world checks: " .. tostring(err))
ok, err = pcall(Q.validate_registry)
check(ok, "the samples pass the registry checks: " .. tostring(err))
local quest_box = dofile(ROOT .. "/mods/PLAYER/grug_map/quest_box.lua")
local V = Q.validate

------------------------------------------------------------------------------
-- Players and NPCs.
------------------------------------------------------------------------------
local function make_player(name, faction, level)
	local meta, lists = {}, {main = {}}
	for i = 1, 16 do lists.main[i] = ItemStack("") end
	local player = {}
	function player:get_player_name() return name end
	function player:is_player() return true end
	function player:get_hp() return 20 end
	function player:get_pos() return {x = 1, y = 2, z = 3} end
	function player:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end}
	end
	local inv = {}
	function inv:get_list(list) return lists[list] end
	function inv:get_stack(list, i) return ItemStack(lists[list][i]) end
	function inv:set_stack(list, i, stack) lists[list][i] = ItemStack(stack); return true end
	function inv:add_item(list, stack)
		local rest = ItemStack(stack)
		for pass = 1, 2 do
			for _, slot in ipairs(lists[list]) do
				if (pass == 1) ~= slot:is_empty() then rest = slot:add_item(rest) end
			end
		end
		return rest
	end
	function player:get_inventory() return inv end
	function player:give(item) return inv:add_item("main", item) end
	function player:slots() return lists.main end
	function player:find(item)
		for _, slot in ipairs(lists.main) do if slot:get_name() == item then return slot end end
	end
	function player:raw_state() return meta["grug_quests:state"] end
	function player:set_raw_state(value) meta["grug_quests:state"] = value end
	players[name] = player
	faction_of[name], level_of[name] = faction, level or 1
	return player
end
local function npc_entity(npc)
	local def = Q.registered_npcs[npc]
	return {_grug_start = def.settlement, _grug_socket = def.socket, object = {
		is_valid = function() return true end, get_pos = function() return {x = 1, y = 2, z = 3} end}}
end
local sessions_entity = {}
-- Opens `npc`'s dialog on quest `id` (its row) and returns the formspec.
local function dialogue(player, npc, id)
	for index, row in ipairs(Q.npc_quests(player, npc)) do
		if row.id == id then
			shown = {}
			sessions_entity[player:get_player_name()] = npc_entity(npc)
			Q.open_npc(player, sessions_entity[player:get_player_name()], index)
			return shown[#shown] or ""
		end
	end
	return ""
end
-- Sends dialog fields (the real handler) and returns the redrawn formspec.
local function click(player, fields)
	shown = {}
	for _, fn in ipairs(receive) do fn(player, "grug_quests:dialogue", fields) end
	return shown[#shown] or ""
end
local function listed(player, npc, id)
	for _, row in ipairs(Q.npc_quests(player, npc)) do if row.id == id then return row end end
end
local function journal_row(player, id)
	for _, row in ipairs(Q.journal(player).quests) do if row.id == id then return row end end
end
local function mob(name)
	return {description = name, object = {}}
end
local function kill(player, name, times)
	for _ = 1, times or 1 do Q.credit_kill(player, mob(name), {x = 0, y = 0, z = 0}) end
end

------------------------------------------------------------------------------
-- A. The shared quest.
------------------------------------------------------------------------------
local CROP = "qs_crop_thieves"
do
	local def = Q.registered_quests[CROP]
	eq(#def.variants, 2, "A one quest, two variants")
	eq(def.giver_variant[EL], D, "A Dawnmere's elder gives the Dawnmere variant")
	eq(def.giver_variant[OE], S, "A Sunscar's elder gives the Sunscar variant")
	check(Q.quests_by_npc[EL][CROP] and Q.quests_by_npc[OE][CROP], "A both givers list the quest")
	eq(table.concat(def.variant_by_key[D].objectives[1].names[1], ","), "Barley Piglet",
		"A Dawnmere's variant counts Dawnmere's piglets")
	eq(table.concat(def.variant_by_key[S].objectives[1].names[1], ","), "Scrub Piglet",
		"A Sunscar's variant counts Sunscar's piglets")
	eq(def.variant_by_key[S].objectives[1].count, 8, "A the count is the quest's")

	local ann = make_player("ann", "accord")
	eq(listed(ann, EL, CROP).status, "available", "A offered at Dawnmere")
	eq(listed(ann, OE, CROP).status, "available", "A ... and listed by Sunscar's elder too (the faction refuses there)")
	-- The giver's text: Dawnmere's elder is human, so the human text.
	local form = dialogue(ann, EL, CROP)
	has(form, "Barley Piglets are eating the Home Fields", "A the giver race's own text, filled in its zone")
	shown = {}
	Q.open_npc(ann, npc_entity(OE))
	eq(#shown, 0, "A Sunscar's elder shows no dialog to an Accord player")
	has(chat[#chat], "I serve only The Throng", "A ... it refuses")
	-- Accept at Dawnmere through the dialog.
	dialogue(ann, EL, CROP)
	click(ann, {accept = "Accept"})
	local active = Q.active_entry(ann, CROP)
	eq(active and active.variant, D, "A the active state keeps the variant")
	eq(active and active.giver, EL, "A ... and the giver")
	check(listed(ann, OE, CROP) == nil, "A while active, Sunscar's elder does not list it")
	-- Only Dawnmere's names count.
	kill(ann, "Scrub Piglet", 3)
	eq(journal_row(ann, CROP).objectives[1].count, 0, "A Sunscar's piglets do not count")
	kill(ann, "Barley Piglet", 8)
	local row = journal_row(ann, CROP)
	check(row.ready, "A eight Barley Piglets: ready")
	eq(Q.hud_line(row, 400), "Return to Elian Reed", "A the HUD returns to the variant's turn-in")
	eq(row.zone, D, "A the journal names the variant's zone")
	has(row.description, "Barley Piglets are eating", "A the quest log reads the giver's text")
	check(not Q.turns_in_at(ann, CROP, OE), "A Sunscar's elder is no turn-in of Ann's variant")
	eq(listed(ann, EL, CROP).status, "ready", "A ready at Dawnmere's elder")
	-- The completion text at the turn-in; the potion choice.
	form = dialogue(ann, EL, CROP)
	has(form, "The fields are quiet again", "A the completion text at the turn-in")
	lacks(form, "Barley Piglets are eating", "A ... in place of the quest text")
	has(form, "and one of:\n  Small Healing Potion × 2\n  Small Mana Potion × 2",
		"A a plain choice reads its name and count, one per line")
	form = click(ann, {choice_1 = "1"})
	has(form, "Chosen:\nSmall Healing Potion", "A the picked plain choice's tooltip lines in the text")
	has(form, "Chosen: Small Healing Potion (see above)", "A ... and its name under the icons")
	click(ann, {turnin = "Complete"})
	eq(Q.status(ann, CROP), "completed", "A turned in")
	eq(ann:find("fx:healing_potion"):get_count(), 2, "A the picked two healing potions")
	check(ann:find("fx:mana_potion") == nil, "A ... and not the other choice")
	check(listed(ann, OE, CROP) == nil, "A not offered in Sunscar afterwards")
	check(listed(ann, EL, CROP) == nil, "A ... nor in Dawnmere")
	check(not Q.accept(ann, CROP, OE), "A Sunscar's elder cannot give it again")

	-- A Throng player takes the Sunscar variant: Sunscar's text and names.
	local bo = make_player("bo", "throng")
	form = dialogue(bo, OE, CROP)
	has(form, "Piglets dig up the Wellfields", "A the variant's own text")
	check(Q.accept(bo, CROP, OE), "A accepted at Sunscar")
	kill(bo, "Barley Piglet", 8)
	check(not journal_row(bo, CROP).ready, "A Dawnmere's piglets do not count for Sunscar's variant")
	kill(bo, "Scrub Piglet", 8)
	row = journal_row(bo, CROP)
	check(row.ready, "A Sunscar's piglets do")
	eq(Q.hud_line(row, 400), "Return to Gara Stonevoice", "A returns to Sunscar's elder")
	-- Round 59: the quest log's level line names the variant's zone, not the
	-- shared quest's home file's (Dawnmere's).
	local log = quest_box.content({quest_selected = CROP}, Q.journal(bo), {x = 13.4, y = 1.05, w = 7, h = 10.7})
	has(log, " · Sunscar Flats", "A the quest log names the zone of the variant taken")
	lacks(log, "Dawnmere Fields", "A ... not the quest's home zone")
	form = dialogue(bo, OE, CROP)
	has(form, "The wells are safe", "A the variant's completion text")
	check(not Q.accept(bo, CROP, EL), "A not accepted twice")
	check(not Q.accept(bo, "qs_story_landing", OE), "A an NPC that does not give a quest cannot give it")

	-- An active entry saved before variants (no variant, no giver): the
	-- first variant's objectives and turn-in.
	local cy = make_player("cy", "accord")
	cy:set_raw_state(core.serialize({active = {[CROP] = {[1] = 5}}, completed = {}, tracked = {CROP}, hud = true}))
	row = journal_row(cy, CROP)
	eq(row and row.objectives[1].count, 5, "A an old entry keeps its counter")
	eq(row and row.npc, EL, "A ... and follows the first variant")
	kill(cy, "Barley Piglet", 3)
	check(journal_row(cy, CROP).ready, "A ... counted by its names")
	check(Q.turns_in_at(cy, CROP, EL), "A ... handed in at its turn-in")
	check(not Q.turn_in(cy, CROP), "A a quest with a choice refuses without a pick")
	check(Q.turn_in(cy, CROP, 2), "A ... and completes with one")
	eq(cy:find("fx:mana_potion"):get_count(), 2, "A the second choice")
end

------------------------------------------------------------------------------
-- B. The role giver.
------------------------------------------------------------------------------
do
	local GUILD = "qs_guild_stone"
	local def = Q.registered_quests[GUILD]
	eq(def.giver_variant.fx_foreman_throng, S, "B the Throng's foreman gives the role quest")
	eq(def.giver_variant.fx_foreman_accord, nil, "B the Accord's foreman does not (the faction filter)")
	local bo = players.bo
	eq(listed(bo, "fx_foreman_throng", GUILD).status, "available", "B offered by the Throng's foreman")
	check(listed(bo, "fx_foreman_accord", GUILD) == nil, "B not listed by the Accord's foreman")
	check(Q.accept(bo, GUILD, "fx_foreman_throng"), "B accepted at the foreman")
	bo:give("default:cobble 5")
	check(Q.turns_in_at(bo, GUILD, "fx_foreman_throng"), "B handed in at the foreman")
	check(Q.turn_in(bo, GUILD), "B turned in")
end

------------------------------------------------------------------------------
-- C. Story and free play in the lists and the markers.
------------------------------------------------------------------------------
do
	local di = make_player("di", "accord", 1)
	local states = Q.marker_states(di)
	eq(states[EL], "story_available", "C an available story quest: the story marker")
	eq(Q.marker_parts(states[EL]), "available", "C ... its status on its own")
	check(select(2, Q.marker_parts(states[EL])), "C ... and its story part")
	local form = dialogue(di, EL, "qs_story_landing")
	has(form, Q.STORY_COLOR .. "Story", "C the dialog's Story category in the accent")
	has(form, "#b8b8b8Side quests", "C ... and the side quests' header")
	has(form, Q.STATUS_COLORS.available .. "  The Landing", "C a story quest keeps its status colour")
	-- A ready side quest at a mixed giver still shows.
	check(Q.accept(di, "qs_crop_thieves", EL), "C a side quest accepted")
	kill(di, "Barley Piglet", 8)
	eq(Q.marker_states(di)[EL], "ready", "C a ready side quest wins over an available story quest")
	-- The quest log's categories.
	check(Q.accept(di, "qs_story_landing", EL), "C the story quest accepted")
	local session = {quest_selected = "qs_story_landing"}
	local log = quest_box.content(session, Q.journal(di), {x = 13.4, y = 1.05, w = 7, h = 10.7})
	has(log, Q.STORY_COLOR .. "Story", "C the quest log's Story category")
	has(log, "Side quests", "C ... and the side quests")
	local entries = log:match("textlist%[[^;]*;[^;]*;grug_quest_list;([^;]*);")
	check(entries and entries:find("Story", 1, true) < entries:find("Crop Thieves", 1, true),
		"C story quests first in the log")
	eq(session.quest_rows[1], nil, "C a header selects no quest")
	check(quest_box.handle(di, session, {grug_quest_list = "CHG:1"}), "C a click on a header redraws the log")
	eq(session.quest_selected, "qs_story_landing", "C ... and keeps the selected quest")
	eq(session.quest_rows[2], "qs_story_landing", "C the story quest under its header")
	kill(di, "Wreck Snapper", 4)
	eq(Q.marker_states(di)[EL], "story_ready", "C two ready quests, one a story quest: the story marker")
	check(Q.turn_in(di, "qs_story_landing"), "C the story step turned in")
	level_of.di = 2
	eq(listed(di, EL, "qs_story_word").status, "available", "C the chain's next step opens")
	-- Every marker value has its map texture (tools/r57_qsys/render_story_icons.py).
	for _, status in ipairs(Q.MARKER_STATUSES) do
		for _, prefix in ipairs({"", "story_"}) do
			local path = ROOT .. "/mods/PLAYER/grug_map/textures/grug_map_quest_" .. prefix .. status .. ".png"
			local handle = io.open(path, "rb")
			check(handle ~= nil, "C the map texture of " .. prefix .. status)
			if handle then handle:close() end
		end
	end
	-- The free follow-up opens with its free predecessor.
	check(listed(di, CK, "qs_free_b") == nil, "C a free follow-up hidden before its predecessor")
end

------------------------------------------------------------------------------
-- D. Choice rewards: equipment with fixed enchants.
------------------------------------------------------------------------------
do
	local ed = make_player("ed", "accord", 5)
	local form = dialogue(ed, EL, "qs_armor")
	has(form, "You will choose one reward:", "D the offer shows the choice")
	has(form, "item_image[7.80,5.95;1.15,1.15;grug_gear:chest_cloth_patch]", "D ... the cloth robe as an icon")
	has(form, "item_image[10.60,5.95;1.15,1.15;grug_gear:chest_metal_bronze]", "D ... the third, the chestplate")
	has(form, "Item level 5", "D ... its tooltip names the reward's item level")
	has(form, "of the Owl", "D ... and its fixed enchant")
	-- Round 57 follow-up (the user): the enchants readable without hovering.
	has(form, "and one of:\n  Patch Robe of the Owl (Suffix: +2 Intelligence (T1))\n" ..
		"  Quick Light Jerkin (Prefix: +1 Dexterity (T1))\n  Heavy Bronze Chestplate (Prefix: +2 Strength (T1))",
		"D the offer names each choice by its enchanted name with its enchants")
	lacks(form, "Patch Robe,", "D ... never by the base name")
	has(form, "Hover an item to see its tooltip.", "D the offer's hint")
	lacks(form, "choice_1", "D no choice button before the turn-in")
	click(ed, {accept = "Accept"})
	kill(ed, "Hill Wolf", 8)
	form = dialogue(ed, EL, "qs_armor")
	has(form, "Choose your reward:", "D the turn-in asks for the choice")
	has(form, "Pick an item to see its enchantments above, or hover it.", "D ... with the hint before a pick")
	lacks(form, "Chosen:", "D ... and no chosen reward yet")
	has(form, "item_image_button[7.80,5.95;1.15,1.15;grug_gear:chest_cloth_patch;choice_1;]",
		"D ... selectable buttons")
	has(form, "tooltip[choice_2;", "D ... each with its tooltip")
	has(form, "button[7.8,8.4;2,0.7;turnin;Complete]", "D Complete below them")
	form = click(ed, {turnin = "Complete"})
	has(form, "Choose your reward first.", "D Complete refused without a pick")
	eq(Q.status(ed, "qs_armor"), "ready", "D ... the quest stays")
	form = click(ed, {choice_2 = "2"})
	has(form, "box[9.12,5.87;1.31,1.31;#7ee06a]", "D the picked choice is framed")
	has(form, "Chosen: Quick Light Jerkin (see above)", "D ... and named by its enchanted name")
	has(form, "Chosen:\nQuick Light Jerkin\nItem level 5\nLeather\n", "D the picked stack's tooltip in the text")
	has(form, "Prefix: +1 Dexterity (T1)\nUsable by:", "D ... with its enchant line")
	-- A full inventory: the preflight refuses the picked reward.
	local slots = ed:slots()
	for i = 1, #slots do slots[i] = ItemStack("default:cobble 99") end
	form = click(ed, {turnin = "Complete"})
	has(form, "Make room in your inventory or bags for the rewards.", "D a full inventory refuses")
	eq(Q.status(ed, "qs_armor"), "ready", "D ... and keeps the quest")
	has(form, "box[9.12,5.87;1.31,1.31;#7ee06a]", "D ... and the pick")
	slots[16] = ItemStack("")
	click(ed, {turnin = "Complete"})
	eq(Q.status(ed, "qs_armor"), "completed", "D completed with room for the reward")
	local jerkin = ed:find("grug_gear:chest_leather_light")
	check(jerkin ~= nil, "D the picked leather jerkin")
	local meta = jerkin and jerkin:get_meta()
	eq(meta and meta:get_int("grug_ilvl"), 5, "D at the quest's reward level")
	eq(meta and meta:get_int("grug_quality"), 2, "D one fixed enchant: Uncommon")
	local affixes = jerkin and grug_items.get_affixes(jerkin) or {}
	eq(#affixes == 1 and affixes[1].channel .. ":" .. affixes[1].stat, "prefix:dex", "D the authored enchant")
	has(meta and meta:get_string("description"), "Quick Light Jerkin", "D its name")
	has(meta and meta:get_string("description"), "Item level 5", "D its tooltip")
	-- The final weapon: prefix and suffix, the receiver's weapon line.
	level_of.ed = 9
	check(Q.accept(ed, "qs_final", EL), "D the weapon quest accepted")
	kill(ed, "Ridge Bear", 5)
	slots[1] = ItemStack("")
	check(Q.turn_in(ed, "qs_final", 1), "D the sword picked")
	local sword = ed:find("grug_gear:sword_bronze")
	eq(sword and sword:get_meta():get_int("grug_quality"), 3, "D prefix and suffix: Rare")
	eq(sword and sword:get_meta():get_int("grug_ilvl"), 9, "D at item level 9")
	has(sword and sword:get_meta():get_string("description"), "Heavy Bronze Sword of the Eagle", "D both enchant words")
	has(sword and sword:get_meta():get_string("description"), "Effective at level 9",
		"D the tooltip initialised for the receiver (grug_inventory.give's step)")
	has(table.concat(fed_items, "|"), "ed grug_gear:sword_bronze 1", "D the feed line names the reward")
end

------------------------------------------------------------------------------
-- E. The system quest without a dialog.
------------------------------------------------------------------------------
do
	local opened = {}
	grug_mail = {texts = {quest = {title = "Use a mailbox in one of the cities", description = "Find a mailbox.",
		completion = "Your first letter waits."}},
		character_ready = function() return true end,
		register_on_mailbox_open = function(fn) opened[#opened + 1] = fn end}
	dofile(ROOT .. "/mods/PLAYER/grug_mail/quest.lua")
	local def = Q.registered_quests.mailbox_visit
	check(def and def.system and #def.rewards.choices == 0, "E the system quest has no choice")
	local fi = make_player("fi", "throng")
	check(grug_mail.grant_starter_quest(fi), "E granted")
	shown = {}
	for _, fn in ipairs(opened) do fn(fi) end
	eq(Q.status(fi, "mailbox_visit"), "completed", "E turned in by opening a mailbox")
	eq(#shown, 0, "E ... without a dialog")
	has(fed_lines[#fed_lines], "Your first letter waits.", "E its completion line goes to the feed")
	local system_choice = pcall(Q.register_quest, "fx_system_choice", {system = true, turnin_text = "x",
		title = "x", description = "x", rewards = {weight = 1, choices = {{item = "fx:healing_potion"},
		{item = "fx:mana_potion"}}}})
	check(not system_choice, "E a system quest never carries a choice")
end

------------------------------------------------------------------------------
-- F. The load checks.
------------------------------------------------------------------------------
local function read_file(path)
	local handle = assert(io.open(path, "r"))
	local text = handle:read("*a")
	handle:close()
	return text
end
local base_files = {}
for _, zone in ipairs({D, S}) do
	local name = zone .. ".quests.json"
	base_files[#base_files + 1] = {name = name, zone = zone, front = false,
		data = json.decode(read_file(SAMPLES .. "/grug_quests/data/zones/" .. name))}
end
local npcs_before = {}
for id in pairs(Q.registered_npcs) do npcs_before[id] = true end
local loader_world
do
	-- The loader's own world view (loader.lua world_view), through its
	-- validate_quest_data seam.
	local captured
	local world_fn = V.world
	V.world = function(files, world) captured = world; return world_fn(files, world) end
	Q.validate_quest_data(Q.quest_files)
	V.world = world_fn
	loader_world = captured
end
local function quest_of(files, id)
	for _, file in ipairs(files) do
		for _, quest in ipairs(file.data.quests) do if quest.id == id then return quest end end
	end
end
local function run(mutate, world)
	local files = deep_copy(base_files)
	mutate(files)
	local found = V.structure(files, npcs_before)
	local warnings = {}
	if #found == 0 then found, warnings = V.world(files, world or loader_world) end
	return found, warnings
end
local function codes(list)
	local out = {}
	for _, message in ipairs(list) do out[#out + 1] = message:match("%[([EW]%-[%w-]+)%]$") or message end
	return table.concat(out, ",")
end
local found, warnings = run(function() end)
eq(#found, 0, "F the samples pass: " .. table.concat(found, " | "))
eq(#warnings, 0, "F ... without warnings: " .. table.concat(warnings, " | "))
local function refused(label, code, mutate, world)
	local list, warns = run(mutate, world)
	local all = {}
	for _, m in ipairs(list) do all[#all + 1] = m end
	for _, m in ipairs(warns) do all[#all + 1] = m end
	local hit
	for _, message in ipairs(all) do
		if message:find("[" .. code .. "]", 1, true) then hit = message end
	end
	check(hit ~= nil, label .. ": " .. code .. " expected, got: " .. codes(all))
	return hit
end
local function accepted(label, mutate, world)
	local list, warns = run(mutate, world)
	eq(#list, 0, label .. ": no error (" .. codes(list) .. ")")
	return warns
end
local function unflag(files) for _, file in ipairs(files) do file.data.reworked = nil end end
-- Free play and story, only in reworked files.
local function two_follow_ups(files)
	local copy = deep_copy(quest_of(files, "qs_free_b"))
	copy.id, copy.title = "qs_free_c", "Water for the Pot"
	table.insert(files[1].data.quests, copy)
end
refused("a free quest with two follow-ups", "E-free-follow-ups", two_follow_ups)
accepted("... in an unreworked file", function(files) two_follow_ups(files); unflag(files) end)
-- Round 59: the follow-ups are counted per faction (the givers' factions),
-- so a free quest may have one follow-up for each; a follow-up given to
-- both factions counts in each.
local function throng_follow_up(files, givers)
	local copy = deep_copy(quest_of(files, "qs_free_b"))
	copy.id, copy.title, copy.giver, copy.turnin = "qs_free_c", "Water for the Pot", nil, nil
	copy.variants = {{zone = S, givers = givers or {"r20_orc_start_cook"}}}
	table.insert(files[2].data.quests, copy)
end
accepted("one follow-up per faction", throng_follow_up)
has(refused("a follow-up given to both factions counts in each", "E-free-follow-ups", function(files)
	throng_follow_up(files)
	quest_of(files, "qs_free_c").variants[1].givers = {{role = "foreman", faction = "throng"},
		{role = "foreman", faction = "accord"}}
end), "not 2 for The Accord (qs_free_b, qs_free_c)", "F ... named with the faction")
accepted("a story quest with two follow-ups", function(files)
	two_follow_ups(files)
	quest_of(files, "qs_free_a").story = true
end)
refused("a free quest requiring two quests", "E-free-requires", function(files)
	quest_of(files, "qs_free_b").requires = {"qs_free_a", "qs_crop_thieves"}
end)
accepted("... in an unreworked file", function(files)
	quest_of(files, "qs_free_b").requires = {"qs_free_a", "qs_crop_thieves"}
	unflag(files)
end)
refused("a chain of free quests", "E-free-chain", function(files)
	local copy = deep_copy(quest_of(files, "qs_free_b"))
	copy.id, copy.requires = "qs_free_c", {"qs_free_b"}
	table.insert(files[1].data.quests, copy)
end)
accepted("the story chain", function() end)
refused("the rework flag is true or absent", "E-type", function(files) files[1].data.reworked = "yes" end)
-- The reward budget.
local function enchanted_reward(files, id, enchants)
	local affixes = {{channel = "prefix", stat = "str"}, {channel = "suffix", stat = "max_hp_percent"}}
	if enchants == 1 then affixes = {affixes[1]} end
	quest_of(files, id).rewards.choices = {
		{item = "grug_gear:chest_metal_bronze", affixes = affixes},
		{item = "grug_gear:chest_leather_light", affixes = {{channel = "prefix", stat = "dex"}}}}
end
local over_budget = function(files)
	enchanted_reward(files, "qs_story_wolves", 1)
	enchanted_reward(files, "qs_free_a", 1)
end
has(refused("three one-enchant rewards in a zone", "E-reward-budget", over_budget),
	"elandor_dawnmere_fields has 3 equipment rewards with 1 enchant", "F ... named with its zone")
refused("two two-enchant rewards in a zone", "E-reward-budget", function(files)
	enchanted_reward(files, "qs_story_wolves", 2)
end)
accepted("... not in an unreworked file", function(files) over_budget(files); unflag(files) end)
local capital_world = setmetatable({capital = function(zone) return zone == D end}, {__index = loader_world})
accepted("... not in a capital", over_budget, capital_world)
local warns = accepted("two one-enchant rewards at one level", function(files)
	enchanted_reward(files, "qs_story_wolves", 1)
end)
check(codes(warns):find("W-reward-levels", 1, true), "F ... warned to spread them: " .. codes(warns))
refused("an enchant outside the item's pool", "E-reward-affixes", function(files)
	quest_of(files, "qs_armor").rewards.choices[1].affixes = {{channel = "prefix", stat = "armor_rating"}}
end)
refused("a single choice", "E-rewards", function(files)
	quest_of(files, "qs_armor").rewards.choices = {{item = "fx:healing_potion"}}
end)
-- A reward is never the requested item.
refused("a reward that is the requested item", "E-reward-requested", function(files)
	quest_of(files, "qs_free_a").rewards.items = {{item = "mobs:meat_raw", count = 3}}
end)
refused("... or of the requested group", "E-reward-requested", function(files)
	quest_of(files, "qs_free_b").rewards.items = {{item = "default:tree", count = 2}}
end)
accepted("... not in an unreworked file", function(files)
	quest_of(files, "qs_free_a").rewards.items = {{item = "mobs:meat_raw", count = 3}}
	unflag(files)
end)
-- The night count.
warns = accepted("eight rats at night", function(files) quest_of(files, "qs_night_shift").objectives[1].count = 8 end)
check(codes(warns):find("W-night-count", 1, true), "F a night count of a day count's size warns: " .. codes(warns))
warns = accepted("one rat at night", function(files) quest_of(files, "qs_night_shift").objectives[1].count = 1 end)
check(codes(warns):find("W-night-count", 1, true), "F ... and one far below a third: " .. codes(warns))
warns = accepted("... in an unreworked file", function(files)
	quest_of(files, "qs_night_shift").objectives[1].count = 8
	unflag(files)
end)
eq(codes(warns), "", "F ... no warning there")
-- No repeatable quests.
has(refused("repeatable", "E-unknown-key", function(files)
	quest_of(files, "qs_free_a").repeatable = {cooldown = 1800}
end), "unknown field 'repeatable'", "F repeatable is an unknown field")
-- The variant shapes and the hub rule.
refused("a variant's giver from another zone's hub", "E-giver-not-hub", function(files)
	quest_of(files, CROP).variants[2].givers = {EL}
end)
refused("a giver in two variants", "E-variant", function(files)
	quest_of(files, CROP).variants[2].zone = D
end)
refused("an override list of the wrong length", "E-variant", function(files)
	quest_of(files, CROP).variants[2].objectives = {{area = "wellfields"}, {area = "wellfields"}}
end)
refused("an override of a fixed field", "E-unknown-key", function(files)
	quest_of(files, CROP).variants[2].objectives = {{area = "wellfields", count = 4}}
end)
refused("a variant without its zone's area", "E-unknown-area", function(files)
	quest_of(files, CROP).variants[2].objectives = nil
end)
refused("giver and variants together", "E-variant", function(files) quest_of(files, CROP).giver = EL end)
has(refused("a shared quest outside its first variant's file", "E-variant", function(files)
	local quest = quest_of(files, CROP)
	quest.variants[1], quest.variants[2] = quest.variants[2], quest.variants[1]
end), "lives in the file of its first variant's zone", "F one home file per shared quest")
refused("a variant zone without a quest file", "E-variant", function(files)
	quest_of(files, CROP).variants[2].zone = "kragmar_redtusk_savanna"
end)
refused("a shared quest's title with a placeholder", "E-placeholder", function(files)
	quest_of(files, CROP).title = "Crop Thieves of {name:home_fields}"
end)
refused("a text keyed by a stranger", "E-texts", function(files)
	quest_of(files, CROP).texts = {r20_human_start_cook = "Not my quest."}
end)
refused("a variant text naming another zone's kind", "E-placeholder-target", function(files)
	quest_of(files, CROP).variants[2].text = "Piglets in the {name:home_fields}."
end)
refused("a role of no faction", "E-variant", function(files)
	quest_of(files, "qs_guild_stone").variants[1].givers = {{role = "foreman", faction = "nobody"}}
end)
refused("a giver without a turn-in of its faction", "E-turnin-faction", function(files)
	quest_of(files, CROP).variants[2].turnins = {EL}
end)
refused("a travel variant turning in elsewhere", "E-talk-turnin", function(files)
	local quest = quest_of(files, "qs_story_word")
	quest.giver, quest.turnin = nil, nil
	quest.variants = {{zone = D, givers = {EL}, turnins = {EL}}}
end)

if failures > 0 then
	error(("R57 QSYS QUESTS FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R57 QSYS QUESTS PASS checks=%d"):format(checks))
