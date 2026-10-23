-- Disposable engine probe (Round 57 lane DETAILS): the recipe details page
-- for screenshots. Never shipped: tools/r57_details/capture.sh stages it
-- through tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) is tools/r57_craft's probe.
-- The page is shown with core.show_formspec under the probe's own form name
-- (the server cannot open a client's inventory); the probe sets the page
-- state as the clicks would. A planks job runs, so the job strip shows the
-- bar, the stop button and View Queue under the page. Logged with the
-- prefix [r57details]: the page's bytes per shot (comparisons).

local P = "[r57details] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r57details_settle") or "") or 3
local FORM = "grug_probe_r57_details_shots:page"
local J = grug_jobs

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r57details_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
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

local function recipe_for(output, group)
	for _, recipe in ipairs(J.recipes_for_output(output)) do
		if not group or recipe.ingredients[1].group == group then return recipe end
	end
end

local function fresh_state(selected, slot)
	return {slot = slot or 1, page = 1, search = "", typed = "", only = false, qty = "1",
		rows = {}, selected = selected}
end

local ENCHANT = "enchant:sword:prefix:str:t3"

local SHOTS = {
	{name = "D1_two_ingredients", run = function(player)
		local bolt = recipe_for("grug_professions:bolt_patch")
		local st = fresh_state(bolt.id)
		context(player).grug_craft = st
		J.open_recipe_details(st, {kind = "recipe", id = bolt.id})
		show(player, "details with two ingredient boxes")
	end},
	{name = "D2_group_page", run = function(player)
		local stick = recipe_for("default:stick", "wood")
		local st = fresh_state(stick.id)
		context(player).grug_craft = st
		J.open_recipe_details(st, {kind = "recipe", id = stick.id})
		table.insert(st.details.pages, {kind = "group", group = "wood", n = 1, page = 1})
		show(player, "group page")
	end},
	{name = "D3_enchant_page", run = function(player)
		local st = fresh_state(nil, 3)
		st.box = "enchant"
		st.ench = ENCHANT
		context(player).grug_craft = st
		J.open_recipe_details(st, {kind = "operation", id = ENCHANT,
			target = "grug_gear:sword_steel"})
		show(player, "enchant page")
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
		grug_xp.set_xp(player, grug_xp.xp_for_level(25))
		J.admin_set(player, "weaponsmith", 3, 1)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		local inv = player:get_inventory()
		inv:add_item("main", "default:aspen_tree 99")
		inv:add_item("main", "grug_mobs:linen_scrap 1")
		inv:add_item("main", "default:wood 12")
		log("start " .. tostring((J.start_job(player, recipe_for("default:aspen_wood").id, 60))))
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
