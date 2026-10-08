-- Hotfix 0.43.1: which shipped settlement data has two fixed points of one
-- route leg in one search cell (grug_mobs/routes.lua end_cell): two idle
-- spots of one composition, or two neighbouring waypoints of one patrol loop,
-- on the same position, or on the same x/z one node apart in height with the
-- lower one's own cell written by the blueprint (end_cell raises a spot whose
-- feet cell is walkable by one, into the upper spot's cell). Only start towns
-- and capitals have the route cache, so only their blueprints are read: each
-- start's one blueprint, each capital's core and every district plot of its
-- roster (a plot's sockets keep their relative places under the planner's
-- turns, offset and base height; plots do not overlap, so pairs are found
-- within one blueprint). Offline, no engine, no world.
-- Usage (repo root): luajit tools/hf_0431/same_cell.lua [REPO]
local repo = arg[1] or "."
_G.core = _G.core or {}
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local capital = dofile(wp40 .. "/r7_capital_blueprint.lua")

local function built(bp)
	while type(bp) == "function" do bp = bp({}) end
	return bp
end

local found = 0
-- settlement -> patrol group -> waypoints over all its blueprints (a loop of
-- one waypoint walks the leg from it to itself)
local loop_size = {}
local function scan(label, bp, key)
	bp = built(bp)
	local at = {}
	for _, c in ipairs(bp.cells or {}) do
		if c.name ~= "air" then at[c.x .. "," .. c.y .. "," .. c.z] = c.name end
	end
	local sockets = bp.landmarks and bp.landmarks.sockets or {}
	local function same_cell(a, b)
		if a.x ~= b.x or a.z ~= b.z then return nil end
		local dy = b.y - a.y
		if dy == 0 then return "same position" end
		if math.abs(dy) ~= 1 then return nil end
		local low = dy > 0 and a or b
		local name = at[low.x .. "," .. low.y .. "," .. low.z]
		if name then
			return ("y %d/%d, the lower spot's cell holds %s"):format(a.y, b.y, name)
		end
		return ("y %d/%d, the lower spot's cell is not written (terrain or air)")
			:format(a.y, b.y)
	end
	local function report(kind, a, b, why)
		found = found + 1
		print(("%s\t%s\t%s (%d,%d,%d) + %s (%d,%d,%d)\t%s%s%s"):format(label, kind,
			a.id, a.x, a.y, a.z, b.id, b.x, b.y, b.z, why,
			a.spawn == false and ", first a spare" or "",
			b.spawn == false and ", second a spare" or ""))
	end
	local idle, loops = {}, {}
	for _, s in ipairs(sockets) do
		if s.role == "idle" then
			idle[#idle + 1] = s
		elseif s.role == "guard_patrol" then
			local sizes = loop_size[key] or {}
			loop_size[key] = sizes
			sizes[s.group] = (sizes[s.group] or 0) + 1
			loops[s.group] = loops[s.group] or {}
			table.insert(loops[s.group], s)
		end
	end
	for i = 1, #idle do
		for j = i + 1, #idle do
			local why = same_cell(idle[i], idle[j])
			if why then report("idle", idle[i], idle[j], why) end
		end
	end
	for group, loop in pairs(loops) do
		table.sort(loop, function(a, b) return a.order < b.order end)
		for i = 1, #loop do
			local a, b = loop[i], loop[i % #loop + 1]
			local why = a ~= b and same_cell(a, b)
			if why then report("patrol " .. group, a, b, why) end
		end
	end
	return #idle
end

local blueprints, spots = 0, 0
for _, profile in ipairs(settlement.roster) do
	if profile.slot == "start" then
		spots = spots + scan(profile.key, dofile(wp40 .. "/" .. profile.blueprint_file),
			profile.key)
		blueprints = blueprints + 1
	elseif profile.slot == "capital" then
		local kit = capital.kit(profile.key)
		spots = spots + scan(profile.key .. " core", kit.core.build(), profile.key)
		blueprints = blueprints + 1
		for _, plot in ipairs(kit.plots) do
			spots = spots + scan(profile.key .. " plot " .. plot.id, plot.build(),
				profile.key)
			blueprints = blueprints + 1
		end
	end
end
local loops_total = 0
for key, sizes in pairs(loop_size) do
	for group, n in pairs(sizes) do
		loops_total = loops_total + 1
		if n < 2 then
			found = found + 1
			print(("%s\tpatrol %s\ta loop of %d waypoint(s)"):format(key, group, n))
		end
	end
end
print(("patrol loops: %d, none of one waypoint unless listed"):format(loops_total))
print(("same-cell pairs: %d (%d blueprints, %d idle spots)"):format(found,
	blueprints, spots))
