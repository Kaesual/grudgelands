-- WP13 roofs: height fields plus one rasteriser that turns any height field
-- into stair, outer stair, inner stair and slab cells.
--
-- A roof is described by a height function h(x, z) over the roof footprint
-- (the building footprint grown by the eave overhang). The rasteriser then
-- decides, per cell, which of the four quarters of that node are raised: a
-- quarter is raised when either of the two orthogonal neighbours that flank
-- it, or the diagonal neighbour in that quarter, is higher. One raised
-- quarter is an outer corner, two adjacent ones a straight stair, three an
-- inner corner (a valley) and zero or four a flat cap. That single rule
-- produces correct gable, hip, saltbox, lean-to and L-shaped roofs.
--
-- The lowest course sits at the eave height, level with the top wall course,
-- so the wall meets the roof with no gap; one node inward the roof is one
-- node higher and passes over the wall top.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local M = {}

local QUARTERS = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

-- Raised quarter of an outer stair, by param2.
local OUTER_PARAM2 = {["-1,1"] = 0, ["1,1"] = 1, ["1,-1"] = 2, ["-1,-1"] = 3}
-- Low quarter of an inner stair, by param2.
local INNER_PARAM2 = {["1,-1"] = 0, ["-1,-1"] = 1, ["-1,1"] = 2, ["1,1"] = 3}

function M.raster(buf, palette, field)
	local x0, x1 = field.x0, field.x1
	local z0, z1 = field.z0, field.z1
	local height = field.height
	local level = {}
	for z = z0, z1 do
		for x = x0, x1 do
			local y = height(x, z)
			if y then level[x .. ":" .. z] = y end
		end
	end
	local function at(x, z) return level[x .. ":" .. z] end
	local stair = palette.node("roof_stair")
	local outer = palette.node("roof_stair_outer")
	local inner = palette.node("roof_stair_inner")
	local slab = palette.node("roof_slab")
	local ridge = palette.node("roof_ridge")
	local top = nil
	for z = z0, z1 do
		for x = x0, x1 do
			local y = at(x, z)
			if y then
				if top == nil or y > top then top = y end
				local raised, count = {}, 0
				for index = 1, #QUARTERS do
					local sx, sz = QUARTERS[index][1], QUARTERS[index][2]
					local side_x, side_z = at(x + sx, z), at(x, z + sz)
					local corner = at(x + sx, z + sz)
					local high = (side_x and side_x > y) or (side_z and side_z > y) or
						(corner and corner > y)
					raised[sx .. "," .. sz] = high and true or false
					if high then count = count + 1 end
				end
				if count == 0 or count == 4 then
					buf:put(x, y, z, count == 0 and slab or ridge, 0)
				elseif count == 1 then
					for key, high in pairs(raised) do
						if high then buf:put(x, y, z, outer, OUTER_PARAM2[key]) end
					end
				elseif count == 3 then
					for key, high in pairs(raised) do
						if not high then buf:put(x, y, z, inner, INNER_PARAM2[key]) end
					end
				elseif raised["1,1"] and raised["-1,1"] then
					buf:put(x, y, z, stair, 0)
				elseif raised["1,-1"] and raised["-1,-1"] then
					buf:put(x, y, z, stair, 2)
				elseif raised["1,1"] and raised["1,-1"] then
					buf:put(x, y, z, stair, 1)
				elseif raised["-1,1"] and raised["-1,-1"] then
					buf:put(x, y, z, stair, 3)
				else
					-- two opposite quarters: a saddle, capped flat.
					buf:put(x, y, z, ridge, 0)
				end
			end
		end
	end
	return top, level
end

local function inside(field, x, z)
	return x >= field.x0 and x <= field.x1 and z >= field.z0 and z <= field.z1
end

-- Stairs are a fixed 45 degrees, so a wide building would otherwise carry a
-- roof taller than its walls. `rise` clips the pitch at a given number of
-- courses; the clipped top becomes a slab ridge deck, which is what a real
-- clipped gable or a hip roof with a short ridge looks like.
local function clip(base, climb, rise)
	if rise and climb > rise then climb = rise end
	return base + climb
end

-- Both slopes fall to the same eave; `axis` names the ridge direction.
function M.gable(spec)
	local field = {x0 = spec.x0, x1 = spec.x1, z0 = spec.z0, z1 = spec.z1}
	local base, axis, rise = spec.base, spec.axis or "x", spec.rise
	function field.height(x, z)
		if not inside(field, x, z) then return nil end
		if axis == "x" then
			return clip(base, math.min(z - field.z0, field.z1 - z), rise)
		end
		return clip(base, math.min(x - field.x0, field.x1 - x), rise)
	end
	return field
end

-- All four sides fall to the eave; the corners become outer stairs.
function M.hip(spec)
	local field = {x0 = spec.x0, x1 = spec.x1, z0 = spec.z0, z1 = spec.z1}
	local base, rise = spec.base, spec.rise
	function field.height(x, z)
		if not inside(field, x, z) then return nil end
		return clip(base, math.min(x - field.x0, field.x1 - x,
			z - field.z0, field.z1 - z), rise)
	end
	return field
end

-- One eave sits `lift` nodes above the other, giving the long rear slope of
-- a saltbox. `axis` is the ridge direction, `lift` raises the low-z eave.
function M.saltbox(spec)
	local field = {x0 = spec.x0, x1 = spec.x1, z0 = spec.z0, z1 = spec.z1}
	local base, axis, lift = spec.base, spec.axis or "x", spec.lift or 2
	local rise = spec.rise
	function field.height(x, z)
		if not inside(field, x, z) then return nil end
		if axis == "x" then
			return math.min(clip(base + lift, z - field.z0, rise),
				clip(base, field.z1 - z, rise and (rise + lift)))
		end
		return math.min(clip(base + lift, x - field.x0, rise),
			clip(base, field.x1 - x, rise and (rise + lift)))
	end
	return field
end

-- A single pitch rising toward `up` ("z+", "z-", "x+" or "x-").
function M.lean_to(spec)
	local field = {x0 = spec.x0, x1 = spec.x1, z0 = spec.z0, z1 = spec.z1}
	local base, up, rise = spec.base, spec.up or "z+", spec.rise
	function field.height(x, z)
		if not inside(field, x, z) then return nil end
		if up == "z+" then return clip(base, z - field.z0, rise) end
		if up == "z-" then return clip(base, field.z1 - z, rise) end
		if up == "x+" then return clip(base, x - field.x0, rise) end
		return clip(base, field.x1 - x, rise)
	end
	return field
end

function M.flat(spec)
	local field = {x0 = spec.x0, x1 = spec.x1, z0 = spec.z0, z1 = spec.z1}
	local base = spec.base
	function field.height(x, z)
		if not inside(field, x, z) then return nil end
		return base
	end
	return field
end

-- A flat roof DECK: `flat` raised by one course.
--
-- Every pitched form puts its lowest course AT the eave, level with the top
-- wall course, because one node inward the roof is already higher and passes
-- over the wall. A flat roof has no inward course: rasterised at the eave it
-- would REPLACE the top wall course with a slab and leave the room below
-- open to the sky at its own ceiling height. The deck therefore stands one
-- course above the wall head, which is what a flat roof on a parapeted
-- building actually is -- walls to full height, joists and deck on top.
--
-- The parapet that makes such a roof read as a fighting platform rather than
-- as a shed lid is a ring of full nodes standing proud of the deck, which no
-- height field can express (the rasteriser writes exactly one cell per
-- column); `dressing.parapet` writes it over the finished deck.
function M.flat_deck(spec)
	local lifted = {x0 = spec.x0, x1 = spec.x1, z0 = spec.z0, z1 = spec.z1,
		base = spec.base + 1}
	return M.flat(lifted)
end

-- The union of several roofs: the highest surface wins at every column. A
-- cross gable built this way produces real valleys, which the rasteriser
-- resolves into inner corner stairs.
function M.combine(fields)
	local field = {x0 = nil, x1 = nil, z0 = nil, z1 = nil}
	for _, part in ipairs(fields) do
		if field.x0 == nil or part.x0 < field.x0 then field.x0 = part.x0 end
		if field.x1 == nil or part.x1 > field.x1 then field.x1 = part.x1 end
		if field.z0 == nil or part.z0 < field.z0 then field.z0 = part.z0 end
		if field.z1 == nil or part.z1 > field.z1 then field.z1 = part.z1 end
	end
	function field.height(x, z)
		local best = nil
		for _, part in ipairs(fields) do
			local y = part.height(x, z)
			if y and (best == nil or y > best) then best = y end
		end
		return best
	end
	return field
end

M.forms = {gable = M.gable, hip = M.hip, saltbox = M.saltbox,
	lean_to = M.lean_to, flat = M.flat, flat_deck = M.flat_deck}

function M.field(form, spec)
	local builder = M.forms[form]
	if not builder then
		error("wp13 roofs: unknown roof form " .. tostring(form), 0)
	end
	return builder(spec)
end

return M
