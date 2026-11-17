-- Round 81 lane PASSES portable test (LuaJIT; docs/planning/round81-plan.md
-- §4 PASSES). Loads the REAL files through tools/r81_passes/measure.lua's
-- sandboxes, with grug_core's REAL join slots (player_slots.lua):
--
--   P  the passes moved onto the join slots register through
--      grug_core.register_player_pass, and none walks the connected
--      players itself;
--   J  spreading: the status row (0.5 s), environment damage (1 s) and the
--      grug_abilities regeneration pass (0.5 s) handle at most two slots of
--      players in one server step, never a player twice in one step, and
--      every player once per period; environment damage deals one whole
--      tick per visit at steady steps; two Mages in different slots
--      regenerate the same within one visit;
--   S  the status pass sweeps once per visit: a ticking status ticks at 1,
--      2 and 3 s and expires after its final tick (on_expire once); an
--      on_expire that sets another status shows it in the same visit; a
--      visit without a tick or an expiry sorts three times (one list, the
--      row's two);
--   I  the identity cache: every accessor reads player meta once per
--      player; each key's writer (set_xp, set_class, set_race,
--      set_faction, start_potion_cooldown) updates it before its callbacks
--      run; a new player object over the same meta (a rejoin) reads it
--      afresh; a race of another faction still counts as unset; the
--      hp_max apply_stats sets is what the nametag reads inside the
--      engine's clamp, and the nametag reads no properties;
--   E  environment damage at 40 join moments with uneven steps: at most
--      one tick on the join visit, exactly one per steady visit, the
--      stall's whole seconds on the visit over a stall;
--   W  the wield poll after an apply() that re-textured the same entity
--      (A, then B through apply, then A again) shows A;
--   M  the call counts of tools/r81_passes/measure.lua on this tree.
--
-- Usage (repo root): luajit tools/r81_passes/portable_test.lua [REPO]
local ROOT = arg and arg[1] or "."
local failures, checks = {}, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end

local saved_arg = arg
arg = nil -- measure.lua prints its report when run as a script
local M = dofile(ROOT .. "/tools/r81_passes/measure.lua")
arg = saved_arg
local STEP = 0.09

------------------------------------------------------------------------------
-- P: the passes register through the join slots.
------------------------------------------------------------------------------
for _, path in ipairs({
	"mods/CORE/grug_core/status.lua", "mods/CORE/grug_core/atmosphere.lua",
	"mods/CORE/grug_core/environment_damage.lua", "mods/PLAYER/grug_abilities/init.lua",
	"mods/ENTITIES/grug_mobs/target_frame.lua", "mods/PLAYER/grug_pvp/init.lua",
	"mods/PLAYER/grug_pvp/page.lua", "mods/PLAYER/grug_inventory/pages.lua",
	"mods/PLAYER/grug_visuals/apply.lua"}) do
	local text = read(path)
	check(text:find("grug_core.register_player_pass(", 1, true) ~= nil,
		"P " .. path .. " registers a player pass")
end
for _, path in ipairs({"mods/CORE/grug_core/status.lua", "mods/CORE/grug_core/atmosphere.lua",
	"mods/CORE/grug_core/environment_damage.lua", "mods/ENTITIES/grug_mobs/target_frame.lua",
	"mods/PLAYER/grug_pvp/page.lua", "mods/PLAYER/grug_visuals/apply.lua"}) do
	check(not read(path):find("get_connected_players", 1, true),
		"P " .. path .. " walks no connected-player list")
end
-- grug_pvp walks the list only at shutdown, to save the timers.
local _, walks = read("mods/PLAYER/grug_pvp/init.lua"):gsub("get_connected_players", "")
eq(walks, 1, "P grug_pvp walks the connected players once (the shutdown save)")
check(not read("mods/PLAYER/grug_visuals/apply.lua"):find("on_step = function", 1, true),
	"P the wield entity has no on_step")
check(not read("mods/PLAYER/grug_pvp/init.lua"):find("tick_stats", 1, true),
	"P no tick_stats in the PvP pass")

------------------------------------------------------------------------------
-- J: spreading.
------------------------------------------------------------------------------
do
	-- The status row: raw source calls per player and step.
	local S = M.status_sandbox(ROOT)
	local per_step, step = {}, 0
	S.G.register_status_source(function(p)
		per_step[step] = per_step[step] or {}
		per_step[step][p] = (per_step[step][p] or 0) + 1
	end)
	local players = {}
	for i = 1, 40 do
		players[i] = S.new_player("s" .. i)
		S.E.join(players[i])
	end
	for s = 1, 45 do -- 4.05 s
		step = s
		S.E.step(STEP)
	end
	local most, twice, visits = 0, false, {}
	for _, seen in pairs(per_step) do
		local n = 0
		for p, count in pairs(seen) do
			n = n + 1
			if count > 1 then twice = true end
			visits[p] = (visits[p] or 0) + 1
		end
		if n > most then most = n end
	end
	check(most <= 10, "J status: at most two slots of five players in one step (" .. most .. ")")
	check(not twice, "J status: no player twice in one step")
	local fair = true
	for _, p in ipairs(players) do
		local n = visits[p] or 0
		if n < 7 or n > 9 then fair = false end
	end
	check(fair, "J status: every player 8 times in 4.05 s (one more or less at the edges)")

	-- Environment damage.
	local E = M.env_sandbox(ROOT)
	local stone = {}
	for i = 1, 100 do
		local p = E.new_player("e" .. i, i - 1)
		E.E.join(p)
		if i > 90 then stone[#stone + 1] = p end
	end
	for s = 1, 111 do
		E.counter.step = s
		E.E.step(STEP)
	end
	check(E.counter.max <= 26, "J env: at most two slots of 13 players in one step (" ..
		E.counter.max .. ")")
	local whole = true
	for _, p in ipairs(stone) do
		if #p.hits < 9 or #p.hits > 10 then whole = false end
		for _, amount in ipairs(p.hits) do
			if amount ~= 5 then whole = false end
		end
	end
	check(whole, "J env: one tick (5 of 100 HP) per visit, 9 or 10 in 9.99 s")

	-- Regeneration: two Mages in different slots, the same gain within one
	-- visit's worth.
	local R = M.regen_sandbox(ROOT)
	local a, b = R.new_player("ma", "mage"), R.new_player("mb", "mage")
	R.join(a)
	R.join(b)
	check(R.env.grug_core.player_pass_slot("ma") ~= R.env.grug_core.player_pass_slot("mb"),
		"J regen: the two Mages sit in different slots")
	a.max_mana, b.max_mana = 1e6, 1e6
	local A = R.env.grug_abilities
	local a0, b0 = A.get_mana(a), A.get_mana(b)
	for _ = 1, 56 do R.step(STEP) end -- 5.04 s
	local rate = A.mana_regen_rate(a, false)
	local ga, gb = A.get_mana(a) - a0, A.get_mana(b) - b0
	check(ga > 4.4 * rate and ga <= 5.04 * rate + 1, "J regen: about 5 s of regeneration (" ..
		ga .. " at " .. rate .. "/s)")
	check(math.abs(ga - gb) <= 0.5 * rate + 1, "J regen: the slots differ by at most one visit")
end

------------------------------------------------------------------------------
-- S: the status pass.
------------------------------------------------------------------------------
do
	local S = M.status_sandbox(ROOT)
	local G = S.G
	local p = S.new_player("ticker")
	local changes = {}
	function p:hud_change(id, prop, value)
		if prop == "text" then changes[id] = value end
	end
	S.E.join(p)
	local ticks, expired = {}, 0
	local start = S.E.now()
	G.set_status(p, "poison", {duration = 3, interval = 1,
		on_tick = function() ticks[#ticks + 1] = (S.E.now() - start) / 1e6 end,
		on_expire = function() expired = expired + 1 end})
	for _ = 1, 50 do S.E.step(STEP) end -- 4.5 s
	eq(#ticks, 3, "S three ticks in a 3 s status at 1 s")
	check(ticks[1] and ticks[1] >= 1 and ticks[1] < 1.6, "S the first tick after 1 s")
	eq(expired, 1, "S expired once, after the final tick")
	eq(G.get_status(p, "poison"), nil, "S gone after the final tick")

	-- An on_expire that sets another status: the same visit shows it.
	local shown_at
	G.set_status(p, "sprint", {duration = 0.2, on_expire = function(player)
		G.set_status(player, "slow", {duration = 10})
		shown_at = "set"
	end})
	local drawn = false
	for _ = 1, 12 do
		S.E.step(STEP)
		if shown_at and not drawn then
			local row = G.status_display(p)
			drawn = row[1] and row[1].id == "slow"
			local found = false
			for _, text in pairs(changes) do
				if row[1] and text == row[1].texture then found = true end
			end
			check(found, "S the visit that expired a status drew the one its on_expire set")
			drawn = true
		end
	end
	check(drawn, "S the expiry ran")

	-- One sweep per visit: a plain visit sorts three times.
	local q = S.new_player("plain")
	S.E.join(q)
	G.set_status(q, "sprint", {duration = 30})
	local before = S.sorts()
	local counted = 0
	G.register_status_source(function(player) if player == q then counted = counted + 1 end end)
	for _ = 1, 12 do S.E.step(STEP) end
	local sorts = S.sorts() - before
	check(counted >= 1, "S the plain player was visited")
	-- `p` (slow, no tick) is visited too: three sorts per visit of each.
	check(sorts > 0 and sorts % 3 == 0, "S three sorts per plain visit (" .. sorts .. ")")
end

------------------------------------------------------------------------------
-- I: the identity cache.
------------------------------------------------------------------------------
do
	local S = M.identity_sandbox(ROOT)
	local X, C, F, T = S.X, S.C, S.F, S.T
	local store = {["grug_xp:xp"] = tostring(X.xp_for_level(10)),
		["grug_factions:faction"] = "accord", ["grug_classes:race"] = "human",
		["grug_classes:class"] = "mage"}
	local p = S.new_player("ida", store)
	S.counts.meta = 0
	for _ = 1, 20 do
		X.get_level(p); X.get_xp(p); C.get_class(p); C.get_race(p); F.get_faction(p)
		T.potion_cooldown_left(p)
	end
	eq(S.counts.meta, 5, "I one meta read per key (XP, class, race, faction, potion)")
	eq(X.get_level(p), 10, "I the level from the stored XP")
	eq(C.get_class(p), "mage", "I the stored class")
	eq(C.get_race(p), "human", "I the stored race")
	eq(F.get_faction(p), "accord", "I the stored faction")

	-- set_xp: the level callbacks see the new level.
	local seen
	X.register_on_level_change(function(player, old, new)
		if player == p then seen = {old, new, X.get_level(player), X.get_xp(player)} end
	end)
	X.set_xp(p, X.xp_for_level(12))
	check(seen and seen[1] == 10 and seen[2] == 12 and seen[3] == 12 and
		seen[4] == X.xp_for_level(12), "I set_xp: the callback reads the new level and XP")
	eq(X.get_level(p), 12, "I set_xp: get_level")
	eq(store["grug_xp:xp"], tostring(X.xp_for_level(12)), "I set_xp: the meta stays the authority")

	-- set_class / set_race / set_faction.
	C.set_class(p, "warrior")
	eq(C.get_class(p), "warrior", "I set_class")
	local chosen
	F.register_on_faction_chosen(function(player, id)
		chosen = {id, F.get_faction(player), C.get_race(player)}
	end)
	F.set_faction(p, "throng")
	check(chosen and chosen[1] == "throng" and chosen[2] == "throng",
		"I set_faction: the callback reads the new faction")
	eq(chosen and chosen[3], nil, "I the old race of the other faction counts as unset")
	eq(C.get_race(p), nil, "I get_race checks the current faction")
	check(C.set_race(p, "orc"), "I set_race to a race of the new faction")
	eq(C.get_race(p), "orc", "I set_race")
	eq(C.get_race_perk(p, "rage_per_hit_taken_bonus"), 1, "I the race perk follows")

	-- A rejoin: a new object over the same meta reads afresh.
	store["grug_xp:xp"] = tostring(X.xp_for_level(20))
	eq(X.get_level(p), 12, "I a direct meta write is not seen by the old object")
	local again = S.new_player("ida", store)
	eq(X.get_level(again), 20, "I the rejoined object reads the meta")
	eq(F.get_faction(again), "throng", "I the rejoined object's faction")
	eq(C.get_race(again), "orc", "I the rejoined object's race")

	-- The potion cooldown.
	eq(T.potion_cooldown_left(again), 0, "I potion: ready")
	T.start_potion_cooldown(again)
	check(T.potion_cooldown_left(again) > 29, "I potion: start_potion_cooldown is seen at once")
	local third = S.new_player("ida", store)
	check(T.potion_cooldown_left(third) > 29, "I potion: a rejoin reads the stored expiry")

	-- applied_max_hp inside the engine's clamp, and no property read by the
	-- nametag.
	local texts = {}
	S.env.grug_core.set_tag_carrier_text = function(_, text) texts[#texts + 1] = text return true end
	local h = S.new_player("hal", {["grug_xp:xp"] = "0", ["grug_factions:faction"] = "accord",
		["grug_classes:class"] = "warrior"})
	S.join(h)
	C.apply_stats(h)
	local full = h.props.hp_max
	h.hp = full
	C.get_max_hp = function() return full - 5 end
	texts = {}
	C.apply_stats(h)
	eq(C.applied_max_hp(h), full - 5, "I applied_max_hp follows apply_stats")
	local last = texts[#texts] or ""
	check(last:find("/" .. (full - 5), 1, true) ~= nil,
		"I the clamp's nametag shows the new maximum (" .. last .. ")")
	S.counts.props = 0
	h:set_hp(h.hp - 1)
	eq(S.counts.props, 0, "I an hp change reads no properties for the nametag")
end

------------------------------------------------------------------------------
-- E: environment damage at any join moment (Round 81 review, Medium 2).
------------------------------------------------------------------------------
do
	-- 40 joins at different moments and slots, uneven 0.08-0.11 s steps (a
	-- fixed generator), 38 s in stone, one 2.6 s stall, 18 s more.
	local seed = 12345
	local function jitter()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return 0.08 + 0.03 * seed / 2147483648
	end
	local bad_join, bad_steady, bad_stall, bad_sum = 0, 0, 0, 0
	local steady_hits, stall_ticks = 0, {}
	for trial = 0, 39 do
		local S = M.env_sandbox(ROOT)
		for i = 1, trial % 8 do S.E.join(S.new_player("f" .. i, 0)) end
		for _ = 1, 3 + (trial * 7) % 23 do S.E.step(jitter()) end
		local p = S.new_player("stone", 95)
		local times, set_hp = {}, p.set_hp
		function p:set_hp(hp)
			times[#times + 1] = S.E.now() / 1e6
			return set_hp(self, hp)
		end
		local joined = S.E.now() / 1e6
		S.E.join(p)
		for _ = 1, 400 do S.E.step(jitter()) end
		local stall_at = S.E.now() / 1e6
		S.E.step(2.6)
		for _ = 1, 200 do S.E.step(jitter()) end
		if (p.hits[1] or 0) > 5 then bad_join = bad_join + 1 end
		local sum, stall_seen = p.hits[1] / 5, false
		for i = 2, #p.hits do
			local ticks = p.hits[i] / 5
			sum = sum + ticks
			if times[i - 1] <= stall_at and times[i] > stall_at then
				-- The visit whose gap holds the stall: its gap rounded.
				stall_seen = true
				stall_ticks[#stall_ticks + 1] = ticks
				local gap = times[i] - times[i - 1]
				if ticks < 2 or ticks ~= math.floor(gap + 0.5) then
					bad_stall = bad_stall + 1
				end
			else
				steady_hits = steady_hits + 1
				if ticks ~= 1 then bad_steady = bad_steady + 1 end
			end
		end
		if not stall_seen then bad_stall = bad_stall + 1 end
		if math.abs(sum - (times[#times] - joined)) > 2 then bad_sum = bad_sum + 1 end
	end
	eq(bad_join, 0, "E env: a join visit deals at most one tick, at 40 join moments")
	eq(bad_steady, 0, "E env: every steady visit deals exactly one tick (" .. steady_hits ..
		" visits)")
	eq(bad_stall, 0, "E env: the visit over a 2.6 s stall deals the stall's whole seconds (" ..
		table.concat(stall_ticks, ",", 1, math.min(#stall_ticks, 10)) .. ", ...)")
	eq(bad_sum, 0, "E env: the ticks add up to the time in stone within two")
end

------------------------------------------------------------------------------
-- W: the wield poll after apply() (Round 81 review, Low).
------------------------------------------------------------------------------
do
	-- apply.lua alone with stub seams: two items of the same pose and
	-- scale, so a swap between them re-textures the one wield entity.
	local function noop() end
	local function permissive(t)
		return setmetatable(t, {__index = function() return noop end})
	end
	local function new_meta()
		local data = {}
		return {get_string = function(_, k) return data[k] or "" end,
			set_string = function(_, k, v) data[k] = v end}
	end
	local function ItemStack(item)
		local name = type(item) == "table" and item:get_name() or item or ""
		local meta = new_meta()
		return {get_name = function() return name end, get_meta = function() return meta end,
			to_string = function() return name end, is_empty = function() return name == "" end,
			get_count = function() return name == "" and 0 or 1 end}
	end
	local entities = {}
	local core = permissive({
		registered_items = {["test:a"] = {}, ["test:b"] = {}},
		get_item_group = function() return 0 end,
		add_entity = function()
			local obj = {textures = nil}
			function obj:get_pos() return {x = 0, y = 0, z = 0} end
			function obj:set_properties(props) if props.textures then self.textures = props.textures end end
			obj.set_attach, obj.remove = noop, noop
			entities[#entities + 1] = obj
			return obj
		end,
	})
	local poll, equipment
	local anim = {x = 0, y = 1}
	local env = setmetatable({
		core = core, ItemStack = ItemStack,
		table = setmetatable({copy = function(t)
			local c = {}
			for k, v in pairs(t) do c[k] = v end
			return c
		end}, {__index = table}),
		grug_core = permissive({
			register_player_pass = function(_, fn) poll = fn end,
			register_on_equipment_change = function(fn) equipment = fn end,
		}),
		grug_classes = permissive({get_class = function() return "warrior" end}),
		grug_inventory = permissive({}),
		player_api = permissive({registered_models = {["character.b3d"] = {
			animations = {stand = anim, walk = anim, mine = anim, walk_mine = anim, sit = anim},
			textures = {"character.png"}, collisionbox = {}}}}),
		grug_visuals = permissive({
			WIELD = {bone = "Arm_Right", size = {x = 1, y = 1}},
			WINGS_NONE = "", BACK_NONE = "", WEAPON_NONE = "",
			wield_transform = function() return {size = {x = 1, y = 1}} end,
			pose_for = function() return "hold" end,
			wield_item_scale = function() return 1 end,
			compose = function() return {stature = 1, key = "look"} end,
			appearance_key = function() return "appearance" end,
		}),
	}, {__index = _G})
	local chunk = assert(loadfile(ROOT .. "/mods/PLAYER/grug_visuals/apply.lua"))
	setfenv(chunk, env)
	chunk()
	env.grug_visuals.player_spec = function() return {} end
	local p = {item = "test:a"}
	local meta = new_meta()
	function p:get_player_name() return "wren" end
	function p:is_player() return true end
	function p:get_wielded_item() return ItemStack(self.item) end
	function p:get_pos() return {x = 0, y = 0, z = 0} end
	function p:get_meta() return meta end
	p.set_properties = noop
	env.grug_visuals.apply(p)
	poll(p) -- records sword A
	p.item = "test:b"
	equipment(p, "grug_chest") -- an armour change within the second: apply shows B
	eq(entities[1] and entities[1].textures[1], "test:b", "W apply re-textures to B")
	p.item = "test:a" -- back to A before the next poll
	poll(p)
	eq(#entities, 1, "W one wield entity (the swap re-textures)")
	eq(entities[1].textures[1], "test:a", "W the next poll shows A again")
end

------------------------------------------------------------------------------
-- M: the call counts on this tree.
------------------------------------------------------------------------------
do
	local n = M.measure(ROOT)
	check(n.status.max_per_step <= 26, "M status: at most 26 of 100 players in one step")
	check(n.status.sorts_per_visit < 4, "M status: about three sorts per visit")
	check(n.env.max_per_step <= 26 and n.env.one_tick_each, "M env: spread, one tick each")
	eq(n.regen.max_per_step, 26, "M regen: two slots of 13 at most")
	eq(n.regen.max_mana_per_visit, 1, "M regen: one max-mana computation per visit")
	eq(n.regen.props_per_visit, 1, "M regen: one property read per visit")
	eq(n.identity.meta_reads, 500, "M identity: one read per key and player")
	eq(n.identity.tag_props, 0, "M identity: no property read for the nametag")
end

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	error(("R81 PASSES PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print(("R81 PASSES PORTABLE PASS checks=%d"):format(checks))
