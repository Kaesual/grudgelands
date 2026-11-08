-- The Expedition catalogue (Round 71): the one place for the slots, the box,
-- the step size and the Expeditions. Pure: no engine calls, so
-- tools/r71_frame/portable_test.lua runs it as it ships. The measured numbers
-- come from lane SPIKE (a box of 256 mapblocks, 12 s to prepare, one at a time).
local M = {}

-- 100 equal slots on one grid, far beyond the map and below the seabed (y -23):
-- box x and z 128, y 64, mapblock aligned, a pitch of 320 so a gap of 192 clears
-- active blocks, sending, mob sight and sound. Slot `i + 10 j + 1`, i, j 0..9.
M.BOX = {x = 128, y = 64, z = 128}
M.ORIGIN = {x = 8064, y = -112, z = -1616}
M.PITCH = 320
M.GRID = 10
M.SLOTS = M.GRID * M.GRID

-- Mapblocks one preparation writes per server step: a count, never a clock.
M.BLOCKS_PER_STEP = 4
-- Generation asks the area round the box, one chunk at a time.
M.EMERGE_MARGIN = 16
-- The solid node of the clearing pass, also what a small template leaves round
-- itself.
M.CLEAR_NODE = "default:stone"

-- The hard ceiling of the entry level, whatever the Expedition's level.
M.ENTRY_CEILING = 60
-- With nobody of the owner inside, an Expedition is released after this long.
M.RESERVE_SECONDS = 600

-- One row per Expedition: `id`, `name` (shown to players), `level` and `max_level`
-- (the mob levels a creator may choose, concept section 9), `max_players` (the most
-- players inside), `template` (a file in templates/, without its extension).
-- `hidden` rows exist for tests: list() leaves them out, so no dialog offers them,
-- and create() still takes them.
M.EXPEDITIONS = {
	{id = "test_vault", name = "Test Vault", level = 20, max_level = 29, max_players = 3,
		template = "test_vault", hidden = true},
	{id = "stilled_seam", name = "The Stilled Seam", level = 20, max_level = 69, max_players = 3,
		template = "stilled_seam"},
	-- Round 72 SHIFT: the level 40-69 Expedition for four (round72-second-shift.md). `signs`:
	-- the text of a wall sign at a template place, written when the run is ready.
	{id = "second_shift", name = "The Second Shift", level = 40, max_level = 69, max_players = 4,
		template = "second_shift", signs = {shift_board = "SECOND SHIFT\nSAME NAMES\nSTILL DUE"}},
}

-- Every 10 levels the tier follows (concept section 9): the ore and gem nodes, the
-- chest's materials (loot.lua) and the item level. The ore is what the tier's rock
-- is mined for, the next metal's input (items_crafting.md section 3.0.1; T2's
-- Anthracite, the Steel input, user 2026-11-07). A template is written with the T2
-- nodes; a run of another tier writes its own in their places (swaps).
M.TEMPLATE_ORE, M.TEMPLATE_GEM = "grug_materials:stone_with_anthracite", "grug_materials:stone_with_jade"
M.TIERS = {
	{tier = 2, min_level = 20, max_level = 29,
		ore = "grug_materials:stone_with_anthracite", gem = "grug_materials:stone_with_jade"},
	{tier = 3, min_level = 30, max_level = 39,
		ore = "grug_materials:stone_with_silver", gem = "grug_materials:stone_with_garnet"},
	{tier = 4, min_level = 40, max_level = 49,
		ore = "grug_materials:stone_with_emberglass", gem = "grug_materials:stone_with_sapphire"},
	{tier = 5, min_level = 50, max_level = 59,
		ore = "grug_materials:abyssal_crystal_ore", gem = "grug_materials:stone_with_ruby"},
	{tier = 6, min_level = 60, max_level = 69,
		ore = "grug_materials:abyssal_crystal_ore", gem = "grug_materials:stone_with_diamond"},
}

-- The tier row of a run level; a level outside the table takes the nearest row.
function M.tier_of(level)
	for _, row in ipairs(M.TIERS) do
		if level <= row.max_level then return row end
	end
	return M.TIERS[#M.TIERS]
end

-- Per tier, the template's nodes a run of that tier writes as others:
-- {[tier] = {[template node] = the tier's node}}; T2's is empty.
function M.swaps()
	local out = {}
	for _, row in ipairs(M.TIERS) do
		local swap = {}
		if row.ore ~= M.TEMPLATE_ORE then swap[M.TEMPLATE_ORE] = row.ore end
		if row.gem ~= M.TEMPLATE_GEM then swap[M.TEMPLATE_GEM] = row.gem end
		out[row.tier] = swap
	end
	return out
end

local by_id = {}
for _, row in ipairs(M.EXPEDITIONS) do by_id[row.id] = row end

function M.definition(id)
	return by_id[id]
end

-- The rows a player can be offered, in catalogue order.
function M.list()
	local rows = {}
	for _, row in ipairs(M.EXPEDITIONS) do
		if not row.hidden then rows[#rows + 1] = row end
	end
	return rows
end

-- Expedition level minus 2, at most 60: 60 needs 58, 61 needs 59, 62-69 need 60.
function M.entry_level(level)
	return math.min(level - 2, M.ENTRY_CEILING)
end

-- A slot's box, both corners inclusive, as new tables.
function M.slot_box(index)
	local at = index - 1
	local i, j = at % M.GRID, math.floor(at / M.GRID)
	local minp = {x = M.ORIGIN.x + M.PITCH * i, y = M.ORIGIN.y, z = M.ORIGIN.z + M.PITCH * j}
	return minp, {x = minp.x + M.BOX.x - 1, y = minp.y + M.BOX.y - 1, z = minp.z + M.BOX.z - 1}
end

-- chunksize 5 (minetest.conf): a mapchunk is 80 nodes, its corner at 80 k - 32.
local CHUNK = 80
local function chunk_index(v) return math.floor((v + 32) / CHUNK) end

-- The chunks a preparation generates, as the node at each one's centre: every chunk
-- of the box and its margin. The preparation's header says why centres matter.
function M.chunks_of(slot)
	local minp, maxp = M.slot_box(slot)
	local margin, list = M.EMERGE_MARGIN, {}
	for kz = chunk_index(minp.z - margin), chunk_index(maxp.z + margin) do
		for ky = chunk_index(minp.y - margin), chunk_index(maxp.y + margin) do
			for kx = chunk_index(minp.x - margin), chunk_index(maxp.x + margin) do
				list[#list + 1] = {x = CHUNK * kx + 8, y = CHUNK * ky + 8, z = CHUNK * kz + 8}
			end
		end
	end
	return list
end

-- The slot whose box holds `pos`, or nil: arithmetic only, safe for hot paths.
-- A float position counts by the node it rounds to.
function M.slot_at(pos)
	local y = math.floor(pos.y + 0.5) - M.ORIGIN.y
	if y < 0 or y >= M.BOX.y then return nil end
	local dx = math.floor(pos.x + 0.5) - M.ORIGIN.x
	local dz = math.floor(pos.z + 0.5) - M.ORIGIN.z
	if dx < 0 or dz < 0 then return nil end
	local i, j = math.floor(dx / M.PITCH), math.floor(dz / M.PITCH)
	if i >= M.GRID or j >= M.GRID then return nil end
	if dx % M.PITCH >= M.BOX.x or dz % M.PITCH >= M.BOX.z then return nil end
	return i + M.GRID * j + 1
end

return M
