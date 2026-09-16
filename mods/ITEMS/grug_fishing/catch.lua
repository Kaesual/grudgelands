--
-- WHAT THE WATER GIVES BACK, and how long it takes -- the whole of it, in
-- plain Lua with no engine in sight, so that `tools/wp13/fishing_kat.lua` can
-- load this very file and check the real numbers rather than a copy of them.
--
-- ONE TABLE FOR THE WHOLE WORLD (playtest round 5, 2026-09-16): "Fish
-- availability shall be IDENTICAL on both continents (distributed over the
-- zones)". Per-zone loot tables are explicitly LATER work, so what exists
-- today is one table and one seam -- `table_for(pos)` -- for the lane that
-- adds them. A second table that happened to be a copy of this one would be
-- the same promise with two places to break it.
--
-- WEIGHTS ARE PERCENT. They sum to 100 on purpose: `catch_at` walks the list
-- in order, so a reader can see "78 % fish" without doing arithmetic, and the
-- fixture asserts the sum.
--

-- The fish is `grug_mobs:raw_fish`, which the game already has: the Mirefolk
-- drop it (grug_mobs/items.lua), the traders already price it at 2c and
-- `items_crafting.md` §2.3's cooking ladder already calls the T1 dish "Cooked
-- Fish". Fishing is a second SOURCE for an existing item, not a second fish.
--
-- The junk exists too, and deliberately costs the design nothing: a snagged
-- branch and a clump of waterweed, both `default` items with no vendor price
-- and no recipe that fishing could shortcut. NOT `grug_gathering:stormkelp` --
-- that is the front-only T5 cooking gate (`items_crafting.md` §2.3), and a
-- world-wide fishing source for it would hand every pond the ingredient the
-- design puts on the contested front.
local WORLD = {
	{name = "grug_mobs:raw_fish", count = 1, weight = 78},
	{name = "default:stick", count = 1, weight = 12},
	{name = "default:papyrus", count = 1, weight = 10},
}

local TOTAL = 0
for _, entry in ipairs(WORLD) do
	TOTAL = TOTAL + entry.weight
end

grug_fishing.WORLD_CATCH = WORLD
grug_fishing.CATCH_TOTAL = TOTAL

-- THE SEAM the later per-zone tables hook into. It takes the position because
-- that is what a zone lookup will need, and it returns the one table there is.
-- Callers must go through it; nothing outside this file may name `WORLD`.
function grug_fishing.table_for(pos)
	return WORLD
end

-- `roll` is an integer in 0 .. TOTAL-1 (the engine draws it from PcgRandom,
-- the fixture enumerates every value). Returns the entry, never nil for a roll
-- in range: the last entry catches any rounding at the top.
function grug_fishing.catch_at(catch_table, roll)
	local seen = 0
	for _, entry in ipairs(catch_table) do
		seen = seen + entry.weight
		if roll < seen then
			return entry
		end
	end
	return catch_table[#catch_table]
end

-- HOW LONG THE FLOAT SITS THERE. A bite is not instant and not predictable;
-- both ends are here and nowhere else. `roll` is an integer in 0 .. SPREAD,
-- so the engine can draw it from the same PcgRandom as the catch and the
-- fixture can enumerate it.
local MIN_WAIT = 3
local WAIT_SPREAD = 7 -- so the longest wait is 10 s

grug_fishing.MIN_WAIT = MIN_WAIT
grug_fishing.MAX_WAIT = MIN_WAIT + WAIT_SPREAD
grug_fishing.WAIT_SPREAD = WAIT_SPREAD

function grug_fishing.wait_for(roll)
	if roll < 0 then
		roll = 0
	elseif roll > WAIT_SPREAD then
		roll = WAIT_SPREAD
	end
	return MIN_WAIT + roll
end
