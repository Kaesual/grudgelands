local EMPTY = "grug_farming:empty_iron_bucket"
local FILLED = "grug_farming:water_bucket"
local sources = {
	ordinary = "default:water_source",
	river = "default:river_water_source",
}
local families = {}
for family, name in pairs(sources) do families[name] = family end

local function allowed(user, pos)
	if not user or not user:is_player() or not pos then return false end
	local eye = grug_core.combat_eye_pos(user)
	if not eye then return false end
	local range = user:get_wielded_item():get_definition().range or 4
	local dx, dy, dz = eye.x - pos.x, eye.y - pos.y, eye.z - pos.z
	if dx * dx + dy * dy + dz * dz > (range + 1) * (range + 1) then
		return false
	end
	local name = user:get_player_name()
	if core.is_protected(pos, name) or not grug_core.world_alterable(pos) then
		core.record_protection_violation(pos, name)
		return false
	end
	return true
end

local function fill(stack, user, pointed)
	if stack:get_count() ~= 1 or not pointed or pointed.type ~= "node" then
		return stack
	end
	local pos = pointed.under
	if not allowed(user, pos) then return stack end
	local node = core.get_node_or_nil(pos)
	local family = node and families[node.name]
	if not family then return stack end
	local result = ItemStack(FILLED)
	result:get_meta():set_string("water_family", family)
	if not core.set_node(pos, {name = "air"}) then return stack end
	return result
end

local function place(stack, user, pointed)
	if stack:get_count() ~= 1 or not pointed or pointed.type ~= "node" then
		return stack
	end
	local source = sources[stack:get_meta():get_string("water_family")]
	if not source then return stack end
	local under = core.get_node_or_nil(pointed.under)
	if not under then return stack end
	local under_def = core.registered_nodes[under.name]
	local pos = under_def and under_def.buildable_to and pointed.under or pointed.above
	if not allowed(user, pos) then return stack end
	local node = core.get_node_or_nil(pos)
	local def = node and core.registered_nodes[node.name]
	-- Do not replace an existing source/flow and do not convert lava. Other
	-- buildable plants/snow follow ordinary bucket placement semantics.
	if not def or not def.buildable_to or
			(def.liquidtype and def.liquidtype ~= "none") then return stack end
	if not core.set_node(pos, {name = source}) then return stack end
	return ItemStack(EMPTY)
end

core.register_craftitem(EMPTY, {
	description = "Iron Bucket",
	inventory_image = "grug_farming_bucket.png",
	stack_max = 1, liquids_pointable = true,
	groups = {grug_bucket = 1},
	on_place = fill,
})
core.register_craftitem(FILLED, {
	description = "Water Bucket",
	inventory_image = "grug_farming_bucket_water.png",
	stack_max = 1, liquids_pointable = true,
	groups = {grug_bucket = 1},
	on_place = place,
})

-- VoxeLibre/mods/ITEMS/mcl_buckets/init.lua:34-41: three ingots in a V.
core.register_craft({
	output = EMPTY,
	recipe = {
		{"grug_materials:iron_bar", "", "grug_materials:iron_bar"},
		{"", "grug_materials:iron_bar", ""},
	},
})
