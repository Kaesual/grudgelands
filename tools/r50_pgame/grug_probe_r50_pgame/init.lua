-- Disposable engine probe (Round 50 lane PGAME): the Claim Stone inventory,
-- a packed item's tooltip and every container kind placed from its packed
-- item, in the real engine. Never shipped: tools/r50_pgame/capture.sh stages
-- it through tools/luanti_headless.sh and connects one real client. The
-- driver (character creation, SHOT / HOVER / ack handshake) follows
-- tools/r491_view's and tools/r49_ui's probes.
--
-- Once the character stands at the human start, it writes a pass of entries
-- for the player as §3 of the plan describes (seq 7, written through the
-- housing storage), runs grug_core's real pack runner over a store holding
-- the marker (the real handler cleans the pass), places a stand-in claim
-- (draft, then activated) and takes the shots. Then it places each kind from
-- its cleaned packed item through the item's own on_place and logs whether
-- the node, its list sizes and every slot match ("place ... ok").

local P = "[r50pgame] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r50pgame_settle") or "") or 3
local SEQ = 7

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}
local probe_spots = {}
local function mark(pos) probe_spots[core.hash_node_position(vector.round(pos))] = true end
local function marked(pos) return probe_spots[core.hash_node_position(vector.round(pos))] end

-- The start town protects everything; the probe's own spots are free.
local interaction_protected = grug_core.interaction_protected
function grug_core.interaction_protected(pos, name)
	if marked(pos) then return false end
	return interaction_protected(pos, name)
end
local is_protected = core.is_protected
function core.is_protected(pos, name)
	if marked(pos) then return false end
	return is_protected(pos, name)
end

-- The last form shown to the player, for the hover position.
local last_form = ""
local show_formspec = core.show_formspec
function core.show_formspec(name, formname, formspec)
	if name == NAME and formspec ~= "" then last_form = formspec end
	return show_formspec(name, formname, formspec)
end

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r50pgame_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- The written book as default's book form writes it.
local function written_book()
	local book = ItemStack("default:book_written")
	local meta = book:get_meta()
	meta:set_string("title", "Letters")
	meta:set_string("owner", NAME)
	meta:set_string("text", "Dear Grug,\nthe ore in the north chest is yours.")
	meta:set_string("description", "\"Letters\" by " .. NAME)
	return book:to_string()
end

-- The tool's pass for the player: one packed item per kind, an unknown node,
-- an unknown item, charcoal above its stack size.
local function seed()
	local storage = grug_housing.storage
	local packed = grug_housing.packed
	local book = written_book()
	local chest = {}
	for i = 1, 14 do chest[i] = ItemStack("default:cobble " .. (i * 3)):to_string() end
	chest[2] = book
	chest[4] = "gone:thing 5"
	chest[7] = "default:steel_ingot 12"
	chest[9] = "default:apple 20"
	local barrel = {}
	for i = 1, 40 do barrel[i] = "default:torch " .. i end
	local rows = {
		packed.make("default:chest", {main = chest}, SEQ),
		packed.make("default:chest_locked", {main = {"default:gold_ingot 4", [32] = "default:apple 3"}}, SEQ),
		packed.make("default:furnace_active", {src = {"default:iron_lump 30"},
			fuel = {"default:coal_lump 10"}, dst = {"default:steel_ingot 3"}}, SEQ),
		packed.make("default:bookshelf", {books = {book, "default:book 3"}}, SEQ),
		packed.make("vessels:shelf", {vessels = {"vessels:glass_bottle 12"}}, SEQ),
		packed.make("gone:barrel", {stuff = barrel}, SEQ),
	}
	for index, stack in ipairs(rows) do
		storage:set_string(("recovered:%s:%d:%d"):format(NAME, SEQ, index), stack:to_string())
	end
	storage:set_string(("recovered:%s:%d:%d"):format(NAME, SEQ, #rows + 1), "grug_smelting:charcoal 120")
	storage:set_string(("recovered:%s:%d:%d"):format(NAME, SEQ, #rows + 2), "gone:coal 3")
	storage:set_string("pack_seq", tostring(SEQ))
	-- grug_core's runner over a store that holds the marker.
	local marker = {["map_reset_pack:" .. SEQ] = "1"}
	local store = {
		get_keys = function()
			local keys = {}
			for key in pairs(marker) do keys[#keys + 1] = key end
			return keys
		end,
		get_string = function(_, key) return marker[key] or "" end,
		set_string = function(_, key, value) marker[key] = value ~= "" and value or nil end,
	}
	grug_core.world_version.run_packs(store)
	log(("cleaned: marker %s, %d entries waiting"):format(
		store:get_string("map_reset_pack:" .. SEQ) == "" and "deleted" or "KEPT",
		grug_housing.recovered.count(NAME)))
	for _, entry in ipairs(grug_housing.recovered.entries(NAME)) do
		local meta = entry.stack:get_meta()
		log(("entry %s %s %s"):format(entry.key, entry.stack:get_name(),
			(meta:get_string("description"):match("^[^\n]*") or "")))
	end
end

-- The form size and a slot's centre (form units) for the hover.
local function hover_of(slot_index)
	local w, h = last_form:match("size%[([%d%.]+),([%d%.]+)%]")
	local station = grug_inventory.STATION
	local col = (slot_index - 1) % 8
	local row = math.floor((slot_index - 1) / 8)
	return {tonumber(w) or 0, tonumber(h) or 0,
		station.x + col * station.pitch + 0.5, station.y + row * station.pitch + 0.5}
end

local claim

local spots = {}
local function place_all(player)
	local inv = player:get_inventory()
	local results = {}
	for _, entry in ipairs(grug_housing.recovered.entries(NAME)) do
		local stack = entry.stack
		if stack:get_name() == grug_housing.packed.ITEM then
			local node = stack:get_meta():get_string("node")
			local lists = grug_housing.packed.lists(stack)
			local at = spots[#results + 1]
			if not at then break end
			local under = vector.offset(at, 0, -1, 0)
			mark(at)
			mark(under)
			core.set_node(under, {name = "default:stone"})
			core.set_node(at, {name = "air"})
			local def = core.registered_items[stack:get_name()]
			local left = def.on_place(ItemStack(stack), player,
				{type = "node", under = under, above = at})
			local placed = core.get_node(at).name
			local meta_inv = core.get_meta(at):get_inventory()
			local ok, why = left:is_empty() and placed == node, ""
			if not ok then why = " placed=" .. placed .. " left=" .. left:get_count() end
			for listname, size in pairs(grug_housing.packed.CONTAINER_LISTS[node] or {}) do
				if meta_inv:get_size(listname) ~= size then
					ok, why = false, why .. (" size %s=%d"):format(listname, meta_inv:get_size(listname))
				end
			end
			for listname, list in pairs(lists) do
				for index, item in pairs(list) do
					local want = ItemStack(item):to_string()
					local got = meta_inv:get_stack(listname, index):to_string()
					if want ~= got then
						ok, why = false, why .. (" %s#%d"):format(listname, index)
					end
				end
			end
			if node == "default:chest_locked" and core.get_meta(at):get_string("owner") ~= NAME then
				ok, why = false, why .. " owner=" .. core.get_meta(at):get_string("owner")
			end
			results[#results + 1] = {node = node, at = at}
			log(("place %s at %s %s%s"):format(node, core.pos_to_string(at),
				ok and "ok" or "FAIL", why))
		end
	end
	-- A protected spot keeps the item.
	local spare = grug_housing.packed.make("default:chest", {main = {"default:apple 1"}}, SEQ)
	local def = core.registered_items[grug_housing.packed.ITEM]
	local town = vector.offset(spots[1], 0, 0, -12)
	local left = def.on_place(ItemStack(spare), player, {type = "node",
		under = vector.offset(town, 0, -1, 0), above = town})
	log(("a protected town spot (%s) keeps the item: %s"):format(
		tostring(core.is_protected(town, NAME)), left:get_count() == 1 and "ok" or "FAIL"))
	return results
end

local SHOTS
SHOTS = {
	{name = "P1_draft_form", run = function(player)
		grug_housing.open_stone_interface(player, claim)
	end},
	{name = "P2_belongings_tab", run = function(player)
		core.close_formspec(NAME, "")
		grug_housing.model.activate(claim, 5)
		grug_housing.sync_stone_node(claim)
		grug_housing.open_stone_interface(player, claim)
		local labels = last_form:match("tabheader%[0,0;stone_tab;([^;]*);") or ""
		local index = 0
		for label in labels:gmatch("[^,]+") do
			index = index + 1
			if label:find("Belongings", 1, true) then break end
		end
		submit(player, "grug_housing:stone", {stone_tab = tostring(index)})
	end},
	{name = "P3_packed_chest_tooltip", hover_slot = 1, run = function() end},
	{name = "P4_furnace_tooltip", hover_slot = 3, run = function() end},
	{name = "P5_restored_chest", run = function(player)
		core.close_formspec(NAME, "")
		local results = place_all(player)
		for _, r in ipairs(results) do
			if r.node == "default:chest" then
				local node = core.get_node(r.at)
				core.registered_nodes[node.name].on_rightclick(r.at, node, player, ItemStack(""))
				break
			end
		end
	end},
	{name = "P6_restored_bookshelf", run = function(player)
		core.close_formspec(NAME, "")
		for i = 1, #spots do
			local node = core.get_node(spots[i])
			if node.name == "default:bookshelf" then
				core.registered_nodes[node.name].on_rightclick(spots[i], node, player, ItemStack(""))
			end
		end
	end},
}

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		local socket
		for _, entry in ipairs(grug_core.settlement_sockets("human")) do
			if entry.role == "waypoint" then socket = entry end
		end
		local base = vector.offset(socket.pos, 3, 0, 0)
		state.phase = "emerge"
		core.emerge_area(vector.offset(base, -8, -4, -16), vector.offset(base, 12, 8, 10),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				for i = 1, 7 do spots[i] = vector.offset(base, i - 1, 0, 3) end
				local center = vector.offset(base, 0, 0, -3)
				mark(center)
				grug_housing.model.issue(NAME, 30, false)
				core.set_node(center, {name = grug_housing.DRAFT_STONE})
				claim = grug_housing.model.create(NAME, center)
				seed()
				player:set_pos(vector.offset(base, 2, 0, 0))
				player:set_look_horizontal(math.pi)
				player:set_look_vertical(0.3)
				log("READY")
				state.phase = "shoot"
				state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
			end)
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.ran then
			state.ran = true
			player:set_physics_override({gravity = 0, speed = 0, jump = 0})
			shot.run(player)
			log("ran " .. shot.name)
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			if shot.hover_slot then
				log(("HOVER %s %s %s %s %s"):format(shot.name, unpack(hover_of(shot.hover_slot))))
			end
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
