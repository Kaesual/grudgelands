-- Round 80 lane FIXES (round80-plan.md §4 FIXES, rulings 9 and 11). Loads the
-- REAL grug_core/combat.lua (with environment_damage.lua) and the REAL
-- grug_factions/init.lua under a small engine stub, runs a hit the way the
-- engine does (builtin register.lua: every modifier, then every logger with
-- the modified number; s_player.cpp then stores it as an integer), and checks:
--   A  absorb amounts are whole numbers at the store: floored as every absorb
--      tooltip floors its number (the shipped kits' shares at several levels),
--      at least 1 for any positive amount, never above the pool;
--   B  a shield broken by a hit leaves whole numbers: the hit through, the
--      absorb left, the nametag the logger draws (the reported bug: a kit's
--      unrounded shield once turned the hit into a fraction);
--   C  a fractional change reaching the modifier leaves it as the integer the
--      engine stores (truncated toward zero, a hit and a heal), soaked in
--      whole points;
--   D  the nametag text prints whole hit points for a fractional input;
--   E  the game's minetest.conf sets movement_liquid_fluidity_smooth to the
--      measured 0.75 (a 30-node fall stops about 8 nodes deep, ruling 9).
-- Usage (repo root): luajit tools/r80_fixes/portable_test.lua [REPO]
local repo = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then failures = failures + 1; print("FAIL " .. label) end
	return ok
end
local function eq(a, b, label)
	return check(a == b, label .. " (got " .. tostring(a) .. ", expected " .. tostring(b) .. ")")
end
local function whole(n) return type(n) == "number" and n == math.floor(n) end

------------------------------------------------------------------------------
-- Engine stub.
------------------------------------------------------------------------------
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
table.copy = copy
vector = {offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end,
	new = function(x, y, z) return {x = x, y = y, z = z} end}

local modifiers, loggers = {}, {}
local us_time = 1000000
local noop = function() end
core = {
	registered_items = {}, registered_entities = {},
	registered_nodes = {air = {walkable = false, drawtype = "airlike"}},
	get_us_time = function() return us_time end,
	get_item_group = function() return 0 end,
	get_translated_string = function(_, text) return text end,
	register_on_player_hpchange = function(fn, modifier)
		local list = modifier and modifiers or loggers
		list[#list + 1] = fn
	end,
	get_connected_players = function() return {} end,
	get_modpath = function() return repo .. "/mods/PLAYER/grug_factions" end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	chat_send_player = noop,
	add_particlespawner = noop,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return noop end
	return nil
end})
grug_sounds = {play = function() return false end, CLICK_STYLE = ""}

grug_core = {}
grug_core.particles = {play = noop}
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(repo .. "/mods/CORE/grug_core/item_names.lua")
dofile(repo .. "/mods/CORE/grug_core/combat.lua")
-- Round 81: the per-player passes register through grug_core.
dofile(repo .. "/tools/r81_passes/all_players_pass.lua")(grug_core, core)
dofile(repo .. "/mods/CORE/grug_core/environment_damage.lua")
eq(#modifiers, 1, "one central hp-change modifier")

-- grug_factions' load-time surface: the zone authority, the tag carrier.
local carrier_text = {}
grug_core.zone_authority_installed = function() return true end
grug_core.factions = {}
grug_core.create_tag_carrier = function(_, name) return name end
grug_core.set_tag_carrier_text = function(carrier, text)
	carrier_text[carrier] = text
	return true
end
grug_core.remove_tag_carrier = noop
grug_xp = {get_level = function() return 3 end}
dofile(repo .. "/mods/PLAYER/grug_factions/init.lua")
eq(#loggers >= 1, true, "grug_factions registers its hp logger")

local function new_player(name, hp_max)
	local p = {name = name, hp = hp_max, hp_max = hp_max}
	function p:get_player_name() return self.name end
	function p:get_hp() return self.hp end
	function p:get_properties() return {hp_max = self.hp_max} end
	function p:get_pos() return {x = 0, y = 0, z = 0} end
	function p:is_player() return true end
	function p:get_meta() return {get_string = function() return "" end} end
	return p
end

-- One hit as the engine runs it: modifiers (last registered first), then the
-- loggers with the modified number, then the integer store (lua_tointeger
-- truncates toward zero) and the clamp.
local function hit(player, change, reason)
	for i = #modifiers, 1, -1 do change = modifiers[i](player, change, reason) end
	for _, fn in ipairs(loggers) do fn(player, change, reason) end
	local stored = change < 0 and math.ceil(change) or math.floor(change)
	player.hp = math.max(0, math.min(player.hp_max, player.hp + stored))
	return change
end
local SET_HP = {type = "set_hp", from = "mod"}

------------------------------------------------------------------------------
-- A  absorb amounts are whole at the store.
------------------------------------------------------------------------------
do
	local p = new_player("a", 100)
	eq(grug_core.add_absorb(p, "a1", 10.4, 30, p), 10, "A 10.4 is stored as 10")
	eq(grug_core.get_absorb(p), 10, "A the shield holds 10")
	eq(grug_core.add_absorb(p, "a1", 10.9, 30, p), 10, "A 10.9 is stored as 10 (refresh)")
	eq(grug_core.add_absorb(p, "a2", 0.3, 30, p), 1, "A a positive sliver is at least 1")
	eq(grug_core.add_absorb(p, "a3", 0, 30, p), 0, "A nothing stays nothing")
	eq(grug_core.add_absorb(p, "a4", 95.7, 30, p), 89, "A the pool clamp (100 - 11) stays whole")
	eq(grug_core.get_absorb(p), 100, "A the shields fill the pool exactly")
end
-- The tooltips (kits.lua effective_support_number, kits_mage Rime Mantle,
-- scout Parry and Close Dance) print math.floor of the share the cast hands
-- to add_absorb: the store must hold that number. Shares of the pool P as
-- shipped (Priest Shield 24 %, Mercy 34 %, Hold Ground 12-21 %, Unbroken
-- 15 %, Rime Mantle 12 %, Parry 10 %, Close Dance 15 %), with the neutral and
-- a geared support factor, at levels 1 to 60.
do
	local fails = 0
	for _, level in ipairs({1, 7, 20, 33, 47, 60}) do
		local pool = grug_core.base_pool(level)
		for _, percent in ipairs({10, 12, 15, 21, 24, 34}) do
			for _, factor in ipairs({1, 1.137}) do
				local p = new_player("t", 10000)
				local share = pool * percent / 100 * factor
				if grug_core.add_absorb(p, "k", share, 10, p) ~= math.floor(share) then
					fails = fails + 1
					print(("  L%d %d%% x%g: tooltip %d, store %s"):format(level, percent,
						factor, math.floor(share), tostring(grug_core.get_absorb(p))))
				end
			end
		end
	end
	eq(fails, 0, "A every kit share: the store holds the tooltip's number")
	local p = new_player("t2", 100)
	grug_core.add_absorb(p, "shield_spell", 23.6, 10, p)
	eq(grug_core.get_absorb(p), 23, "A the review's case: tooltip 23, shield 23")
end

------------------------------------------------------------------------------
-- B  a shield broken by a hit: whole numbers in the hit, the absorb and the tag.
------------------------------------------------------------------------------
do
	local p = new_player("anna", 100)
	grug_core.add_absorb(p, "shield_spell", 23.6, 10, p)
	eq(grug_core.get_absorb(p), 23, "B the kit's 23.6 shield holds 23")
	local change = hit(p, -40, SET_HP)
	eq(change, -17, "B the hit breaks the shield; 17 go through")
	check(whole(change), "B the loggers see a whole change")
	eq(grug_core.get_absorb(p), 0, "B the shield is gone")
	eq(p.hp, 83, "B the stored hit points")
	eq(carrier_text.anna, "anna [Lv 3] 83/100", "B the nametag shows whole numbers")
	-- Two shields, the shorter-lived first; both whole after a partial soak.
	grug_core.add_absorb(p, "short", 7.4, 5, p)
	grug_core.add_absorb(p, "long", 12.5, 20, p)
	change = hit(p, -10, SET_HP)
	eq(change, 0, "B a hit within two shields is fully soaked")
	eq(grug_core.get_absorb(p), 9, "B 7 + 12 - 10 = 9 left, whole")
	change = hit(p, -15, SET_HP)
	eq(change, -6, "B the rest breaks them; 6 go through")
	eq(carrier_text.anna, "anna [Lv 3] 77/100", "B the nametag after the second break")
end

------------------------------------------------------------------------------
-- C  a fractional change leaves the modifier as the engine's integer.
------------------------------------------------------------------------------
do
	local p = new_player("cara", 100)
	eq(hit(p, -7.6, SET_HP), -7, "C -7.6 without a shield is the stored -7")
	grug_core.add_absorb(p, "c", 3, 10, p)
	eq(hit(p, -7.6, SET_HP), -4, "C -7.6 against a 3-point shield is -4")
	eq(grug_core.get_absorb(p), 0, "C the shield soaked exactly 3")
	eq(carrier_text.cara, "cara [Lv 3] 89/100", "C the nametag")
	local heal = hit(p, 7.6, SET_HP)
	eq(heal, 7, "C a +7.6 heal is the stored +7 (toward zero, not up)")
	eq(carrier_text.cara, "cara [Lv 3] 96/100", "C the nametag after the heal")
	eq(hit(p, 0.9, SET_HP), 0, "C a +0.9 sliver stores nothing")
end

------------------------------------------------------------------------------
-- D  the nametag text of a fractional input.
------------------------------------------------------------------------------
eq(grug_factions.player_tag_text("dora", 7, 14.6, 20), "dora [Lv 7] 14/20",
	"D a fraction is printed whole")
eq(grug_factions.player_tag_text("dora", 7, 20, 20), "dora [Lv 7] 20/20", "D whole input unchanged")
do
	local p = new_player("dora", 100)
	grug_factions.refresh_player_tag(p, 99.5)
	eq(carrier_text.dora, "dora [Lv 3] 99/100", "D the refresh with a fractional prediction")
end

------------------------------------------------------------------------------
-- E  water brakes a fast fall: the game's setting.
------------------------------------------------------------------------------
do
	local f = assert(io.open(repo .. "/minetest.conf", "rb"))
	local conf = f:read("*a")
	f:close()
	local value = tonumber(conf:match("\nmovement_liquid_fluidity_smooth = ([%d%.]+)"))
	check(value ~= nil, "E minetest.conf sets movement_liquid_fluidity_smooth")
	eq(value, 0.75, "E the measured value (30-node fall stops at about 8 nodes)")
end

if failures > 0 then
	error(("R80 FIXES PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R80 FIXES PORTABLE OK checks=%d"):format(checks))
