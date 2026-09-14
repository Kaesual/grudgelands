-- Stair / slab / inner / outer shapes for grug_decor materials.
--
-- GRUG PATCH: vendored copy of the four shape registrations of
-- `mods/BASE/stairs/init.lua` (minetest_game `stairs`, LGPL-2.1+, commit
-- b5243f3 per VENDOR.md), with three deliberate changes:
--   (a) the registered names live in the `grug_decor:` namespace instead of
--       `stairs:` -- the package contract is that every grug_decor node name
--       starts with `grug_decor:`, and `stairs.register_stair_and_slab` can
--       only ever produce `stairs:stair_<subname>` (it hardcodes the leading
--       `:stairs:` override prefix);
--   (b) every `register_craft` call of the originals is dropped -- this mod
--       registers no recipes at all;
--   (c) the slab `on_place` matches our own `_slab` suffix instead of the
--       `^stairs:slab_` prefix.
-- The node boxes, `paramtype`/`paramtype2`, `is_ground_content`, the
-- `stair`/`slab` group tags and the placement rotation logic are byte-for-byte
-- the upstream ones, so the shapes behave exactly like the vendored `stairs`.

-- GRUG PATCH: copy of the local `rotate_and_place` of mods/BASE/stairs/init.lua,
-- the deprecated namespace alias rewritten to `core` per project convention.
local function rotate_and_place(itemstack, placer, pointed_thing)
	local p0 = pointed_thing.under
	local p1 = pointed_thing.above
	local param2 = 0

	if placer then
		local placer_pos = placer:get_pos()
		if placer_pos then
			local diff = vector.subtract(p1, placer_pos)
			param2 = core.dir_to_facedir(diff)
			-- The player places a node on the side face of the node he is standing on
			if p0.y == p1.y and math.abs(diff.x) <= 0.5 and math.abs(diff.z) <= 0.5 and diff.y < 0 then
				-- reverse node direction
				param2 = (param2 + 2) % 4
			end
		end

		local finepos = core.pointed_thing_to_face_pos(placer, pointed_thing)
		local fpos = finepos.y % 1

		if p0.y - 1 == p1.y or (fpos > 0 and fpos < 0.5)
				or (fpos < -0.5 and fpos > -0.999999999) then
			param2 = param2 + 20
			if param2 == 21 then
				param2 = 23
			elseif param2 == 23 then
				param2 = 21
			end
		end
	end
	return core.item_place(itemstack, placer, pointed_thing, param2)
end

-- GRUG PATCH: copy of the local `set_textures` of mods/BASE/stairs/init.lua.
local function set_textures(images, worldaligntex)
	local stair_images = {}
	for i, image in ipairs(images) do
		stair_images[i] = type(image) == "string" and {name = image} or table.copy(image)
		if stair_images[i].backface_culling == nil then
			stair_images[i].backface_culling = true
		end
		if worldaligntex and stair_images[i].align_style == nil then
			stair_images[i].align_style = "world"
		end
	end
	return stair_images
end

local function shared(def, images, worldaligntex, extra_group)
	local groups = table.copy(def.groups)
	groups[extra_group] = 1
	return {
		drawtype = "nodebox",
		tiles = set_textures(images, worldaligntex),
		use_texture_alpha = def.use_texture_alpha,
		sunlight_propagates = def.sunlight_propagates,
		light_source = def.light_source,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = groups,
		sounds = def.sounds,
	}
end

local function fill(target, source)
	for k, v in pairs(source) do
		target[k] = v
	end
	return target
end

-- Register the four shapes of one material.
--
-- `subname` is the part after `grug_decor:`; `def` carries `description`,
-- `tiles`, `groups`, `sounds` and optionally `use_texture_alpha`,
-- `sunlight_propagates`, `light_source` and `worldaligntex`.
function grug_decor.register_shapes(subname, def)
	local images = def.tiles
	local wa = def.worldaligntex
	local name = "grug_decor:" .. subname

	core.register_node(name .. "_stair", fill(shared(def, images, wa, "stair"), {
		description = def.description .. " Stair",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, 0.0, 0.5},
				{-0.5, 0.0, 0.0, 0.5, 0.5, 0.5},
			},
		},
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end
			return rotate_and_place(itemstack, placer, pointed_thing)
		end,
	}))

	core.register_node(name .. "_stair_inner", fill(shared(def, images, wa, "stair"), {
		description = "Inner " .. def.description .. " Stair",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, 0.0, 0.5},
				{-0.5, 0.0, 0.0, 0.5, 0.5, 0.5},
				{-0.5, 0.0, -0.5, 0.0, 0.5, 0.0},
			},
		},
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end
			return rotate_and_place(itemstack, placer, pointed_thing)
		end,
	}))

	core.register_node(name .. "_stair_outer", fill(shared(def, images, wa, "stair"), {
		description = "Outer " .. def.description .. " Stair",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, 0.0, 0.5},
				{-0.5, 0.0, 0.0, 0.0, 0.5, 0.5},
			},
		},
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end
			return rotate_and_place(itemstack, placer, pointed_thing)
		end,
	}))

	core.register_node(name .. "_slab", fill(shared(def, images, wa, "slab"), {
		description = def.description .. " Slab",
		node_box = {
			type = "fixed",
			fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5},
		},
		on_place = function(itemstack, placer, pointed_thing)
			local under = core.get_node(pointed_thing.under)
			local wield_item = itemstack:get_name()
			local player_name = placer and placer:get_player_name() or ""

			-- GRUG PATCH: our slabs carry a `_slab` suffix, not a
			-- `stairs:slab_` prefix.
			if under and under.name:find("_slab$") then
				-- place slab using under node orientation
				local dir = core.dir_to_facedir(vector.subtract(
					pointed_thing.above, pointed_thing.under), true)

				local p2 = under.param2

				-- Placing a slab on an upside down slab should make it right-side up.
				if p2 >= 20 and dir == 8 then
					p2 = p2 - 20
				-- same for the opposite case: slab below normal slab
				elseif p2 <= 3 and dir == 4 then
					p2 = p2 + 20
				end

				-- else attempt to place node with proper param2
				core.item_place_node(ItemStack(wield_item), placer, pointed_thing, p2)
				if not core.is_creative_enabled(player_name) then
					itemstack:take_item()
				end
				return itemstack
			else
				return rotate_and_place(itemstack, placer, pointed_thing)
			end
		end,
	}))
end
