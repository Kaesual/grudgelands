-- Disposable engine probe (playtest-fix Lane A). Never shipped:
-- tools/pt_fixes/lane_a/run.sh stages it through tools/luanti_headless.sh.
--
-- A headless server has no client, so each "player" is a real, invisible,
-- non-pointable probe entity whose ObjectRef answers the player accessors the
-- input path reads (is_player, name, controls, look, meta, inventory, wield,
-- HUD, physics). The engine's side of a right-click is replayed faithfully:
-- controls first, then the wielded item's on_place (node), on_secondary_use
-- (object/nothing) and ObjectRef:right_click for an object, and the engine's
-- repeat_place_time (0.25 s) repeats while RMB stays held on a node. The
-- shipped code under test runs unmodified on the real engine: contextual
-- input (stepped every server step like the 20 Hz pass), grug_food, the
-- Scout draw loop and the grug_core movement aggregator.

local P = "[food_input_probe] "
local BASE = vector.new(400, 300, 400)
local SPACING = 8
local REPEAT_PLACE = 0.25
local failures, checks = 0, 0

local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
end

core.register_entity("grug_probe_food_input:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	on_punch = function() return true end,
})

-- An interactive NPC stand-in. Registered at load time, so contextual input's
-- generic on_mods_loaded wrapper covers it like every trader and villager.
local npc_clicks = 0
core.register_entity("grug_probe_food_input:npc", {
	initial_properties = {
		physical = false, pointable = true, static_save = false,
		visual = "sprite", textures = {"blank.png"},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	on_rightclick = function(self, clicker)
		npc_clicks = npc_clicks + 1
	end,
})

--
-- Probe players.
--
local fakes, by_name, active = {}, {}, {}
local methods

local function install(ref)
	if methods then return end
	methods = getmetatable(ref)
	local function override(name, fn)
		local original = methods[name]
		methods[name] = function(self, ...)
			local fake = fakes[self]
			if fake then return fn(fake, ...) end
			return original(self, ...)
		end
	end
	override("is_player", function() return true end)
	override("get_player_name", function(f) return f.name end)
	override("get_player_control", function(f) return f.controls end)
	override("get_player_control_bits", function() return 0 end)
	override("get_look_dir", function(f) return vector.copy(f.look) end)
	override("get_look_horizontal", function(f) return f.yaw end)
	override("get_look_vertical", function(f) return f.pitch end)
	override("get_meta", function(f) return f.holder:get_meta() end)
	override("get_inventory", function(f) return f.inv end)
	override("get_wield_list", function() return "main" end)
	override("get_wield_index", function(f) return f.index end)
	override("get_wielded_item", function(f)
		return f.inv:get_stack("main", f.index)
	end)
	override("set_wielded_item", function(f, stack)
		return f.inv:set_stack("main", f.index, stack)
	end)
	override("hud_add", function(f, def)
		f.hud_next = f.hud_next + 1
		f.huds[f.hud_next] = table.copy(def)
		if def.z_index == -200 then f.eat_huds = f.eat_huds + 1 end
		return f.hud_next
	end)
	override("hud_change", function(f, id, stat, value)
		local hud = f.huds[id]
		if not hud then return false end
		hud[stat] = value
		if hud.z_index == -200 and stat == "offset" then
			f.jitter[#f.jitter + 1] = value.y
		end
		return true
	end)
	override("hud_remove", function(f, id) f.huds[id] = nil end)
	override("hud_get_flags", function(f) return table.copy(f.flags) end)
	override("hud_set_flags", function(f, flags)
		for key, value in pairs(flags) do f.flags[key] = value end
	end)
	override("set_physics_override", function(f, override)
		for key, value in pairs(override) do f.physics[key] = value end
	end)
	override("get_physics_override", function(f) return table.copy(f.physics) end)
	local get_player_by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return by_name[name] or get_player_by_name(name)
	end
	local equipped = grug_core.get_equipped_weapon
	grug_core.get_equipped_weapon = function(player)
		local fake = player and fakes[player]
		if fake then return fake.weapon and ItemStack(fake.weapon) or nil end
		return equipped(player)
	end
end

local function make_player(label, class, pos)
	local ref = core.add_entity(pos, "grug_probe_food_input:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_" .. label
	local inv = core.create_detached_inventory("grug_probe_" .. label, {})
	inv:set_size("main", 32)
	local fake = {
		name = name, ref = ref, controls = {}, look = vector.new(0, -0.6, 0.8),
		yaw = 0, pitch = 0.6, holder = ItemStack("default:stick"), inv = inv,
		index = 1, huds = {}, hud_next = 0, eat_huds = 0, jitter = {},
		flags = {wielditem = true}, physics = {}, natives = 0,
	}
	fake.look = vector.normalize(fake.look)
	fakes[ref] = fake
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	-- Faction protection covers most of the world; the probe tests input,
	-- not territory, so its players may build anywhere.
	core.set_player_privs(name, {interact = true, protection_bypass = true})
	ref:get_meta():set_string("grug_classes:class", class)
	for _, fn in ipairs(core.registered_on_joinplayers) do
		local origin = core.callback_origins[fn]
		if origin and origin.mod == "grug_projectiles" then fn(ref, nil) end
	end
	active[name] = fake
	return ref, fake
end

--
-- The engine's side of RMB.
--
local function native(fake, pointed)
	local ref = fake.ref
	fake.natives = fake.natives + 1
	local stack = ref:get_wielded_item()
	local def = stack:get_definition()
	if pointed.type == "node" then
		local result = def.on_place(stack, ref, pointed)
		if result then ref:set_wielded_item(result) end
		return
	end
	if def.on_secondary_use then
		local result = def.on_secondary_use(stack, ref, pointed)
		if result then ref:set_wielded_item(result) end
	end
	if pointed.type == "object" and pointed.ref:get_pos() then
		pointed.ref:right_click(ref)
	end
end

local function press(fake, pointed)
	fake.controls = {place = true}
	fake.pointed = pointed
	fake.next_repeat = core.get_us_time() + REPEAT_PLACE * 1e6
	if pointed then native(fake, pointed) end
end

local function release(fake)
	fake.controls = {}
	fake.pointed = nil
end

-- The 20 Hz contextual pass reaches connected players only; probe players are
-- stepped here on every server step, plus the engine's node place repeats.
core.register_globalstep(function()
	local now = core.get_us_time()
	for _, fake in pairs(active) do
		if fake.controls.place and fake.pointed and fake.pointed.type == "node" and
				now >= fake.next_repeat then
			fake.next_repeat = now + REPEAT_PLACE * 1e6
			fake.repeats = (fake.repeats or 0) + 1
			native(fake, fake.pointed)
		end
		grug_abilities.input.step(fake.ref)
	end
end)

--
-- Observation helpers.
--
local notices, bursts, sounds = {}, {}, {}

local function aim(ref, fake, target)
	local eye = vector.offset(ref:get_pos(), 0,
		ref:get_properties().eye_height or 1.625, 0)
	local cb = target:get_properties().collisionbox or {0, 0, 0, 0, 1, 0}
	local centre = vector.offset(target:get_pos(), 0, (cb[2] + cb[5]) / 2, 0)
	local dir = vector.direction(eye, centre)
	fake.look = dir
	fake.yaw = core.dir_to_yaw(dir)
	fake.pitch = -math.asin(dir.y)
end

local function spawn_mob(pos)
	local obj = core.add_entity(pos, "grug_mobs:bandit")
	local ent = obj and obj:get_luaentity()
	assert(ent, "mob was not added")
	grug_mobs.ensure_init(ent)
	ent._grug_level = 1
	grug_mobs.ensure_init(ent)
	ent.health = ent.hp_max
	ent.old_health = ent.health
	return obj, ent
end

-- Place sounds the probe player hears itself.
local function place_sound_heard(fake, item_name)
	local def = core.registered_nodes[item_name]
	local want = def and def.sounds and def.sounds.place
	want = type(want) == "table" and want.name or want
	for _, entry in ipairs(sounds) do
		if entry.to == fake.name and entry.name == want then return true end
	end
	return false
end
local rightclicks = {door = 0, chest = 0}

local function wrap_observers()
	local notify = grug_abilities.notify
	grug_abilities.notify = function(player, text, ...)
		notices[#notices + 1] = {name = player:get_player_name(), text = text}
		return notify(player, text, ...)
	end
	local flash = grug_abilities.flash
	grug_abilities.flash = function(player, text, ...)
		log("flash to " .. player:get_player_name() .. ": " .. tostring(text))
		return flash(player, text, ...)
	end
	local play = core.sound_play
	core.sound_play = function(spec, params, ...)
		sounds[#sounds + 1] = {name = type(spec) == "table" and spec.name or spec,
			to = params and params.to_player}
		return play(spec, params, ...)
	end
	local spawner = core.add_particlespawner
	core.add_particlespawner = function(def, ...)
		local pool = def and def.texpool
		if type(pool) == "table" and type(pool[1]) == "string" and
				pool[1]:sub(1, 12) == "[combine:3x3" then
			bursts[#bursts + 1] = def.amount
		end
		return spawner(def, ...)
	end
	for name, def in pairs(core.registered_nodes) do
		local kind = name:find("^doors:door_wood_") and "door" or
			(name == "default:chest" and "chest" or nil)
		if kind and def.on_rightclick then
			local original = def.on_rightclick
			def.on_rightclick = function(...)
				rightclicks[kind] = rightclicks[kind] + 1
				return original(...)
			end
		end
	end
end

local function notices_for(name)
	local list = {}
	for _, entry in ipairs(notices) do
		if entry.name == name then list[#list + 1] = entry.text end
	end
	return list
end

local function eat_hud(fake)
	for _, hud in pairs(fake.huds) do
		if hud.z_index == -200 then return hud end
	end
end

local function count(fake, slot)
	return fake.inv:get_stack("main", slot or 1):get_count()
end

local function speed(fake)
	return fake.physics.speed or 1
end

local function apples(origin)
	return #core.find_nodes_in_area(vector.offset(origin, -3, -1, -3),
		vector.offset(origin, 3, 4, 5), {"default:apple"})
end

local function floor_pointed(origin)
	local under = vector.offset(origin, 0, -1, 2)
	return {type = "node", under = under, above = vector.offset(under, 0, 1, 0)}
end

local function run_callbacks(list, mods, ref)
	for _, fn in ipairs(list) do
		local origin = core.callback_origins[fn]
		if origin and mods[origin.mod] then
			local ok, err = pcall(fn, ref)
			if not ok then log("callback " .. origin.mod .. " raised: " .. tostring(err)) end
		end
	end
end
local END_MODS = {grug_abilities = true, grug_core = true, grug_food = true}

local function eating_now(label, fake, eating)
	local hud = eat_hud(fake)
	if eating then
		check(hud ~= nil and hud.position.x == 0.5 and hud.position.y == 1 and
			hud.alignment.y == -1 and hud.scale.x == -25 and hud.scale.y == -45,
			label .. ": large bottom-centre food image behind the HUD")
		check(fake.flags.wielditem == false, label .. ": wielditem hidden")
		check(grug_core.get_move_stance(fake.ref, "grug_food:eating") == 0.35 and
			math.abs(speed(fake) - 0.35) < 1e-9,
			label .. ": eating stance x0.35 written (speed " .. speed(fake) .. ")")
	else
		check(hud == nil, label .. ": no eating image")
		check(fake.flags.wielditem ~= false, label .. ": wielditem shown")
		check(grug_core.get_move_stance(fake.ref, "grug_food:eating") == nil and
			speed(fake) == 1, label .. ": no eating slowdown (speed " .. speed(fake) .. ")")
	end
end

--
-- Scenarios: {label, steps = {{t, fn}, ...}} run one after another.
--
local scenarios = {}
local function scenario(label, build) scenarios[#scenarios + 1] = {label = label, build = build} end

local function food_player(label, origin, item)
	local ref, fake = make_player(label, "warrior", origin)
	fake.inv:set_stack("main", 1, ItemStack((item or "default:apple") .. " 5"))
	return ref, fake
end

scenario("click_ground", function(origin)
	local _, fake = food_player("click_ground", origin)
	local pointed = floor_pointed(origin)
	return {
		{0, function() press(fake, pointed) end},
		{0.05, function()
			check(apples(origin) == 0 and count(fake) == 5,
				"click_ground: nothing placed while the press is undecided")
			release(fake)
		end},
		{0.5, function()
			check(core.get_node(pointed.above).name == "default:apple" and
				apples(origin) == 1, "click_ground: exactly one apple placed on release")
			check(count(fake) == 5 - 1, "click_ground: one apple left the stack (" ..
				count(fake) .. ")")
			check(fake.eat_huds == 0 and grug_core.get_status(fake.ref, "food") == nil,
				"click_ground: no eating")
			check(place_sound_heard(fake, "default:apple"),
				"click_ground: the placer hears the place sound")
		end},
	}
end)

scenario("hold_ground", function(origin)
	local _, fake = food_player("hold_ground", origin)
	local pointed = floor_pointed(origin)
	local burst_start
	return {
		{0, function() burst_start = #bursts; press(fake, pointed) end},
		{0.7, function()
			eating_now("hold_ground", fake, true)
			check(count(fake) == 5 and apples(origin) == 0,
				"hold_ground: nothing eaten or placed before 1.5 s")
		end},
		{1.8, function() release(fake) end},
		{2.1, function()
			check(count(fake) == 4, "hold_ground: exactly one portion eaten (" .. count(fake) .. ")")
			check(grug_core.get_status(fake.ref, "food") ~= nil, "hold_ground: food status running")
			check(apples(origin) == 0, "hold_ground: no apple placed")
			check((fake.repeats or 0) >= 4, "hold_ground: engine place repeats ran (" ..
				(fake.repeats or 0) .. ") and did nothing")
			eating_now("hold_ground (after)", fake, false)
			local n, total, sizes = #bursts - burst_start, 0, true
			for index = burst_start + 1, #bursts do
				total = total + bursts[index]
				sizes = sizes and bursts[index] >= 8 and bursts[index] <= 25
			end
			check(n >= 4 and n <= 8 and sizes, ("hold_ground: %d crumb bursts, %d particles")
				:format(n, total))
			local distinct = {}
			for _, y in ipairs(fake.jitter) do distinct[("%.3f"):format(y)] = true end
			local k = 0
			for _ in pairs(distinct) do k = k + 1 end
			check(#fake.jitter >= 8 and k >= 4, ("hold_ground: image bobbed (%d offset " ..
				"updates, %d distinct)"):format(#fake.jitter, k))
			log(("hold_ground: per-eat cost %d HUD offset updates, %d particle " ..
				"spawner calls, %d particles"):format(#fake.jitter, n, total))
		end},
	}
end)

local function node_scenarios(kind, place_node)
	scenario("hold_" .. kind, function(origin)
		local _, fake = food_player("hold_" .. kind, origin)
		local pos = vector.offset(origin, 0, 0, 2)
		place_node(pos)
		local name = core.get_node(pos).name
		local pointed = {type = "node", under = pos, above = vector.offset(pos, 0, 0, -1)}
		local before
		return {
			{0, function() before = rightclicks[kind]; press(fake, pointed) end},
			{0.7, function()
				eating_now("hold_" .. kind, fake, true)
				check(rightclicks[kind] == before, "hold_" .. kind .. ": no interaction on press")
			end},
			{1.8, function() release(fake) end},
			{2.1, function()
				check(count(fake) == 4, "hold_" .. kind .. ": ate one portion (" .. count(fake) .. ")")
				check(rightclicks[kind] == before and core.get_node(pos).name == name,
					"hold_" .. kind .. ": the " .. kind .. " was never interacted with (" ..
					(rightclicks[kind] - before) .. ", " .. (fake.repeats or 0) .. " repeats)")
				check(apples(origin) == 0, "hold_" .. kind .. ": no apple placed")
			end},
		}
	end)
	scenario("click_" .. kind, function(origin)
		local _, fake = food_player("click_" .. kind, origin)
		local pos = vector.offset(origin, 0, 0, 2)
		place_node(pos)
		local name = core.get_node(pos).name
		local pointed = {type = "node", under = pos, above = vector.offset(pos, 0, 0, -1)}
		local before
		return {
			{0, function() before = rightclicks[kind]; press(fake, pointed) end},
			{0.05, function()
				check(rightclicks[kind] == before, "click_" .. kind .. ": no interaction before release")
				release(fake)
			end},
			{0.5, function()
				check(rightclicks[kind] == before + 1, "click_" .. kind ..
					": interacted exactly once on release (" .. (rightclicks[kind] - before) .. ")")
				if kind == "door" then
					check(core.get_node(pos).name ~= name, "click_door: the door toggled (" ..
						name .. " -> " .. core.get_node(pos).name .. ")")
				end
				check(count(fake) == 5 and apples(origin) == 0 and fake.eat_huds == 0,
					"click_" .. kind .. ": nothing eaten or placed")
			end},
		}
	end)
end
node_scenarios("door", function(pos)
	core.set_node(pos, {name = "doors:door_wood_a", param2 = 0})
	core.set_node(vector.offset(pos, 0, 1, 0), {name = "doors:hidden", param2 = 0})
end)
node_scenarios("chest", function(pos)
	core.set_node(pos, {name = "default:chest", param2 = 0})
	local def = core.registered_nodes["default:chest"]
	if def.on_construct then def.on_construct(pos) end
end)

local function npc_scenario(click)
	local label = click and "click_npc" or "hold_npc"
	scenario(label, function(origin)
		local ref, fake = food_player(label, origin)
		local npc = core.add_entity(vector.offset(origin, 0, 0, 2), "grug_probe_food_input:npc")
		local pointed = {type = "object", ref = npc}
		local before
		return {
			{0, function() before = npc_clicks; press(fake, pointed) end},
			{click and 0.05 or 0.7, function()
				check(npc_clicks == before, label .. ": no NPC interaction on press")
				if click then release(fake) else eating_now(label, fake, true) end
			end},
			{1.8, function() release(fake) end},
			{2.1, function()
				if click then
					check(npc_clicks == before + 1 and count(fake) == 5,
						label .. ": NPC right-clicked once on release, nothing eaten (" ..
						(npc_clicks - before) .. ", " .. count(fake) .. ")")
				else
					check(npc_clicks == before and count(fake) == 4,
						label .. ": ate one portion, NPC never right-clicked (" ..
						(npc_clicks - before) .. ", " .. count(fake) .. ")")
				end
				npc:remove()
			end},
		}
	end)
end
npc_scenario(false)
npc_scenario(true)

scenario("hold_nothing", function(origin)
	local _, fake = food_player("hold_nothing", origin, "grug_cooking:bread")
	return {
		{0, function() press(fake, {type = "nothing"}) end},
		{0.7, function() eating_now("hold_nothing", fake, true) end},
		{1.8, function() release(fake) end},
		{2.1, function()
			check(count(fake) == 4, "hold_nothing: ate one portion (" .. count(fake) .. ")")
		end},
	}
end)

scenario("combat_hold", function(origin)
	local ref, fake = food_player("combat_hold", origin)
	local pointed = floor_pointed(origin)
	return {
		{0, function() grug_core.mark_in_combat(ref); press(fake, pointed) end},
		{0.45, function()
			local list = notices_for(fake.name)
			check(#list == 1 and list[1] == "Cannot eat while in combat.",
				"combat_hold: refused at the hold threshold (" .. #list .. " notice(s))")
			eating_now("combat_hold", fake, false)
		end},
		{1.8, function() release(fake) end},
		{2.1, function()
			check(count(fake) == 5 and apples(origin) == 0 and fake.eat_huds == 0,
				"combat_hold: nothing eaten, placed or shown")
			check(#notices_for(fake.name) == 1, "combat_hold: one notice only")
		end},
	}
end)

scenario("combat_click", function(origin)
	local ref, fake = food_player("combat_click", origin)
	local pointed = floor_pointed(origin)
	return {
		{0, function() grug_core.mark_in_combat(ref); press(fake, pointed) end},
		{0.05, function() release(fake) end},
		{0.5, function()
			check(apples(origin) == 1 and count(fake) == 4 and #notices_for(fake.name) == 0,
				"combat_click: a click in combat still places")
		end},
	}
end)

-- M1: a hotbar switch and a fresh press observed in the same step.
for _, hold in ipairs({false, true}) do
	local label = hold and "switch_then_hold" or "switch_then_click"
	scenario(label, function(origin)
		local _, fake = make_player(label, "warrior", origin)
		fake.inv:set_stack("main", 1, ItemStack("default:stick"))
		fake.inv:set_stack("main", 2, ItemStack("default:apple 5"))
		local pointed = floor_pointed(origin)
		return {
			{0.3, function()
				fake.index = 2
				press(fake, pointed)
			end},
			{hold and 2.1 or 0.35, function() release(fake) end},
			{hold and 2.4 or 0.8, function()
				if hold then
					check(count(fake, 2) == 4 and apples(origin) == 0,
						label .. ": the new item's hold ate one portion (" .. count(fake, 2) ..
						", " .. apples(origin) .. " apple(s))")
				else
					check(count(fake, 2) == 4 and apples(origin) == 1,
						label .. ": the new item's click placed one apple (" .. count(fake, 2) ..
						", " .. apples(origin) .. " apple(s))")
				end
				active[fake.name] = nil
			end},
		}
	end)
end

-- M2: a double click whose release fell between two control snapshots.
scenario("double_click_node", function(origin)
	local _, fake = food_player("double_click_node", origin)
	local first = floor_pointed(origin)
	local second = floor_pointed(vector.offset(origin, 1, 0, 0))
	return {
		{0, function() press(fake, first) end},
		{0.05, function()
			press(fake, second)
			check(core.get_node(first.above).name == "default:apple",
				"double_click_node: the first click settled at the second press")
		end},
		{0.1, function() release(fake) end},
		{0.6, function()
			check(core.get_node(second.above).name == "default:apple" and
				apples(origin) == 2 and count(fake) == 3,
				"double_click_node: two clicks placed two apples (" .. apples(origin) ..
				", stack " .. count(fake) .. ")")
		end},
	}
end)

scenario("double_click_object", function(origin)
	local _, fake = food_player("double_click_object", origin)
	local first = floor_pointed(origin)
	local npc = core.add_entity(vector.offset(origin, 1, 0, 2), "grug_probe_food_input:npc")
	local before
	return {
		{0, function() before = npc_clicks; press(fake, first) end},
		{0.05, function()
			press(fake, {type = "object", ref = npc})
			check(apples(origin) == 1 and npc_clicks == before,
				"double_click_object: the first click placed, the NPC press is deferred")
		end},
		{0.1, function() release(fake) end},
		{0.6, function()
			check(npc_clicks == before + 1 and count(fake) == 4 and apples(origin) == 1,
				"double_click_object: then the NPC was right-clicked once (" ..
				(npc_clicks - before) .. ", stack " .. count(fake) .. ")")
			npc:remove()
		end},
	}
end)

scenario("double_click_nothing", function(origin)
	local _, fake = food_player("double_click_nothing", origin)
	local first = floor_pointed(origin)
	return {
		{0, function() press(fake, first) end},
		{0.05, function() press(fake, {type = "nothing"}) end},
		{0.1, function() release(fake) end},
		{0.6, function()
			check(apples(origin) == 1 and count(fake) == 4 and fake.eat_huds == 0,
				"double_click_nothing: first click placed, the air click did nothing (" ..
				apples(origin) .. ", stack " .. count(fake) .. ")")
		end},
	}
end)

-- A stack of one: the click empties it by placing, the hold by eating.
for _, hold in ipairs({false, true}) do
	local label = hold and "single_hold" or "single_click"
	scenario(label, function(origin)
		local _, fake = make_player(label, "warrior", origin)
		fake.inv:set_stack("main", 1, ItemStack("default:apple"))
		local pointed = floor_pointed(origin)
		return {
			{0, function() press(fake, pointed) end},
			{hold and 1.8 or 0.05, function() release(fake) end},
			{hold and 2.1 or 0.5, function()
				check(count(fake) == 0 and apples(origin) == (hold and 0 or 1),
					label .. ": the last apple was " .. (hold and "eaten" or "placed") ..
					" (stack " .. count(fake) .. ", " .. apples(origin) .. " placed)")
				if hold then
					check(grug_core.get_status(fake.ref, "food") ~= nil and
						eat_hud(fake) == nil and speed(fake) == 1,
						label .. ": status running, feedback cleared")
				end
			end},
		}
	end)
end

scenario("meatblock_click", function(origin)
	local _, fake = food_player("meatblock_click", origin, "mobs:meatblock")
	fake.look = vector.normalize(vector.new(0.8, -0.6, 0))
	local under = vector.offset(origin, 2, -1, 0)
	local pointed = {type = "node", under = under, above = vector.offset(under, 0, 1, 0)}
	return {
		{0, function() press(fake, pointed) end},
		{0.05, function() release(fake) end},
		{0.5, function()
			local node = core.get_node(pointed.above)
			local want = core.dir_to_facedir(fake.look)
			check(node.name == "mobs:meatblock" and node.param2 == want and want ~= 0,
				("meatblock_click: placed rotated by rotate_node (%s param2 %d, want %d)")
					:format(node.name, node.param2, want))
			check(count(fake) == 4, "meatblock_click: one block left the stack")
			check(place_sound_heard(fake, "mobs:meatblock"),
				"meatblock_click: the placer hears the place sound")
		end},
	}
end)

-- Every end path of a running eat clears image, wielditem flag and stance.
local food_ends = {
	release = function(fake) release(fake) end,
	stun = function(fake) grug_core.set_stun(fake.ref, 0.2) end,
	slot = function(fake) fake.index = 2 end,
	death = function(fake)
		run_callbacks(core.registered_on_dieplayers, END_MODS, fake.ref)
	end,
	leave = function(fake)
		active[fake.name] = nil
		run_callbacks(core.registered_on_leaveplayers, END_MODS, fake.ref)
	end,
}
for _, path in ipairs({"release", "stun", "slot", "death", "leave"}) do
	scenario("food_end_" .. path, function(origin)
		local label = "food_end_" .. path
		local _, fake = food_player(label, origin)
		-- A second food in the next slot: after a slot change the still-held
		-- press repeats place for it, which must not act either.
		fake.inv:set_stack("main", 2, ItemStack("default:apple 5"))
		local pointed = floor_pointed(origin)
		return {
			{0, function() press(fake, pointed) end},
			{0.5, function()
				check(eat_hud(fake) ~= nil, label .. ": eating before the end path")
				food_ends[path](fake)
			end},
			{0.8, function()
				if path == "leave" then
					check(grug_core.get_move_stance(fake.ref, "grug_food:eating") == nil,
						label .. ": no stance left")
				else
					eating_now(label, fake, false)
				end
			end},
			{1.8, function() release(fake) end},
			{2.1, function()
				check(count(fake, 1) == 5 and count(fake, 2) == 5 and apples(origin) == 0,
					label .. ": nothing eaten or placed (" .. count(fake, 1) .. "/" ..
					count(fake, 2) .. ", " .. apples(origin) .. " apple(s), " ..
					(fake.repeats or 0) .. " repeats)")
				active[fake.name] = nil
			end},
		}
	end)
end

-- Bow draw: meta range "0" and the x0.5 stance while drawn; every end path
-- removes both.
local bow_name
local function loose_range(fake)
	for _, stack in ipairs(fake.inv:get_list("main")) do
		if stack:get_name() == "grug_abilities:loose" then
			return stack:get_meta():get_string("range")
		end
	end
end
local bow_ends = {
	release = function(fake) release(fake) end,
	cancel = function(fake) grug_abilities.input.cancel(fake.ref) end,
	stun = function(fake) grug_core.set_stun(fake.ref, 0.2) end,
	slot = function(fake) fake.index = 2 end,
	death = function(fake)
		run_callbacks(core.registered_on_dieplayers, END_MODS, fake.ref)
	end,
	leave = function(fake)
		active[fake.name] = nil
		run_callbacks(core.registered_on_leaveplayers, END_MODS, fake.ref)
	end,
}
for _, path in ipairs({"release", "cancel", "stun", "slot", "death", "leave"}) do
	scenario("bow_end_" .. path, function(origin)
		local label = "bow_end_" .. path
		local ref, fake = make_player(label, "scout", origin)
		fake.weapon = bow_name
		fake.look, fake.pitch = vector.new(0, 0, 1), 0
		local mob
		if path == "release" then
			-- A visible hostile in front, so the release really launches.
			local ent
			mob, ent = spawn_mob(vector.offset(origin, 0, 0, 6))
			aim(ref, fake, mob)
		end
		fake.inv:set_stack("main", 1, grug_abilities.stack_for(ref, "loose"))
		fake.inv:set_stack("main", 3, ItemStack("grug_gear:arrow 20"))
		return {
			{0, function()
				check(grug_abilities.is_unlocked(ref, "loose") and bow_name ~= nil,
					label .. ": Loose unlocked, bow " .. tostring(bow_name))
				check(loose_range(fake) == "", label .. ": no range override before the draw")
				press(fake, nil)
			end},
			{0.35, function()
				check(grug_abilities.scout_draw_active(ref), label .. ": drawing")
				check(loose_range(fake) == "0", label .. ": loose stack meta range \"0\" while drawn")
				check(grug_core.get_move_stance(ref, "scout_draw") == 0.5 and
					math.abs(speed(fake) - 0.5) < 1e-9, label .. ": draw stance x0.5 (speed " ..
					speed(fake) .. ")")
				bow_ends[path](fake)
			end},
			{0.8, function()
				check(not grug_abilities.scout_draw_active(ref), label .. ": draw ended")
				check(loose_range(fake) == "", label .. ": range override removed (" ..
					tostring(loose_range(fake)) .. ")")
				check(grug_core.get_move_stance(ref, "scout_draw") == nil and
					(path == "leave" or speed(fake) == 1), label .. ": draw stance cleared (speed " ..
					speed(fake) .. ")")
				if path == "release" then
					check(count(fake, 3) == 19, label .. ": the release launched one arrow (" ..
						count(fake, 3) .. " left)")
					if mob and mob:get_pos() then mob:remove() end
				end
				release(fake)
			end},
			{1.0, function() active[fake.name] = nil end},
		}
	end)
end

scenario("stance_aggregator", function(origin)
	local ref, fake = make_player("stance", "warrior", origin)
	active[fake.name] = nil
	local function speed_is(value, label)
		local state = grug_core.get_move_state(ref).speed
		check(math.abs(state - value) < 1e-9 and math.abs(speed(fake) - value) < 1e-9,
			("stance: %s -> %.3f (state %.3f, written %.3f)"):format(label, value, state,
				speed(fake)))
	end
	return {{0, function()
		grug_core.set_move_modifier(ref, "scout_sprint", {speed = 0.5}, 10)
		speed_is(1.5, "sprint")
		grug_core.set_move_stance(ref, "scout_draw", 0.5)
		speed_is(0.75, "sprint x draw stance (stance scales sprint)")
		grug_core.set_move_modifier(ref, "probe_slow", {speed = -0.4}, 10)
		speed_is(0.55, "sprint + slow, x stance")
		grug_core.set_move_immunity(ref, 10)
		speed_is(0.75, "immunity discards the slow, keeps the stance")
		grug_core.clear_negative_move_modifiers(ref)
		speed_is(0.75, "Shake Loose clear keeps the stance")
		grug_core.set_move_stance(ref, "grug_food:eating", 0.35)
		speed_is(0.2625, "two stances multiply")
		grug_core.clear_move_stance(ref, "grug_food:eating")
		grug_core.clear_move_stance(ref, "scout_draw")
		speed_is(1.5, "stances cleared")
		grug_core.clear_movement(ref)
	end}}
end)

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("food input probe done", false, 0)
end

local function run_scenario(index)
	local sc = scenarios[index]
	if not sc then return finish() end
	local origin = vector.offset(BASE, (index - 1) * SPACING, 0, 0)
	log("scenario " .. sc.label)
	local ok, steps = pcall(sc.build, origin)
	check(ok, sc.label .. ": scenario built" .. (ok and "" or (" (" .. tostring(steps) .. ")")))
	if not ok then return core.after(0, run_scenario, index + 1) end
	local last = 0
	for _, step in ipairs(steps) do
		last = math.max(last, step[1])
		core.after(step[1], function()
			local fine, err = pcall(step[2])
			check(fine, sc.label .. " @" .. step[1] .. "s ran" ..
				(fine and "" or (" (" .. tostring(err) .. ")")))
		end)
	end
	core.after(last + 0.3, run_scenario, index + 1)
end

local function build_arena(minp, maxp)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local c_air = core.get_content_id("air")
	local c_floor = core.get_content_id("default:stone")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				data[area:index(x, y, z)] = y == minp.y and c_floor or c_air
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

core.register_on_mods_loaded(function()
	assert(grug_abilities.input and grug_abilities.input.food_native,
		"contextual food input is missing")
	for name, def in pairs(core.registered_items) do
		if core.get_item_group(name, "grug_bow") > 0 and not bow_name then bow_name = name end
		if core.get_item_group(name, "grug_food") > 0 and def.type == "node" then
			log(("node food %s prediction=%q"):format(name, tostring(def.node_placement_prediction)))
		end
	end
end)

core.after(2, function()
	for _, name in ipairs({"default:apple", "mobs:meatblock", "mobs:meatblock_raw"}) do
		check(core.registered_items[name].node_placement_prediction == "",
			name .. ": no client placement prediction")
	end
	check(core.registered_entities["grug_probe_food_input:npc"].on_rightclick ~= nil,
		"probe NPC keeps an on_rightclick")
	local minp = vector.offset(BASE, -4, -1, -4)
	local maxp = vector.offset(BASE, SPACING * #scenarios + 4, 6, 8)
	log("emerging arena " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			build_arena(minp, maxp)
			-- No real player keeps these blocks active; without a forceload
			-- the probe entities are deactivated (and, unsaved, removed).
			for x = minp.x, maxp.x + 15, 16 do
				for y = minp.y, maxp.y + 15, 16 do
					for z = minp.z, maxp.z + 15, 16 do
						assert(core.forceload_block(vector.new(math.min(x, maxp.x),
							math.min(y, maxp.y), math.min(z, maxp.z)), true, -1))
					end
				end
			end
			wrap_observers()
			core.after(3, run_scenario, 1)
		end)
	end)
end)
