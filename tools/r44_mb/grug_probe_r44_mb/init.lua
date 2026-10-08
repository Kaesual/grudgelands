-- Disposable engine probe (Round 44 lane MB), never shipped. Staged through
--   PROBE=tools/r44_mb/grug_probe_r44_mb tools/luanti_headless.sh 300
-- (a second boot of the same world with ROOT= and a GAME_PATCH that sets
-- grug_map_quality = high measures the high base). Two seconds after the
-- server runs it logs, then shuts the server down:
--   * the Map tab's formspec bytes at zoom 1x and 8x for a stand-in viewer of
--     each faction (sfinv.get_formspec on a fake ObjectRef with only the
--     methods the page reads), with its element counts;
--   * the minimap's densest window in each capital: the most static minimap
--     markers inside one minimap circle (radius 202 nodes: the 440-node
--     window less half an icon), every quest giver of the faction counted
--     (the worst case), for the marker kinds before Round 44 (quest givers,
--     trainers, the Steward, the capital services, innkeepers) and after
--     (quest givers, trainers); home and waystones add at most two.
-- The base render itself logs its own line ("[grug_map] rendered ...").
local P = "[r44mb_probe] "
local function log(text) core.log("action", P .. text) end
local RADIUS = 202

local function fake_player(name, faction, pos)
	local store = {["grug_factions:faction"] = faction}
	local meta = {}
	function meta:get_string(key) return store[key] or "" end
	function meta:get_int(key) return tonumber(store[key]) or 0 end
	function meta:get_float(key) return tonumber(store[key]) or 0 end
	function meta:set_string(key, value) store[key] = value ~= "" and value or nil end
	function meta:set_int(key, value) store[key] = tostring(value) end
	function meta:set_float(key, value) store[key] = tostring(value) end
	function meta:contains(key) return store[key] ~= nil end
	function meta:to_table() return {fields = store} end
	local inv = core.create_detached_inventory("r44mb_" .. name, {}, name)
	inv:set_size("main", 32)
	local p = {}
	local M = {}
	function M:is_player() return true end
	function M:is_valid() return true end
	function M:get_player_name() return name end
	function M:get_pos() return vector.copy(pos) end
	function M:get_look_horizontal() return 0 end
	function M:get_meta() return meta end
	function M:get_inventory() return inv end
	function M:get_wield_index() return 1 end
	setmetatable(p, {__index = function(_, key)
		if M[key] then return M[key] end
		return function() return nil end
	end})
	return p
end

local function count(form, pattern)
	local n = 0
	for _ in form:gmatch(pattern) do n = n + 1 end
	return n
end

local function page_bytes(faction, pos)
	local name = "r44mb_" .. faction
	local player = fake_player(name, faction, pos)
	local page = sfinv.pages["grug_map:atlas"]
	local context = {page = "grug_map:atlas"}
	sfinv.contexts[name] = context
	page:on_enter(player, context)
	for _, zoom in ipairs({1, 8}) do
		context.grug_map_zoom = zoom
		local ok, form = pcall(sfinv.get_formspec, player, context)
		if ok then
			log(("page %s zoom %dx: %d bytes (image_button %d, button %d, hypertext %d, " ..
				"tooltip %d, image %d, style %d)"):format(faction, zoom, #form,
				count(form, "image_button%["), count(form, "[^_]button%["),
				count(form, "hypertext%["), count(form, "tooltip%["),
				count(form, "[^_]image%["), count(form, "style%[")))
		else
			log("page " .. faction .. " failed: " .. tostring(form))
		end
	end
	page:on_leave(player, context)
	sfinv.contexts[name] = nil
end

-- Every NPC marker position of `faction` by kind: trainers, the Steward,
-- services and innkeepers from the settlement sockets, quest givers from
-- grug_quests.registered_npcs.
local function npc_positions(faction)
	local faction_of_race, sockets = {}, {}
	for _, identity in ipairs(grug_core.start_identities()) do
		faction_of_race[identity.race_id] = identity.faction_id
	end
	local rows = {}
	local ROLE = {trainer = "trainer", riding_trainer = "trainer", housing_manager = "steward",
		crownbinder = "service", culture_vendor = "service", innkeeper = "innkeeper"}
	for _, settlement in ipairs(grug_core.settlement_socket_settlements()) do
		local own = faction_of_race[settlement.race_id] == faction
		for _, socket in ipairs(grug_core.settlement_sockets_at(settlement.key)) do
			sockets[settlement.key .. "/" .. socket.id] = socket.pos
			local kind = ROLE[socket.role]
			if own and kind and socket.spawn ~= false then
				rows[#rows + 1] = {kind = kind, x = socket.pos.x, z = socket.pos.z}
			end
		end
	end
	for _, npc in pairs(grug_quests.registered_npcs) do
		local pos = sockets[npc.settlement .. "/" .. npc.socket]
		if pos and npc.faction == faction then
			rows[#rows + 1] = {kind = "quest", x = pos.x, z = pos.z}
		end
	end
	return rows
end

local BEFORE = {quest = true, trainer = true, steward = true, service = true, innkeeper = true}
local AFTER = {quest = true, trainer = true}

local function densest(rows, kinds, centre)
	local list = {}
	for _, row in ipairs(rows) do
		local dx, dz = row.x - centre.x, row.z - centre.z
		if kinds[row.kind] and dx * dx + dz * dz <= 600 * 600 then list[#list + 1] = row end
	end
	local best = 0
	local centres = {centre}
	for _, row in ipairs(list) do centres[#centres + 1] = row end
	for _, c in ipairs(centres) do
		local n = 0
		for _, row in ipairs(list) do
			local dx, dz = row.x - c.x, row.z - c.z
			if dx * dx + dz * dz <= RADIUS * RADIUS then n = n + 1 end
		end
		if n > best then best = n end
	end
	return best
end

local function minimap_density()
	local faction_of_race = {}
	for _, identity in ipairs(grug_core.start_identities()) do
		faction_of_race[identity.race_id] = identity.faction_id
	end
	local by_faction = {}
	for _, settlement in ipairs(grug_core.settlement_socket_settlements()) do
		if settlement.slot == "capital" or settlement.slot == "start" then
			local faction = faction_of_race[settlement.race_id]
			by_faction[faction] = by_faction[faction] or npc_positions(faction)
			local rows = by_faction[faction]
			local near = {}
			for _, row in ipairs(rows) do
				local dx, dz = row.x - settlement.anchor.x, row.z - settlement.anchor.z
				if dx * dx + dz * dz <= 600 * 600 then near[row.kind] = (near[row.kind] or 0) + 1 end
			end
			local kinds = {}
			for kind, n in pairs(near) do kinds[#kinds + 1] = kind .. " " .. n end
			table.sort(kinds)
			log(("minimap %s %s (%s): densest window before %d, after %d markers " ..
				"(within 600 nodes: %s)"):format(settlement.slot, settlement.key, faction,
				densest(rows, BEFORE, settlement.anchor), densest(rows, AFTER, settlement.anchor),
				table.concat(kinds, ", ")))
		end
	end
end

local clock, done = 0, false
core.register_globalstep(function(dtime)
	if done then return end
	clock = clock + dtime
	if clock < 2 then return end
	done = true
	local ok, err = pcall(function()
		for _, faction in ipairs(grug_core.faction_ids) do
			page_bytes(faction, {x = 0, y = 20, z = 0})
		end
		minimap_density()
	end)
	if not ok then log("failed: " .. tostring(err)) end
	log("done")
	core.request_shutdown("r44 mb probe done", false, 0)
end)
