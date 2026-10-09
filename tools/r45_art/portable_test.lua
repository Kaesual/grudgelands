-- Round 45 ART portable test (LuaJIT): the user's art picks in the game.
--
--   luajit tools/r45_art/portable_test.lua [REPO]
--
-- S. The five redesigned stations, as registered (tools/wp13/stub_registry.lua
--    runs the real station_nodes.lua and grug_brewing/node.lua): a fixed
--    node box whose every box lies within the node with positive extents;
--    selection/collision boxes, if any, within the node too; six plain tiles,
--    each a 16x16 PNG in the owning mod's textures/ in the design's face
--    order (their bytes: tools/r45_a2/generate.py --check); the boxes equal
--    the picked design.lua's; groups and the station id unchanged; the lit brewing stand looks the same, glows and
--    drops the unlit one. The forge keeps its anvil.
-- T. Every trinket item (the real trinkets.lua on a small stub) names its own
--    grug_gear_trinket_<key>_t<tier>.png, which exists as a 16x16 PNG; every
--    such name a mod's Lua spells out exists.
-- O. No mod's Lua names a removed texture (the old loom and brewing tiles).
-- Prints "R45 ART PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end

local function read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local data = handle:read("*a")
	handle:close()
	return data
end

-- Width and height from a PNG's IHDR, or nil when it is not a PNG.
local function png_size(data)
	if not data or data:sub(1, 8) ~= "\137PNG\r\n\26\n" or data:sub(13, 16) ~= "IHDR" then
		return nil
	end
	local function u32(at)
		local a, b, c, d = data:byte(at, at + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	return u32(17), u32(21)
end

local function within_node(box)
	if type(box) ~= "table" or #box ~= 6 then return false end
	for i = 1, 6 do
		if type(box[i]) ~= "number" or box[i] < -0.5 or box[i] > 0.5 then return false end
	end
	return box[1] < box[4] and box[2] < box[5] and box[3] < box[6]
end

-- The literal boxes and tile names of a generated design.lua.
local function design(station, variant)
	local chunk = assert(loadfile(ROOT .. "/tools/r45_a2/" .. station .. "/" ..
		variant .. "/design.lua"))
	return chunk()
end

------------------------------------------------------------------------------
-- S. Stations
------------------------------------------------------------------------------
local registry = dofile(ROOT .. "/tools/wp13/stub_registry.lua").load(ROOT)
local nodes = registry.nodes
local FACES = {"top", "bottom", "right", "left", "back", "front"}
local STATIONS = {
	{station = "tanning_rack", pick = "B", node = "grug_jobs:tanning_rack",
		dir = "mods/PLAYER/grug_jobs/textures", prefix = "grug_jobs_tanning_rack",
		groups = {choppy = 2}},
	{station = "tailor_bench", pick = "B", node = "grug_jobs:tailor_bench",
		dir = "mods/PLAYER/grug_jobs/textures", prefix = "grug_jobs_tailor_bench",
		groups = {choppy = 2}},
	{station = "carving_bench", pick = "B", node = "grug_jobs:carving_bench",
		dir = "mods/PLAYER/grug_jobs/textures", prefix = "grug_jobs_carving_bench",
		groups = {choppy = 2}},
	{station = "jewellers_bench", pick = "A", node = "grug_jobs:jewellers_bench",
		dir = "mods/PLAYER/grug_jobs/textures", prefix = "grug_jobs_jewellers_bench",
		groups = {cracky = 2}},
	{station = "brewing_stand", pick = "B", node = "grug_brewing:brewing_stand",
		dir = "mods/ITEMS/grug_brewing/textures", prefix = "grug_brewing_stand",
		groups = {cracky = 2}},
}

local function same_groups(a, b)
	for k, v in pairs(a or {}) do if b[k] ~= v then return false end end
	for k, v in pairs(b) do if (a or {})[k] ~= v then return false end end
	return true
end

local function boxes_of(nodebox)
	if type(nodebox) ~= "table" then return nil end
	local fixed = nodebox.fixed
	if type(fixed) == "table" and type(fixed[1]) == "number" then fixed = {fixed} end
	return fixed
end

for _, s in ipairs(STATIONS) do
	local def = nodes[s.node]
	if check(def ~= nil, "S " .. s.node .. " registered") then
		local label = "S " .. s.station
		check(def.drawtype == "nodebox" and def.node_box and def.node_box.type == "fixed",
			label .. " is a fixed node box")
		local boxes = boxes_of(def.node_box) or {}
		local inside = #boxes > 0
		for _, box in ipairs(boxes) do inside = inside and within_node(box) end
		check(inside, label .. " every box within the node, positive extents")
		for _, field in ipairs({"selection_box", "collision_box"}) do
			if def[field] then
				local ok = true
				for _, box in ipairs(boxes_of(def[field]) or {}) do
					ok = ok and within_node(box)
				end
				check(ok, label .. " " .. field .. " within the node")
			end
		end
		local picked = design(s.station, s.pick)
		local same = #boxes == #picked.boxes
		for i = 1, #picked.boxes do
			for j = 1, 6 do same = same and boxes[i] and boxes[i][j] == picked.boxes[i][j] end
		end
		check(same, label .. " boxes are the picked design's (" .. s.pick .. ")")
		check(type(def.tiles) == "table" and #def.tiles == 6, label .. " six tiles")
		for i = 1, 6 do
			local name = def.tiles and def.tiles[i]
			local expected = s.prefix .. "_" .. FACES[i] .. ".png"
			if check(name == expected, label .. " tile " .. i .. " is " .. expected) then
				local data = read(s.dir .. "/" .. name)
				local w, h = png_size(data)
				check(w == 16 and h == 16, label .. " " .. name .. " is a 16x16 PNG in " .. s.dir)
				-- Its bytes are the picked tile's: tools/r45_a2/generate.py --check.
				check(picked.tiles[i]:find("_" .. FACES[i] .. ".png", 1, true) ~= nil,
					label .. " the design's tile " .. i .. " is its " .. FACES[i])
			end
		end
		check(same_groups(def.groups, s.groups), label .. " groups unchanged")
		check(def._grug_station == s.station, label .. " station id unchanged")
	end
end

do
	local lit, unlit = nodes["grug_brewing:brewing_stand_active"], nodes["grug_brewing:brewing_stand"]
	if check(lit ~= nil and unlit ~= nil, "S both brewing stands registered") then
		local same = #boxes_of(lit.node_box) == #boxes_of(unlit.node_box)
		for i, box in ipairs(boxes_of(unlit.node_box)) do
			for j = 1, 6 do same = same and boxes_of(lit.node_box)[i][j] == box[j] end
		end
		for i = 1, 6 do same = same and lit.tiles[i] == unlit.tiles[i] end
		check(same, "S the lit brewing stand has the same boxes and tiles")
		check((lit.light_source or 0) > 0 and (unlit.light_source or 0) == 0,
			"S the lit brewing stand glows, the unlit one does not")
		check(lit.drop == "grug_brewing:brewing_stand" and unlit.drop == lit.drop,
			"S both brewing stands drop the unlit one")
		check(lit.groups.not_in_creative_inventory == 1, "S the lit stand stays out of creative")
	end
	local forge = nodes["grug_jobs:forge"]
	check(forge and forge.tiles[1] == "grug_jobs_anvil_top.png^[transformR90" and
		#boxes_of(forge.node_box) == 4, "S the forge keeps its anvil")
end

------------------------------------------------------------------------------
-- T. Trinkets
------------------------------------------------------------------------------
do
	local items = {}
	local saved_core, saved_gear = rawget(_G, "core"), rawget(_G, "grug_gear")
	core = {
		colorize = function(_, text) return text end,
		register_craftitem = function(name, def) items[name] = def end,
	}
	grug_gear = {BRACKETS = {}, required_level = function(ilvl) return ilvl end}
	for tier = 1, 6 do grug_gear.BRACKETS[tier] = {ilvl = tier * 10} end
	dofile(ROOT .. "/mods/ITEMS/grug_gear/trinkets.lua")
	local trinkets = grug_gear.TRINKETS
	core, grug_gear = saved_core, saved_gear

	check(#trinkets == 6, "T six trinket identities")
	local seen, count = {}, 0
	for _, identity in ipairs(trinkets) do
		for tier = 1, 6 do
			local name = "grug_gear:" .. identity.key .. "_t" .. tier
			local def = items[name]
			local expected = "grug_gear_trinket_" .. identity.key .. "_t" .. tier .. ".png"
			if check(def ~= nil, "T " .. name .. " registered") then
				count = count + 1
				check(def.inventory_image == expected, "T " .. name .. " shows " .. expected)
				check(not seen[def.inventory_image], "T " .. name .. " has its own image")
				seen[def.inventory_image] = true
				local w, h = png_size(read("mods/ITEMS/grug_gear/textures/" .. expected))
				check(w == 16 and h == 16, "T " .. expected .. " is a 16x16 PNG")
			end
		end
	end
	check(count == 36, "T 36 trinket items")
end

------------------------------------------------------------------------------
-- T/O. Texture names spelled out in mod Lua
------------------------------------------------------------------------------
do
	local list = io.popen("cd '" .. ROOT .. "' && find mods -name '*.lua' -type f | sort")
	local removed = {"grug_jobs_loom_", "grug_brewing_top.png", "grug_brewing_base.png",
		"grug_brewing_side.png"}
	local named, stale = 0, {}
	for path in list:lines() do
		local source = read(path) or ""
		for name in source:gmatch("grug_gear_trinket_[%w_]+%.png") do
			named = named + 1
			check(png_size(read("mods/ITEMS/grug_gear/textures/" .. name)) ~= nil,
				"T " .. path .. " names an existing " .. name)
		end
		for _, old in ipairs(removed) do
			if source:find(old, 1, true) then stale[#stale + 1] = path .. ": " .. old end
		end
	end
	list:close()
	check(named >= 1, "T the Goldsmith product display names a trinket icon")
	check(#stale == 0, "O no removed station texture is named: " .. table.concat(stale, ", "))
end

if failures > 0 then
	print("R45 ART PORTABLE FAIL failures=" .. failures .. " checks=" .. checks)
	os.exit(1)
end
print("R45 ART PORTABLE PASS checks=" .. checks)
