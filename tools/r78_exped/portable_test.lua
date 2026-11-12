-- Round 78 lane EXPED portable test (LuaJIT): nothing a player does changes a node an
-- Expedition template writes, and the respawn lock.
-- Prints "R78 EXPED PORTABLE PASS checks=<n>".
--
--   luajit tools/r78_exped/portable_test.lua [REPO]
--
--   A  the template audit, under the game's own registrations (tools/r57_details'
--      harness): every cell every template writes at every tier (template.resolve with
--      catalogue.swaps and catalogue.STATIC), by the builtin falling.lua's rules (an
--      attached node needs a walkable support that is no mark, a falling node a floor
--      that is walkable and not buildable_to, and no mark), and every node a player
--      can act on in place (a right-click, punch, form, inventory or timer callback) is
--      KEPT with its reason. The same audit of the files as they are finds today's
--      weak cells: the hanging lanterns and The Second Shift's 29 torches facing no wall.
--   B  the static copies: their look and light are the originals', with no attachment,
--      no fall, no callback and no drop
--   C  the respawn lock (grug_expeditions/respawn_lock.lua) on a fake engine that
--      plays the builtin death screen's calls (builtin/game/death_screen.lua)
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function eq(got, want, label)
	check(got == want, label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
end

-- ---- A. The template audit -------------------------------------------------------------
local game = dofile(repo .. "/tools/r57_details/game_harness.lua")(repo)
local C = dofile(repo .. "/mods/PLAYER/grug_expeditions/catalogue.lua")
local T = dofile(repo .. "/mods/PLAYER/grug_expeditions/template.lua")

local _, ffi = pcall(require, "ffi")
ffi.cdef[[int uncompress(uint8_t *dest, unsigned long *destLen, const uint8_t *src, unsigned long srcLen);]]
local zlib = ffi.load("z")
local function inflate(bytes)
	local room = 4 * 1048576
	local out, size = ffi.new("uint8_t[?]", room), ffi.new("unsigned long[1]", room)
	assert(zlib.uncompress(out, size, bytes, #bytes) == 0)
	return ffi.string(out, size[0])
end

-- The mod's own nodes (the harness skips grug_expeditions; init.lua and chest.lua):
-- walkable, diggable = false, each an interaction the run is made of.
local OWN = {["grug_expeditions:waystone"] = {}, ["grug_expeditions:reward_chest"] = {},
	["grug_expeditions:reward_door"] = {}}
local AIR = {walkable = false, buildable_to = true}
local function def_of(name)
	if name == "air" then return AIR end
	return OWN[name] or assert(game.nodes[name], "a node the game does not register: " .. name)
end

-- The callbacks a player reaches at a node that stands in a box (digging and placing
-- ask core.is_protected on their own path, so on_dig, can_dig and on_place are not here).
local ACTIVE = {"on_rightclick", "on_punch", "on_receive_fields", "allow_metadata_inventory_put",
	"allow_metadata_inventory_take", "allow_metadata_inventory_move", "on_metadata_inventory_put",
	"on_metadata_inventory_take", "on_metadata_inventory_move", "on_timer"}
-- What stays although a player can act on it, and why.
local KEPT = {
	["grug_expeditions:waystone"] = "the start and end waystone: the waystone window (entry.lua)",
	["grug_expeditions:reward_chest"] = "the reward chest the run pays from (chest.lua)",
	["grug_expeditions:reward_door"] = "the boss door, taken away by open_door (chest.lua)",
	["default:sign_wall_wood"] = "The Second Shift's board: reading is free, its on_receive_fields " ..
		"asks core.is_protected before a write",
	["grug_decor:capital_lava"] = "a capital service prop: its callbacks deny, hint or do nothing (capital.lua)",
	["grug_trees:swamp_hanging_moss_strand"] = "its on_timer is leaf decay, started only by a dug " ..
		"gravewood trunk's after_destruct; no template writes that trunk, and VoxelManip starts no timer",
}
local function active_callbacks(name)
	if OWN[name] then return {"own"} end
	local def, out = def_of(name), {}
	for _, key in ipairs(ACTIVE) do
		if type(def[key]) == "function" then out[#out + 1] = key end
	end
	return out
end

-- builtin/common/item_s.lua core.wallmounted_to_dir
local WALLMOUNTED = {[0] = {0, 1, 0}, {0, -1, 0}, {1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1},
	{0, 1, 0}, {0, -1, 0}}
local function walkable(def) return def.walkable ~= false end

-- The cells a punch or a neighbour change could move (builtin/game/falling.lua
-- check_single_for_falling and check_attached_node): {["node why"] = count}.
local function weak_cells(tpl, name_of, dig)
	local size = tpl.size
	local total = size.x * size.y * size.z
	local cells = tpl.cells
	local function at(x, y, z)
		if x < 0 or y < 0 or z < 0 or x >= size.x or y >= size.y or z >= size.z then return nil end
		local i = z * size.y * size.x + y * size.x + x + 1
		return name_of[cells:byte(i)], cells:byte(total + i)
	end
	local weak = {}
	local function note(name, why)
		local key = name .. " " .. why
		weak[key] = (weak[key] or 0) + 1
	end
	for z = 0, size.z - 1 do
		for y = 0, size.y - 1 do
			for x = 0, size.x - 1 do
				local name, param2 = at(x, y, z)
				local def = def_of(name)
				local groups = def.groups or {}
				if (groups.falling_node or 0) ~= 0 then
					local below = at(x, y - 1, z)
					local bdef = below and def_of(below)
					if not below or not walkable(bdef) or bdef.buildable_to or dig[below] then
						note(name, "falls")
					end
				end
				local rating = groups.attached_node or 0
				if rating ~= 0 then
					local d
					if rating == 3 then d = {0, -1, 0}
					elseif rating == 4 then d = {0, 1, 0}
					elseif rating == 2 then d = nil -- facedir or 4dir: no template uses it
					elseif def.paramtype2 == "wallmounted" or def.paramtype2 == "colorwallmounted" then
						d = WALLMOUNTED[param2 % 8]
					else d = {0, -1, 0} end
					local support = d and at(x + d[1], y + d[2], z + d[3])
					if not support or not walkable(def_of(support)) or dig[support] then
						note(name, "drops")
					end
				end
			end
		end
	end
	return weak
end

-- template.resolve on a stub engine: content ids by name, the game's nodes.
local function resolved(tpl, static)
	local ids, names = {}, {}
	_G.core = {
		registered_nodes = setmetatable({}, {__index = function(_, name)
			if name == "air" or OWN[name] or game.nodes[name] then return {} end
		end}),
		get_content_id = function(name)
			if not ids[name] then
				names[#names + 1] = name
				ids[name] = #names
			end
			return ids[name]
		end,
	}
	T.resolve(tpl, C.swaps(), static)
	_G.core = nil
	return names
end

local templates, seen = {}, {}
for _, row in ipairs(C.EXPEDITIONS) do
	if not seen[row.template] then
		seen[row.template] = true
		local file = assert(io.open(repo .. "/mods/PLAYER/grug_expeditions/templates/" .. row.template ..
			T.EXTENSION, "rb"))
		templates[#templates + 1] = T.parse(file:read("*a"), inflate, row.template)
		file:close()
	end
end
check(#templates == 4, "A four templates: " .. #templates)

-- The static nodes are no mark and no tier node.
for from, to in pairs(C.STATIC) do
	check(game.nodes[to] ~= nil, "A " .. to .. " is registered")
	for _, tier in ipairs(C.TIERS) do
		check(from ~= tier.ore and from ~= tier.gem and to ~= tier.ore and to ~= tier.gem,
			"A " .. from .. " is no tier node")
	end
end

-- The files as they are: today's weak cells, so the audit sees what ruling 5 is about.
local before = {}
for _, tpl in ipairs(templates) do
	local names = resolved(tpl, nil)
	local name_of = {}
	for index in ipairs(tpl.nodes) do name_of[index - 1] = names[tpl.ids[index - 1]] end
	for key, count in pairs(weak_cells(tpl, name_of, tpl.dig)) do
		before[tpl.name .. ": " .. key] = count
	end
end
local LANTERN = "grug_decor:xdecor_lantern_hanging drops"
eq(before["stilled_seam: " .. LANTERN], 57, "A before: The Stilled Seam's hanging lanterns")
eq(before["second_shift: " .. LANTERN], 43, "A before: The Second Shift's hanging lanterns")
eq(before["last_mint: " .. LANTERN], 77, "A before: The Last Mint's hanging lanterns")
eq(before["second_shift: default:torch_wall drops"], 29, "A before: The Second Shift's torches")
local kinds = 0
for _ in pairs(before) do kinds = kinds + 1 end
eq(kinds, 4, "A before: nothing else is weak")

-- As every run writes them: no weak cell at any tier, every node acted on is kept.
local written = {}
for _, tpl in ipairs(templates) do
	local names = resolved(tpl, C.STATIC)
	for _, tier in ipairs(C.TIERS) do
		local variant = tpl.variants[tier.tier]
		local label = "A " .. tpl.name .. " T" .. tier.tier
		check(variant ~= nil, label .. " has its variant")
		local name_of = {}
		for index in ipairs(tpl.nodes) do
			local name = names[variant.ids[index - 1]]
			name_of[index - 1] = name
			written[name] = true
			check(C.STATIC[name] == nil, label .. " writes no " .. name)
		end
		for key, count in pairs(weak_cells(tpl, name_of, variant.dig)) do
			check(false, label .. ": " .. count .. " x " .. key)
		end
		for mark in pairs(variant.dig) do
			check(mark == tier.ore or mark == tier.gem, label .. " marks only its ore and gem: " .. mark)
		end
	end
end
local acted = {}
for name in pairs(written) do
	local callbacks = active_callbacks(name)
	if #callbacks > 0 then
		acted[#acted + 1] = name
		check(KEPT[name] ~= nil, "A " .. name .. " (" .. table.concat(callbacks, ", ") .. ") is kept with a reason")
	end
end
table.sort(acted)
eq(#acted, 6, "A the nodes a player acts on in place: " .. table.concat(acted, ", "))
for name in pairs(KEPT) do check(written[name], "A kept " .. name .. " is written") end

-- ---- B. The static copies ---------------------------------------------------------------
for from, to in pairs(C.STATIC) do
	local original, copy = game.nodes[from], game.nodes[to]
	local label = "B " .. to
	for _, key in ipairs({"drawtype", "mesh", "paramtype", "paramtype2", "light_source", "walkable",
			"sunlight_propagates"}) do
		eq(copy[key], original[key], label .. " keeps " .. key)
	end
	check(copy.groups.attached_node == nil and copy.groups.falling_node == nil, label .. " holds still")
	eq(copy.groups.not_in_creative_inventory, 1, label .. " is no creative item")
	eq(copy.drop, "", label .. " drops nothing")
	for _, key in ipairs(ACTIVE) do
		check(type(copy[key]) ~= "function", label .. " has no " .. key)
	end
end
for _, to in ipairs({"grug_decor:expedition_torch_wall", "grug_decor:expedition_bookshelf"}) do
	local copy = game.nodes[to]
	for key, value in pairs(copy) do
		check(type(value) ~= "function", "B " .. to .. " has no callback: " .. key)
	end
	eq(copy.floodable, false, "B " .. to .. " is not floodable")
end
check(type(game.nodes["default:bookshelf"].on_rightclick) == "function", "B the original shelf still opens")
eq(game.nodes["default:torch_wall"].groups.attached_node, 1, "B the original torch still attaches")

-- ---- C. The respawn lock ----------------------------------------------------------------
local FORM, BUILTIN = "grug_expeditions:death", "__builtin:death"
local now = 0          -- core.get_us_time()
local timers = {}      -- core.after: {at, fn, args}
local online = {}      -- name -> player
local screen = {}      -- name -> {form, text}: what the client shows
local combat = {}      -- name -> true
local callbacks = {}
local function player_of(name, pos)
	local p = {name = name, hp = 20, pos = pos}
	function p:get_player_name() return self.name end
	function p:get_hp() return self.hp end
	function p:get_pos() return self.pos end
	return p
end
_G.core = {
	formspec_escape = function(text) return text end,
	get_us_time = function() return now end,
	after = function(delay, fn, ...)
		timers[#timers + 1] = {at = now + delay * 1e6, fn = fn, args = {...}}
	end,
	get_player_by_name = function(name) return online[name] end,
	get_player_information = function() return {formspec_version = 9} end,
	show_formspec = function(name, form, text) screen[name] = {form = form, text = text} end,
	register_on_player_receive_fields = function(fn) callbacks.fields = fn end,
	register_on_respawnplayer = function(fn) callbacks.respawn = fn end,
	register_on_joinplayer = function(fn) callbacks.join = fn end,
}
-- The builtin's core.show_death_screen (death_screen.lua): its form.
core.show_death_screen = function(player) screen[player:get_player_name()] = {form = BUILTIN} end
_G.grug_core = {in_combat = function(player) return combat[player:get_player_name()] == true end}
local BOX = {x = 9000, y = 0, z = 0}
local run = {id = 1, state = "running", entered = {}, inside = {}}
local party = {}
_G.grug_expeditions = {
	run_at = function(pos) return pos == BOX and run.state ~= "ended" and run or nil end,
	belongs = function(r, p)
		local name = type(p) == "string" and p or p:get_player_name()
		return r == run and party[name] == true
	end,
}
dofile(repo .. "/mods/PLAYER/grug_expeditions/respawn_lock.lua")
eq(grug_expeditions.RESPAWN_LOCK_SECONDS, 10, "C the lock is 10 s")

local function pending()
	local n = 0
	for _, t in ipairs(timers) do if not t.done then n = n + 1 end end
	return n
end
local function advance(seconds)
	local stop = now + seconds * 1e6
	while true do
		local next_timer
		for _, t in ipairs(timers) do
			if not t.done and t.at <= stop and (not next_timer or t.at < next_timer.at) then next_timer = t end
		end
		if not next_timer then break end
		now = math.max(now, next_timer.at)
		next_timer.done = true
		next_timer.fn(unpack(next_timer.args))
	end
	now = stop
end
-- The builtin's calls (death_screen.lua): a death, a join with hp 0, Esc on another form.
local function die(player)
	player.hp = 0
	core.show_death_screen(player, {type = "punch"})
end
local function esc(player)
	local name = player:get_player_name()
	local form = screen[name] and screen[name].form
	if form ~= BUILTIN and player:get_hp() == 0 then core.show_death_screen(player, nil) end
	callbacks.fields(player, form, {quit = "true"})
end
local function leave(player) online[player:get_player_name()] = nil; run.inside[player:get_player_name()] = nil end
local function join(player)
	online[player:get_player_name()] = player
	if player:get_hp() == 0 then core.show_death_screen(player, nil) end
	callbacks.join(player)
end
local function respawn(player)
	player.hp = 20
	callbacks.respawn(player)
	screen[player:get_player_name()] = nil
end
local function seconds(name)
	local s = screen[name]
	if not s or s.form ~= FORM then return nil end
	return tonumber(s.text:match("Respawn in (%d+) s"))
end
-- A run of three inside: ann dies, bob fights, cid does not.
local function setup()
	-- The last case's dead players respawn, its ticks are spent.
	for _, name in ipairs({"ann", "bob", "cid"}) do callbacks.respawn(player_of(name, BOX)) end
	for _, t in ipairs(timers) do t.done = true end
	run = {id = run.id + 1, state = "running", entered = {}, inside = {}}
	party, combat, screen = {}, {}, {}
	local players = {}
	for _, name in ipairs({"ann", "bob", "cid"}) do
		players[name] = player_of(name, BOX)
		online[name], run.entered[name], run.inside[name], party[name] = players[name], true, true, true
	end
	return players.ann, players.bob, players.cid
end

-- Locked 10 s while a living member fights; the countdown on the screen; then free.
local ann, bob, cid = setup()
combat.bob = true
die(ann)
eq(screen.ann.form, FORM, "C1 a death while bob fights: the lock's form")
eq(seconds("ann"), 10, "C1 10 s")
check(screen.ann.text:find("respawn;", 1, true) and not screen.ann.text:find("button_exit", 1, true),
	"C1 the Respawn button does not quit")
eq(pending(), 1, "C1 one timer")
advance(3)
eq(seconds("ann"), 7, "C1 after 3 s: 7")
advance(6.5)
eq(seconds("ann"), 1, "C1 after 9.5 s: 1")
advance(0.5)
eq(screen.ann.form, BUILTIN, "C1 after 10 s: the builtin screen")
eq(pending(), 0, "C1 no timer after the end")
combat.bob = true
core.show_death_screen(ann, nil)
eq(screen.ann.form, BUILTIN, "C1 a free lock stays free while bob fights on")

-- The grey button while locked: the lock's form again, no respawn.
ann, bob, cid = setup()
combat.bob = true
die(ann)
advance(2)
callbacks.fields(ann, FORM, {respawn = "Respawn in 8 s"})
eq(ann.hp, 0, "C2 the grey button does not respawn")
eq(seconds("ann"), 8, "C2 the grey button shows the lock again")

-- Freed early: the fight ends at 4 s, the next tick frees, in place (no reopen: the
-- client replaces the open form's content, game_formspec.cpp).
ann, bob, cid = setup()
combat.bob = true
die(ann)
advance(4)
eq(seconds("ann"), 6, "C3 at 4 s: 6")
combat.bob = nil
advance(1)
eq(screen.ann.form, BUILTIN, "C3 the fight ended: free at once")
eq(pending(), 0, "C3 the timer stops")

-- Free at once with nobody fighting, and dead or outside members do not count.
ann, bob, cid = setup()
die(ann)
eq(screen.ann.form, BUILTIN, "C4 nobody fights: the builtin screen")
eq(pending(), 0, "C4 no timer")
combat.bob = true
core.show_death_screen(ann, nil)
eq(screen.ann.form, BUILTIN, "C4 a fight after the death locks nothing")
ann, bob, cid = setup()
combat.bob, bob.hp = true, 0
die(ann)
eq(screen.ann.form, BUILTIN, "C4 a dead member's fight does not lock")
ann, bob, cid = setup()
combat.bob, run.inside.bob = true, nil
die(ann)
eq(screen.ann.form, BUILTIN, "C4 a member outside the box does not lock")
ann, bob, cid = setup()
combat.ann = true
die(ann)
eq(screen.ann.form, BUILTIN, "C4 the dead player's own fight does not lock")

-- Esc re-shows with the time left, and adds no second timer.
ann, bob, cid = setup()
combat.bob = true
die(ann)
advance(3.5)
esc(ann)
eq(seconds("ann"), 7, "C5 Esc at 3.5 s: the lock again, 7 s")
esc(ann)
eq(pending(), 1, "C5 still one timer")
advance(1)
eq(seconds("ann"), 6, "C5 the countdown goes on")

-- Relog keeps the remaining time: the clock runs on through the logout.
ann, bob, cid = setup()
combat.bob = true
die(ann)
advance(2)
leave(ann)
advance(3)
eq(pending(), 0, "C6 offline: the timer stopped")
screen.ann = nil
join(ann)
eq(seconds("ann"), 5, "C6 a relog at 5 s: the lock with 5 s")
eq(pending(), 1, "C6 the timer runs again")
advance(5)
eq(screen.ann.form, BUILTIN, "C6 free at 10 s")
-- A relog after the end: free.
ann, bob, cid = setup()
combat.bob = true
die(ann)
leave(ann)
advance(12)
join(ann)
eq(screen.ann.form, BUILTIN, "C6 a relog after 10 s: free")

-- The run left (expelled from the party) or ended: free at the next tick.
ann, bob, cid = setup()
combat.bob = true
die(ann)
advance(1)
run.entered.ann, party.ann = nil, nil
advance(1)
eq(screen.ann.form, BUILTIN, "C7 left the run: free")
ann, bob, cid = setup()
combat.bob = true
die(ann)
advance(1)
run.state = "ended"
advance(1)
eq(screen.ann.form, BUILTIN, "C7 the run ended: free")

-- Outside a run the builtin screen, unchanged, and no lock is kept.
ann, bob, cid = setup()
combat.bob = true
ann.pos = {x = 0, y = 0, z = 0}
die(ann)
eq(screen.ann.form, BUILTIN, "C8 a death outside a run: the builtin screen")
eq(pending(), 0, "C8 no timer")
-- Not one of the run (another party in the slot's box): the builtin screen.
ann, bob, cid = setup()
combat.bob, party.ann = true, nil
die(ann)
eq(screen.ann.form, BUILTIN, "C8 not the run's: the builtin screen")

-- The respawn ends the lock: the next death is judged anew.
ann, bob, cid = setup()
die(ann)
eq(screen.ann.form, BUILTIN, "C9 free death")
respawn(ann)
combat.bob = true
die(ann)
eq(seconds("ann"), 10, "C9 after a respawn a new death locks again")
respawn(ann)
advance(20)
eq(screen.ann, nil, "C9 a stale tick after the respawn shows nothing")
-- A join alive drops a lock: the next screen is a new death's.
ann, bob, cid = setup()
combat.bob = true
die(ann)
advance(4)
leave(ann)
ann.hp = 20
join(ann)
ann.hp = 0
core.show_death_screen(ann, nil)
eq(seconds("ann"), 10, "C9 a join alive leaves no lock")

print("R78 EXPED PORTABLE PASS checks=" .. checks)
