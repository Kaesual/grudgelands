-- Disposable engine probe (Round 54 lane VIEW): the character creation
-- preview and the Character tab's 3D view, for screenshots. Never shipped:
-- tools/r54_view/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, SHOT / ack
-- handshake) follows tools/r49_inv's probe.
--
-- The Character page is shown as a dialog with sfinv's own formspec for the
-- page (the same string the inventory would show). Gear is written straight
-- into the equipment lists and announced through
-- grug_inventory.equipment_changed, the game's path for a server-side write.
-- An `_alt` shot is the same page with another camera rotation in the
-- model[] element, to compare (the user tunes the view).

local P = "[r54view] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r54view_settle") or "") or 3
local ALT_ROTATION = core.settings:get("r54view_alt") or "0,200"
local CHARACTER_PAGE = "grug_inventory:character"
local ARMOR_SLOTS = {"head", "chest", "legs", "feet"}

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r54view_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- What the page's model[] shows, for the log: mesh, texture count and the
-- element's length, and the weapon slot.
local function describe_preview(player)
	local preview = grug_visuals.preview
	if not preview then
		local props = player:get_properties()
		return "no seam; live mesh " .. tostring(props.mesh) .. " textures " ..
			#(props.textures or {})
	end
	local view = preview(player)
	local lengths = {}
	for index, texture in ipairs(view.textures) do lengths[index] = #texture end
	return ("seam mesh %s textures %d lengths %s weapon %s"):format(view.mesh,
		#view.textures, table.concat(lengths, "/"), tostring(view.textures[4]))
end

-- The page with another camera rotation: the model[] element's sixth part
-- (pos; size; name; mesh; textures; rotation), found by walking its
-- unescaped ";" up to the ";" or "]" that ends it.
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

local function show_character(player, rotation)
	sfinv.set_page(player, CHARACTER_PAGE)
	local context = sfinv.get_or_create_context(player)
	local fs = sfinv.get_formspec(player, context)
	if rotation then
		fs = replace_rotation(fs, rotation)
	end
	core.show_formspec(NAME, "grug_probe_r54_view:character", fs)
	log(("character page %d bytes; %s"):format(#fs, describe_preview(player)))
end

local function wear(player, line, bracket, weapon)
	local inv = player:get_inventory()
	for _, slot in ipairs(ARMOR_SLOTS) do
		inv:set_stack("grug_" .. slot, 1, line and grug_gear.armor_item(slot, line, bracket) or "")
	end
	inv:set_stack("grug_weapon", 1, weapon or "")
	inv:set_stack("grug_offhand", 1, "")
	grug_inventory.equipment_changed(player)
	local worn = {}
	for _, list in ipairs({"grug_head", "grug_chest", "grug_legs", "grug_feet", "grug_weapon"}) do
		worn[#worn + 1] = list .. "=" .. inv:get_stack(list, 1):get_name()
	end
	log("wearing " .. table.concat(worn, " "))
end

local SHOTS = {
	{name = "C1_creation", run = function(player)
		core.show_formspec(NAME, "grug_probe_r54_view:creation",
			player:get_inventory_formspec())
		log("creation window " .. #player:get_inventory_formspec() .. " bytes")
	end},
	-- Create first; the shot waits for the arrival and its welcome dialog,
	-- which the Character page then replaces.
	{name = "V1_metal_t6_sword", prepare = function(player)
		core.close_formspec(NAME, "grug_probe_r54_view:creation")
		submit(player, "", {create_character = "Create"})
		state.arrived = nil
	end, ready = function(player)
		if player:get_meta():get_string("grug_classes:arriving") ~= "" or
				not grug_classes.get_class(player) then
			return false
		end
		state.arrived = state.arrived or core.get_us_time()
		return core.get_us_time() - state.arrived > 3000000
	end, run = function(player)
		core.close_formspec(NAME, "grug_inventory:welcome")
		wear(player, "metal", 6, grug_gear.weapon_item("sword", 6))
		show_character(player)
	end},
	{name = "V1_metal_t6_sword_alt", run = function(player)
		show_character(player, ALT_ROTATION)
	end},
	{name = "V2_cloth_t1_bare", run = function(player)
		wear(player, "cloth", 1, nil)
		show_character(player)
	end},
	{name = "V2_cloth_t1_bare_alt", run = function(player)
		show_character(player, ALT_ROTATION)
	end},
	-- A bow in the main hand list (the Scout's Ranged slot is that list).
	{name = "V3_leather_t3_bow", run = function(player)
		wear(player, "leather", 3, grug_gear.weapon_item("bow", 3))
		show_character(player)
	end},
	{name = "V3_leather_t3_bow_alt", run = function(player)
		show_character(player, ALT_ROTATION)
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
		if grug_classes.get_class(player) then
			log("the client's character exists already; the probe needs a new one")
			state.phase = "done"
			core.request_shutdown("probe done", false, 0)
			return
		end
		-- The draft only: the creation shot comes first, Create in V1.
		submit(player, "", {faction_accord = "Accord"})
		submit(player, "", {race_human = "Human"})
		submit(player, "", {class_warrior = "Warrior"})
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
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
			if shot.prepare and not state.prepared then
				state.prepared = true
				shot.prepare(player)
			end
			if shot.ready and not shot.ready(player) then return end
			state.ran = true
			shot.run(player)
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran, state.prepared = 0, false, false, false
		end
	end
end)
