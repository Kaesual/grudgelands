-- Disposable engine probe (Round 57 lane CRAFT): the Crafting tab in layout
-- C for screenshots, and the tier unlock's numbers on the real data. Never
-- shipped: tools/r57_craft/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r49_inv's probe.
--
-- The page is shown with core.show_formspec under the probe's own form
-- name (the server cannot open a client's inventory); the probe sets the
-- page state directly, as the clicks would. Logged with the prefix
-- [r57craft]: per profession and tier the Basic recipes the tier unlocks
-- (needed_basic), the size of the stored set for a character with every
-- profession at tier 6, and the page's bytes per shot (comparisons).

local P = "[r57craft] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r57craft_settle") or "") or 3
local FORM = "grug_probe_r57_craft:page"
local J = grug_jobs

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r57craft_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- The unlock numbers: per profession and tier, and the stored set's size
-- for every profession at tier 6.
local function unlock_numbers()
	local all, total = {}, 0
	local professions = {}
	for name in pairs(J.PROFESSIONS) do professions[#professions + 1] = name end
	table.sort(professions)
	for _, profession in ipairs(professions) do
		local counts = {}
		for tier = 1, 6 do
			local list = J.needed_basic(profession, tier)
			counts[tier] = #list
			for _, id in ipairs(list) do
				if not all[id] then
					all[id] = true
					total = total + 1
				end
			end
		end
		log(("unlock %s T1..T6: %s"):format(profession, table.concat(counts, " ")))
	end
	local bytes = 1
	for id in pairs(all) do bytes = bytes + 1 + #id end
	log(("unlock: %d distinct Basic recipes over every profession and tier, a stored set of" ..
		" about %d bytes; %d Basic recipes in all"):format(total, bytes,
		#J.recipes_in_area("basic")))
	local sample = J.needed_basic("tailor", 1)
	local names = {}
	for index = 1, math.min(#sample, 12) do
		local recipe = J.recipe(sample[index])
		names[#names + 1] = recipe and core.registered_items[recipe.output] and
			core.registered_items[recipe.output].description:match("^[^\n]*") or sample[index]
	end
	log("unlock tailor T1 needs: " .. table.concat(names, ", "))
end

local function context(player)
	local ctx = sfinv.get_or_create_context(player)
	ctx.page = "sfinv:crafting"
	return ctx
end

local function show(player, label)
	local ctx = context(player)
	J.update_job(player, "open")
	local fs = sfinv.get_formspec(player, ctx)
	core.show_formspec(NAME, FORM, fs)
	log(("bytes %s: page %d"):format(label, #fs))
end

local function recipe_for(output)
	for _, recipe in ipairs(J.recipes_for_output(output)) do return recipe end
end

local forge_pos, sword_name, enchant_id

local function stock(player)
	local inv = player:get_inventory()
	inv:add_item("main", "default:aspen_tree 99")
	inv:add_item("main", "default:aspen_tree 30")
	inv:add_item("main", "default:aspen_wood 20")
	local op = J.station_operation(enchant_id)
	for _, entry in ipairs(op.ingredients) do
		inv:add_item("main", (entry.item or "") .. " " .. (entry.n * 3))
	end
end

local function sword()
	local stack = ItemStack(sword_name)
	grug_items.crafted_output(stack, core.get_player_by_name(NAME))
	return stack
end

local SHOTS = {
	{name = "C1_idle", run = function(player)
		local st = {slot = 1, page = 1, search = "", typed = "", only = false, qty = "40",
			rows = {}, selected = recipe_for("default:aspen_wood").id}
		context(player).grug_craft = st
		show(player, "idle")
	end},
	{name = "C2_running_queue_of_3", run = function(player)
		local planks = recipe_for("default:aspen_wood").id
		log("start " .. tostring((J.start_job(player, planks, 60))))
		log("queue sticks " .. tostring((J.start_job(player, recipe_for("default:stick").id, 5))))
		log("queue planks " .. tostring((J.start_job(player, planks, 5))))
		player:get_inventory():set_stack(J.TARGET_LIST, 1, sword())
		local ok, reason = J.start_operation(player, enchant_id)
		log("queue enchant " .. tostring(ok) .. " " .. tostring(reason))
		log("queue " .. #J.queue_state(player))
		local st = context(player).grug_craft
		st.qty = "1"
		J.toggle_favorite(player, planks)
		show(player, "running with a queue of 3")
	end},
	{name = "C3_queue_view", run = function(player)
		local st = context(player).grug_craft
		J.open_craft_box(st, "queue")
		show(player, "queue view")
	end},
	{name = "C4_enchant_box", run = function(player)
		local st = context(player).grug_craft
		st.box, st.box_return, st.selected = "enchant", nil, nil
		st.slot = 3
		player:get_inventory():set_stack(J.TARGET_LIST, 1, sword())
		st.ench = enchant_id
		show(player, "enchant box while a job runs")
	end},
	{name = "C5_overflow", run = function(player)
		local st = context(player).grug_craft
		st.box, st.slot, st.selected = nil, 1, recipe_for("default:stick").id
		local inv = player:get_inventory()
		inv:set_stack(J.OUTPUT_LIST, 1, "default:cobble 50")
		inv:set_stack(J.OUTPUT_LIST, 2, "default:dirt 20")
		show(player, "the overflow row")
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
		unlock_numbers()
		grug_xp.set_xp(player, grug_xp.xp_for_level(25))
		J.admin_set(player, "weaponsmith", 3, 1)
		sword_name = "grug_gear:sword_steel"
		enchant_id = "enchant:sword:prefix:str:t3"
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		local pos = vector.round(player:get_pos())
		forge_pos = vector.offset(pos, 2, 0, 0)
		core.set_node(forge_pos, {name = "grug_jobs:forge"})
		stock(player)
		log("forge " .. core.pos_to_string(forge_pos) .. " level " .. grug_xp.get_level(player))
		state.phase = "shoot"
		state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
		log("READY")
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
			shot.run(player)
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
