-- Disposable engine probe (Round 55 lane GAME): the offhand look as the game
-- composes it, for screenshots. Never shipped: tools/r55_game/capture.sh
-- stages it (with the test art baked by tools/r55_offhand/bake.py into its
-- textures/) through tools/luanti_headless.sh and connects one real client.
-- The studio and the SHOT / ack handshake are tools/r54_model's probe's
-- (copied, names changed); the Character page is shown as
-- tools/r54_view's probe shows it.
--
-- Every figure wears what the REAL game path gives the capture player: the
-- probe writes the gear straight into the equipment lists, the class into
-- the player's meta and the hotbar item into the wielded slot, runs
-- grug_visuals.apply (or grug_inventory.equipment_changed) and copies the
-- player's texture list onto a frozen mesh figure. The cloak source is a
-- stub (a real cloak texture, and tools/r55_offhand/test_art/wings_test.png
-- as the wings), installed after grug_achievements'.
--
-- The setting grug_offhand_visuals comes from the staged minetest.conf
-- (capture.sh OFFHAND=true or false); the probe logs what the game read.
--
-- Another lane's shots (capture.sh SCENE=, staged as scene.lua; Round 55
-- FINISH): scene.lua returns function(api) -> {on = fn() -> shots, off =
-- fn() -> shots, real_cloaks = true|nil}, the lists built after the items
-- are found. With real_cloaks the stub cloak source is not
-- installed (grug_achievements' own one serves) and a look's `cloak_id`
-- ("none" by default) is selected through grug_achievements.select_cloak. A
-- shot may carry `before(player)` (run once before it is set up) and
-- `formspec` (a function returning a formspec shown instead of figures).
local P = "[r55game] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r55game_settle") or "") or 4
local CHARACTER_PAGE = "grug_inventory:character"
local CLOAK = "grug_achievements_cloak_plain_grey.png"
local WINGS = "r55game_wings_test.png"
local PLAYER = "grug_visuals_character.b3d"
local PI = math.pi
local STAND, WALK, BLOCK, CAST, SIT = 0, 172, 380, 230, 100
local function log(msg) core.log("action", P .. msg) end
-- The Character page's camera from behind (its default is 0,130).
local BACK_VIEW = "0,310"
-- Only the shots whose names start with this (capture.sh ONLY=), all if empty.
local ONLY = core.settings:get("r55game_only") or ""

local state = {phase = "wait", clock = 0}
local stub = {cloak = nil, wings = nil}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r55game_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

core.register_entity("grug_probe_r55_game:figure", {
	initial_properties = {
		visual = "mesh", mesh = "character.b3d", textures = {"character.png"},
		physical = false, pointable = false, collide_with_objects = false,
		collisionbox = {0, 0, 0, 0, 0, 0}, static_save = false,
	},
})

-- The studio: a grass floor x -8..8, z -4..12 at y 0 relative to S.
local S
local function build_studio()
	local minp, maxp = vector.offset(S, -10, -2, -6), vector.offset(S, 10, 8, 14)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local cid = core.get_content_id
	local air, grass, dirt = cid("air"), cid("default:dirt_with_grass"), cid("default:dirt")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local rx, ry, rz = x - S.x, y - S.y, z - S.z
				local id = air
				if rx >= -8 and rx <= 8 and rz >= -4 and rz <= 12 and ry <= 0 and ry >= -1 then
					id = ry == 0 and grass or dirt
				end
				data[area:index(x, y, z)] = id
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

--
-- The game state of the capture player.
--
local ITEMS = {}
local function find_items()
	for name, def in pairs(core.registered_items) do
		if (def.groups or {}).grug_ability then
			if def._grug_ability_slot == "weapon" and (not ITEMS.bow_skill or name < ITEMS.bow_skill) then
				ITEMS.bow_skill = name
			elseif def._grug_ability_slot == "melee" and (not ITEMS.melee_skill or
					name == "grug_abilities:strike") then
				ITEMS.melee_skill = name
			end
		end
	end
	ITEMS.pickaxe = core.registered_items["default:pick_steel"] and "default:pick_steel" or "default:pick_stone"
	log(("items: bow skill %s, melee skill %s, tool %s"):format(tostring(ITEMS.bow_skill),
		tostring(ITEMS.melee_skill), ITEMS.pickaxe))
end

-- Gear, class, hotbar item and cloak, then the real apply.
local SCENE
local function dress(player, look)
	local inv = player:get_inventory()
	player:get_meta():set_string("grug_classes:class", look.class)
	for _, slot in ipairs(grug_visuals.SLOTS) do
		inv:set_stack("grug_" .. slot, 1, look.line and grug_gear.armor_item(slot, look.line, look.tier) or "")
	end
	inv:set_stack("grug_weapon", 1, look.weapon or "")
	inv:set_stack("grug_offhand", 1, look.offhand or "")
	inv:set_stack("main", player:get_wield_index(), look.held or "")
	stub.cloak = look.cloak and CLOAK or nil
	stub.wings = look.wings and WINGS or nil
	if SCENE and SCENE.real_cloaks then
		grug_achievements.select_cloak(player, look.cloak_id or "none")
	end
	grug_inventory.equipment_changed(player)
	grug_visuals.apply(player)
	local props = player:get_properties()
	return {mesh = props.mesh, textures = table.copy(props.textures)}
end

local live = {}
local function clear()
	for _, obj in ipairs(live) do
		if obj:get_pos() then obj:remove() end
	end
	live = {}
end

local function vec(t) return vector.offset(S, t[1], t[2], t[3]) end

-- A figure: {x, yaw, frame, look, (hand = item the wield entity shows)}.
local function place(player, shot)
	clear()
	for i, fig in ipairs(shot.figures) do
		local drawn = dress(player, fig.look)
		local obj = core.add_entity(vec({fig.x, 0.5, 0}), "grug_probe_r55_game:figure")
		if obj then
			obj:set_properties({mesh = drawn.mesh, textures = drawn.textures})
			obj:set_yaw(fig.yaw or 0)
			obj:set_animation({x = fig.frame or 0, y = fig.frame or 0}, 0, 0, false)
			live[#live + 1] = obj
			local hand = fig.look.shown
			if hand then
				local def = core.registered_items[hand]
				local pose = grug_visuals.pose_for(hand, core.get_item_group, def and def._grug_wield_pose)
				local wield = core.add_entity(vec({fig.x, 0.5, 0}), "grug_visuals:wield")
				if wield then
					local t = grug_visuals.wield_transform(1, pose)
					wield:set_properties({textures = {hand}, wield_item = hand, visual_size = t.size})
					wield:set_attach(obj, t.bone, t.pos, t.rot)
					live[#live + 1] = wield
				end
			end
			local lengths = {}
			for index, texture in ipairs(drawn.textures) do lengths[index] = #texture end
			log(("figure %d of %s: %s, %d textures (bytes %s); offhand %s; back %s; wings %s"):format(
				i, shot.name, drawn.mesh, #drawn.textures, table.concat(lengths, "/"),
				tostring(drawn.textures[5]), tostring(drawn.textures[6]), tostring(drawn.textures[7])))
		end
	end
end

-- The model[] element's camera rotation, its sixth part (tools/r54_view's
-- probe: walk its unescaped ";" up to the one that ends the part).
local function replace_rotation(fs, rotation)
	local start = fs:find("model[", 1, true)
	if not start then return fs end
	local part, from, i = 1, nil, start + #"model["
	while i <= #fs do
		local c = fs:sub(i, i)
		if c == "\\" then
			i = i + 2
		else
			if c == ";" or c == "]" then
				if from then
					return fs:sub(1, from - 1) .. rotation .. fs:sub(i)
				end
				if c == "]" then return fs end
				part = part + 1
				if part == 6 then from = i + 1 end
			end
			i = i + 1
		end
	end
	return fs
end

local function show_character(player, look, rotation)
	local drawn = dress(player, look)
	sfinv.set_page(player, CHARACTER_PAGE)
	local fs = sfinv.get_formspec(player, sfinv.get_or_create_context(player))
	if rotation then
		fs = replace_rotation(fs, rotation)
	end
	core.show_formspec(NAME, "grug_probe_r55_game:character", fs)
	local view = grug_visuals.preview(player)
	log(("character page: preview %d textures; card %s; offhand %s; back %s; wings %s; world back %s"):format(
		#view.textures, view.textures[4], view.textures[5], view.textures[6], view.textures[7],
		tostring(drawn.textures[6])))
end

--
-- The shots.
--
local function shield(b) return "grug_gear:shield_" .. grug_gear.MATERIALS[b].metal.key end
local function book(b) return "grug_gear:spellbook_" .. grug_gear.MATERIALS[b].metal.key end

local function warrior(b)
	return {class = "warrior", line = "metal", tier = b, weapon = grug_gear.weapon_item("sword", b),
		offhand = shield(b)}
end

local function scout(held, cloak)
	local bow, sword = grug_gear.weapon_item("bow", 4), grug_gear.weapon_item("sword", 4)
	local shown = held == "bow_skill" and bow or held == "melee_skill" and sword or ITEMS[held] or held
	return {class = "scout", line = "leather", tier = 4, weapon = bow, offhand = sword,
		held = ITEMS[held] or held, shown = shown, cloak = cloak}
end

local WIDE, FAR, NEAR = {0, 0.6, -4.8}, {0, 0.5, -3.6}, {0, 0.5, -2.2}

local function shots_on()
	local mage = {class = "mage", line = "cloth", tier = 2, weapon = grug_gear.weapon_item("staff", 2),
		offhand = book(2)}
	local priest = {class = "priest", line = "cloth", tier = 5, weapon = grug_gear.weapon_item("staff", 5),
		offhand = book(5)}
	local winged = {class = "priest", line = "cloth", tier = 3, cloak = true, wings = true}
	local function row(looks, yaw, frame)
		local out = {}
		for i, look in ipairs(looks) do
			out[i] = {x = (i - (#looks + 1) / 2) * 1.4, yaw = yaw, frame = frame, look = look}
		end
		return out
	end
	local scouts = {scout("bow_skill"), scout("melee_skill"), scout("pickaxe"),
		scout(grug_gear.weapon_item("bow", 4))}
	local scouts_cloak = {scout("bow_skill", true), scout("melee_skill", true), scout("pickaxe", true),
		scout(grug_gear.weapon_item("sword", 4), true)}
	return {
		{name = "W1_shields_T1_T3_T6_3q", cam = FAR, pitch = 0.2,
			figures = row({warrior(1), warrior(3), warrior(6)}, PI * 0.7, STAND)},
		{name = "W2_shields_T1_T3_T6_left", cam = FAR, pitch = 0.2,
			figures = row({warrior(1), warrior(3), warrior(6)}, PI / 2, STAND)},
		{name = "W3_shields_block_front", cam = FAR, pitch = 0.2,
			figures = row({warrior(1), warrior(3), warrior(6)}, PI, BLOCK)},
		{name = "W4_shields_walk_sit_3q", cam = FAR, pitch = 0.2, figures = {
			{x = -0.8, yaw = PI * 0.7, frame = WALK, look = warrior(6)},
			{x = 0.8, yaw = PI * 0.7, frame = SIT, look = warrior(3)}}},
		{name = "B1_mage_priest_books_3q", cam = FAR, pitch = 0.2, figures = {
			{x = -1.4, yaw = PI * 0.7, frame = STAND, look = mage},
			{x = 0, yaw = PI / 2, frame = STAND, look = priest},
			{x = 1.4, yaw = PI * 0.7, frame = CAST, look = priest}}},
		{name = "S1_scout_back_no_cloak", cam = WIDE, pitch = 0.15,
			figures = row(scouts, PI * 0.1, STAND)},
		{name = "S2_scout_front_no_cloak", cam = WIDE, pitch = 0.15,
			figures = row(scouts, PI * 0.8, STAND)},
		{name = "S3_scout_back_cloak", cam = WIDE, pitch = 0.15,
			figures = row(scouts_cloak, PI * 0.1, STAND)},
		{name = "S4_scout_back_walk_cloak", cam = WIDE, pitch = 0.15,
			figures = row(scouts_cloak, PI * 0.25, WALK)},
		{name = "C1_wings_back_3q", cam = FAR, pitch = 0.2, figures = {
			{x = -1.2, yaw = 0, frame = STAND, look = winged},
			{x = 0, yaw = PI * 0.25, frame = WALK, look = winged},
			{x = 1.2, yaw = PI * 0.5, frame = STAND, look = winged}}},
		{name = "C2_wings_front", cam = FAR, pitch = 0.2, figures = {
			{x = -0.7, yaw = PI, frame = STAND, look = winged},
			{x = 0.7, yaw = PI * 0.75, frame = STAND, look = winged}}},
		{name = "T1_tab_warrior_shield", tab = warrior(6)},
		{name = "T2_tab_warrior_shield_back", tab = warrior(6), rotation = BACK_VIEW},
		{name = "T3_tab_scout_cloak", tab = scout("pickaxe", true)},
		{name = "T4_tab_scout_cloak_back", tab = scout("pickaxe", true), rotation = BACK_VIEW},
		{name = "T5_tab_scout_no_cloak_back", tab = scout("pickaxe"), rotation = BACK_VIEW},
		{name = "T6_tab_mage_book", tab = mage},
	}
end

local function shots_off()
	return {
		{name = "X1_off_warrior_scout_3q", cam = FAR, pitch = 0.2, figures = {
			{x = -0.8, yaw = PI * 0.7, frame = STAND, look = warrior(6)},
			{x = 0.8, yaw = PI * 0.15, frame = STAND, look = scout("bow_skill", true)}}},
		{name = "T1_tab_warrior_shield", tab = warrior(6)},
		{name = "T2_tab_warrior_shield_back", tab = warrior(6), rotation = BACK_VIEW},
		{name = "T4_tab_scout_cloak_back", tab = scout("pickaxe", true), rotation = BACK_VIEW},
	}
end

local SHOTS

-- The api a staged scene.lua gets (see the header).
local scene_path = core.get_modpath(core.get_current_modname()) .. "/scene.lua"
local scene_file = io.open(scene_path, "r")
if scene_file then
	scene_file:close()
	SCENE = dofile(scene_path)({log = log, items = ITEMS, warrior = warrior, scout = scout,
		shield = shield, book = book, frames = {stand = STAND, walk = WALK, block = BLOCK,
		cast = CAST, sit = SIT}, cams = {wide = WIDE, far = FAR, near = NEAR}, back_view = BACK_VIEW,
		name = NAME})
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.2 then return end
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
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		player:hud_set_flags({hotbar = false, healthbar = false, crosshair = false,
			wielditem = false, breathbar = false, minimap = false, minimap_radar = false})
		if not (SCENE and SCENE.real_cloaks) then
			grug_visuals.register_cloak_source(function()
				return stub.cloak, stub.cloak and "plain_grey" or nil, stub.wings
			end)
		end
		find_items()
		log("setting grug_offhand_visuals read as " .. tostring(grug_visuals.OFFHAND_VISUALS))
		SHOTS = {}
		local list = SCENE and (grug_visuals.OFFHAND_VISUALS and SCENE.on() or SCENE.off()) or
			(grug_visuals.OFFHAND_VISUALS and shots_on() or shots_off())
		for _, shot in ipairs(list) do
			if shot.name:sub(1, #ONLY) == ONLY then SHOTS[#SHOTS + 1] = shot end
		end
		local at = vector.round(player:get_pos())
		S = vector.offset(at, 0, 40, 0)
		state.phase = "emerge"
		core.emerge_area(vector.offset(S, -16, -16, -16), vector.offset(S, 16, 16, 24),
			function(_, _, remaining)
				if remaining > 0 then return end
				core.after(0, function()
					build_studio()
					log("studio at " .. core.pos_to_string(S))
					state.phase, state.shot, state.waited, state.logged = "shoot", 1, 0, false
					log("READY")
				end)
			end)
	elseif state.phase == "shoot" then
		core.set_timeofday(0.5)
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			clear()
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then
			if shot.before then
				shot.before(player)
			end
			if shot.formspec then
				clear()
				player:set_pos(vec(FAR))
				core.show_formspec(NAME, "grug_probe_r55_game:scene", shot.formspec())
			elseif shot.tab then
				clear()
				player:set_pos(vec(FAR))
				show_character(player, shot.tab, shot.rotation)
			else
				core.close_formspec(NAME, "grug_probe_r55_game:character")
				core.close_formspec(NAME, "grug_probe_r55_game:scene")
				place(player, shot)
			end
		end
		if not shot.tab and not shot.formspec then
			player:set_pos(vec(shot.cam))
			player:set_look_horizontal(shot.yaw or 0)
			player:set_look_vertical(shot.pitch or 0)
		end
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
