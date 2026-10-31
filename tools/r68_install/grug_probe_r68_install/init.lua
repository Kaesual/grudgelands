-- Disposable engine probe (Round 68 follow-up INSTALL): the picked bar,
-- setting, gem and block icons, for screenshots. Never shipped:
-- tools/r68_install/capture.sh stages it through tools/luanti_headless.sh
-- and connects one real client. The driver (character creation, SHOT / ack
-- handshake) is tools/r68_signs' probe.
--
-- I1/I2: a form with the 47 items in inventory slots (a read-only detached
-- inventory, so the client draws them exactly as in a bag), rows of the
-- same items as item images at about 32 and 16 px below.
-- W1-W3: walls of the ten metal blocks and the seven gem blocks, two high,
-- and a 3 x 3 patch each of Garnet, Ruby, Iron, Steel, Silversteel and
-- Gold, built in the air 30 nodes above the arrival point (stone floor,
-- noon).
-- Scene "stairs" (r68install_scene, follow-up STAIRS) instead: S1-S3, each
-- of the five metal blocks with its stair, inner stair, outer stair and
-- slab beside it, one row per metal.

local P = "[r68install] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r68install_settle") or "") or 3
local SCENE = core.settings:get("r68install_scene") or "icons"
local M, A = "grug_materials:", "grug_artisans:"

local METALS = {"copper", "tin", "bronze", "iron", "steel", "silver", "silversteel",
	"embersteel", "abyssal_steel", "gold"}
local SETTINGS = {"tin", "iron", "copper_inlaid_steel", "gold", "gold_filigreed_embersteel",
	"gold_filigreed_abyssal_steel"}
local GEMS = {"citrine", "jade", "garnet", "sapphire", "ruby", "diamond"}

-- Rows of the form: bars, settings, rough/cut pairs, the two minerals,
-- metal blocks, gem and crystal blocks.
local ROWS = {{}, {}, {}, {}, {}, {}}
for _, key in ipairs(METALS) do
	table.insert(ROWS[1], M .. key .. "_bar")
	table.insert(ROWS[5], M .. key .. "_block")
end
for _, key in ipairs(SETTINGS) do table.insert(ROWS[2], A .. "setting_" .. key) end
for _, key in ipairs(GEMS) do
	table.insert(ROWS[3], M .. "rough_" .. key)
	table.insert(ROWS[3], M .. "cut_" .. key)
	table.insert(ROWS[6], M .. key .. "_block")
end
ROWS[4] = {M .. "quartz", M .. "abyssal_crystal"}
table.insert(ROWS[6], M .. "abyssal_crystal_block")

local function log(msg) core.log("action", P .. msg) end

local inv = core.create_detached_inventory("r68install", {
	allow_move = function() return 0 end,
	allow_put = function() return 0 end,
	allow_take = function() return 0 end,
})
local total = 0
for _, row in ipairs(ROWS) do total = total + #row end
inv:set_size("main", total)
do
	local i = 1
	for _, row in ipairs(ROWS) do
		for _, name in ipairs(row) do
			inv:set_stack("main", i, name)
			i = i + 1
		end
	end
end

local function form()
	local spec = {"formspec_version[6]", "size[16,14.6]", "no_prepend[]",
		"bgcolor[#202020ff;true]"}
	local y, start = 0.4, 0
	for _, row in ipairs(ROWS) do
		spec[#spec + 1] = ("list[detached:r68install;main;0.4,%.2f;%d,1;%d]"):format(y, #row, start)
		start = start + #row
		y = y + 1.35
	end
	-- The same items as item images at two small sizes (about 32 and 16 px
	-- at the capture's GUI scale; the report measures them).
	for _, size in ipairs({0.5, 0.25}) do
		local x = 0.4
		for _, row in ipairs(ROWS) do
			for _, name in ipairs(row) do
				if x + size > 15.6 then x, y = 0.4, y + size * 1.4 end
				spec[#spec + 1] = ("item_image[%.2f,%.2f;%.2f,%.2f;%s]"):format(x, y, size, size, name)
				x = x + size * 1.15
			end
		end
		y = y + size * 1.6
	end
	return table.concat(spec)
end

local state = {phase = "wait", clock = 0}
local O

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r68install_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function at(x, y, z) return vector.add(O, vector.new(x, y, z)) end
local function set(x, y, z, name) core.set_node(at(x, y, z), {name = name}) end

local function build()
	for x = -4, 40 do for z = -8, 6 do set(x, -1, z, "default:stone") end end
	-- W1: the ten metal blocks, each a column two high, at z = 2.
	for i, key in ipairs(METALS) do
		for y = 0, 1 do set(i - 1, y, 2, M .. key .. "_block") end
	end
	-- W2: the seven gem and crystal blocks beside them.
	for i, name in ipairs(ROWS[6]) do
		for y = 0, 1 do set(11 + i, y, 2, name) end
	end
	-- W3: 3 x 3 patches (the repeated tile): Garnet, Ruby, Iron, Steel,
	-- Silversteel and Gold.
	for i, name in ipairs({M .. "garnet_block", M .. "ruby_block", M .. "iron_block",
			M .. "steel_block", M .. "silversteel_block", M .. "gold_block"}) do
		local x0 = 22 + (i - 1) * 3
		for x = 0, 2 do for y = 0, 2 do set(x0 + x, y, 2, name) end end
	end
end

local function view(player, x, y, z, yaw, pitch)
	player:set_pos(at(x, y, z))
	player:set_look_horizontal(math.rad(yaw))
	player:set_look_vertical(math.rad(pitch))
end

-- The player's eyes are about 1.5 above its position.
local SHOTS = {
	{name = "I1_inventory_slots", run = function(p, player_name)
		view(p, 4.5, -0.5, -6, 0, 0)
		core.show_formspec(player_name, "grug_probe_r68_install:icons", form())
	end},
	{name = "W1_metal_and_gem_walls", run = function(p, player_name)
		core.close_formspec(player_name, "grug_probe_r68_install:icons")
		view(p, 9, -0.6, -6.5, 0, 6)
	end},
	{name = "W2_walls_angle", run = function(p) view(p, 1, -0.6, -2.5, 50, 6) end},
	{name = "W3_repeated_patches", run = function(p) view(p, 30.5, -0.3, -5.5, 0, 4) end},
}

-- Scene "stairs": rows at z = 2, 4, ..., 10 (Iron, Tin, Copper, Bronze,
-- Gold), x = 0 block, 1 stair, 2 inner stair, 3 outer stair, 4 slab; the
-- stairs face the camera (param2 0 puts the high step at +z).
local STAIR_METALS = {"iron", "tin", "copper", "bronze", "gold"}
local STAIR_ROW = {"%s_block", "stair_%s_block", "stair_inner_%s_block",
	"stair_outer_%s_block", "slab_%s_block"}
if SCENE == "stairs" then
	ROWS = {}
	for i, metal in ipairs(STAIR_METALS) do
		ROWS[i] = {}
		for _, pattern in ipairs(STAIR_ROW) do
			table.insert(ROWS[i], M .. pattern:format(metal))
		end
	end
	total = #STAIR_METALS * #STAIR_ROW
	build = function()
		for x = -4, 12 do for z = -8, 14 do set(x, -1, z, "default:stone") end end
		for i, row in ipairs(ROWS) do
			for x, name in ipairs(row) do set(x - 1, 0, 2 * i, name) end
		end
	end
	SHOTS = {
		{name = "S1_metal_stairs_above", run = function(p) view(p, 2, 3.5, -3, 0, 38) end},
		{name = "S2_metal_stairs_angle", run = function(p) view(p, -3.5, 1.5, -2, -35, 22) end},
		{name = "S3_iron_and_tin_close", run = function(p) view(p, 2, 0.6, -0.6, 0, 30) end},
	}
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
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		O = vector.round(vector.add(player:get_pos(), vector.new(0, 30, 0)))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:hud_set_flags({crosshair = false, wielditem = false})
		core.set_timeofday(0.5)
		build()
		for i, row in ipairs(ROWS) do
			local images = {}
			for _, name in ipairs(row) do
				local def = core.registered_items[name]
				local image = def and (def.tiles and def.tiles[1] or def.inventory_image) or "?"
				-- Stairs and slabs carry tile tables (name, alignment).
				images[#images + 1] = type(image) == "table" and image.name or image
			end
			log(("row %d: %s"):format(i, table.concat(images, " ")))
		end
		log(("built at %s, %d items"):format(core.pos_to_string(O), total))
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
			core.set_timeofday(0.5)
			shot.run(player, NAME)
			log("ran " .. shot.name)
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
