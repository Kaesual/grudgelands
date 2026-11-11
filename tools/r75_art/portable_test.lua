-- Round 75 ART/SHOP: full decor registration, wall footprint and reward boundaries.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	assert(ok, label)
end
local function read(path)
	local f = assert(io.open(repo .. "/" .. path))
	local s = f:read("*a"); f:close(); return s
end
local function copy(t)
	if type(t) ~= "table" then return t end
	local c = {}; for k,v in pairs(t) do c[k] = copy(v) end; return c
end
table.copy = copy
local modpath = repo .. "/mods/ITEMS/grug_decor"
local nodes, protected, placed, violation, clicked = {}, nil, nil, false, false
local function key(p) return string.format("%d:%d:%d", p.x,p.y,p.z) end
core = {
	registered_nodes = {air = {buildable_to = true, walkable = false},
		["test:stone"] = {walkable = true, drawtype = "normal"},
		-- The real default dependency registers this material before grug_decor.
		["default:junglewood"] = {tiles = {"default_junglewood.png"}}},
	get_modpath = function() return modpath end,
	get_current_modname = function() return "grug_decor" end,
	register_node = function(id, def) def.name = id; core.registered_nodes[id] = def end,
	get_node_or_nil = function(p) return {name = nodes[key(p)] or "air"} end,
	get_node = function(p) return {name = nodes[key(p)] or "air"} end,
	is_protected = function(p) return key(p) == protected end,
	record_protection_violation = function() violation = true end,
	dir_to_facedir = function(d)
		if d.x ~= 0 then return d.x > 0 and 1 or 3 end
		return d.z > 0 and 0 or 2
	end,
	item_place_node = function(stack, player, pointed, p2) placed = p2; return stack end,
}
default = setmetatable({}, {__index = function() return function() return {} end end})
vector = {
	add = function(a,b) return {x=a.x+b.x,y=a.y+b.y,z=a.z+b.z} end,
	subtract = function(a,b) return {x=a.x-b.x,y=a.y-b.y,z=a.z-b.z} end,
}
grug_core = {node_rightclick = function(stack) if clicked then return stack end end}
dofile(modpath .. "/init.lua")
local catalog = dofile(modpath .. "/paintings_catalog.lua")
check(#catalog == 16, "16 original paintings")
for size = 1,2 do
	local obj = read("mods/ITEMS/grug_decor/models/grug_decor_painting_" .. size .. ".obj")
	check(obj:find("g wood\nusemtl wood",1,true) and obj:find("g canvas\nusemtl canvas",1,true),
		"engine creates wood and canvas buffers")
	local minx, maxx = math.huge, -math.huge
	for x in obj:gmatch("\nv ([^ ]+) [^\n]+") do
		local runtime_x = -tonumber(x) -- Irrlicht OBJ handedness conversion.
		minx = math.min(minx,runtime_x); maxx = math.max(maxx,runtime_x)
	end
	check(math.abs(minx+.46) < .00001 and math.abs(maxx-(size-.54)) < .00001,
		"runtime bounds match selection and checked footprint")
end
local parts = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp13/parts.lua")
local pillars = 0
for id, def in pairs(core.registered_nodes) do
	if def._grug_city_architecture then
		pillars = pillars + 1
		check(def.groups.not_in_creative_inventory == 1 and def.drop == "",
			id .. " stays a hidden city construction material")
		check(parts.param2_kind(id) == parts.FACEDIR,
			id .. " participates in building rotation")
	end
end
check(pillars == 12, "twelve material pillar variants registered")
local count = 0
for id,def in pairs(core.registered_nodes) do
	if def._grug_city_decoration then
		count = count + 1
		check(def.drop == "" and def.diggable, id .. " removable without loot")
		check(not def.on_construct and not def.on_timer and not def.on_rightclick and
			not def.on_destruct and not def.preserve_metadata, id .. " static clone")
		local expected = def.paramtype2 == "facedir" and parts.FACEDIR or
			(def.paramtype2 == "wallmounted" and parts.WALLMOUNTED or parts.NONE)
		check(parts.param2_kind(id) == expected, id .. " follows the building's rotation")
	end
end
check(count >= 100, "city copies registered before displays")
local player = {get_player_name = function() return "owner" end}
local stack = {}
local large = core.registered_nodes["grug_decor:painting_highcourt"]
local axes = {{x=0,y=0,z=1},{x=1,y=0,z=0},{x=0,y=0,z=-1},{x=-1,y=0,z=0}}
for p2,back in ipairs(axes) do
	nodes = {}; protected = nil; violation = false
	local right = {x=back.z,y=0,z=-back.x}
	local pointed = {type="node", above={x=0,y=0,z=0}, under=back}
	for x=0,1 do for y=0,1 do
		nodes[key({x=x*right.x+back.x,y=y,z=x*right.z+back.z})] = "test:stone"
	end end
	placed = nil; large.on_place(stack,player,pointed)
	check(placed == p2-1, "large picture facing " .. p2)
	local corner = {x=right.x,y=1,z=right.z}
	protected = key(corner); placed = nil; large.on_place(stack,player,pointed)
	check(placed == nil and violation, "protected far corner " .. p2)
	protected = nil; nodes[key(corner)] = "test:stone"
	large.on_place(stack,player,pointed)
	check(placed == nil, "occupied far corner " .. p2)
	nodes[key(corner)] = nil
	nodes[key(vector.add(corner,back))] = nil
	large.on_place(stack,player,pointed)
	check(placed == nil, "unsupported far corner " .. p2)
end
placed = nil
large.on_place(stack,player,{type="node",above={x=0,y=1,z=0},under={x=0,y=0,z=0}})
check(placed == nil, "no floor-mounted painting")
clicked = true
check(large.on_place(stack,player,{type="object"}) == stack and placed == nil,
	"interactive node handled before placement")

local stock = read("mods/ENTITIES/grug_traders/stock.lua")
local shelf = assert(stock:match('profession_shelf%("culture", {%s*(.-)\n}%)'))
local prices = {}
for id,price in shelf:gmatch('{"([^"]+)", (%d+)}') do
	check(not prices[id], "no duplicate shop item " .. id)
	prices[id] = tonumber(price)
	check(core.registered_nodes[id] or id:match("^grug_displays:"), "registered shop item " .. id)
end
check(prices["grug_decor:cottages_wagon_wheel"] == 200, "wheel costs two silver")
check(not prices["grug_decor:xdecor_itemframe"] and not prices["grug_displays:armor_stand"],
	"basic displays craft only")
for _,row in ipairs(dofile(modpath .. "/furnishings_catalog.lua")) do
	check(prices[row.item] == row.price, "furnishing price " .. row.item)
end
local loot = dofile(repo .. "/mods/PLAYER/grug_expeditions/loot.lua")
for _,row in ipairs(catalog) do
	local item = "grug_decor:painting_" .. row.id
	check(prices[item] == row.price, "painting access " .. item)
	if row.expedition then
		local hits = 0
		for roll = 1,100 do
			local plan = loot.plan(loot.TABLES[row.expedition], 60, function(lo,hi)
				if lo == 1 and hi == 100 then return roll end
				return lo
			end, {1,2})
			local got = false
			for _,reward in ipairs(plan) do
				if reward.item and reward.item:match("^grug_decor:painting_") then
					check(reward.item == item and reward.count == 1, "only corresponding single painting")
					check(not got, "one art row per personal chest"); got = true
				end
			end
			check(got == (roll <= 2), "2% boundary " .. row.id .. " roll " .. roll)
			if got then hits = hits + 1 end
		end
		check(hits == 2, "exact two successes out of 100")
	end
end
local found = {}
for _,row in ipairs(dofile(repo .. "/tools/r45_rg/edits.lua")) do
	if row.output == "grug_decor:xdecor_itemframe" or row.output == "grug_displays:armor_stand" then
		check(row.count == 1 and #row.added == 1 and row.added[1].group == "wood", "wood-only Basic recipe")
		found[row.output] = row.added[1].n
	end
end
check(found["grug_decor:xdecor_itemframe"] == 4 and found["grug_displays:armor_stand"] == 6,
	"agreed plank costs")
print("r75_art: " .. checks .. " checks passed")
