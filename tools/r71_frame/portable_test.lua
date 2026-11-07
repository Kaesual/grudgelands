-- Round 71 lane FRAME portable test (LuaJIT): the Expedition catalogue and the
-- template reader as they ship. Prints "R71 FRAME PORTABLE PASS checks=<n>".
--
--   luajit tools/r71_frame/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local C = dofile(repo .. "/mods/PLAYER/grug_expeditions/catalogue.lua")

-- A. Slots: 100, mapblock aligned, apart, found again by arithmetic.
check(C.SLOTS == 100, "A 100 slots")
local minp, maxp = C.slot_box(1)
check(minp.x == 8064 and minp.y == -112 and minp.z == -1616, "A the first corner")
check(maxp.x == 8191 and maxp.y == -49 and maxp.z == -1489, "A the first box is 128 x 64 x 128")
minp, maxp = C.slot_box(100)
check(minp.x == 8064 + 320 * 9 and minp.z == -1616 + 320 * 9, "A the last corner")
for slot = 1, C.SLOTS do
	local a, b = C.slot_box(slot)
	check(a.x % 16 == 0 and a.y % 16 == 0 and a.z % 16 == 0, "A aligned " .. slot)
	check(C.slot_at(a) == slot and C.slot_at(b) == slot, "A corners of " .. slot)
	check(C.slot_at({x = a.x + 0.4, y = a.y + 3.2, z = b.z}) == slot, "A a float position")
	check(not C.slot_at({x = a.x - 1, y = a.y, z = a.z}), "A west of " .. slot)
	check(not C.slot_at({x = b.x + 1, y = a.y, z = a.z}), "A east of " .. slot)
	check(not C.slot_at({x = a.x, y = a.y - 1, z = a.z}), "A below " .. slot)
	check(not C.slot_at({x = a.x, y = b.y + 1, z = a.z}), "A above " .. slot)
	check(not C.slot_at({x = a.x, y = a.y, z = b.z + 1}), "A north of " .. slot)
end
check(not C.slot_at({x = 0, y = -80, z = 0}), "A the map holds no slot")
check(not C.slot_at({x = 8064 + 3200, y = -80, z = -1616}), "A beyond the grid")

-- B. The entry level.
check(C.entry_level(20) == 18 and C.entry_level(21) == 19 and C.entry_level(22) == 20, "B below 60")
check(C.entry_level(60) == 58 and C.entry_level(61) == 59, "B 60 and 61")
for level = 62, 69 do check(C.entry_level(level) == 60, "B the ceiling at " .. level) end

-- C. The catalogue's rows.
for _, row in ipairs(C.EXPEDITIONS) do
	check(row.id and row.name and row.level and row.max_players and row.template, "C row " .. row.id)
end
check(C.definition("test_vault").max_players == 3, "C the test row")
for _, row in ipairs(C.list()) do check(not row.hidden, "C list leaves hidden rows out") end

-- D. The template reader, on the shipped test template through zlib.
local T = dofile(repo .. "/mods/PLAYER/grug_expeditions/template.lua")
local ffi = require("ffi")
ffi.cdef[[int uncompress(uint8_t *dest, unsigned long *destLen, const uint8_t *src, unsigned long srcLen);]]
local zlib = ffi.load("z")
local function inflate(bytes)
	local out, size = ffi.new("uint8_t[?]", 4194304), ffi.new("unsigned long[1]", 4194304)
	assert(zlib.uncompress(out, size, bytes, #bytes) == 0)
	return ffi.string(out, size[0])
end
local file = assert(io.open(repo .. "/mods/PLAYER/grug_expeditions/templates/test_vault.exp", "rb"))
local text = file:read("*a")
file:close()
local tpl = T.parse(text, inflate, "test_vault")
T.check_fits(tpl, C.BOX, {"arrival", "start_waystone", "end_waystone"}, "test_vault")
check(tpl.name == "test_vault" and tpl.size.x == 48 and tpl.size.y == 32 and tpl.size.z == 48, "D the head")
check(tpl.places.start_waystone.x == 8 and #tpl.encounters == 2, "D places and markers")
check(tpl.encounters[1].mob == "grug_mobs:giant_spider" and tpl.encounters[1].count == 2 and
	tpl.encounters[2].tier == "elite" and tpl.encounters[2].room == "hall", "D a marker's fields")
local function cell(pos)
	local at = pos.z * tpl.size.y * tpl.size.x + pos.y * tpl.size.x + pos.x + 1
	return tpl.nodes[tpl.cells:byte(at) + 1]
end
check(cell(tpl.places.start_waystone) == "grug_expeditions:waystone", "D the stone's cell")
check(cell(tpl.places.arrival) == "air" and cell({x = 0, y = 0, z = 0}) == "default:stonebrick", "D cells")

local function refused(head, needle)
	local ok, message = pcall(T.parse, head, inflate, "bad")
	check(not ok and message:find(needle, 1, true), "D refused: " .. needle .. " got " .. tostring(message))
end
refused("nonsense\n", "not a version 1")
refused("grudgelands-expedition-template 1\nname x\n", "data line")
refused("grudgelands-expedition-template 1\nsize 1 2\ndata 0\n", "malformed")
refused("grudgelands-expedition-template 1\ndata 9\nabc", "cut short")
local big = {size = {x = 144, y = 16, z = 16}, places = {}, encounters = {}}
check(not pcall(T.check_fits, big, C.BOX, {}, "big"), "D too wide")
big.size = {x = 20, y = 16, z = 16}
check(not pcall(T.check_fits, big, C.BOX, {}, "big"), "D not on mapblocks")
big.size = {x = 16, y = 16, z = 16}
check(not pcall(T.check_fits, big, C.BOX, {"arrival"}, "big"), "D a required place")

print("R71 FRAME PORTABLE PASS checks=" .. checks)
