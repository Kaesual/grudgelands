-- Round 76.2 portable test (LuaJIT): the /home chat command.
--
--   luajit tools/r762_home/portable_test.lua [repo]
--
-- Loads the REAL grug_home/home_command.lua on a fake engine with a stubbed
-- grug_home. Checks that /home is registered without a privilege, calls
-- grug_home.return_home exactly when the button could (a home, no return
-- under way, alive) and leaves every other rule to it (combat, guards and the
-- cooldown are return_home's own answers, so the command passes them on
-- without a second line), refuses character creation's stasis, and answers
-- the silent cases with one line.

local repo = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end

local commands = {}
local players = {}
local stasis = false
grug_core = {player_in_creation_stasis = function(name) return stasis end}
core = {
	register_chatcommand = function(name, def) commands[name] = def end,
	get_player_by_name = function(name) return players[name] end,
}

local calls = 0
local state = {}
grug_home = {
	get = function(player) return state.home and {label = "Dawnmere"} or nil end,
	is_pending = function(player) return state.pending end,
	return_home = function(player)
		calls = calls + 1
		return state.accept
	end,
}

dofile(repo .. "/mods/PLAYER/grug_home/home_command.lua")

local def = commands.home
check(def ~= nil, "/home is registered")
check(def and (def.privs == nil or next(def.privs) == nil), "/home needs no privilege")
check(def and type(def.description) == "string" and def.description ~= "", "/home has a description")

local function player(hp)
	return {get_hp = function() return hp end, get_player_name = function() return "ana" end}
end
local function run(case, hp)
	state = case
	players.ana = hp and player(hp) or nil
	calls = 0
	return def.func("ana", "")
end

-- Not in the game (no player object).
local ok, msg = run({home = true}, nil)
check(ok == false and msg:find("in the game", 1, true) and calls == 0, "offline: one line, no call")

-- Character creation or its waiting point (review finding): a home exists
-- already, but the buttons are suspended; the command refuses too.
stasis = true
ok, msg = run({home = true, accept = true}, 20)
check(ok == false and msg:find("cannot return home yet", 1, true) and calls == 0,
	"creation stasis: one line, no call")
stasis = false

-- No home (a character without a faction, still in creation).
ok, msg = run({home = false}, 20)
check(ok == false and msg:find("cannot return home yet", 1, true) and calls == 0, "no home: one line, no call")

-- A trip under way (a return, a waystone or a lift): the button reads
-- "Preparing arrival".
ok, msg = run({home = true, pending = true}, 20)
check(ok == false and msg:find("already being prepared", 1, true) and calls == 0, "pending: one line, no call")

-- Dead.
ok, msg = run({home = true}, 0)
check(ok == false and msg:find("while dead", 1, true) and calls == 0, "dead: one line, no call")

-- Allowed by the command: return_home decides and answers (combat, guard,
-- cooldown or the trip); the command adds no line either way.
ok, msg = run({home = true, accept = true}, 20)
check(ok == true and msg == nil and calls == 1, "home: return_home called once, no extra line")
ok, msg = run({home = true, accept = false}, 20)
check(ok == true and msg == nil and calls == 1, "refused by return_home: its own line only")

-- An argument is ignored (no target, no other player's home).
state = {home = true, accept = true}
players.ana = player(20)
calls = 0
ok = def.func("ana", "bo")
check(ok == true and calls == 1, "an argument changes nothing")

if failures > 0 then
	error(("R762 HOME PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print("R762 HOME PORTABLE PASS checks=" .. checks)
