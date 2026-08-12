-- Canonical registrations for reachable derivatives of migrated storage
-- materials. Existing recipes keep working through one-way aliases, but this
-- file intentionally adds no recipe: WP26 owns material processing/storage.

local function register_derivative(derivative)
	local source = core.registered_nodes[derivative.source]
	if not source then
		error("grug_materials: missing derivative source " .. derivative.source)
	end
	local def = table.copy(source)
	def.name = nil
	def.type = nil
	def.mod_origin = nil
	def.description = derivative.description
	def.is_ground_content = false
	def.groups = table.copy(def.groups or {})
	def.groups.level = nil
	def.groups.grug_natural = nil
	def.groups.grug_resource = nil
	def.groups.grug_stratum = nil
	def.drop = derivative.target
	if derivative.target:find("^grug_materials:slab_") and def.on_place then
		local source_on_place = def.on_place
		def.on_place = function(itemstack, placer, pointed_thing)
			local under = pointed_thing and pointed_thing.under and
				core.get_node(pointed_thing.under)
			if under and under.name:find("^grug_materials:slab_") then
				local player_name = placer and placer:get_player_name() or ""
				local dir = core.dir_to_facedir(vector.subtract(
					pointed_thing.above, pointed_thing.under), true)
				local param2 = under.param2
				if param2 >= 20 and dir == 8 then
					param2 = param2 - 20
				elseif param2 <= 3 and dir == 4 then
					param2 = param2 + 20
				end
				core.item_place_node(ItemStack(itemstack:get_name()), placer,
					pointed_thing, param2)
				if not core.is_creative_enabled(player_name) then
					itemstack:take_item()
				end
				return itemstack
			end
			return source_on_place(itemstack, placer, pointed_thing)
		end
	end
	core.register_node(derivative.target, def)
end

for _, derivative in ipairs(grug_materials.STORAGE_DERIVATIVES) do
	register_derivative(derivative)
end
