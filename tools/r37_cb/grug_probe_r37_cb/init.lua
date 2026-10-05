-- Disposable Round 37 CB probe (tools/r37_cb/engine.sh). Never shipped.
--
-- The server cost of durability on the combat path, with fake players (the
-- Round 35 T stand-in) joined through the real join chain, each a Warrior
-- with a sword, four armour pieces, a filled main list and four filled bags,
-- the Character page selected (the default):
--   WEAPON  one weapon-wear event: grug_core.run_settled_outgoing_action with
--           a fresh action id, which is what every landed swing or cast
--           settles (grug_repair wears the melee weapon);
--   TAKEN   one taken hit: every non-modifier hp-change callback with a
--           punch reason, as the engine runs them after the modifier (the
--           settled-incoming hook wears a random armour piece, plus the HUD,
--           nametag and talent loggers);
--   TAKEN0  the same chain with every armour piece removed (no wear), so
--           TAKEN - TAKEN0 is the armour-wear share.
-- Per kind: the median and best microseconds per event over ROUNDS rounds,
-- and how many Character-page formspecs and property writes one event
-- caused. CHECK lines compare the weapon's tooltip line with the exact
-- durability afterwards. Every line carries "[r37cb]"; the probe ends the
-- server when done. It calls only seams that exist before and after the
-- Round 37 change, so the same probe measures both.
local P = "[r37cb] "
local function log(s) core.log("action", P .. s) end
local now_us = core.get_us_time
local NPLAYERS = 8
local ROUNDS = 9
local PER_ROUND = 25 -- events per fake player per round

-- ------------------------------------------------------------ fake players
local fakes, fake_list = {}, {}
local orig_gcp = core.get_connected_players
local orig_gpbn = core.get_player_by_name
core.get_connected_players = function()
	local real = orig_gcp()
	if #fake_list == 0 then return real end
	local out = {}
	for i = 1, #real do out[i] = real[i] end
	for i = 1, #fake_list do out[#out + 1] = fake_list[i] end
	return out
end
core.get_player_by_name = function(name) return fakes[name] or orig_gpbn(name) end
local orig_gpwi = core.get_player_window_information
core.get_player_window_information = function(name)
	if fakes[name] then
		return {size = {x = 1920, y = 1080}, max_formspec_size = {x = 20, y = 11.25},
			real_gui_scaling = 1, real_hud_scaling = 1}
	end
	return orig_gpwi(name)
end
local orig_gpi = core.get_player_information
core.get_player_information = function(name)
	if fakes[name] then
		return {address = "127.0.0.1", ip_version = 4, connection_uptime = 100,
			protocol_version = 48, formspec_version = 8, lang_code = "",
			min_rtt = 0.01, max_rtt = 0.05, avg_rtt = 0.02, min_jitter = 0,
			max_jitter = 0, avg_jitter = 0, version_string = "5.15.0"}
	end
	return orig_gpi(name)
end
local fake_refs = {}
local orig_ctc = grug_core.create_tag_carrier
grug_core.create_tag_carrier = function(parent, owner)
	if fake_refs[parent] then return nil end
	return orig_ctc(parent, owner)
end

local counts = {formspec = 0, properties = 0}

local function new_meta()
	local store = {}
	local m = {}
	function m:get_string(k) return store[k] or "" end
	function m:set_string(k, v)
		v = tostring(v or "")
		store[k] = v ~= "" and v or nil
	end
	function m:get(k) return store[k] end
	function m:get_int(k) return math.floor(tonumber(store[k]) or 0) end
	function m:set_int(k, v) store[k] = tostring(math.floor(v)) end
	function m:get_float(k) return tonumber(store[k]) or 0 end
	function m:set_float(k, v) store[k] = tostring(v) end
	function m:contains(k) return store[k] ~= nil end
	function m:get_keys() local r = {} for k in pairs(store) do r[#r + 1] = k end return r end
	function m:to_table() return {fields = table.copy(store)} end
	function m:from_table() return true end
	function m:equals(o) return o == m end
	function m:mark_as_private() end
	return m
end

local function make_fake(name, pos)
	local inv = core.create_detached_inventory("r37cb_" .. name, {}, name)
	for list, size in pairs({main = 32, craft = 9, craftpreview = 1,
			craftresult = 1, hand = 1}) do
		inv:set_size(list, size)
	end
	inv:set_width("craft", 3)
	local p = {_name = name, _pos = vector.copy(pos), _yaw = 0, _pitch = 0,
		_hp = 20, _breath = 10, _inv = inv, _meta = new_meta(), _huds = {},
		_next_hud = 0, _wield = 1, _formspec = "", _prepend = "",
		_armor = {fleshy = 100}, _physics = {speed = 1, jump = 1, gravity = 1},
		_props = {hp_max = 20, breath_max = 10, eye_height = 1.625,
			collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
			selectionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
			visual = "mesh", mesh = "character.b3d", textures = {"character.png"},
			visual_size = {x = 1, y = 1}, stepheight = 0.6, nametag = ""},
		_flags = {breathing = true, drowning = true, node_damage = true},
		_hudflags = {hotbar = true, healthbar = true, crosshair = true,
			wielditem = true, breathbar = true, minimap = false,
			minimap_radar = false, basic_debug = false, chat = true},
		_nametag = {color = {a = 255, r = 255, g = 255, b = 255}, text = ""},
		_lighting = {}, _sky = {}, _anim = {range = {x = 0, y = 0}, speed = 0, blend = 0, loop = true},
		_eye1 = vector.zero(), _eye3 = vector.zero()}
	p._meta:set_string("grug_factions:faction", "accord")
	p._meta:set_string("grug_classes:race", "human")
	p._meta:set_string("grug_classes:class", "warrior")
	local M = {}
	function M:is_player() return true end
	function M:is_valid() return true end
	function M:get_player_name() return self._name end
	function M:get_pos() return vector.copy(self._pos) end
	function M:set_pos(v) self._pos = vector.copy(v) end
	function M:move_to(v) self._pos = vector.copy(v) end
	function M:get_velocity() return vector.zero() end
	function M:get_look_horizontal() return self._yaw end
	function M:get_look_vertical() return self._pitch end
	function M:get_yaw() return self._yaw end
	function M:get_look_dir()
		local c = math.cos(self._pitch)
		return vector.new(-math.sin(self._yaw) * c, -math.sin(self._pitch), math.cos(self._yaw) * c)
	end
	function M:get_hp() return self._hp end
	function M:set_hp(hp) self._hp = math.max(0, math.min(self._props.hp_max or 20, math.floor(hp))) end
	function M:get_breath() return self._breath end
	function M:get_properties() return table.copy(self._props) end
	function M:set_properties(t)
		counts.properties = counts.properties + 1
		for k, v in pairs(t or {}) do self._props[k] = v end
	end
	function M:get_meta() return self._meta end
	function M:get_inventory() return self._inv end
	function M:get_wield_index() return self._wield end
	function M:get_wield_list() return "main" end
	function M:get_wielded_item() return self._inv:get_stack("main", self._wield) end
	function M:set_wielded_item(s) self._inv:set_stack("main", self._wield, s) return true end
	function M:get_player_control()
		return {up = false, down = false, left = false, right = false, jump = false,
			aux1 = false, sneak = false, dig = false, place = false, LMB = false,
			RMB = false, zoom = false, movement_x = 0, movement_y = 0}
	end
	function M:get_player_control_bits() return 0 end
	function M:get_armor_groups() return table.copy(self._armor) end
	function M:set_armor_groups(t) self._armor = table.copy(t) end
	function M:get_physics_override() return table.copy(self._physics) end
	function M:set_physics_override(t) for k, v in pairs(t or {}) do self._physics[k] = v end end
	function M:get_attach() return nil end
	function M:get_children() return {} end
	function M:get_luaentity() return nil end
	function M:get_eye_offset() return vector.copy(self._eye1), vector.copy(self._eye3), vector.copy(self._eye3) end
	function M:get_flags() return table.copy(self._flags) end
	function M:hud_get_flags() return table.copy(self._hudflags) end
	function M:get_sky() return self._sky end
	function M:get_lighting() return self._lighting end
	function M:get_nametag_attributes() return table.copy(self._nametag) end
	function M:set_nametag_attributes(t) for k, v in pairs(t or {}) do self._nametag[k] = v end end
	function M:get_animation() local a = self._anim return a.range, a.speed, a.blend, a.loop end
	function M:get_formspec_prepend() return self._prepend end
	function M:get_inventory_formspec() return self._formspec end
	function M:set_inventory_formspec(fs)
		counts.formspec = counts.formspec + 1
		self._formspec = fs
	end
	function M:get_camera() return {mode = "any"} end
	function M:hud_add(def)
		self._next_hud = self._next_hud + 1
		self._huds[self._next_hud] = table.copy(def or {})
		return self._next_hud
	end
	function M:hud_change(id, stat, value)
		if self._huds[id] then self._huds[id][stat] = value end
	end
	function M:hud_remove(id) self._huds[id] = nil end
	function M:hud_get(id) return self._huds[id] and table.copy(self._huds[id]) end
	setmetatable(p, {__index = function(_, key)
		local fn = M[key]
		if fn then return fn end
		if type(key) == "string" and (key:match("^get_") or key:match("^set_") or
				key:match("^hud_") or key:match("^is_") or key:match("^add_") or
				key:match("^send_") or key:match("^override_") or
				key == "punch" or key == "respawn" or key == "remove") then
			return function() return nil end
		end
		return nil
	end})
	fake_refs[p] = true
	return p
end

local function join_fake(p)
	pcall(function()
		local h = core.get_auth_handler()
		if not h.get_auth(p._name) then h.create_auth(p._name, "") end
	end)
	fakes[p._name] = p
	fake_list[#fake_list + 1] = p
	for _, cb in ipairs(core.registered_on_joinplayers) do
		local ok, err = pcall(cb, p, nil)
		if not ok then
			local origin = core.callback_origins[cb]
			log("JOINERR " .. tostring(origin and origin.mod) .. " " .. tostring(err):sub(1, 200))
		end
	end
end

-- ------------------------------------------------------------ gear
local ARMOR = {grug_head = "grug_equip_head", grug_chest = "grug_equip_chest",
	grug_legs = "grug_equip_legs", grug_feet = "grug_equip_feet"}

local function pick_gear()
	local names = {}
	for name in pairs(core.registered_items) do names[#names + 1] = name end
	table.sort(names)
	local gear = {}
	for _, name in ipairs(names) do
		local def = core.registered_items[name]
		local groups = def.groups or {}
		local stack = ItemStack(name)
		if not gear.grug_weapon and (groups.grug_equip_weapon or 0) > 0 and
				grug_gear.weapon_family(stack) == "sword" then
			gear.grug_weapon = name
		end
		for list, group in pairs(ARMOR) do
			if not gear[list] and (groups[group] or 0) > 0 then gear[list] = name end
		end
	end
	return gear
end

local function fill_bags(p)
	local inv = p:get_inventory()
	local names = {}
	for name, def in pairs(core.registered_craftitems) do
		if not name:find("bag", 1, true) and (def.stack_max or 99) > 1 then names[#names + 1] = name end
	end
	table.sort(names)
	for i = 1, math.min(24, #names) do
		inv:set_stack("main", i + 8, ItemStack(names[(i * 37) % #names + 1] .. " 5"))
	end
	local bags = {}
	for name in pairs(core.registered_items) do
		if core.get_item_group(name, "bagslots") > 0 then bags[#bags + 1] = name end
	end
	table.sort(bags, function(a, b)
		return core.get_item_group(a, "bagslots") > core.get_item_group(b, "bagslots")
	end)
	for i = 1, grug_inventory.BAG_COUNT do
		local bag = bags[1]
		if bag then
			inv:set_stack(grug_inventory.bag_list(i), 1, ItemStack(bag))
			local slots = core.get_item_group(bag, "bagslots")
			inv:set_size(grug_inventory.content_list(i), slots)
			for s = 1, slots, 2 do
				inv:set_stack(grug_inventory.content_list(i), s,
					ItemStack(names[(s * 13 + i * 7) % #names + 1] .. " 3"))
			end
		end
	end
end

local function equip(p, gear, with_armor)
	local inv = p:get_inventory()
	for list, name in pairs(gear) do
		local stack = ItemStack("")
		if list == "grug_weapon" or with_armor then
			stack = ItemStack(name)
			grug_gear.initialize_weapon_tooltip(stack, p)
		end
		inv:set_stack(list, 1, stack)
	end
	grug_inventory.equipment_changed(p)
end

-- ------------------------------------------------------------ bench
local function median(list)
	local sorted = {}
	for i, v in ipairs(list) do sorted[i] = v end
	table.sort(sorted)
	return sorted[math.floor((#sorted + 1) / 2)], sorted[1]
end

local function bench(label, event)
	local per = {}
	counts.formspec, counts.properties = 0, 0
	local events = 0
	for _ = 1, ROUNDS do
		local t = now_us()
		for _, p in ipairs(fake_list) do
			for _ = 1, PER_ROUND do event(p) end
		end
		local n = #fake_list * PER_ROUND
		per[#per + 1] = (now_us() - t) / n
		events = events + n
	end
	local med, best = median(per)
	log(("RESULT %s median=%.1f us/event best=%.1f us/event events=%d " ..
		"formspecs/event=%.2f property_writes/event=%.2f"):format(label, med, best,
		events, counts.formspec / events, counts.properties / events))
end

local function weapon_event(p)
	grug_core.run_settled_outgoing_action(p, {}, "damage")
end

local loggers = core.registered_on_player_hpchanges.loggers
local function taken_event(p)
	local reason = {type = "punch", from = "mod"}
	for i = 1, #loggers do loggers[i](p, -1, reason) end
end

local function check_lines(label)
	local bad, worst = 0, ""
	for _, p in ipairs(fake_list) do
		for _, list in ipairs({"grug_weapon", "grug_head", "grug_chest", "grug_legs", "grug_feet"}) do
			local stack = p:get_inventory():get_stack(list, 1)
			if not stack:is_empty() then
				local want = grug_repair.durability_line(stack)
				local desc = stack:get_meta():get_string("description")
				if not desc:find(want, 1, true) then
					bad = bad + 1
					worst = list .. " want '" .. want .. "'"
				end
			end
		end
	end
	log(("CHECK %s durability lines exact: %s %s"):format(label, bad == 0 and "yes" or
		("NO (" .. bad .. " off)"), worst))
end

-- ------------------------------------------------------------ phases
local phase, phase_t, total_t = "wait", 0, 0
local gear
core.register_globalstep(function(dtime)
	total_t = total_t + dtime
	phase_t = phase_t + dtime
	if phase == "wait" then
		-- A fake joining before world preparation is ready stays in the
		-- character-creation lock, which suspends its Character page.
		if total_t > 3 and grug_core.zone_authority_installed() and
				(grug_core.world_preparation_status().ready or total_t > 200) then
			log(("world preparation ready=%s after %.0f s"):format(
				tostring(grug_core.world_preparation_status().ready), total_t))
			local start = grug_core.start_position("accord", "human")
			gear = pick_gear()
			for list, name in pairs(gear) do log("gear " .. list .. " " .. name) end
			for i = 1, NPLAYERS do
				local p = make_fake("r37cb" .. i, start)
				join_fake(p)
				fill_bags(p)
				equip(p, gear, true)
			end
			local ctx = sfinv.contexts[fake_list[1]:get_player_name()]
			log("fakes " .. #fake_list .. " page " .. tostring(ctx and ctx.page) ..
				" suspended " .. tostring(sfinv.inventory_suspended(fake_list[1])))
			phase, phase_t = "bench", 0
		end
	elseif phase == "bench" and phase_t > 1 then
		bench("WEAPON", weapon_event)
		bench("TAKEN", taken_event)
		check_lines("after wear")
		for _, p in ipairs(fake_list) do equip(p, gear, false) end
		bench("TAKEN0", taken_event)
		log("RESULT DONE")
		phase = "off"
		core.request_shutdown("r37cb probe done", false, 0)
	end
end)
