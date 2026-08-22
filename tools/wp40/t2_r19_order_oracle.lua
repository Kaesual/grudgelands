-- WP40 T2 independent C2 comparator for the R19 completion-multiplicity
-- order (wp40-t2-plan.md section 7.1, wp40-t2-contracts.md sections 12.5 and
-- 13).
--
-- This is the C2 oracle's OWN reading of the declared order, extracted from
-- t2_partition_test.lua so that the synthetic KATs
-- (tools/wp40/t2_correction_kat_test.lua) can drive it beside the two
-- production comparators of geometry/partition.lua -- the live three-way
-- cross-check that contracts 13.4 requires in place of the retired keys-4/5
-- tripwire.  Its semantics are unchanged by that extraction: it implements
-- the authority, not whatever a compiler happens to do, and it is the
-- authority reproduction against which production was aligned.
--
-- Keys 4 and 5 are the declared "lexicographic by (x, z)" over the coordinate
-- tuples -- signed integers, never a rendering of them.  Key 6 is the
-- declared probe BYTE sequence under canonical orientation, already compared
-- as bytes by its caller.  The two are deliberately different comparisons.
--
-- The comparator consumes tuples carrying:
--   total_retreat, max_retreat, elbow_count  -- non-negative integers
--   terminals, previouses                    -- arrays of {x = ..., z = ...},
--                                               already sorted by point_less
--   canonical                                -- the canonical probe bytes
--
-- Pure and dependency-free: dofile returns the table directly.
local oracle = {}

local function point_less(a, b)
	return a.x < b.x or a.x == b.x and a.z < b.z
end

local function sequence_less(a, b)
	for index = 1, math.min(#a, #b) do
		if point_less(a[index], b[index]) then return true end
		if point_less(b[index], a[index]) then return false end
	end
	return #a < #b
end

local function sequence_equal(a, b)
	if #a ~= #b then return false end
	for index = 1, #a do
		if a[index].x ~= b[index].x or a[index].z ~= b[index].z then return false end
	end
	return true
end

-- The first key of the section 7.1 order at which the two tuples differ, or 0
-- when they are equal under all six -- which is duplicate authority and is
-- rejected before the order applies.
local function first_difference(a, b)
	if a.total_retreat ~= b.total_retreat then return 1 end
	if a.max_retreat ~= b.max_retreat then return 2 end
	if a.elbow_count ~= b.elbow_count then return 3 end
	if not sequence_equal(a.terminals, b.terminals) then return 4 end
	if not sequence_equal(a.previouses, b.previouses) then return 5 end
	if a.canonical ~= b.canonical then return 6 end
	return 0
end

local function less(a, b)
	local key = first_difference(a, b)
	if key == 1 then return a.total_retreat < b.total_retreat end
	if key == 2 then return a.max_retreat < b.max_retreat end
	if key == 3 then return a.elbow_count < b.elbow_count end
	if key == 4 then return sequence_less(a.terminals, b.terminals) end
	if key == 5 then return sequence_less(a.previouses, b.previouses) end
	if key == 6 then return a.canonical < b.canonical end
	return false
end

oracle.point_less = point_less
oracle.sequence_less = sequence_less
oracle.sequence_equal = sequence_equal
oracle.first_difference = first_difference
oracle.less = less
return oracle
