-- /prof portable test (after Round 55: the professions debug command,
-- grug_jobs/admin.lua and state.lua's admin_set/admin_unlearn). Loads the
-- REAL registry.lua, state.lua and admin.lua under small stubs and checks:
--   A. the command: `server` privilege, online targets only, the usage;
--   B. set: a primary into a slot at a tier, capped at the character's band
--      with the eligibility note, the primary it replaces dropped as by
--      unlearn (job XP forfeited, target slot returned), one in the other
--      slot refused, a secondary without a slot, bad slots/tiers/names;
--   C. learn and unlearn: the first free slot, both slots taken, an already
--      known profession, a secondary unlearned (the trainer never can);
--      clear empties a slot;
--   D. show, the target's chat line (none for oneself) and the action log.
--
-- Usage (repo root): luajit tools/r55_prof/portable_test.lua [REPO]

grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local repo = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function has(text, needle, label)
	return check(type(text) == "string" and text:find(needle, 1, true) ~= nil,
		label .. " (" .. tostring(text) .. ")")
end

local commands, online, chat, logs = {}, {}, {}, {}
local forfeited, returned, refreshed = {}, 0, 0
_G.core = {
	registered_items = {},
	get_item_group = function() return 0 end,
	get_all_craft_recipes = function() return nil end,
	chat_send_player = function(name, text)
		chat[name] = chat[name] or {}
		chat[name][#chat[name] + 1] = text
	end,
	log = function(level, text) logs[#logs + 1] = level .. " " .. text end,
	register_on_mods_loaded = function() end,
	register_chatcommand = function(name, def) commands[name] = def end,
	get_player_by_name = function(name) return online[name] end,
}
local levels = {}
_G.grug_xp = {get_level = function(player) return levels[player:get_player_name()] or 1 end}
_G.grug_inventory = {refresh = function() refreshed = refreshed + 1 end}

_G.grug_jobs = {}
dofile(repo .. "/mods/PLAYER/grug_jobs/registry.lua")
dofile(repo .. "/mods/PLAYER/grug_jobs/state.lua")
grug_jobs.forfeit_job_xp = function(_, profession) forfeited[#forfeited + 1] = profession end
grug_jobs.return_operation_target = function() returned = returned + 1 end
dofile(repo .. "/mods/PLAYER/grug_jobs/admin.lua")
local J = grug_jobs

local function make_player(name, level)
	local store = {}
	local meta = {}
	function meta:get_string(key) return store[key] or "" end
	function meta:set_string(key, value) store[key] = value end
	function meta:get_int(key) return tonumber(store[key]) or 0 end
	function meta:set_int(key, value) store[key] = value end
	local player = {get_meta = function() return meta end,
		get_player_name = function() return name end, store = store}
	online[name], levels[name] = player, level
	return player
end

local prof = commands.prof
local function run(param, by) return prof.func(by or "admin", param) end
local function last_chat(name) local list = chat[name] or {} return list[#list] end

-- ---------------------------------------------------------------------------
-- A. The command.
-- ---------------------------------------------------------------------------
check(prof ~= nil, "A /prof is registered")
eq(prof.privs and prof.privs.server, true, "A /prof needs the server privilege")
make_player("admin", 60)
local ok, text = run("")
check(not ok, "A no arguments is refused")
has(text, "Usage: /prof", "A the usage")
ok, text = run("ghost")
check(not ok, "A an offline player cannot be shown")
has(text, "not online: ghost", "A names the offline player")
ok, text = run("set ghost 1 weaponsmith 3")
check(not ok, "A an offline target is refused")
ok, text = run("set")
check(not ok, "A an action alone is refused")
has(text, "Usage: /prof", "A ... with the usage, not as a player name")
ok, text = run("bogus admin 1")
check(not ok, "A an unknown action is refused")
has(text, "Usage: /prof", "A the usage after an unknown action")

-- ---------------------------------------------------------------------------
-- B. set.
-- ---------------------------------------------------------------------------
local low = make_player("low", 12)
ok, text = run("set low 1 weaponsmith T6")
check(ok, "B a primary into slot 1")
eq(J.primary_at(low, 1), "weaponsmith", "B slot 1 holds the Weaponsmith")
eq(J.profession_level(low, "weaponsmith"), 2, "B T6 asked at level 12 gives T2")
eq(low.store["grug_jobs:level:weaponsmith"], 2, "B the stored tier is the capped one")
has(text, "set slot 1 to Weaponsmith T2", "B the admin's result")
has(text, "only eligible for T2 (character level 12)", "B the eligibility note")
eq(last_chat("low"), "An admin set slot 1 to Weaponsmith tier 2.", "B the target's line")
eq(J.crafts_in_tier(low, "weaponsmith"), 0, "B the tier's crafts start at 0")

local high = make_player("high", 55)
ok, text = run("set high 2 armorsmith 6")
check(ok, "B T6 at level 55")
eq(J.profession_level(high, "armorsmith"), 6, "B level 55 is eligible for T6")
check(not text:find("eligible", 1, true), "B no note without a cap")
eq(J.primary_at(high, 1), nil, "B slot 1 stays empty")

-- A tier change in place keeps the profession and resets the crafts.
high.store["grug_jobs:crafts:armorsmith"] = 7
forfeited, returned = {}, 0
ok = run("set high 2 armorsmith 3")
check(ok, "B a tier change in place")
eq(J.profession_level(high, "armorsmith"), 3, "B the tier went down to 3")
eq(J.crafts_in_tier(high, "armorsmith"), 0, "B the crafts reset")
eq(#forfeited, 0, "B nothing is dropped for the same profession")
check(not select(2, run("set high 2 armorsmith 3")):find("replaced", 1, true),
	"B no replaced note for the same profession")

-- Replacing a primary drops it as unlearn does.
high.store["grug_jobs:crafts:armorsmith"] = 5
ok, text = run("set high 2 tailor 4")
check(ok, "B a primary replaces another")
has(text, "set slot 2 to Tailor T4 (replaced Armorsmith; its progression was lost).",
	"B the admin hears what was replaced")
eq(last_chat("high"), "An admin set slot 2 to Tailor tier 4 (replaced Armorsmith; " ..
	"its progression was lost).", "B so does the target")
eq(J.primary_at(high, 2), "tailor", "B slot 2 holds the Tailor")
check(not J.has(high, "armorsmith"), "B the Armorsmith is gone")
eq(high.store["grug_jobs:level:armorsmith"], 0, "B its tier is gone")
eq(high.store["grug_jobs:crafts:armorsmith"], 0, "B its crafts are gone")
eq(forfeited[1], "armorsmith", "B its running job forfeits its XP")
eq(returned, 1, "B the enchant/upgrade slot item comes back")

ok, text = run("set high 1 tailor 2")
check(not ok, "B the profession in the other slot is refused")
has(text, "already in slot 2", "B names the other slot")
eq(J.primary_at(high, 1), nil, "B slot 1 unchanged after the refusal")

ok, text = run("set high 3 goldsmith 2")
check(not ok, "B slot 3 is refused")
has(text, "Slot must be 1 or 2", "B the slot message")
ok, text = run("set high 1 goldsmith 7")
check(not ok, "B tier 7 is refused")
has(text, "Tier must be 1 to 6", "B the tier message")
ok, text = run("set high 1 goldsmith 0")
check(not ok, "B tier 0 is refused")
ok, text = run("set high 1 bogus 2")
check(not ok, "B an unknown profession is refused")
has(text, "Unknown profession", "B the profession message")
ok, text = run("set high 1 T3")
check(not ok, "B a slot without a profession is refused")
has(text, "Usage: /prof", "B ... with the usage")
ok, text = run("set high weaponsmith 2")
check(not ok, "B a primary without a slot is refused")
has(text, "slot 1 or 2", "B says the primary needs a slot")

ok, text = run("set high cooking 5")
check(ok, "B a secondary takes no slot")
eq(J.profession_level(high, "cooking"), 5, "B Cooking T5")
has(text, "high: set Cooking T5.", "B the secondary's result")
eq(last_chat("high"), "An admin set Cooking to tier 5.", "B the secondary's line")
ok = run("set low Alchemy T6")
check(ok, "B a secondary by its name")
eq(J.profession_level(low, "alchemist"), 2, "B Alchemy capped at T2 for level 12")
ok, text = run("set high 1 cooking 2")
check(not ok, "B a secondary with a slot is refused")
has(text, "takes no slot", "B the secondary message")

-- ---------------------------------------------------------------------------
-- C. learn, unlearn, clear.
-- ---------------------------------------------------------------------------
local fresh = make_player("fresh", 25)
ok, text = run("learn fresh goldsmith")
check(ok, "C learn a primary without a tier")
eq(J.primary_at(fresh, 1), "goldsmith", "C into the first free slot")
eq(J.profession_level(fresh, "goldsmith"), 1, "C at T1")
ok, text = run("learn fresh woodcarver 6")
check(ok, "C learn a primary at a tier")
eq(J.primary_at(fresh, 2), "woodcarver", "C into the second slot")
eq(J.profession_level(fresh, "woodcarver"), 3, "C capped at T3 for level 25")
has(text, "only eligible for T3", "C the eligibility note")
eq(last_chat("fresh"), "An admin taught you Woodcarver (tier 3).", "C the target's line")
ok, text = run("learn fresh leatherworker")
check(not ok, "C both slots taken")
has(text, "both primary slots taken", "C the message")
ok, text = run("learn fresh goldsmith 2")
check(not ok, "C an already known profession")
has(text, "use /prof set", "C points to set")
ok = run("learn fresh alchemist 2")
check(ok, "C learn a secondary")
check(J.has(fresh, "alchemist"), "C Alchemy learned")

forfeited, returned = {}, 0
ok, text = run("unlearn fresh alchemist")
check(ok, "C a secondary can be unlearned by the command")
check(not J.has(fresh, "alchemist"), "C Alchemy is gone")
eq(fresh.store["grug_jobs:level:alchemist"], 0, "C its tier is gone")
eq(forfeited[1], "alchemist", "C its running job forfeits its XP")
ok = run("learn fresh cooking")
ok, text = run("unlearn fresh cooking")
check(ok, "C Cooking can be unlearned by the command")
has(text, "learned again at the next join", "C the Cooking note")
ok, text = run("unlearn fresh alchemist")
check(not ok, "C an unknown profession cannot be unlearned")
has(text, "does not know Alchemy", "C the message")
eq(J.unlearn(fresh, "goldsmith"), true, "C the trainer's unlearn still works")
eq(J.primary_at(fresh, 1), nil, "C ... and empties slot 1")
eq(fresh.store["grug_jobs:level:goldsmith"], 0, "C ... and drops the tier")

ok, text = run("clear fresh 2")
check(ok, "C clear slot 2")
has(text, "cleared slot 2 (Woodcarver)", "C the message")
eq(J.primary_at(fresh, 2), nil, "C slot 2 is empty")
eq(last_chat("fresh"), "An admin removed Woodcarver; its progression was lost.",
	"C the target's line")
ok, text = run("clear fresh 2")
check(not ok, "C an empty slot cannot be cleared")
has(text, "slot 2 is empty", "C the message")

-- ---------------------------------------------------------------------------
-- D. show, the target's line and the log.
-- ---------------------------------------------------------------------------
low.store["grug_jobs:crafts:weaponsmith"] = 4
ok, text = run("low")
check(ok, "D show")
eq(text, "low, character level 12 (eligible up to T2): slot 1 Weaponsmith T2 " ..
	"(crafts 4/15), slot 2 empty, Cooking not learned, Alchemy T2 (crafts 0/15).",
	"D the line")
ok, text = run("high")
has(text, "Cooking T5 (crafts 0/30)", "D a secondary's progress")
run("set high 1 weaponsmith 6")
has(select(2, run("high")), "Weaponsmith T6 (crafts max)", "D the last tier")

local before = #(chat.admin or {})
ok = run("set admin 1 weaponsmith 6", "admin")
check(ok, "D the admin sets their own slot")
eq(#(chat.admin or {}), before, "D no extra line for oneself")
has(logs[#logs], "action [grug_jobs] admin ran /prof set admin 1 weaponsmith 6",
	"D the action log")
local count = #logs
run("set admin 1 weaponsmith 9")
eq(#logs, count, "D a refused call is not logged")
check(refreshed > 0, "D the Crafting tab is refreshed")

local summary = ("R55 PROF PORTABLE %s checks=%d failures=%d"):format(
	failures == 0 and "PASS" or "FAIL", checks, failures)
print(summary)
if failures > 0 then os.exit(1) end
