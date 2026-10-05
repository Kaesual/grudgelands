-- Round 36 lane W: an authoring aid for the Round 20 decor rows (LuaJIT, no
-- engine). It proposes `props` rows (`decor` for a rift candidate) for a
-- composition from its kind's
-- theme, placing each piece exactly as the builder will (`decor_kit.place`,
-- the same open-ground, door and clearance rules) with one free cell round
-- every piece, and prints them for the catalogue. The rows are then
-- reviewed on renders and kept as authored data; the game never runs this.
--
--   luajit tools/r36_w/author.lua REPO KEY[,KEY...] [RECIPE]
--
-- KEY is a Round 20 anchor key or r14:<village|outpost|camp>:<race> (the
-- rows of the Round 14 builder's DECOR table).
--
-- RECIPE overrides the kind's theme: "piece:zone,piece:zone,...", a zone
-- being court (round the centre), wall (against a building), edge (by the
-- composition's rim) or open (between them). For the four rift candidates
-- the crack's cells and a node round them are kept free, and their own
-- prop rows stay as they are.
local repo, keys, recipe_arg = arg[1], arg[2], arg[3]
assert(repo and keys, "usage: author.lua REPO KEY[,KEY...] [RECIPE]")
_G.core = _G.core or {}
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local decor = dofile(wp13 .. "/decor_kit.lua")(wp13)
local parts = dofile(wp13 .. "/parts.lua")
local rift = dofile(repo .. "/mods/ENTITIES/grug_mobs/rift_core.lua")

local THEMES = {
	village = "well:court,lamp:court,craft:wall,woodpile:wall,flowers:wall,stores:wall,garden:open,bench:court",
	outpost = "banner:court,rack:wall,stores:wall,lamp:court,bench:wall",
	bandit_frontier = "stores:wall,lean_to:open,rack:open,palisade:edge,drying:open",
	mine = "ore_heap:wall,ore_cart:court,woodpile:wall,craft:wall,lamp:court,rack:open,stores:wall",
	mirefolk = "drying:open,totem:court,baskets:wall,ashpit:open,lamp:court",
	clash = "palisade:edge,banner:open,fallen_banner:open,graves:edge,burnt_cart:open,rack:open,rubble:open",
	apex_mine = "lean_to:edge,lean_to:edge,ashpit:open,counter:wall,ore_heap:wall,ore_heap:wall,ore_cart:open," ..
		"stores:wall,craft:wall,lamp:court,lamp:open,lamp:open,woodpile:wall",
	rare_route = "den:edge,nest:open,bones:open,scrape:open,remains:open",
}

local function parse(text)
	local out = {}
	for item in text:gmatch("[^,]+") do
		local piece, zone = item:match("^([%w_]+):(%a+)$")
		assert(piece, "recipe item: " .. item)
		out[#out + 1] = {piece, zone}
	end
	return out
end

-- The Round 14 compositions (KEY "r14:<kind>:<race>"): each try builds the
-- real composition with the rows so far plus the candidate, so the
-- builder's own rules decide; the candidate's new cells must keep a node
-- clear of the earlier pieces.
local R14_THEMES = {
	village = "well:court,flowers:wall,craft:wall,lamp:court,woodpile:wall",
	outpost = "banner:court,rack:open,stores:wall",
	camp = "palisade:edge,rack:open,lean_to:open,ashpit:open",
}
local function author_r14(kind, race, recipe_text)
	local build = dofile(wp40 .. "/r14_poi_blueprint.lua")
	local function make(rows)
		return build({schema = "grug_r14_author_v1", race = race, kind = kind, decor = rows})
	end
	local function grid(bp)
		local g = {}
		for _, c in ipairs(bp.cells) do g[c.x .. ":" .. c.y .. ":" .. c.z] = c end
		return g, bp
	end
	local rows = {}
	local current, bp = grid(make(rows))
	local lo, hi = bp.bounds.min.x, bp.bounds.max.x
	local half = (hi - lo + 1) / 2
	local taken = {}
	local function built(x, z)
		local c = current[x .. ":1:" .. z]
		return c ~= nil and c.name ~= "air"
	end
	for _, item in ipairs(parse(recipe_text or R14_THEMES[kind])) do
		local piece, zone = item[1], item[2]
		local tries = {}
		for z = lo, hi do for x = lo, hi do for face = 0, 3 do
			local r = math.max(math.abs(x), math.abs(z))
			local fx, fz = parts.facedir_step(face)
			local toward = -(fx * x + fz * z) / math.max(1, math.sqrt(x * x + z * z))
			local walls = 0
			for dz = -2, 2 do for dx = -2, 2 do
				if built(x + dx, z + dz) then walls = walls + 1 end
			end end
			local score
			if zone == "court" then score = -math.abs(r - 4) * 2 + toward * 2 - walls
			elseif zone == "wall" then score = math.min(walls, 6) - (walls > 9 and 4 or 0) + toward
			elseif zone == "edge" then score = -math.abs(r - (half - 2)) * 2 + toward - walls * 0.5
			else score = -math.abs(r - half * 0.6) - walls + toward end
			score = score + parts.position_hash(x * 4 + face, z + #rows * 7) / 32768 * 0.5
			tries[#tries + 1] = {score, x, z, face}
		end end end
		table.sort(tries, function(a, b)
			if a[1] ~= b[1] then return a[1] > b[1] end
			if a[2] ~= b[2] then return a[2] < b[2] end
			if a[3] ~= b[3] then return a[3] < b[3] end
			return a[4] < b[4]
		end)
		local placed
		for _, t in ipairs(tries) do
			local try = {}
			for i, r in ipairs(rows) do try[i] = r end
			try[#try + 1] = {piece, t[2], t[3], t[4]}
			local ok, result = pcall(make, try)
			if ok then
				local g = grid(result)
				local new, clash = {}, false
				for k, c in pairs(g) do
					local old = current[k]
					if (old == nil or old.name ~= c.name) and c.name ~= "air" then
						new[#new + 1] = c
						if taken[c.x .. ":" .. c.z] then clash = true end
					end
				end
				if not clash then
					for _, c in ipairs(new) do
						for dz = -1, 1 do for dx = -1, 1 do taken[(c.x + dx) .. ":" .. (c.z + dz)] = true end end
					end
					current, rows, placed = g, try, true
					break
				end
			end
		end
		if not placed then io.stderr:write("r14 " .. kind .. " " .. race .. ": no room for " .. piece .. "\n") end
	end
	local out = {}
	for _, r in ipairs(rows) do out[#out + 1] = ('{"%s",%d,%d,%d}'):format(r[1], r[2], r[3], r[4]) end
	print(("r14:%s:%s\t%s = {%s},"):format(kind, race, race, table.concat(out, ",")))
end

local want = {}
for k in keys:gmatch("[^,]+") do
	local kind, race = k:match("^r14:(%a+):(%a+)$")
	if kind then author_r14(kind, race, recipe_arg) else want[k] = true end
end
for _, profile in ipairs(settlement.roster) do
	if want[profile.key] then
		local art = profile.art
		local base = {}
		for k, v in pairs(art) do base[k] = v end
		local candidate = rift.CANDIDATES[profile.key]
		base.decor = {}
		if not candidate then
			-- an apex camp keeps its sample wall
			base.props = {}
			for _, q in ipairs(art.props) do
				if q[1] == "samples" then base.props[#base.props + 1] = q end
			end
		end
		local p0 = {}
		for k, v in pairs(profile) do p0[k] = v end
		p0.art = base
		local bp = dofile(wp40 .. "/r20_poi_blueprint.lua")({}, p0)
		local cells = {}
		for _, c in ipairs(bp.cells) do cells[c.x .. ":" .. c.y .. ":" .. c.z] = c end
		local buf = decor.view(function(x, y, z, name, param2)
			cells[x .. ":" .. y .. ":" .. z] = {x = x, y = y, z = z, name = name, param2 = param2}
		end, function(x, y, z) return cells[x .. ":" .. y .. ":" .. z] end)
		local lo, hi = -art.width / 2, art.width / 2 - 1
		local ground = cells[lo .. ":0:" .. lo].name
		local brush = decor.brush(buf, art.race)
		brush.display = "grug_mapgen:poi_display_" .. art.race
		local reserved = {}
		for z = -2, 2 do for x = -2, 2 do reserved[x .. ":" .. z] = true end end
		for _, s in ipairs(bp.landmarks.structures) do
			local e, turn = s.entry, s.entry_turn
			local ox, oz = ({0, 1, 0, -1})[turn + 1], ({-1, 0, 1, 0})[turn + 1]
			decor.reserve_door(reserved, {{e.x, e.z}, {e.x + math.abs(oz), e.z + math.abs(ox)}}, ox, oz, 2)
		end
		local keep = {}
		if candidate then
			for _, c in ipairs(rift.crack_cells(art, candidate)) do
				for dz = -1, 1 do for dx = -1, 1 do keep[(c[1] + dx) .. ":" .. (c[2] + dz)] = true end end
			end
			for _, q in ipairs(art.props) do
				for dz = -1, 1 do for dx = -1, 1 do keep[(q[2] + dx) .. ":" .. (q[3] + dz)] = true end end
			end
		end
		local function built(x, z)
			local c = cells[x .. ":1:" .. z]
			return c ~= nil and c.name ~= "air"
		end
		local rules = {ground = {[ground] = true}, reserved = reserved, keep = keep, label = profile.key,
			inside = function(x, y, z) return x >= lo and x <= hi and z >= lo and z <= hi and y >= 0 and
				y <= art.height end}
		local recipe = parse(recipe_arg or THEMES[art.kind])
		local rows = {}
		local half = art.width / 2
		for _, item in ipairs(recipe) do
			local piece, zone = item[1], item[2]
			local tries = {}
			for z = lo, hi do for x = lo, hi do for face = 0, 3 do
				local r = math.max(math.abs(x), math.abs(z))
				local fx, fz = parts.facedir_step(face)
				-- toward the centre, and the wall contact round the anchor
				local toward = -(fx * x + fz * z) / math.max(1, math.sqrt(x * x + z * z))
				local walls = 0
				for dz = -2, 2 do for dx = -2, 2 do
					if built(x + dx, z + dz) then walls = walls + 1 end
				end end
				local score
				if zone == "court" then score = -math.abs(r - 4) * 2 + toward * 2 - walls
				elseif zone == "wall" then score = math.min(walls, 6) - (walls > 9 and 4 or 0) + toward
				elseif zone == "edge" then score = -math.abs(r - (half - 2)) * 2 + toward - walls * 0.5
				else score = -math.abs(r - half * 0.6) - walls + toward end
				score = score + parts.position_hash(x * 4 + face, z + #rows * 7) / 32768 * 0.5
				tries[#tries + 1] = {score, x, z, face}
			end end end
			table.sort(tries, function(a, b)
				if a[1] ~= b[1] then return a[1] > b[1] end
				if a[2] ~= b[2] then return a[2] < b[2] end
				if a[3] ~= b[3] then return a[3] < b[3] end
				return a[4] < b[4]
			end)
			local placed
			for _, t in ipairs(tries) do
				local before = {}
				for k, v in pairs(cells) do before[k] = v end
				local ok = pcall(decor.place, brush, {piece, t[2], t[3], t[4]}, rules)
				if ok then
					-- a free node round the new piece
					for k, c in pairs(cells) do
						if before[k] ~= c and c.y >= 0 then
							for dz = -1, 1 do for dx = -1, 1 do
								local key = (c.x + dx) .. ":" .. (c.z + dz)
								reserved[key] = true
								keep[key] = keep[key] or (c.y == 0 and c.name ~= ground) or nil
							end end
						end
					end
					placed = {piece, t[2], t[3], t[4]}
					break
				end
			end
			if placed then
				rows[#rows + 1] = placed
			else
				io.stderr:write(profile.key .. ": no room for " .. piece .. "\n")
			end
		end
		local out = {}
		for _, r in ipairs(rows) do
			out[#out + 1] = ('{"%s",%d,%d,%d}'):format(r[1], r[2], r[3], r[4])
		end
		print(profile.key .. "\tdecor={" .. table.concat(out, ",") .. "}")
	end
end
