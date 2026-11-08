-- Round 69 lane QUESTMAP portable test (LuaJIT): quest-drop markers on real
-- data. The REAL grug_quests loader over the shipped quest files, recipes and
-- mob names (tools/r56_questmap/model.lua's harness), the real state.lua,
-- hud.lua and the map's targets.lua and quest_box.lua:
--   S  which quests have a named source: exactly the fourteen of the plan,
--      in every variant, each with the names the drop counts; every other
--      item objective has none;
--   T  targets.lua over the shipped recipes (one made-up region per kind and
--      camp; that each forms a region on every seed is
--      tools/r28_regions/quest_targets.py's, the real index the lane's
--      engine probe's): every variant of the fourteen gets a target, a ring
--      for an area, a crosshair for a leader or garrison camp; every other
--      item objective none;
--   J  the journal: the count comes from the inventory, so the marker goes
--      when the item is carried; the row carries the source;
--   L  the objective line in the quest log, the tooltips and the HUD, with
--      its width; the plain lines stay as they were;
--   X  the Bannerbreak and Glassroot texts;
--   D  the real giver's dialogue (npc.lua) at every giver of every quest: the
--      objective line of the variant that giver gives, with its source
--      (Round 69 follow-up); the player accepting there gets that variant.
-- Usage (repo root): luajit tools/r69_questmap/portable_test.lua [REPO]
local repo = arg and arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end

-- The model's harness puts every global back when it returns: keep what the
-- real files need here, as they stand once the loader ran.
local KEEP = {"core", "grug_core", "grug_zones", "grug_mobs", "grug_quests", "grug_xp", "grug_money",
	"ItemStack", "vector"}
local real_dofile, kept = dofile, nil
rawset(_G, "dofile", function(path)
	local result = real_dofile(path)
	if path:find("grug_quests/loader.lua", 1, true) then
		kept = {}
		for _, name in ipairs(KEEP) do kept[name] = rawget(_G, name) end
	end
	return result
end)
real_dofile(repo .. "/tools/r56_questmap/model.lua")(repo)
rawset(_G, "dofile", real_dofile)
for name, value in pairs(kept) do rawset(_G, name, value) end
local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
rawset(table, "copy", deep_copy)
core.serialize = function(value) return value end
core.deserialize = function(value) return value ~= "" and deep_copy(value) or nil end

local Q = grug_quests
local SR = grug_mobs.spawn_regions
-- The quest items' names (grug_mobs registers them from this file).
do
	local handle = assert(io.open(repo .. "/mods/ENTITIES/grug_mobs/data/items.json", "r"))
	for _, row in ipairs(core.parse_json(handle:read("*a"))) do
		core.registered_items[row.id] = {description = row.name, short_description = row.name}
	end
	handle:close()
end

-- The state and the HUD over the registered quests.
rawset(_G, "grug_inventory", {BAG_COUNT = 0, HOTBAR_STORE = "hotbar_store"})
rawset(_G, "grug_factions", {same_faction = function() return false end})
real_dofile(repo .. "/mods/PLAYER/grug_quests/state.lua")
grug_core.hud_layout.QUEST_WRAP = 38
real_dofile(repo .. "/mods/PLAYER/grug_quests/hud.lua")
local quest_box = real_dofile(repo .. "/mods/PLAYER/grug_map/quest_box.lua")
local targets = real_dofile(repo .. "/mods/PLAYER/grug_map/targets.lua")

local FOURTEEN = {
	"accord_main_orders", "archshadow_front_02", "border_packets", "capital_raw_meat",
	"dawnmere_pantry_02", "frostbarrow_cutting_04", "gordrazhak_fangs", "highcourt_provisions_01",
	"kezamba_smokehouse_02", "nv_front_01", "speargrass_yard_02", "start_crabs", "start_rats",
	"throng_main_04",
}
local ids = {}
for id in pairs(Q.registered_quests) do ids[#ids + 1] = id end
table.sort(ids)
eq(#ids, 393, "S the shipped quests") -- Round 71 L20: the Expedition's group quest; Round 72: The Second Shift's and The Last Mint's

-- S -----------------------------------------------------------------------
local variants_seen, sourced_items, plain_items = 0, 0, 0
do
	local sourced = {}
	for _, id in ipairs(ids) do
		local def = Q.registered_quests[id]
		for _, key in ipairs(def.variant_order) do
			local variant = def.variant_by_key[key]
			local has_source, has_drop = false, {}
			for _, drop in ipairs(variant.quest_drops) do has_drop[drop.item] = true end
			for _, objective in ipairs(variant.objectives) do
				if objective.type == "item" then
					if objective.sources then
						has_source = true
						sourced_items = sourced_items + 1
						check(type(objective.source) == "string" and objective.source ~= "",
							"S " .. id .. "/" .. key .. " has names: " .. tostring(objective.source))
					else
						plain_items = plain_items + 1
						check(not has_drop[objective.item], "S " .. id .. "/" .. key .. " drops its item")
						eq(objective.source, nil, "S " .. id .. " no source text")
					end
				else
					eq(objective.sources, nil, "S " .. id .. " only item objectives")
				end
			end
			if has_source then
				variants_seen = variants_seen + 1
				sourced[id] = (sourced[id] or 0) + 1
			end
		end
		if sourced[id] then
			eq(sourced[id], #def.variant_order, "S every variant of " .. id)
		end
	end
	local list = {}
	for id in pairs(sourced) do list[#list + 1] = id end
	table.sort(list)
	eq(table.concat(list, " "), table.concat(FOURTEEN, " "), "S exactly the plan's fourteen quests")
	-- The names a drop counts are the source's, and two sources of one role
	-- (accord_main_orders: its own and a drop) read once.
	local packet = Q.registered_quests.border_packets
	for _, key in ipairs(packet.variant_order) do
		local variant = packet.variant_by_key[key]
		local names = {}
		for name in pairs(variant.quest_drops[1].name_set) do names[#names + 1] = name end
		table.sort(names)
		local shown = variant.objectives[1].source
		for _, name in ipairs(names) do
			check(shown:find(name, 1, true) ~= nil, "S the drop's name " .. name .. " in " .. shown)
		end
	end
	eq(Q.registered_quests.border_packets.variant_by_key.kragmar_bannerbreak_mesa.objectives[1].source,
		"Trench Archer", "S Bannerbreak's Packet reads its archers")
	local orders = Q.registered_quests.accord_main_orders.objectives[1]
	eq(#orders.sources, 2, "S the Orders name their source twice")
	check(orders.source == nil or not orders.source:find(" or ", 1, true), "S ...and read once")
end

-- T -----------------------------------------------------------------------
-- Every kind and camp of the shipped recipes as one region, leaders at a
-- spot of their own.
local function spot_of(text)
	local sum = 7
	for i = 1, #text do sum = (sum * 31 + text:byte(i)) % 100003 end
	return sum, sum * 3 % 100003
end
local zone_regions = {}
local function zone_map(zone)
	local regions = {}
	for _, id in ipairs(SR.zone_area_ids(zone)) do
		local unit = SR.get_area(zone, id)
		local x, z = spot_of(zone .. "/" .. id)
		regions[#regions + 1] = {kind = {id = id, roles = unit.roles}, x = x, z = z, size = 9}
	end
	zone_regions[zone] = #regions
	return {regions = regions}
end
local index = targets.build({
	zone_ids = SR.zone_ids,
	map = function(zone) return SR.zone_has_recipe(zone) and zone_map(zone) or nil end,
	leader_roles = SR.leader_roles,
	leader_pos = function(role)
		local x, z = spot_of(role)
		return {x = x, z = z}
	end,
})
local lookup = {
	npc = function() return nil end,
	place = function() return nil end,
	-- A garrison camp's anchor (window.lua: the settlement of that key).
	area = function(ref)
		local zone, id = ref:match("^([^/]+)/(.+)$")
		local poi = grug_mobs.pvp_garrison.poi(id)
		if not (poi and poi.zone_id == zone) then return nil end
		local x, z = spot_of(id)
		return {x = x, z = z}
	end,
	role = function() return nil end,
}
local HERE = {x = 0, z = 0}
-- Rings or crosshairs per quest in the data (a leader, a garrison camp).
local CROSSHAIR = {accord_main_orders = true, frostbarrow_cutting_04 = true, throng_main_04 = true}
do
	local in_fourteen = {}
	for _, id in ipairs(FOURTEEN) do in_fourteen[id] = true end
	for _, id in ipairs(FOURTEEN) do
		local def = Q.registered_quests[id]
		for _, key in ipairs(def.variant_order) do
			local variant = def.variant_by_key[key]
			local one = {objectives = variant.objectives, zone = variant.zone}
			local found = targets.targets(index, one, nil, HERE, lookup)
			local where = "T " .. id .. "/" .. key
			check(#found.crosshairs + #found.rings > 0, where .. " has a target")
			if CROSSHAIR[id] then
				eq(#found.crosshairs, 1, where .. " a crosshair")
				eq(#found.rings, 0, where .. " no ring")
			else
				check(#found.rings > 0, where .. " rings for an area")
				eq(#found.crosshairs, 0, where .. " no crosshair")
			end
			-- Each sourced objective is marked by name, in `objectives`.
			local marked = {}
			for _, list in ipairs({found.crosshairs, found.rings}) do
				for _, mark in ipairs(list) do
					for _, k in ipairs(mark.objectives) do marked[k] = true end
				end
			end
			for k, objective in ipairs(variant.objectives) do
				if objective.sources then check(marked[k], where .. " objective " .. k .. " marked") end
			end
			-- Finished: no marker.
			local done = {}
			for k, objective in ipairs(variant.objectives) do
				done[k] = {count = objective.count, required = objective.count}
			end
			found = targets.targets(index, one, done, HERE, lookup)
			eq(#found.crosshairs + #found.rings, 0, where .. " finished marks nothing")
		end
	end
	-- Every other item objective marks nothing, on its own.
	local plain = 0
	for _, id in ipairs(ids) do
		local def = Q.registered_quests[id]
		for _, key in ipairs(def.variant_order) do
			local variant = def.variant_by_key[key]
			for _, objective in ipairs(variant.objectives) do
				if objective.type == "item" and not objective.sources then
					plain = plain + 1
					local found = targets.targets(index, {objectives = {objective}, zone = variant.zone},
						nil, HERE, lookup)
					eq(#found.crosshairs + #found.rings, 0, "T " .. id .. " a plain item marks nothing")
				end
			end
		end
	end
	check(plain > 83, "T the plain objectives were read: " .. plain)
	-- Two objectives on two areas: a ring each, one finished drops its own.
	local pantry = Q.registered_quests.dawnmere_pantry_02
	local both = targets.targets(index, pantry, nil, HERE, lookup)
	eq(#both.rings, 2, "T the pantry's two areas")
	local left = targets.targets(index, pantry,
		{{count = pantry.objectives[1].count, required = pantry.objectives[1].count},
			{count = 0, required = pantry.objectives[2].count}}, HERE, lookup)
	eq(#left.rings, 1, "T a finished objective drops only its ring")
	eq(left.rings[1].objectives[1], 2, "T the open objective keeps its ring")
end

-- J -----------------------------------------------------------------------
local function stack(name, count)
	return {get_name = function() return name end, get_count = function() return count end}
end
local function make_player(entry)
	local held, meta = {}, {["grug_quests:state"] = {
		active = {border_packets = entry}, completed = {}, tracked = {"border_packets"}, hud = true}}
	local player = {held = held}
	function player:get_player_name() return "ann" end
	function player:get_meta()
		return {get_string = function(_, key) return meta[key] or "" end,
			set_string = function(_, key, value) meta[key] = value end}
	end
	function player:get_inventory()
		return {get_list = function(_, list) return list == "main" and held or {} end}
	end
	return player
end
do
	-- The text's directions need a world's regions; this reads objectives.
	Q.quest_text = function() return "" end
	local PACKET = "grug_mobs:runners_packet"
	local variant = Q.registered_quests.border_packets.variant_by_key.kragmar_bannerbreak_mesa
	local player = make_player({variant = "kragmar_bannerbreak_mesa", giver = variant.givers[1]})
	local one = {objectives = variant.objectives, zone = variant.zone}
	local quest = Q.journal(player).quests[1]
	eq(quest.objectives[1].count, 0, "J nothing carried")
	eq(quest.objectives[1].source, "Trench Archer", "J the row carries the source")
	local found = targets.targets(index, one, quest.objectives, HERE, lookup)
	eq(#found.rings, 1, "J the ring while the Packet is missing")
	eq(found.rings[1].objectives[1], 1, "J it names the objective")
	player.held[1] = stack(PACKET, 1)
	quest = Q.journal(player).quests[1]
	eq(quest.objectives[1].count, 1, "J the Packet carried counts")
	found = targets.targets(index, one, quest.objectives, HERE, lookup)
	eq(#found.rings + #found.crosshairs, 0, "J the marker goes when it is carried")
end

-- L -----------------------------------------------------------------------
do
	local variant = Q.registered_quests.border_packets.variant_by_key.kragmar_bannerbreak_mesa
	local function row(objective, count, levels)
		return {type = objective.type, item = objective.item, group = objective.group, count = count,
			required = objective.count, source = objective.source, levels = levels}
	end
	local line = quest_box.objective_label(row(variant.objectives[1], 0))
	eq(line, "Bring Runner's Packet: 0/1 (from Trench Archer)", "L the line the plan names")
	eq(quest_box.objective_label(row(variant.objectives[1], 0, {38, 40})),
		"Bring Runner's Packet: 0/1 (from Trench Archer) (level 38\226\128\14740)", "L with its levels")
	eq(quest_box.objective_label({type = "item", group = "tree", count = 0, required = 3}),
		"Bring Any Tree: 0/3", "L a plain item's line is unchanged")
	eq(Q.hud_line({objectives = {row(variant.objectives[1], 0)}}, 38),
		"0/1 Runner's Packet from Trench Archer", "L the HUD line fits its 38 characters")
	eq(Q.hud_line({objectives = {{type = "item", group = "tree", count = 0, required = 3}}}, 38),
		"0/3 Bring Any Tree", "L a plain HUD line is unchanged")
	-- Every quest of the fourteen: the widest line, in the log and the HUD.
	local widest, cut = 0, {}
	for _, id in ipairs(FOURTEEN) do
		local def = Q.registered_quests[id]
		for _, key in ipairs(def.variant_order) do
			local rows = {}
			for k, objective in ipairs(def.variant_by_key[key].objectives) do
				rows[k] = row(objective, 0)
				rows[k].mobs, rows[k].names = objective.mobs, objective.names
				rows[k].npc, rows[k].label = objective.npc, objective.label
			end
			local full = Q.hud_line({objectives = rows}, 400)
			widest = math.max(widest, #full)
			local shown = Q.hud_line({objectives = rows}, 38)
			check(#shown <= 38, "L " .. id .. " keeps the tracker's width")
			if shown ~= full then cut[#cut + 1] = key .. "/" .. id .. ": " .. full end
		end
	end
	print(("  HUD lines: widest %d characters, %d of the variants cut at 38"):format(widest, #cut))
	for _, text in ipairs(cut) do print("    " .. text) end
end

-- X -----------------------------------------------------------------------
do
	local variant = Q.registered_quests.border_packets.variant_by_key.kragmar_bannerbreak_mesa
	local text = variant.description
	check(not text:find("Somewhere in that camp", 1, true), "X the text suggests no world object")
	check(text:find("archers carry a Runner's Packet", 1, true) ~= nil, "X the archers carry it")
	text = Q.registered_quests.border_packets.variant_by_key.elandor_glassroot_wilds.description
	check(text:find("Bring me a Runner's Packet from those fletchers. A path", 1, true) ~= nil,
		"X the Glassroot sentence names the fletchers")
	check(not text:find("from the camp", 1, true), "X ...and no camp the text does not place")
end

-- D -----------------------------------------------------------------------
do
	local DASH = "\226\128\147"
	rawset(_G, "grug_sounds", {play = function() end})
	rawset(_G, "grug_factions", {same_faction = function() return false end,
		serves = function() return true end})
	rawset(_G, "vector", {distance = function() return 1 end})
	core.formspec_escape = core.formspec_escape or function(text) return text end
	core.colorize = core.colorize or function(_, text) return text end
	local shown
	core.show_formspec = function(_, _, form) shown = form end
	core.register_on_player_receive_fields = function() end
	core.register_on_leaveplayer = function() end
	core.register_entity = function() end
	grug_core.register_tag_visibility = function() end
	real_dofile(repo .. "/mods/CORE/grug_core/ui.lua")
	real_dofile(repo .. "/mods/CORE/grug_core/ui_rows.lua")
	grug_core.ui.text_scale = function() return 1 end
	real_dofile(repo .. "/mods/PLAYER/grug_quests/npc.lua")
	Q.completion_text = function() return nil end

	-- The quest's whole detail text at giver `npc`, as offered.
	local reader = make_player(nil)
	function reader:is_player() return true end
	function reader:get_hp() return 20 end
	function reader:get_pos() return {x = 0, y = 0, z = 0} end
	local real_rows = Q.npc_quests
	local function offer(id, npc)
		local def = Q.registered_quests[id]
		Q.npc_by_socket["fixture/" .. npc] = npc
		Q.npc_quests = function()
			return {{id = id, title = def.title, status = "available", level = def.level}}
		end
		shown = nil
		check(Q.open_npc(reader, {_grug_start = "fixture", _grug_socket = npc, object = {
			is_valid = function() return true end, get_pos = function() return {x = 0, y = 0, z = 0} end}}, id),
			"D " .. id .. " opens at " .. npc)
		Q.npc_quests = real_rows
		return shown or ""
	end
	local function has(text, part, label)
		check(text:find(part, 1, true) ~= nil, label .. ": " .. part)
	end
	local function hasnt(text, part, label)
		check(text:find(part, 1, true) == nil, label .. ": no " .. part)
	end

	-- The lines the user read, one per giver.
	local packet = Q.registered_quests.border_packets
	local function packet_offer(key) return offer("border_packets", packet.variant_by_key[key].givers[1]) end
	has(packet_offer("kragmar_bannerbreak_mesa"), "OBJECTIVES\nBring Runner's Packet \195\151 1 (from " ..
		"Trench Archer)\n", "D the Bannerbreak offer")
	-- The level range needs a world's recipes (validate.objective_levels):
	-- the engine run's; here its place in the line.
	local shown_levels = packet.variant_by_key.elandor_glassroot_wilds.objectives[1]
	shown_levels.levels = {38, 40}
	has(packet_offer("elandor_glassroot_wilds"), "OBJECTIVES\nBring Runner's Packet \195\151 1 (from " ..
		"Bandit Fletcher) (level 38" .. DASH .. "40)\n", "D the Glassroot offer")
	shown_levels.levels = nil

	-- Every giver of every quest: the objectives of the variant it gives,
	-- which is what Q.accept records, not the quest's first variant.
	local offers, sourced, moved, widest, widest_line = 0, 0, 0, 0, nil
	for _, id in ipairs(ids) do
		local def = Q.registered_quests[id]
		for npc, key in pairs(def.giver_variant) do
			local form = offer(id, npc)
			offers = offers + 1
			local first = def.variant_by_key[def.variant_order[1]]
			for k, objective in ipairs(def.variant_by_key[key].objectives) do
				local line = Q.objective_action(objective) .. " \195\151 " .. objective.count ..
					(objective.source and " (from " .. objective.source .. ")" or "") ..
					Q.objective_levels_text(objective)
				has(form, "\n" .. line .. "\n", "D " .. id .. " at " .. npc)
				if objective.source then
					sourced = sourced + 1
					if #line > widest then widest, widest_line = #line, line end
				else
					hasnt(line, "(from ", "D " .. id .. " a plain line")
				end
				local other = first.objectives[k]
				if Q.objective_action(other) ~= Q.objective_action(objective) or
						Q.objective_levels_text(other) ~= Q.objective_levels_text(objective) then
					moved = moved + 1
				end
			end
		end
	end
	check(sourced >= 32, "D every sourced row was offered: " .. sourced)
	print(("  offers: %d givers, %d sourced lines, widest %d bytes: %s"):format(offers, sourced, widest,
		tostring(widest_line)))
	print(("  %d lines read their own variant now, not the quest's first"):format(moved))

	-- The player accepting at that giver gets the variant the offer showed.
	local taker = make_player(nil)
	local glassroot = packet.variant_by_key.elandor_glassroot_wilds
	grug_xp.get_level = function() return 39 end
	check(Q.accept(taker, "border_packets", glassroot.givers[1]), "D accept at Glassroot")
	eq(Q.journal(taker).quests[1].objectives[1].source, "Bandit Fletcher",
		"D the log reads the source the offer named")
end

print(("r69_questmap: %d sourced item objectives over %d variants, %d plain, %d checks, %d failures")
	:format(sourced_items, variants_seen, plain_items, checks, failures))
if failures > 0 then error(failures .. " failure(s)", 0) end
