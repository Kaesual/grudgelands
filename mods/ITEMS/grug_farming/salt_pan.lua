-- The salt pan (Round 48, plant-growth-plan.md §2.15-§2.16, §3.11-§3.12):
-- salt is no plant. A crafted pan stands on any solid ground and collects
-- Salt Crust while water (group:water) is within WATER_RADIUS of it: four
-- fill stages of STAGE_SECONDS each, no light needed, the progress kept while
-- the water is gone. Right-click on a full pan scrapes one Salt Crust and
-- empties it to stage 1; digging returns the pan (and the crust of a full
-- one). The pan wears the wild salt basin's look (grug_nodes.crop_visual
-- "salt_crust") and runs on its own node timer: the crop timers hang on the
-- farm soil below a crop, which a pan on stone does not have, so a small
-- timer of its own is simpler than a crop profile flag.
--
-- `farm` carries the shared numbers and the harvest helper of init.lua.
return function(farm)
	local ITEM = "grug_farming:salt_pan"
	local SALT = "grug_cooking:salt_crust"
	local STAGES, STAGE_SECONDS = farm.STAGES, farm.STAGE_SECONDS
	-- The water check runs at the soil check's pace.
	local CHECK_SECONDS = farm.SOIL_INTERVAL
	local PROGRESS_META = "grug_salt_progress"

	local stage_of = {}
	local function stage_name(stage) return ITEM .. "_" .. stage end

	local function liquid(definition)
		return definition.liquidtype ~= nil and definition.liquidtype ~= "none"
	end

	local function start_timer(pos)
		core.get_node_timer(pos):start(CHECK_SECONDS)
	end

	local function fill_timer(pos, elapsed)
		local stage = stage_of[core.get_node(pos).name]
		if not stage or stage >= STAGES then return false end
		-- No water: nothing accrues; the next check comes as usual.
		if not core.find_node_near(pos, farm.WATER_RADIUS, {"group:water"}) then
			return true
		end
		local meta = core.get_meta(pos)
		local progress = meta:get_float(PROGRESS_META) + elapsed
		local advance = math.floor(progress / STAGE_SECONDS)
		if advance >= 1 then
			stage = math.min(STAGES, stage + advance)
			core.swap_node(pos, {name = stage_name(stage)})
			progress = stage >= STAGES and 0 or progress - advance * STAGE_SECONDS
		end
		meta:set_float(PROGRESS_META, progress)
		return stage < STAGES
	end

	local function scrape(pos, node, clicker, itemstack)
		if not clicker or not clicker:is_player() or
				clicker:get_player_control().sneak then return itemstack end
		if stage_of[node.name] ~= STAGES then return itemstack end
		local name = clicker:get_player_name()
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return itemstack
		end
		core.swap_node(pos, {name = stage_name(1)})
		core.get_meta(pos):set_float(PROGRESS_META, 0)
		start_timer(pos)
		farm.give_harvest(clicker, pos, SALT)
		return itemstack
	end

	-- On the top face of any walkable, solid node that is no liquid; into a
	-- free (buildable, not liquid) cell; both the usual player protection.
	local function place(itemstack, placer, pointed_thing)
		local clicked = grug_core.node_rightclick(itemstack, placer, pointed_thing)
		if clicked then return clicked end
		if not pointed_thing or pointed_thing.type ~= "node" then return itemstack end
		local under = core.get_node(pointed_thing.under)
		local under_definition = core.registered_nodes[under.name]
		local pos = under_definition and under_definition.buildable_to and
			pointed_thing.under or pointed_thing.above
		local target = core.registered_nodes[core.get_node(pos).name]
		local support = core.registered_nodes[core.get_node(
			{x = pos.x, y = pos.y - 1, z = pos.z}).name]
		if not target or not target.buildable_to or liquid(target) or
				not support or not support.walkable or support.buildable_to or
				liquid(support) then
			return itemstack
		end
		local name = placer and placer:get_player_name() or ""
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return itemstack
		end
		core.set_node(pos, {name = stage_name(1)})
		if not core.is_creative_enabled(name) then itemstack:take_item(1) end
		return itemstack
	end

	core.register_craftitem(ITEM, {
		description = "Salt Pan",
		inventory_image = "grug_farming_salt_pan.png",
		on_place = place,
	})

	for stage = 1, STAGES do
		local full = stage == STAGES
		stage_of[stage_name(stage)] = stage
		local definition = grug_nodes.crop_visual("salt_crust", stage,
			default.node_sound_metal_defaults(), "cultivated")
		local gameplay = {
			description = full and "Salt Pan (Full)" or "Salt Pan (Filling)",
			inventory_image = "grug_farming_salt_pan.png",
			wield_image = "grug_farming_salt_pan.png",
			selection_box = definition.node_box,
			buildable_to = false,
			floodable = false,
			groups = {snappy = 3, oddly_breakable_by_hand = 3, attached_node = 1,
				grug_salt_pan = stage, not_in_creative_inventory = 1},
			drop = full and {items = {{items = {ITEM}}, {items = {SALT}}}} or ITEM,
			on_construct = start_timer,
			on_timer = fill_timer,
			on_rightclick = scrape,
		}
		for key, value in pairs(gameplay) do definition[key] = value end
		core.register_node(stage_name(stage), definition)
	end

	return {item = ITEM, stage_name = stage_name, PROGRESS_META = PROGRESS_META}
end
