-- Disposable engine probe (0.49.1 lane VIEW): every station form with the
-- player's combined bag, for screenshots. Never shipped:
-- tools/r491_view/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, SHOT / ack
-- handshake) follows tools/r48_mail's probe.
--
-- It places a chest, a furnace (lit, cooking), a bookshelf, a vessels
-- shelf and a dual furnace beside the human start's waystone, equips four
-- bags with some items, and opens each form through the node's own
-- right-click; the Claim Stone form opens on a stand-in claim. The town's
-- interaction protection is lifted for the probe's own nodes only.

local P = "[r491view] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r491view_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}
local spots = {}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r491view_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function first_item(names)
	for _, name in ipairs(names) do
		if core.registered_items[name] then return name end
	end
end

-- The probe's nodes are not protected (the start town's protection would
-- refuse the shared furnace's lists).
local probe_nodes = {}
local interaction_protected = grug_core.interaction_protected
function grug_core.interaction_protected(pos, name)
	if probe_nodes[core.hash_node_position(vector.round(pos))] then return false end
	return interaction_protected(pos, name)
end

-- The Claim Stone form on a stand-in claim (an active stone with fuel).
local fake_claim
local player_claim = grug_housing.player_claim
function grug_housing.player_claim(name)
	if fake_claim and name == NAME then return fake_claim, "placed" end
	return player_claim(name)
end

local function equip_bags(player, sizes)
	local inv = player:get_inventory()
	local items = {[4] = "grug_inventory:bag_small", [8] = "grug_inventory:bag_medium",
		[12] = "grug_inventory:bag_large"}
	for i = 1, grug_inventory.BAG_COUNT do
		local size = sizes[i] or 0
		inv:set_stack(grug_inventory.bag_list(i), 1, ItemStack(size > 0 and items[size] or ""))
		inv:set_size(grug_inventory.content_list(i), size)
	end
	local fill = {"default:cobble 40", "default:dirt 25", "default:apple 7", "default:torch 30",
		"default:stick 16", "default:coal_lump 9", "default:paper 4", "default:book 2"}
	for index = 1, #fill do
		local stack = ItemStack(fill[index])
		if core.registered_items[stack:get_name()] then
			inv:set_stack("main", 8 + index * 2, stack)
			for i = 1, grug_inventory.BAG_COUNT do
				local list = grug_inventory.content_list(i)
				if inv:get_size(list) >= index then inv:set_stack(list, index, stack) end
			end
		end
	end
end

local function open(player, which)
	core.close_formspec(NAME, "")
	local pos = spots[which]
	local node = core.get_node(pos)
	core.registered_nodes[node.name].on_rightclick(pos, node, player, ItemStack(""))
end

-- A scroll event as the client sends it, through the form's own handler.
local function scroll(player, formname, value)
	submit(player, formname, {grug_inv_scroll_station = "CHG:" .. value})
end

local SHOTS = {
	{name = "V1_chest_four_bags", run = function(player) open(player, "chest") end},
	{name = "V2_furnace_burning", run = function(player) open(player, "furnace") end},
	{name = "V3_furnace_burning_scrolled", run = function(player)
		-- Scrolled two rows down; the furnace re-shows its form every second
		-- while the shot settles.
		scroll(player, "grug_jobs:workspace", 20)
	end},
	{name = "V4_bookshelf", run = function(player) open(player, "bookshelf") end},
	{name = "V5_vessels_shelf", run = function(player) open(player, "vessels") end},
	{name = "V6_dual_furnace", run = function(player) open(player, "dual") end},
	{name = "V7_claim_stone", run = function(player)
		core.close_formspec(NAME, "")
		local now = os.time()
		fake_claim = {id = 990001, owner = NAME, center = vector.round(player:get_pos()),
			placed_at = now - 86400, activated_at = now - 86400,
			paid_until = now + 3 * 86400, permissions = {}}
		grug_housing.open_stone_interface(player, fake_claim)
	end},
	{name = "V8_chest_no_bags", run = function(player)
		equip_bags(player, {})
		open(player, "chest")
	end},
	{name = "V9_chest_one_bag", run = function(player)
		equip_bags(player, {12})
		open(player, "chest")
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
		local stand = vector.offset(socket.pos, 3, 0, 3)
		state.phase = "emerge"
		core.emerge_area(vector.offset(base, -8, -4, -8), vector.offset(base, 12, 8, 8),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				local row = {
					{"chest", "default:chest"}, {"furnace", "default:furnace"},
					{"bookshelf", "default:bookshelf"}, {"vessels", "vessels:shelf"},
					{"dual", "grug_smelting:dual_furnace"},
				}
				for index, entry in ipairs(row) do
					local pos = vector.offset(base, index - 1, 0, 0)
					core.set_node(pos, {name = entry[2]})
					spots[entry[1]] = pos
					probe_nodes[core.hash_node_position(pos)] = true
				end
				-- Books and vessels for the shelves, a lit furnace cooking.
				local books = core.get_meta(spots.bookshelf):get_inventory()
				books:set_stack("books", 1, ItemStack("default:book"))
				books:set_stack("books", 2, ItemStack("default:book"))
				local vessels = core.get_meta(spots.vessels):get_inventory()
				local bottle = first_item({"vessels:glass_bottle", "vessels:drinking_glass"})
				if bottle then vessels:set_stack("vessels", 1, ItemStack(bottle .. " 3")) end
				local furnace = core.get_meta(spots.furnace):get_inventory()
				local ore = first_item({"default:cobble", "grug_materials:copper_lump",
					"grug_materials:iron_lump", "default:sand"})
				furnace:set_stack("src", 1, ItemStack(ore .. " 30"))
				furnace:set_stack("fuel", 1, ItemStack("default:coal_lump 10"))
				local def = core.registered_nodes[core.get_node(spots.furnace).name]
				def.on_metadata_inventory_put(spots.furnace, "fuel", 1,
					ItemStack("default:coal_lump"), player)
				player:set_pos(stand)
				player:set_look_horizontal(math.pi)
				player:set_look_vertical(0.3)
				equip_bags(player, {12, 8, 12, 4})
				log("stations at " .. core.pos_to_string(base) .. ", cooking " .. tostring(ore))
				state.phase = "shoot"
				state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
				log("READY")
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
			log("ran " .. shot.name .. ", form " .. tostring(default.node_formspec.shown_form(NAME)))
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
