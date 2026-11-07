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

-- The creator's choice on top of an Expedition's level: +0 to +9.
M.MAX_BONUS = 9
-- The hard ceiling of the entry level, whatever the Expedition's level.
M.ENTRY_CEILING = 60
-- With nobody of the owner inside, an Expedition is released after this long.
M.RESERVE_SECONDS = 600

-- One row per Expedition: `id`, `name` (shown to players), `level`, `max_players`
-- (the most players inside), `template` (a file in templates/, without its
-- extension). `hidden` rows exist for tests: list() leaves them out, so no
-- dialog offers them, and create() still takes them.
M.EXPEDITIONS = {
	{id = "test_vault", name = "Test Vault", level = 20, max_players = 3,
		template = "test_vault", hidden = true},
}

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
