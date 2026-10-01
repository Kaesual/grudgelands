-- Round 24 Lane E portable test: quest tracker (ruling 23) and environmental
-- damage (ruling 24). Loads the REAL game files under a minimal `core` stub.
--
-- Usage (repo root): luajit tools/r24_tracker_damage/portable_test.lua

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy

-- Minimal engine surface. Registrations are captured, everything else absent.
local hp_modifiers, globalsteps = {}, {}
local serial = {}
local item_groups = {["default:lava_source"] = {lava = 3}, ["default:lava_flowing"] = {lava = 3}}
local us_time = 1000000
core = {
	registered_items = {["grug_food:raw_meat"] = {description = "Raw Meat\nRestores 5 HP"},
		["default:pine_wood"] = {description = "\27(T@default)Pine Wood Planks\27E"}},
	-- Stand-in for the engine's English resolution of translation escapes.
	get_translated_string = function(_, text)
		return (text:gsub("\27%(T@[^)]*%)", ""):gsub("\27E", ""))
	end,
	registered_entities = {["grug_mobs:boar"] = {description = "Boar"}},
	registered_nodes = {
		["default:water_source"] = {drowning = 1, liquidtype = "source", walkable = false},
		["default:lava_source"] = {drowning = 1, liquidtype = "source", walkable = false,
			damage_per_second = 8, groups = {lava = 3}},
		["air"] = {walkable = false, drawtype = "airlike", sunlight_propagates = true},
	},
	get_us_time = function() return us_time end,
	get_item_group = function(name, group)
		return (item_groups[name] or {})[group] or 0
	end,
	serialize = function(value) serial[#serial + 1] = deep_copy(value); return tostring(#serial) end,
	deserialize = function(text) return deep_copy(serial[tonumber(text)]) end,
	register_on_player_hpchange = function(fn, modifier)
		if modifier then hp_modifiers[#hp_modifiers + 1] = fn end
	end,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	get_connected_players = function() return {} end,
	chat_send_player = function() end,
	add_particlespawner = function() end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end,
	new = function(x, y, z) return {x = x, y = y, z = z} end}

grug_core = {}
dofile("mods/CORE/grug_core/hud_layout.lua")
dofile("mods/CORE/grug_core/item_names.lua")
dofile("mods/CORE/grug_core/combat.lua")
dofile("mods/CORE/grug_core/death_messages.lua")
dofile("mods/CORE/grug_core/environment_damage.lua")
eq(#hp_modifiers, 1, "one central hp-change modifier")
local modifier = hp_modifiers[1]
local env_step = globalsteps[#globalsteps]

-- A player double: hp, pool, breath, head node, armor groups, flags.
local function new_player(name, hp_max)
	local p = {name = name, hp = hp_max, hp_max = hp_max, breath = 10, head = "air",
		armor = {fleshy = 100}, flags = {drowning = true}, set_calls = {}}
	function p:get_player_name() return self.name end
	function p:get_hp() return self.hp end
	function p:get_properties() return {hp_max = self.hp_max, eye_height = 1.5, breath_max = 10} end
	function p:get_pos() return {x = 0, y = 0, z = 0} end
	function p:get_breath() return self.breath end
	function p:get_armor_groups() return self.armor end
	function p:get_flags() return self.flags end
	function p:is_player() return true end
	function p:set_hp(hp, reason)
		-- Engine order: modifiers, then clamp.
		local change = modifier(self, hp - self.hp, reason)
		self.hp = math.max(0, math.min(self.hp_max, self.hp + change))
		self.set_calls[#self.set_calls + 1] = {hp = hp, reason = reason}
	end
	return p
end

------------------------------------------------------------------------------
-- Ruling 24: amounts.
------------------------------------------------------------------------------
local pools = {1, 4, 5, 9, 10, 19, 20, 24, 25, 99, 100, 101, 325, 1234, 6000}
for _, h in ipairs(pools) do
	local lava_expected = math.max(1, math.ceil(h * 20 / 100))
	local drown_expected = math.max(1, math.ceil(h * 10 / 100))
	eq(grug_core.lava_damage(h), lava_expected, "lava_damage(" .. h .. ")")
	eq(grug_core.drowning_damage(h), drown_expected, "drowning_damage(" .. h .. ")")
	-- Full pool dies in at most 5 lava / 10 drowning ticks, never fewer than
	-- the share implies (4 / 9 ticks leave HP when the pool allows it).
	check(5 * grug_core.lava_damage(h) >= h, "lava kills full pool in 5 ticks at " .. h)
	check(10 * grug_core.drowning_damage(h) >= h, "drowning kills full pool in 10 ticks at " .. h)
end
eq(grug_core.lava_damage(0), 0, "lava_damage without pool")
eq(grug_core.lava_damage(nil), 0, "lava_damage nil pool")

-- Heavy armor must not matter for environmental damage.
grug_core.get_armor_rating = function() return 100000 end

local lava_reason = {type = "node_damage", from = "engine", node = "default:lava_source",
	node_pos = {x = 0, y = 0, z = 0}}
for _, h in ipairs({20, 100, 325, 1234}) do
	local p = new_player("lava" .. h, h)
	eq(modifier(p, -8, lava_reason), -grug_core.lava_damage(h),
		"engine lava tick replaced by 20% of pool " .. h)
	local flowing = {type = "node_damage", from = "engine", node = "default:lava_flowing"}
	eq(modifier(p, -8, flowing), -grug_core.lava_damage(h), "flowing lava " .. h)
	-- Engine drown tick is cancelled (per-second tick replaces it).
	eq(modifier(p, -1, {type = "drown", from = "engine", node = "default:water_source"}), 0,
		"engine drown tick cancelled " .. h)
	-- Our tick's amount passes through unchanged.
	eq(modifier(p, -grug_core.drowning_damage(h), {type = "drown", from = "mod",
		custom_type = grug_core.DROWNING_CUSTOM_TYPE}), -grug_core.drowning_damage(h),
		"mod drowning amount unchanged " .. h)
	-- Fall: native r settles as ceil(max_hp * r / 20).
	eq(modifier(p, -5, {type = "fall", from = "engine"}), -math.ceil(h * 5 / 20),
		"fall scales with pool " .. h)
end
-- Non-lava node damage (dragon scorch via set_hp) keeps its own amount.
do
	local p = new_player("scorch", 325)
	eq(modifier(p, -30, {type = "node_damage", from = "mod", node = "grug_mobs:scorch"}), -30,
		"mod node damage unchanged")
end

-- Absorb shield: never consumed by fall, lava or drowning; still by others.
do
	local p = new_player("shield", 325)
	eq(grug_core.add_absorb(p, "test", 100, 60, p), 100, "absorb granted")
	eq(modifier(p, -8, lava_reason), -65, "lava bypasses absorb")
	eq(grug_core.get_absorb(p), 100, "absorb untouched by lava")
	eq(modifier(p, -33, {type = "drown", from = "mod", custom_type = grug_core.DROWNING_CUSTOM_TYPE}),
		-33, "drowning bypasses absorb")
	eq(grug_core.get_absorb(p), 100, "absorb untouched by drowning")
	eq(modifier(p, -4, {type = "fall", from = "engine"}), -65, "fall bypasses absorb")
	eq(grug_core.get_absorb(p), 100, "absorb untouched by fall")
	-- Control: a mod-issued node damage (scorch) and suffocation still soak.
	eq(modifier(p, -30, {type = "node_damage", from = "mod", node = "grug_mobs:scorch"}), 0,
		"scorch absorbed")
	eq(grug_core.get_absorb(p), 70, "absorb consumed by scorch")
	eq(modifier(p, -16, {type = "set_hp", from = "mod", custom_type = "grug_core:suffocation"}), 0,
		"suffocation absorbed")
	eq(grug_core.get_absorb(p), 54, "absorb consumed by suffocation")
end

-- Drowning per-second tick (environment_damage.lua globalstep).
do
	local p = new_player("diver", 100)
	core.get_connected_players = function() return {p} end
	core.get_node = function() return {name = p.head} end
	core.get_player_privs = function() return {} end
	p.head, p.breath = "default:water_source", 3
	env_step(1.0)
	eq(p.hp, 100, "breath left: no drowning")
	p.breath = 0
	env_step(0.5)
	eq(p.hp, 100, "half interval: no tick yet")
	env_step(0.5)
	eq(p.hp, 90, "one second without breath: 10% of pool")
	local last = p.set_calls[#p.set_calls].reason
	eq(last.type, "drown", "drowning reason type")
	eq(last.custom_type, grug_core.DROWNING_CUSTOM_TYPE, "drowning custom type")
	eq(grug_core.death_message("diver", {type = "drown", from = "mod",
		custom_type = grug_core.DROWNING_CUSTOM_TYPE}), "drown", "drowning death message")
	eq(grug_core.death_message("diver", lava_reason), "node_damage", "lava death message")
	env_step(2.0)
	eq(p.hp, 70, "a 2 s step settles two ticks")
	p.armor = {immortal = 1}
	env_step(1.0)
	eq(p.hp, 70, "immortal: no drowning")
	p.armor = {fleshy = 100}
	p.flags = {drowning = false}
	env_step(1.0)
	eq(p.hp, 70, "drowning flag off: no drowning")
	p.flags = {drowning = true}
	p.head = "air"
	env_step(1.0)
	eq(p.hp, 70, "air: no drowning")
	p.head = "default:water_source"
	for _ = 1, 10 do env_step(1.0) end
	eq(p.hp, 0, "drowns to death")
	local calls = #p.set_calls
	env_step(1.0)
	eq(#p.set_calls, calls, "dead player gets no further tick")
	-- Small pool.
	local q = new_player("tiny", 5)
	core.get_connected_players = function() return {q} end
	core.get_node = function() return {name = "default:water_source"} end
	q.breath = 0
	env_step(1.0)
	eq(q.hp, 4, "pool 5 drowns 1 HP per second")
	core.get_connected_players = function() return {} end
end

------------------------------------------------------------------------------
-- Ruling 23: tracker.
------------------------------------------------------------------------------
grug_inventory = {BAG_COUNT = 0, wrap_text = function(text) return text end}
grug_factions = {get_faction = function() return "accord" end, same_faction = function() return false end}
grug_classes = {get_race = function() return "human" end}
grug_xp = {get_level = function() return 60 end}
grug_mobs = {register_on_eligible_kill = function() end, register_participant_drop_hook = function() end}
grug_money = {}
grug_quests = {}
dofile("mods/PLAYER/grug_quests/registry.lua")
dofile("mods/PLAYER/grug_quests/state.lua")
dofile("mods/PLAYER/grug_quests/labels.lua")
dofile("mods/PLAYER/grug_quests/hud.lua")
local Q = grug_quests
eq(Q.MAX_TRACKED, 10, "tracker cap constant")

Q.register_npc("giver", {settlement = "s", socket = "a", title = "Brunna Flintbraid"})
Q.register_npc("other", {settlement = "s", socket = "b", title = "Orrik Pineledger"})
for i = 1, 12 do
	Q.register_quest(("q%02d"):format(i), {title = "Quest Title Number " .. i,
		description = "d", npc = "giver",
		objectives = {{type = "item", item = "grug_food:raw_meat", count = 4}}})
end
Q.register_quest("hunt", {title = "Tusks at the Timberline", description = "d", npc = "giver",
	turnin_npc = "other", objectives = {{type = "kill", mobs = {"grug_mobs:boar"}, count = 3}}})

local meta_store = {}
local held = {}
local player = {}
function player:get_player_name() return "tracker" end
function player:get_meta()
	return {get_string = function(_, k) return meta_store[k] or "" end,
		set_string = function(_, k, v) meta_store[k] = v end}
end
function player:get_inventory()
	return {get_list = function(_, list)
		if list ~= "main" then return {} end
		local stacks = {}
		for name, count in pairs(held) do
			stacks[#stacks + 1] = {get_name = function() return name end,
				get_count = function() return count end}
		end
		return stacks
	end}
end

for i = 1, 12 do check(Q.accept(player, ("q%02d"):format(i)), "accept q" .. i) end
local journal = Q.journal(player)
eq(#journal.tracked, 10, "auto-track stops at the cap")
eq(journal.tracked[10], "q10", "first ten accepted quests tracked")
local ok, message = Q.set_tracked(player, "q11", true)
eq(ok, false, "eleventh track refused")
eq(message, "Track at most 10 quests.", "quest-log notice names the cap")
check(Q.set_tracked(player, "q01", false), "untrack one")
check(Q.set_tracked(player, "q11", true), "track eleventh after freeing a slot")
eq(#Q.journal(player).tracked, 10, "still ten tracked")

local text = Q.hud_text(Q.journal(player), nil)
local lines = {}
for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
eq(#lines, 10, "ten HUD lines for ten tracked quests")
eq(lines[1], "0/4 Bring Raw Meat", "objective-only line")
check(not text:find("Quest Title", 1, true), "no quest title on the HUD")
eq(lines[1], lines[2], "identical objectives read the same")

-- Ready quest: "Return to <turn-in NPC>"; kill objective line.
check(Q.set_tracked(player, "q02", false), "free a slot")
check(Q.accept(player, "hunt"), "accept hunt")
check(Q.set_tracked(player, "hunt", true), "track hunt")
text = Q.hud_text(Q.journal(player), nil)
check(text:find("0/3 Defeat Boar", 1, true) ~= nil, "kill objective line")
held["grug_food:raw_meat"] = 4
text = Q.hud_text(Q.journal(player), nil)
check(text:find("Return to Brunna Flintbraid", 1, true) ~= nil, "ready line names the giver")
check(not text:find("Bring Raw Meat", 1, true), "ready quests show no objective")
local ready = {ready = true, npc = "other", objectives = {}}
eq(Q.hud_line(ready, 38), "Return to Orrik Pineledger", "ready line uses turn-in NPC title")

-- One line at any width, truncated with an ellipsis, UTF-8 safe.
local long = {ready = false, objectives = {{type = "kill", mobs = {"grug_mobs:boar"},
	count = 0, required = 12, description = "Defeat the whole sounder of timberline boars"}}}
for width = 12, 38 do
	local line = Q.hud_line(long, width)
	check(#line <= width and not line:find("\n", 1, true), "one line within width " .. width)
end
check(Q.hud_line(long, 20):sub(-3) == "...", "truncation marked")
local accented = {ready = true, npc = "accented", objectives = {}}
Q.registered_npcs.accented = {title = "Sévérine Ëlvåndottir the Long-Named"}
for width = 12, 38 do
	local line = Q.hud_line(accented, width)
	local tail = line:sub(1, -4)
	local last = tail:byte(-1)
	check(#line <= width and not (last and last >= 0xC0), "utf-8 cut clean at width " .. width)
end
-- Translated item names: escapes resolved before measuring and cutting.
local planks = {ready = false, objectives = {{type = "item", item = "default:pine_wood",
	count = 0, required = 6}}}
eq(Q.hud_line(planks, 38), "0/6 Bring Pine Wood Planks", "escaped item name resolved")
check(not Q.hud_line(planks, 16):find("\27", 1, true), "no escape byte after a cut")
-- Hidden HUD or empty log renders nothing.
local hidden = Q.journal(player)
hidden.hud_enabled = false
eq(Q.hud_text(hidden, nil), "", "HUD toggle off")

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then os.exit(1) end
