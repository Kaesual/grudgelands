-- Disposable engine probe (Round 70 lane FARMFIX). Never shipped:
-- tools/r70_farmfix/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client, which is what the checks need (a real player).
--
-- After the character is made (the Round 49 driver) the probe freezes it and
-- runs the CHECK lines on real objects: a hoe's on_use at a real dropped item
-- (dirt, a potion into the belt, a broken hoe), tilling, the list of usable
-- items, the node timers of a planted field. Then it stands corn stages 2, 3
-- and 4 and wild corn in a row for the screenshots.
local P = "[r70farmfix] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r70farmfix_settle") or "") or 4
local function log(msg) core.log("action", P .. msg) end
local function check(label, ok, detail)
	log(("CHECK %s %s%s"):format(ok and "PASS" or "FAIL", label,
		detail and (" (" .. tostring(detail) .. ")") or ""))
end

local SHOTS = {
	{name = "A_corn_row", pitch = 0.12},
	{name = "B_corn_feet", pitch = 0.62},
}

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r70farmfix_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function total(player, item)
	local inv, count = player:get_inventory(), 0
	for _, list in ipairs({"main", grug_inventory.POTION_BELT}) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			if stack:get_name() == item then count = count + stack:get_count() end
		end
	end
	return count
end

local function clear_stage(base)
	for dx = -4, 4 do
		for dz = 1, 7 do
			for dy = 0, 4 do
				core.set_node({x = base.x + dx, y = base.y + dy, z = base.z + dz}, {name = "air"})
			end
			core.set_node({x = base.x + dx, y = base.y - 1, z = base.z + dz},
				{name = "default:dirt_with_grass"})
		end
	end
end

-- The real on_use of a wielded hoe at a real item entity beside the player.
local function use_at_drop(player, hoe, itemstring)
	player:set_wielded_item(ItemStack(hoe))
	local at = vector.offset(player:get_pos(), 1, 1, 0)
	local object = core.add_item(at, itemstring)
	local definition = ItemStack(hoe):get_definition()
	local result = definition.on_use(ItemStack(hoe), player, {type = "object", ref = object})
	return object, result
end

local function run_checks(player, base)
	local usable = {}
	for name, definition in pairs(core.registered_items) do
		if type(definition.on_use) == "function" then
			local family = name:match("^[^:]*") .. ":" ..
				name:match(":(.*)$"):gsub("_t%d+$", ""):gsub("^hoe.*$", "hoe")
			usable[family] = (usable[family] or 0) + 1
		end
	end
	local names = {}
	for family, count in pairs(usable) do names[#names + 1] = family .. " x" .. count end
	table.sort(names)
	log("CHECK LIST usable items: " .. table.concat(names, ", "))

	local inv = player:get_inventory()
	inv:set_list(grug_inventory.POTION_BELT, {})
	inv:set_size(grug_inventory.POTION_BELT, grug_inventory.POTION_BELT_SIZE)

	local before = total(player, "default:dirt")
	local object = use_at_drop(player, "grug_farming:hoe", "default:dirt 3")
	check("hoe picks up a drop", total(player, "default:dirt") == before + 3 and
		not object:is_valid(), total(player, "default:dirt") - before)

	local potion = "grug_alchemy:potion_healing_t1"
	object = use_at_drop(player, "grug_farming:hoe", potion .. " 2")
	check("the pickup lands on the belt", inv:get_stack(grug_inventory.POTION_BELT, 1):get_count() == 2 and
		not object:is_valid(), inv:get_stack(grug_inventory.POTION_BELT, 1):to_string())

	local broken = ItemStack("grug_farming:hoe_steel")
	broken:set_wear(65535)
	before = total(player, "default:dirt")
	object = use_at_drop(player, broken, "default:dirt 2")
	check("a broken hoe picks up a drop", total(player, "default:dirt") == before + 2 and
		not object:is_valid(), total(player, "default:dirt") - before)

	local under = {x = base.x + 3, y = base.y - 1, z = base.z + 1}
	core.set_node(under, {name = "default:dirt"})
	-- The start town is protected; the hoe's own refusal is not the question.
	local is_protected = core.is_protected
	core.is_protected = function() return false end
	local hoe = ItemStack("grug_farming:hoe")
	hoe = hoe:get_definition().on_use(hoe, player, {type = "node", under = under,
		above = {x = under.x, y = under.y + 1, z = under.z}})
	core.is_protected = is_protected
	check("a hoe still tills", core.get_node(under).name == grug_farming.SOIL_DRY and
		hoe:get_wear() > 0, core.get_node(under).name)

	-- A planted row: each crop's timer runs its own stage length.
	local same, lengths = true, {}
	for dx = -3, 2 do
		local soil = {x = base.x + dx, y = base.y - 1, z = base.z + 7}
		core.set_node(soil, {name = "default:water_source"})
		core.set_node(vector.offset(soil, 0, 0, -1), {name = grug_farming.SOIL_WET})
		local crop = vector.offset(soil, 0, 1, -1)
		core.set_node(crop, {name = "grug_farming:carrot_1"})
		local timer = core.get_node_timer(crop)
		local wanted = grug_farming.stage_seconds(crop, 1)
		lengths[#lengths + 1] = timer:get_timeout()
		same = same and timer:get_timeout() == wanted
	end
	check("planted crops run their own stage lengths", same, table.concat(lengths, " "))
	player:set_wielded_item(ItemStack(""))
end

-- Left to right as seen: corn stage 2, 3, 4, wild corn, on wet soil and grass.
local function stage_corn(base)
	local z = base.z + 3
	local function soil(x)
		core.set_node({x = x, y = base.y - 1, z = z}, {name = grug_farming.SOIL_WET})
	end
	local function at(x, y) return {x = x, y = y, z = z} end
	-- The camera looks along +z, so +x is on the left.
	soil(base.x + 2)
	core.set_node(at(base.x + 2, base.y), {name = "grug_farming:corn_2"})
	soil(base.x + 1)
	core.set_node(at(base.x + 1, base.y), {name = "grug_farming:corn_3"})
	core.set_node(at(base.x + 1, base.y + 1), {name = "grug_farming:corn_3_upper_1"})
	soil(base.x)
	core.set_node(at(base.x, base.y), {name = "grug_farming:corn_4"})
	core.set_node(at(base.x, base.y + 1), {name = "grug_farming:corn_4_upper_1"})
	core.set_node(at(base.x, base.y + 2), {name = "grug_farming:corn_4_upper_2"})
	core.set_node(at(base.x - 1, base.y), {name = "grug_gathering:corn_source"})
	log("corn at " .. core.pos_to_string(at(base.x, base.y)) .. ", wild: " ..
		tostring(core.registered_nodes["grug_gathering:corn_source"] ~= nil))
end

local function show(player, shot)
	player:set_camera({mode = "first"})
	player:set_look_horizontal(0)
	player:set_look_vertical(shot.pitch or 0)
	core.set_timeofday(0.5)
end

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
			submit(player, {faction_accord = "Accord"})
			submit(player, {race_human = "Human"})
			submit(player, {class_warrior = "Warrior"})
			submit(player, {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		local base = vector.round(player:get_pos())
		log("character complete at " .. core.pos_to_string(base))
		clear_stage(base)
		run_checks(player, base)
		stage_corn(base)
		state.phase = "shoot"
		state.shot, state.waited, state.logged = 1, 0, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			player:set_camera({mode = "any"})
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then show(player, shot) end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log(("SHOT %s"):format(shot.name))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)
