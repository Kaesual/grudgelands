-- Disposable engine probe (0.49.1 lane ANIM): a burning workspace furnace
-- and dual furnace with the animated fire and arrow, for screenshots. Never
-- shipped: tools/r491_anim/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r491_view's
-- probe.
--
-- It places a furnace and a dual furnace (player-placed: shared stations)
-- beside the human start's waystone, fills them with a 10 s smelt and logs
-- (15 s each), and opens the furnace through its own right-click. Every
-- show_formspec of the workspace form is logged with its game time and
-- size. Shots: A1 and A2 a few seconds apart (both moved, the re-sends
-- between them logged), A3 the dual furnace. Then the furnace stays open
-- for one minute: "minute <shows> shows, <bytes> bytes".

local P = "[r491anim] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r491anim_settle") or "") or 3
local FORM = "grug_jobs:workspace"

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}
local spots = {}
local clock = 0

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r491anim_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- Every show of the workspace form, with the probe's clock and its size.
local shows = {}
local show_formspec = core.show_formspec
function core.show_formspec(name, formname, formspec)
	if name == NAME and formname == FORM and formspec ~= "" then
		shows[#shows + 1] = {at = clock, bytes = #formspec}
		local fire = formspec:match("animated_image%[[^%]]-grug_furnace_fire;[^%]]*%]") or "(still)"
		local arrow = formspec:match("animated_image%[[^%]]-grug_furnace_arrow;[^%]]*%]") or "(still)"
		log(("shown at %.1f s: %d bytes; fire %s; arrow %s"):format(clock, #formspec, fire, arrow))
	end
	return show_formspec(name, formname, formspec)
end

-- The probe's nodes are not protected (the start town's protection would
-- refuse the shared furnace's lists).
local probe_nodes = {}
local interaction_protected = grug_core.interaction_protected
function grug_core.interaction_protected(pos, name)
	if probe_nodes[core.hash_node_position(vector.round(pos))] then return false end
	return interaction_protected(pos, name)
end

local function cookable(names)
	for _, name in ipairs(names) do
		if core.registered_items[name] and core.get_craft_result({method = "cooking",
				width = 1, items = {name}}).time > 0 then
			return name
		end
	end
end

local function open(player, which)
	core.close_formspec(NAME, "")
	local pos = spots[which]
	local node = core.get_node(pos)
	core.registered_nodes[node.name].on_rightclick(pos, node, player, ItemStack(""))
end

local function put(pos, list, index, item, player)
	local inv = core.get_meta(pos):get_inventory()
	inv:set_stack(list, index, ItemStack(item))
	local def = core.registered_nodes[core.get_node(pos).name]
	def.on_metadata_inventory_put(pos, list, index, ItemStack(item), player)
end

local shot_at = {}
local SHOTS = {
	{name = "A1_furnace_burning", run = function(player) open(player, "furnace") end},
	-- The form stays open; the fire and the arrow move on the client.
	{name = "A2_furnace_seconds_later", run = function() end},
	{name = "A3_dual_furnace_burning", run = function(player) open(player, "dual") end},
}

core.register_globalstep(function(dtime)
	clock = clock + dtime
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
				for index, entry in ipairs({{"furnace", "default:furnace"},
						{"dual", "grug_smelting:dual_furnace"}}) do
					local pos = vector.offset(base, index - 1, 0, 0)
					core.set_node(pos, {name = entry[2]})
					spots[entry[1]] = pos
					probe_nodes[core.hash_node_position(pos)] = true
				end
				local ore = cookable({"default:iron_lump", "default:copper_lump", "default:cobble"})
				put(spots.furnace, "fuel", 1, "default:tree 10", player)
				put(spots.furnace, "src", 1, ore .. " 30", player)
				put(spots.dual, "fuel", 1, "default:tree 10", player)
				-- Copper + Tin -> Bronze (the dual furnace's alloys take bars).
				put(spots.dual, "input", 1, "grug_materials:copper_bar 10", player)
				put(spots.dual, "input", 2, "grug_materials:tin_bar 10", player)
				player:set_pos(stand)
				player:set_look_horizontal(math.pi)
				player:set_look_vertical(0.3)
				log("stations at " .. core.pos_to_string(base) .. ", smelting " .. tostring(ore))
				state.phase = "shoot"
				state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
				log("READY")
			end)
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			-- One burning minute with the furnace open.
			open(player, "furnace")
			state.phase, state.minute_from, state.minute_at = "minute", #shows, clock
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
			shot_at[shot.name] = clock
			if shot.name == "A2_furnace_seconds_later" then
				local count = 0
				for _, s in ipairs(shows) do
					if s.at > shot_at.A1_furnace_burning then count = count + 1 end
				end
				log(("between A1 (%.1f s) and A2 (%.1f s): %d re-sends"):format(
					shot_at.A1_furnace_burning, clock, count))
			end
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	elseif state.phase == "minute" then
		if clock - state.minute_at < 60 then return end
		local count, bytes = 0, 0
		for index = state.minute_from + 2, #shows do -- after the opening show
			count, bytes = count + 1, bytes + shows[index].bytes
		end
		log(("minute %d shows, %d bytes (the opening show of %d bytes not counted)"):format(
			count, bytes, shows[state.minute_from + 1] and shows[state.minute_from + 1].bytes or 0))
		state.phase = "done"
		log("shutdown")
		core.request_shutdown("probe done", false, 0)
	end
end)
