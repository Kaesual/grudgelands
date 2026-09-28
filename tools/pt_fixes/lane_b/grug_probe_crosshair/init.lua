-- Disposable engine probe (playtest-fix Lane B). Never shipped:
-- tools/pt_fixes/lane_b/run.sh stages it through tools/luanti_headless.sh.
--
-- A headless server has no client, so each "player" is a real, invisible
-- probe entity whose ObjectRef answers the player accessors the code under
-- test reads (the Lane A pattern). The shipped code runs unmodified on the
-- real engine: grug_core.combat_ray, grug_abilities.aimed_target, contextual
-- input, the crosshair module and the Scout draw loop. Probe players are not
-- connected players, so the probe runs the 0.05 s pass's two calls
-- (input.step, crosshair.update) for them on every server step.

local P = "[crosshair_probe] "
local BASE = vector.new(600, 300, 600)
local SPACING = 6
local DEPTH = 40
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

local HERO_BOX = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
core.register_entity("grug_probe_crosshair:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = HERO_BOX,
	},
	on_punch = function() return true end,
})
-- A pointable probe player (the ally a heal aims at). Visible: the engine
-- gives an invisible entity no selection box (LuaEntitySAO::getSelectionBox).
core.register_entity("grug_probe_crosshair:ally", {
	initial_properties = {
		physical = false, pointable = true, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		collisionbox = HERO_BOX,
	},
	on_punch = function() return true end,
})
-- A static hostile: exactly the fields the aim authority reads
-- (_cmi_is_mob, health, _grug_faction, _grug_noncombatant), no AI that could
-- walk it across a range boundary.
local DUMMY_R = 0.4
core.register_entity("grug_probe_crosshair:dummy", {
	initial_properties = {
		physical = false, pointable = true, static_save = false,
		visual = "sprite", textures = {"blank.png"},
		collisionbox = {-DUMMY_R, 0, -DUMMY_R, DUMMY_R, 1.9, DUMMY_R},
	},
	_cmi_is_mob = true,
	health = 20,
	on_punch = function() return true end,
})
-- An interactive NPC stand-in (on_rightclick), wrapped by contextual input's
-- generic on_mods_loaded pass like every trader and villager.
local NPC_R = 0.3
core.register_entity("grug_probe_crosshair:npc", {
	initial_properties = {
		physical = false, pointable = true, static_save = false,
		visual = "sprite", textures = {"blank.png"},
		collisionbox = {-NPC_R, 0, -NPC_R, NPC_R, 1.8, NPC_R},
	},
	on_rightclick = function() end,
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
	override("get_player_window_information", function(f)
		return f.hud_scaling and {real_hud_scaling = f.hud_scaling} or nil
	end)
	override("hud_add", function(f, def)
		f.hud_next = f.hud_next + 1
		f.huds[f.hud_next] = table.copy(def)
		return f.hud_next
	end)
	override("hud_change", function(f, id, stat, value)
		local hud = f.huds[id]
		if not hud then return false end
		hud[stat] = value
		f.changes[#f.changes + 1] = {id = id, stat = stat, value = value}
		return true
	end)
	override("hud_remove", function(f, id) f.huds[id] = nil end)
	override("hud_get_flags", function(f) return table.copy(f.flags) end)
	override("hud_set_flags", function(f, flags)
		for key, value in pairs(flags) do f.flags[key] = value end
	end)
	override("set_physics_override", function(f, o)
		for key, value in pairs(o) do f.physics[key] = value end
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
	-- Talent ranks per probe player (the real talent state needs levels and
	-- point spending the probe does not exercise).
	local talent_bonus = grug_classes.get_talent_bonus
	grug_classes.get_talent_bonus = function(player, key)
		local fake = player and fakes[player]
		if fake and fake.talents[key] then return fake.talents[key] end
		return talent_bonus(player, key)
	end
end

local faction_key = "grug_factions:faction"

local function make_player(label, class, pos, entity)
	local ref = core.add_entity(pos, entity or "grug_probe_crosshair:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_" .. label
	local inv = core.create_detached_inventory("grug_probe_x_" .. label, {})
	inv:set_size("main", 32)
	local fake = {
		name = name, ref = ref, controls = {}, look = vector.new(0, 0, 1),
		yaw = 0, pitch = 0, holder = ItemStack("default:stick"), inv = inv,
		index = 1, huds = {}, hud_next = 0, changes = {}, talents = {},
		flags = {wielditem = true}, physics = {},
	}
	fakes[ref] = fake
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	core.set_player_privs(name, {interact = true, protection_bypass = true})
	ref:get_meta():set_string("grug_classes:class", class)
	ref:get_meta():set_string(faction_key, "accord")
	for _, fn in ipairs(core.registered_on_joinplayers) do
		local origin = core.callback_origins[fn]
		if origin and origin.mod == "grug_projectiles" then fn(ref, nil) end
	end
	grug_abilities.crosshair.join(ref)
	return ref, fake
end

local function activate(fake) active[fake.name] = fake end
local function deactivate(fake) active[fake.name] = nil end

-- The 0.05 s pass's per-player work, for probe players, every server step.
core.register_globalstep(function()
	for _, fake in pairs(active) do
		grug_abilities.input.step(fake.ref)
		grug_abilities.crosshair.update(fake.ref)
	end
end)

--
-- Observation helpers.
--
local X = grug_abilities.crosshair
local side_effects = {set_target = 0, debug = 0}

local function view(fake) return X.debug_view(fake.ref) end
local function state_text(fake) local v = view(fake); return v and v.state end
local function ring_text(fake) local v = view(fake); return v and v.ring end
local function changes_of(fake, which, stat)
	local v = view(fake)
	local id = v and v[which .. "_id"]
	local list = {}
	for _, c in ipairs(fake.changes) do
		if c.id == id and (stat == nil or c.stat == stat) then list[#list + 1] = c end
	end
	return list
end
local function expect_state(fake, want, label)
	-- The pass's own call first, so the HUD reflects the current aim.
	if fake.reaim then fake.reaim() end
	X.update(fake.ref)
	local got = X.state(fake.ref)
	local text = state_text(fake)
	local want_text = want and X.STATE_TEXTURE[want] or ""
	check(got == want and text == want_text,
		("%s: state %s (got %s, hud %q)"):format(label, tostring(want), tostring(got), text))
end

local function eye(fake)
	return grug_core.combat_eye_pos(fake.ref)
end
local function look_at(fake, point)
	local dir = vector.direction(eye(fake), point)
	fake.look = dir
	fake.yaw = core.dir_to_yaw(dir)
	fake.pitch = -math.asin(dir.y)
end
local function look_ahead(fake)
	fake.look, fake.yaw, fake.pitch = vector.new(0, 0, 1), 0, 0
end
-- Put an object so its near face is `d` metres ahead of the eye (+z).
local function place_ahead(fake, obj, d, radius)
	local e = eye(fake)
	obj:set_pos(vector.new(e.x, fake.ref:get_pos().y, e.z + d + radius))
end
local function hold(fake, stack)
	fake.inv:set_stack("main", fake.index, ItemStack(stack or ""))
end
local function skill(fake, id)
	fake.inv:set_stack("main", fake.index, grug_abilities.stack_for(fake.ref, id))
end

local function spawn_bandit(pos)
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

local function run_callbacks(list, mods, ref)
	for _, fn in ipairs(list) do
		local origin = core.callback_origins[fn]
		if origin and mods[origin.mod] then
			local ok, err = pcall(fn, ref)
			if not ok then log("callback " .. origin.mod .. " raised: " .. tostring(err)) end
		end
	end
end
local END_MODS = {grug_abilities = true, grug_core = true}

local launches = {}

local function wrap_observers()
	local set_target = grug_abilities.set_target
	grug_abilities.set_target = function(player, ...)
		if player and fakes[player] then side_effects.set_target = side_effects.set_target + 1 end
		return set_target(player, ...)
	end
	local debug_enabled = grug_core.combat_debug_enabled
	grug_core.combat_debug_enabled = function(name, ...)
		if by_name[name] then side_effects.debug = side_effects.debug + 1 end
		return debug_enabled(name, ...)
	end
	local spawn_batch = grug_projectiles.spawn_batch
	grug_projectiles.spawn_batch = function(kind, list, ...)
		for _, l in ipairs(list) do
			launches[#launches + 1] = {kind = kind, damage = l.data and l.data.damage,
				speed = l.speed, owner = l.owner}
		end
		return spawn_batch(kind, list, ...)
	end
	local flash = grug_abilities.flash
	grug_abilities.flash = function(player, text, ...)
		log("flash to " .. player:get_player_name() .. ": " .. tostring(text))
		return flash(player, text, ...)
	end
end

--
-- Scenarios: {label, steps = {{t, fn}, ...}} run one after another.
--
local scenarios = {}
local function scenario(label, build) scenarios[#scenarios + 1] = {label = label, build = build} end

-- HUD elements: centred, explicit z order.
scenario("hud_elements", function(origin)
	local _, fake = make_player("hud", "warrior", origin)
	return {{0, function()
		local v = view(fake)
		local s, r = fake.huds[v.state_id], fake.huds[v.ring_id]
		local function centred(h)
			return h.type == "image" and h.position.x == 0.5 and h.position.y == 0.5 and
				h.alignment.x == 0 and h.alignment.y == 0 and h.offset.x == 0 and
				h.offset.y == 0 and h.text == ""
		end
		check(centred(s) and s.z_index == 1, "hud: state overlay centred, empty, z 1")
		check(centred(r) and r.z_index == 3, "hud: draw ring centred, empty, z 3")
		check(X.Z_READY == 2, "hud: weapon-ready ring between them (z 2)")
	end}}
end)

-- Hostile skill range boundaries: {label, class, skill, range, talents}.
local range_cases = {
	{"strike", "warrior", "strike", 3},
	{"charge", "warrior", "charge", 12},
	{"fireball", "mage", "fireball", 20},
	{"loose", "scout", "loose", 25},
	{"loose_longshot", "scout", "loose", 33, {loose_range_add = 8}},
}
for _, case in ipairs(range_cases) do
	local label, class, id, range, talents = case[1], case[2], case[3], case[4], case[5]
	scenario("range_" .. label, function(origin)
		local ref, fake = make_player("r_" .. label, class, origin)
		fake.talents = talents or {}
		local dummy = core.add_entity(origin, "grug_probe_crosshair:dummy")
		local set0, debug0 = side_effects.set_target, side_effects.debug
		return {
			{0, function()
				skill(fake, id)
				check(grug_abilities.is_unlocked(ref, id), label .. ": " .. id .. " unlocked")
				check(grug_abilities.get_range(ref, grug_abilities.registered[id]) == range,
					label .. ": effective range " .. range)
				look_ahead(fake)
				place_ahead(fake, dummy, range - 0.3, DUMMY_R)
				activate(fake)
			end},
			{0.3, function()
				expect_state(fake, "hostile", label .. " @" .. (range - 0.3) .. " m")
				place_ahead(fake, dummy, range + 0.3, DUMMY_R)
			end},
			{0.6, function()
				expect_state(fake, nil, label .. " @" .. (range + 0.3) .. " m")
			end},
			{0.9, function()
				check(side_effects.set_target == set0 and side_effects.debug == debug0,
					label .. ": overlay wrote no Target Frame memory and ran no cast diagnostics")
				check(grug_abilities.get_target(ref, false) == nil,
					label .. ": enemy target memory still empty")
				local text_changes = changes_of(fake, "state", "text")
				check(#text_changes == 2, label .. ": exactly two state packets (" ..
					#text_changes .. ")")
				deactivate(fake)
				dummy:remove()
			end},
		}
	end)
end

-- A real grug mob at 5 m with Fireball.
scenario("bandit_fireball", function(origin)
	local _, fake = make_player("bandit", "mage", origin)
	local mob
	return {
		{0, function()
			skill(fake, "fireball")
			mob = spawn_bandit(vector.offset(origin, 0, 0, 5))
			look_at(fake, vector.offset(mob:get_pos(), 0, 1, 0))
			activate(fake)
		end},
		{0.2, function()
			look_at(fake, vector.offset(mob:get_pos(), 0, 1, 0))
			expect_state(fake, "hostile", "bandit_fireball: real bandit at ~5 m")
			deactivate(fake)
			mob:remove()
		end},
	}
end)

-- Friendly heal: ally player just inside/outside 15 m; a hostile is not green.
scenario("friendly_flash_heal", function(origin)
	local ref, fake = make_player("heal", "priest", origin)
	local ally_ref = make_player("ally", "warrior", origin, "grug_probe_crosshair:ally")
	local dummy
	return {
		{0, function()
			skill(fake, "flash_heal")
			check(grug_abilities.get_range(ref, grug_abilities.registered.flash_heal) == 15,
				"flash_heal: effective range 15")
			look_ahead(fake)
			place_ahead(fake, ally_ref, 14.7, 0.3)
			activate(fake)
		end},
		{0.3, function()
			local def = grug_abilities.registered.flash_heal
			local target, ray = grug_abilities.aimed_target(ref, def)
			log(("flash_heal diag: unlocked=%s wield=%s target=%s status=%s reason=%s " ..
				"distance=%s kind=%s relation=%s")
				:format(tostring(grug_abilities.is_unlocked(ref, "flash_heal")),
					fake.inv:get_stack("main", fake.index):get_name(), tostring(target),
					tostring(ray.status), tostring(ray.reason), tostring(ray.distance),
					tostring(ray.object_kind), tostring(ray.relation)))
			expect_state(fake, "friendly", "flash_heal: ally @14.7 m")
			place_ahead(fake, ally_ref, 15.3, 0.3)
		end},
		{0.6, function()
			expect_state(fake, nil, "flash_heal: ally @15.3 m")
			ally_ref:set_pos(vector.offset(origin, 3, 0, 0))
			dummy = core.add_entity(origin, "grug_probe_crosshair:dummy")
			place_ahead(fake, dummy, 5, DUMMY_R)
		end},
		{0.9, function()
			expect_state(fake, nil, "flash_heal: hostile in range shows no state")
			check(grug_abilities.get_target(ref, true) == nil and
				grug_abilities.get_target(ref, false) == nil,
				"flash_heal: no ally/enemy memory written by the overlay")
			deactivate(fake)
			dummy:remove()
		end},
	}
end)

-- Self-target skill: no hostile/friendly state even on a hostile.
scenario("self_blink", function(origin)
	local _, fake = make_player("blink", "mage", origin)
	local dummy = core.add_entity(origin, "grug_probe_crosshair:dummy")
	return {
		{0, function()
			skill(fake, "blink")
			look_ahead(fake)
			place_ahead(fake, dummy, 2, DUMMY_R)
			activate(fake)
		end},
		{0.3, function()
			expect_state(fake, nil, "blink: hostile at 2 m")
			deactivate(fake)
			dummy:remove()
		end},
	}
end)

-- Neutral interact: NPC, dropped item, interactive node; inside and beyond
-- hand reach; empty hand, tool, food-free skill.
local held = {
	{"hand", function(fake) hold(fake, "") end},
	{"tool", function(fake) hold(fake, "default:pick_stone") end},
	{"skill", function(fake) skill(fake, "fireball") end},
}
local targets = {
	npc = function(origin, fake, d)
		local obj = core.add_entity(origin, "grug_probe_crosshair:npc")
		look_ahead(fake)
		place_ahead(fake, obj, d, NPC_R)
		return function() obj:remove() end
	end,
	item = function(origin, fake, d)
		-- Resting on the floor (top at origin.y - 0.5, item box half size
		-- 0.3): look down at it; `d` is roughly the slant distance to its
		-- near surface. The look is re-aimed at every check.
		local e = eye(fake)
		local drop_y = origin.y - 0.2
		local dy = e.y - drop_y
		local flat = math.sqrt(math.max(0.01, (d + 0.2) * (d + 0.2) - dy * dy))
		local obj = core.add_item(vector.new(e.x, drop_y, e.z + flat), "default:dirt")
		look_at(fake, obj:get_pos())
		fake.reaim = function()
			if obj:get_pos() then look_at(fake, obj:get_pos()) end
		end
		return function() fake.reaim = nil; obj:remove() end
	end,
	chest = function(origin, fake, d)
		local e = eye(fake)
		local pos = vector.round(vector.new(e.x, e.y, e.z + d + 0.5))
		core.set_node(pos, {name = "default:chest"})
		look_at(fake, pos)
		return function() core.remove_node(pos) end
	end,
}
for _, kind in ipairs({"npc", "item", "chest"}) do
	for _, h in ipairs(held) do
		scenario("interact_" .. kind .. "_" .. h[1], function(origin)
			local _, fake = make_player("i_" .. kind .. "_" .. h[1], "mage", origin)
			local cleanup
			return {
				{0, function()
					h[2](fake)
					cleanup = targets[kind](origin, fake, 3.3)
					activate(fake)
				end},
				{0.3, function()
					expect_state(fake, "interact", kind .. "/" .. h[1] .. " within reach")
					cleanup()
					cleanup = targets[kind](origin, fake, 4.6)
				end},
				{0.6, function()
					expect_state(fake, nil, kind .. "/" .. h[1] .. " beyond reach")
					cleanup()
					deactivate(fake)
				end},
			}
		end)
	end
end

-- Precedence: an interactive hostile within reach reads hostile with Strike,
-- interact with an empty hand.
scenario("precedence", function(origin)
	local _, fake = make_player("prec", "warrior", origin)
	local dummy = core.add_entity(origin, "grug_probe_crosshair:dummy")
	dummy:get_luaentity().on_rightclick = function() end
	return {
		{0, function()
			skill(fake, "strike")
			look_ahead(fake)
			place_ahead(fake, dummy, 2.5, DUMMY_R)
			activate(fake)
		end},
		{0.3, function()
			expect_state(fake, "hostile", "precedence: Strike on an interactive hostile")
			hold(fake, "")
		end},
		{0.6, function()
			expect_state(fake, "interact", "precedence: empty hand on the same target")
			deactivate(fake)
			dummy:remove()
		end},
	}
end)

-- Packets only on change; integer scale for a fractional HUD factor.
scenario("packets_and_scale", function(origin)
	local _, fake = make_player("pkt", "warrior", origin)
	fake.hud_scaling = 1.5
	local npc = core.add_entity(origin, "grug_probe_crosshair:npc")
	return {
		{0, function()
			hold(fake, "")
			look_ahead(fake)
			place_ahead(fake, npc, 2, NPC_R)
			activate(fake)
		end},
		{1.0, function()
			local texts = changes_of(fake, "state", "text")
			local scales = changes_of(fake, "state", "scale")
			check(#texts == 1, "packets: one text packet over ~1 s of steady aim (" .. #texts .. ")")
			local want = 1 / 1.5 * 1.001
			check(#scales == 1 and math.abs(scales[1].value.x - want) < 1e-9 and
				math.abs(21 * scales[1].value.x * 1.5 - 21) < 0.1 and
				math.floor(21 * scales[1].value.x * 1.5) == 21,
				("scale: one scale packet %.6f for real_hud_scaling 1.5 (21 px -> %.3f px)")
				:format(scales[1] and scales[1].value.x or -1,
					scales[1] and 21 * scales[1].value.x * 1.5 or -1))
			npc:set_pos(vector.offset(origin, 3, 0, 0))
		end},
		{1.3, function()
			local texts = changes_of(fake, "state", "text")
			check(#texts == 2 and texts[2].value == "", "packets: one more on losing the target")
			fake.hud_scaling = 2
			npc:set_pos(vector.offset(origin, 0, 0, 2.3))
		end},
		{1.6, function()
			local scales = changes_of(fake, "state", "scale")
			check(#scales == 2 and scales[2].value.x == 1, "scale: integer factor 2 -> scale 1")
			deactivate(fake)
			npc:remove()
		end},
	}
end)

-- Bow draw time and Fletching.
local bow_name
scenario("draw_time", function(origin)
	local ref, fake = make_player("dtime", "scout", origin)
	fake.weapon = bow_name
	return {{0, function()
		local def = core.registered_items[bow_name]
		check(def._grug_bow_draw_time == 2.5, "draw: bow owns 2.5 s")
		local t = grug_abilities.loose_draw_time(ref)
		check(math.abs(t - 2.5) < 1e-9, ("draw: base full draw %.3f s"):format(t))
		local want = {2.25, 2.0, 1.75, 1.5}
		local fletching = grug_classes.registered_talents and
			grug_classes.registered_talents.fletching
		for rank = 1, 4 do
			local sub = fletching and fletching.effects.draw_time_sub[rank]
			fake.talents = {draw_time_sub = sub}
			local got = grug_abilities.loose_draw_time(ref)
			check(sub ~= nil and math.abs(got - want[rank]) < 1e-9,
				("draw: Fletching rank %d -> %.3f s (sub %s)"):format(rank, got, tostring(sub)))
		end
		fake.talents = {}
		local m = grug_abilities.loose_draw_multiplier
		check(math.abs(m(0) - 0.2) < 1e-12 and math.abs(m(0.5) - 0.9) < 1e-12 and
			math.abs(m(1) - 3.0) < 1e-12,
			("curve: f=0 x%.2f, f=0.5 x%.2f, f=1 x%.2f"):format(m(0), m(0.5), m(1)))
	end}}
end)

-- Real releases at a hostile: tap, half and full draw.
local function press(fake) fake.controls = {place = true} end
local function release(fake) fake.controls = {} end
local function ring_frames(fake)
	local list = {}
	for _, c in ipairs(changes_of(fake, "ring", "text")) do list[#list + 1] = c.value end
	return list
end

-- Scenario steps fire from core.after: 0.1 s is at least one server step
-- after the press, so the draw has started.
for _, case in ipairs({{"tap", 0.1}, {"half", 1.25}, {"full", 2.8}}) do
	local label, at = case[1], case[2]
	scenario("release_" .. label, function(origin)
		local ref, fake = make_player("rel_" .. label, "scout", origin)
		fake.weapon = bow_name
		local mob, launch0, t0
		return {
			{0, function()
				skill(fake, "loose")
				fake.inv:set_stack("main", 3, ItemStack("grug_gear:arrow 20"))
				mob = spawn_bandit(vector.offset(origin, 0, 0, 6))
				look_at(fake, vector.offset(mob:get_pos(), 0, 1, 0))
				activate(fake)
				launch0 = #launches
				t0 = core.get_us_time()
				press(fake)
			end},
			{at, function()
				look_at(fake, vector.offset(mob:get_pos(), 0, 1, 0))
				release(fake)
			end},
			{at + 0.4, function()
				local shot = launches[launch0 + 1]
				check(shot ~= nil and #launches == launch0 + 1,
					label .. ": exactly one arrow launched")
				if shot then
					local f = shot.speed / 40
					local stack = ItemStack(bow_name)
					local base = stack:get_tool_capabilities().damage_groups.fleshy +
						grug_classes.get_ranged_bonus(ref)
					local want = math.floor(base * (0.2 + 2.8 * f * f))
					check(shot.damage == want, ("%s: f=%.3f base %d -> damage %d (want %d, x%.3f)")
						:format(label, f, base, shot.damage, want, 0.2 + 2.8 * f * f))
					if label == "tap" then
						check(f > 0 and f < 0.12, label .. ": tap draw fraction " .. f)
					elseif label == "half" then
						check(math.abs(f - 0.5) < 0.06, label .. ": half draw fraction " .. f ..
							" (2.5 s draw)")
					else
						check(f == 1 and shot.damage == math.floor(base * 3),
							label .. ": full draw x3")
					end
				end
				local frames = ring_frames(fake)
				check(frames[1] == "grug_abilities_draw_ring_00.png" and
					frames[#frames] == "", label .. ": ring shown from frame 00, removed on release (" ..
					#frames .. " packets)")
				check(ring_text(fake) == "", label .. ": ring hidden after release")
				if label == "full" then
					local ok, last = true, -1
					local saw_full = false
					for i = 1, #frames - 1 do
						local n = tonumber(frames[i]:match("_(%d%d)%.png$") or "")
						if frames[i] == "grug_abilities_draw_ring_full.png" then
							saw_full = true
							ok = ok and i == #frames - 1
						elseif not n or n <= last then
							ok = false
						else
							last = n
						end
					end
					check(ok and saw_full and last == 15,
						"full: ring frames strictly progress 00..15 then full (" ..
						table.concat(frames, ","):gsub("grug_abilities_draw_ring_", "")
							:gsub("%.png", "") .. ")")
				end
				log(("%s: elapsed %.2f s"):format(label, (core.get_us_time() - t0) / 1e6))
				deactivate(fake)
				if mob:get_pos() then mob:remove() end
			end},
		}
	end)
end

-- Every draw end path removes the ring.
local ends = {
	cancel = function(fake) grug_abilities.input.cancel(fake.ref) end,
	stun = function(fake) grug_core.set_stun(fake.ref, 0.2) end,
	slot = function(fake) fake.index = 2 end,
	death = function(fake)
		run_callbacks(core.registered_on_dieplayers, END_MODS, fake.ref)
	end,
	leave = function(fake)
		deactivate(fake)
		run_callbacks(core.registered_on_leaveplayers, END_MODS, fake.ref)
	end,
	unequip = function(fake) fake.weapon = nil end,
}
for _, path in ipairs({"cancel", "stun", "slot", "death", "leave", "unequip"}) do
	scenario("ring_end_" .. path, function(origin)
		local label = "ring_end_" .. path
		local ref, fake = make_player(label, "scout", origin)
		fake.weapon = bow_name
		return {
			{0, function()
				skill(fake, "loose")
				fake.inv:set_stack("main", 3, ItemStack("grug_gear:arrow 20"))
				look_ahead(fake)
				activate(fake)
				press(fake)
			end},
			{0.6, function()
				check(grug_abilities.scout_draw_active(ref), label .. ": drawing")
				local r = ring_text(fake) or ""
				check(r:find("^grug_abilities_draw_ring_%d%d%.png$") ~= nil,
					label .. ": ring frame shown (" .. r .. ")")
				ends[path](fake)
			end},
			{0.9, function()
				check(not grug_abilities.scout_draw_active(ref), label .. ": draw ended")
				if path == "leave" then
					check(view(fake) == nil, label .. ": HUD record released")
				else
					check(ring_text(fake) == "", label .. ": ring removed (" ..
						tostring(ring_text(fake)) .. ")")
				end
				release(fake)
			end},
			{1.0, function() deactivate(fake) end},
		}
	end)
end

-- Per-player per-pass cost: the old pass work (input.step) against the new
-- one (input.step + crosshair.update), idle buttons, several aims.
scenario("perf", function(origin)
	local N = 1000
	local ref, fake = make_player("perf", "scout", origin)
	fake.weapon = bow_name
	local dummy = core.add_entity(origin, "grug_probe_crosshair:dummy")
	local npc = core.add_entity(vector.offset(origin, 3, 0, 0), "grug_probe_crosshair:npc")
	local function measure(label, setup)
		setup()
		local input, x = grug_abilities.input, grug_abilities.crosshair
		for _ = 1, 500 do input.step(ref); x.update(ref) end
		-- Seven alternating rounds; the median of each side is reported.
		local b, a = {}, {}
		for round = 1, 7 do
			local t = core.get_us_time()
			for _ = 1, N do input.step(ref) end
			b[round] = (core.get_us_time() - t) / N
			t = core.get_us_time()
			for _ = 1, N do input.step(ref); x.update(ref) end
			a[round] = (core.get_us_time() - t) / N
		end
		table.sort(b); table.sort(a)
		local before, after = b[4], a[4]
		log(("perf %-34s before %6.2f us  after %6.2f us  (+%.2f us, state %s)")
			:format(label, before, after, after - before, tostring(X.state(ref))))
	end
	return {{0.2, function()
		measure("empty hand, open air", function()
			hold(fake, ""); fake.look = vector.new(0, 1, 0)
			dummy:set_pos(vector.offset(origin, -3, 0, 0))
		end)
		measure("empty hand, floor at ~2 m", function()
			hold(fake, ""); look_at(fake, vector.offset(origin, 0, -1, 1))
		end)
		measure("empty hand, NPC at 2 m", function()
			hold(fake, ""); look_ahead(fake); place_ahead(fake, npc, 2, NPC_R)
		end)
		measure("Loose, open air (25 m ray)", function()
			skill(fake, "loose"); fake.look = vector.new(0, 0.2, 1)
			npc:set_pos(vector.offset(origin, 3, 0, 0))
		end)
		measure("Loose, hostile at 20 m", function()
			skill(fake, "loose"); look_ahead(fake); place_ahead(fake, dummy, 20, DUMMY_R)
		end)
		measure("Strike, NPC at 2 m", function()
			skill(fake, "strike"); dummy:set_pos(vector.offset(origin, -3, 0, 0))
			look_ahead(fake); place_ahead(fake, npc, 2, NPC_R)
		end)
		dummy:remove(); npc:remove()
	end}}
end)

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("crosshair probe done", false, 0)
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
	for name in pairs(core.registered_items) do
		if core.get_item_group(name, "grug_bow") > 0 and not bow_name then bow_name = name end
	end
end)

core.after(2, function()
	local minp = vector.offset(BASE, -4, -1, -4)
	local maxp = vector.offset(BASE, SPACING * #scenarios + 4, 6, DEPTH)
	log("emerging arena " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			build_arena(minp, maxp)
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
