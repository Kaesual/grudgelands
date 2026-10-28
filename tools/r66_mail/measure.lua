-- Round 66 lane MAIL measurement (LuaJIT; not a fixture): the size of a
-- player's sent list at the cap and the storage cost a send adds.
--
--   luajit tools/r66_mail/measure.lua [REPO] [LUANTI_SOURCE]
--
-- Loads the REAL grug_mail model and store with the engine's own
-- core.serialize / core.deserialize (builtin/common/serialize.lua of
-- LUANTI_SOURCE, default REPO/reference_projects/luanti) on an in-memory
-- mod storage. A send's storage work is timed without and with the sent
-- copy: "before" reads the recipient's box twice and writes it once (as
-- grug_mail.send_letter does), "after" also reads, extends and writes the
-- sender's sent list. Money and the attachment slots cost the same in both
-- and are left out. Numbers are comparisons on this machine, not targets.

local ROOT = arg and arg[1] or "."
local LUANTI = arg and arg[2] or (ROOT .. "/reference_projects/luanti")

local mod_storage = {}
local Storage = {}
Storage.__index = Storage
function Storage:get_string(key) return mod_storage[key] or "" end
function Storage:set_string(key, value) mod_storage[key] = value ~= "" and value or nil end
function Storage:get_int(key) return tonumber(mod_storage[key]) or 0 end
function Storage:set_int(key, value) mod_storage[key] = tostring(value) end

core = {get_mod_storage = function() return setmetatable({}, Storage) end,
	log = function(_, text) print(text) end}
dofile(LUANTI .. "/builtin/common/serialize.lua")

local clock = 1800000000
os.time = function() return clock end
grug_mail = {}
local M = dofile(ROOT .. "/mods/PLAYER/grug_mail/model.lua")
grug_mail.model = M
local S = dofile(ROOT .. "/mods/PLAYER/grug_mail/store.lua")

local NAMES = {"Masterwork Bronze Battle Axe", "Iron Ingot x99", "Bag of Coins",
	"Linen Scrap x99"}
local ITEMS = {"grug_gear:battle_axe_bronze 1 0", "grug_materials:iron_bar 99",
	"grug_money:bag_of_coins 1 0", "grug_materials:linen_scrap 99"}

-- Distinct texts: the engine's serializer stores a repeated string once.
local serial = 0
local function text(char, count)
	serial = serial + 1
	return serial .. string.rep(char, count - #tostring(serial))
end

-- A full sent list: 50 copies at the subject and body limits, four names.
local function full_sent(char)
	local list = {}
	for id = 1, M.SENT_LIMIT do
		M.keep_sent(list, M.sent_copy(id, "Brakkathorn", text("s", M.SUBJECT_MAX),
			text(char, M.BODY_MAX), M.postage(4), NAMES, clock))
	end
	return list
end

-- A box with `count` player letters at the limits, four stacks each.
local function full_box(count)
	local box = M.new_box()
	for id = 1, count do
		M.deliver(box, M.letter(1000 + id, "player", "Alicewright", text("s", M.SUBJECT_MAX),
			text("x", M.BODY_MAX), ITEMS, clock))
	end
	return box
end

print("Sent list at the cap (50 copies, 60-character subject, 4,000-character body, four names):")
for _, case in ipairs({{"ASCII body", "x"}, {"two-byte body (ä)", "ä"}, {"three-byte body (€)", "€"}}) do
	S.save_sent("Alice", full_sent(case[2]))
	print(("  %-20s %8.1f KB serialised"):format(case[1], #mod_storage["sent:Alice"] / 1024))
end
S.save_box("Brakka", full_box(50))
print(("  for comparison: a box of 50 player letters at the same limits %.1f KB"):format(
	#mod_storage["box:Brakka"] / 1024))

local function send_storage(with_copy, id)
	local box = S.box("Brakka")
	box = S.box("Brakka")
	M.deliver(box, M.letter(id, "player", "Alice", "Subject", text("x", M.BODY_MAX), ITEMS, clock))
	S.save_box("Brakka", box)
	if with_copy then
		local sent = S.sent("Alice")
		M.keep_sent(sent, M.sent_copy(id, "Brakka", "Subject", text("x", M.BODY_MAX),
			M.postage(4), NAMES, clock))
		S.save_sent("Alice", sent)
	end
	-- Keep the box at its size so every round costs the same.
	box = S.box("Brakka")
	table.remove(box.letters, 1)
	S.save_box("Brakka", box)
end

local function time(rounds, func)
	local started = os.clock()
	for round = 1, rounds do func(round) end
	return (os.clock() - started) / rounds * 1000
end

print("Storage work per send (ms, mean of the rounds; the box restore is in both):")
for _, case in ipairs({
	{"empty box, sent list from 0", 0, false},
	{"49-letter box, sent list from 0", 49, false},
	{"49-letter box, full sent list", 49, true},
}) do
	local rounds = 40
	S.save_box("Brakka", full_box(case[2]))
	S.save_sent("Alice", case[3] and full_sent("x") or {})
	local before = time(rounds, function(round) send_storage(false, 5000 + round) end)
	S.save_sent("Alice", case[3] and full_sent("x") or {})
	local after = time(rounds, function(round) send_storage(true, 6000 + round) end)
	print(("  %-32s before %7.2f  after %7.2f  (+%.2f)"):format(case[1], before, after,
		after - before))
end
