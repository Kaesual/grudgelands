-- The dual furnace node pair (task card T1; `items_crafting.md` §1.1/§3.0.2).
--
-- Ported from LotT `lottblocks/crafting.lua` (LGPL 2.1, GPL-3.0-or-later
-- compatible) at the pinned submodule commit recorded in VENDOR.md. What is
-- taken is the STATION: two material slots plus a separate fuel slot, an
-- either-order two-input matcher, one output, and a node timer rather than a
-- globalstep or an ABM (`crafting.lua:84,220`). None of its media is taken --
-- `lottblocks` art is CC BY-SA 3.0 and the two front faces are re-skinned from
-- the vendored minetest_game fronts instead (LICENSE-media.md).
--
-- Five deliberate departures from the upstream code, all toward
-- `mods/BASE/default/furnace.lua`, which is the pattern the rest of this game
-- already follows:
--
--   1. TIME IS `elapsed`, NOT ONE TICK. LotT adds exactly 1 to `fuel_time` and
--      `src_time` per call (`crafting.lua:103,107`), so a server that ran the
--      timer late -- or a mapblock that was unloaded and stepped forward in
--      one call -- loses the difference. This port consumes the `elapsed`
--      the engine hands it, like the normal furnace.
--   2. PROTECTION. LotT's `allow_metadata_inventory_*` never ask
--      `core.is_protected` (`crafting.lua:239-268`), so a protected furnace
--      could be emptied by anyone. Ours use the normal furnace's rule.
--   3. `can_dig` AND `on_blast` empty-check all three lists, and an output
--      that no longer fits is dropped rather than lost.
--   4. A BURNT FUEL'S LEFTOVER NEVER BLOCKS THE FUEL SLOT
--      (`furnace.lua:212-219`); neither LotT nor a naive port moves it out.
--   5. `src_time` BELONGS TO A RECIPE. Swapping the material slots mid-cook
--      drops the old recipe's progress instead of carrying it into the new
--      one -- which, with WP26's rising cook ladder, is what kept
--      `cook_time - src_time` from going negative (see the timer below).
--
-- Cook times are runtime calibration (task card §1, "No number freezing");
-- they live with the recipes in `recipes.lua`.

local function formspec(fuel_percent, item_percent)
	local fire = "image[2.75,1.5;1,1;default_furnace_fire_bg.png"
	local arrow = "image[3.9,1.5;1,1;gui_furnace_arrow_bg.png"
	if fuel_percent then
		fire = fire .. "^[lowpart:" .. fuel_percent ..
			":default_furnace_fire_fg.png]"
		arrow = arrow .. "^[lowpart:" .. item_percent ..
			":gui_furnace_arrow_fg.png^[transformR270]"
	else
		fire = fire .. "]"
		arrow = arrow .. "^[transformR270]"
	end
	return "size[8,8.5]" ..
		"list[context;input;2.25,0.5;2,1;]" ..
		"list[context;fuel;2.75,2.5;1,1;]" ..
		fire ..
		arrow ..
		"list[context;output;5,0.96;2,1;]" ..
		"list[current_player;main;0,4.25;8,1;]" ..
		"list[current_player;main;0,5.5;8,3;8]" ..
		"listring[context;output]" ..
		"listring[current_player;main]" ..
		"listring[context;input]" ..
		"listring[current_player;main]" ..
		"listring[context;fuel]" ..
		"listring[current_player;main]" ..
		default.get_hotbar_bg(0, 4.25)
end

local INACTIVE = "grug_smelting:dual_furnace"
local ACTIVE = "grug_smelting:dual_furnace_active"

grug_smelting.NODE = INACTIVE
grug_smelting.NODE_ACTIVE = ACTIVE

local function can_dig(pos)
	local inv = core.get_meta(pos):get_inventory()
	return inv:is_empty("input") and inv:is_empty("output") and
		inv:is_empty("fuel")
end

local function is_fuel(stack)
	return core.get_craft_result({method = "fuel", width = 1,
		items = {stack}}).time ~= 0
end

local function allow_put(pos, listname, index, stack, player)
	if core.is_protected(pos, player:get_player_name()) then
		return 0
	end
	if listname == "fuel" then
		-- Mined Coal in the FUEL slot is fuel and nothing else; it never
		-- stands in for the Coal a Steel Bar consumes (§3.0.2, gate 2).
		return is_fuel(stack) and stack:get_count() or 0
	elseif listname == "output" then
		return 0
	end
	return stack:get_count()
end

local function allow_move(pos, from_list, from_index, to_list, to_index,
		count, player)
	local inv = core.get_meta(pos):get_inventory()
	return allow_put(pos, to_list, to_index,
		inv:get_stack(from_list, from_index), player)
end

local function allow_take(pos, listname, index, stack, player)
	if core.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end

local function swap_node(pos, name)
	local node = core.get_node(pos)
	if node.name == name then
		return
	end
	node.name = name
	core.swap_node(pos, node)
end

local function add_or_drop(inv, pos, item)
	local leftover = inv:add_item("output", item)
	if not leftover:is_empty() then
		core.item_drop(leftover, nil,
			core.find_node_near(pos, 1, {"air"}) or vector.offset(pos, 0, 1, 0))
	end
end

-- The recipe the two material slots currently match, or nil.
local function matched(inv)
	return grug_smelting.match(inv:get_stack("input", 1):get_name(),
		inv:get_stack("input", 2):get_name())
end

local function dual_furnace_timer(pos, elapsed)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	local fuel_time = meta:get_float("fuel_time") or 0
	local src_time = meta:get_float("src_time") or 0
	local fuel_totaltime = meta:get_float("fuel_totaltime") or 0

	-- WHICH recipe `src_time` belongs to. Without it, swapping the two
	-- material slots mid-cook carries the old recipe's progress into the new
	-- one, and if the new one is SHORTER than the progress already made,
	-- `cook_time - src_time` below goes negative: the bar finishes instantly,
	-- `fuel_time + step` runs the fuel backwards and `elapsed - step` makes
	-- the remaining budget grow. `default/furnace.lua:159-162` has the same
	-- two lines, but there it is latent because nearly every cooktime in that
	-- game is 3 s; WP26 deliberately ships a 4/6/8/10/12 s ladder, so the
	-- exploit is reachable by hand (review 2026-09-16, finding 1).
	--
	-- Progress on one alloy is not progress on another, so the honest fix is
	-- to drop it when the matched recipe changes.
	local src_recipe = meta:get_string("src_recipe")

	local recipe, fuel
	local output_full = false
	local update = true
	while elapsed > 0 and update do
		update = false
		recipe = matched(inv)
		local cook_time = recipe and recipe.time or 0

		local recipe_name = recipe and recipe.output or ""
		if recipe_name ~= src_recipe then
			src_time = 0
			src_recipe = recipe_name
		end

		local step = math.min(elapsed, fuel_totaltime - fuel_time)
		if recipe then
			step = math.min(step, cook_time - src_time)
		end
		-- Belt and braces. The reset above is what makes a negative `step`
		-- unreachable today; this keeps it unreachable if a later change ever
		-- lets `src_time` outrun its own recipe again.
		if step < 0 then
			step = 0
		end

		if fuel_time < fuel_totaltime then
			fuel_time = fuel_time + step
			if recipe then
				src_time = src_time + step
				if src_time >= cook_time then
					if inv:room_for_item("output", recipe.output) then
						-- EXACTLY ONE OF EACH, both slots, every time (§3.3,
						-- gate 3). The matcher already proved both slots hold
						-- a material, so neither take_item can come back
						-- empty.
						for slot = 1, grug_smelting.INPUT_SLOTS do
							local stack = inv:get_stack("input", slot)
							stack:take_item(1)
							inv:set_stack("input", slot, stack)
						end
						inv:add_item("output", recipe.output)
						src_time = src_time - cook_time
						update = true
					else
						output_full = true
					end
				else
					update = true
				end
			end
		else
			if recipe then
				local afterfuel
				fuel, afterfuel = core.get_craft_result({method = "fuel",
					width = 1, items = inv:get_list("fuel")})
				if fuel.time == 0 then
					fuel_totaltime = 0
					src_time = 0
				else
					-- Do not let a burnt fuel's leftover BLOCK the fuel slot.
					-- A lava bucket burns and hands back an empty bucket,
					-- which is not fuel; written straight back it would sit
					-- in the one fuel slot for ever and the furnace would
					-- never refuel again. `default/furnace.lua:212-219` moves
					-- such a leftover out instead, and so does this port
					-- (review 2026-09-16, finding 6). No fuel Grudgelands
					-- ships has a leftover today; the KAT feeds a synthetic
					-- one so the branch is not written blind.
					local leftover = afterfuel.items[1]
					if leftover:is_empty() or is_fuel(leftover) then
						inv:set_stack("fuel", 1, leftover)
					else
						inv:set_stack("fuel", 1, "")
						add_or_drop(inv, pos, leftover)
					end
					if fuel.replacements[1] then
						add_or_drop(inv, pos, fuel.replacements[1])
					end
					fuel_totaltime = fuel.time + (fuel_totaltime - fuel_time)
					update = true
				end
			else
				fuel_totaltime = 0
				src_time = 0
			end
			fuel_time = 0
		end

		elapsed = elapsed - step
	end

	if fuel and fuel_totaltime > fuel.time then
		fuel_totaltime = fuel.time
	end
	if not recipe then
		src_time = 0
		src_recipe = ""
	end

	local item_percent, item_state = 0, "Empty"
	if recipe then
		item_percent = math.floor(src_time / recipe.time * 100)
		item_state = output_full and "100% (output full)" or
			(item_percent .. "%")
	elseif not inv:is_empty("input") then
		item_state = "No alloy for this input"
	end

	local active = fuel_totaltime ~= 0
	local fuel_state, fuel_percent = "Empty", nil
	if active then
		fuel_percent = 100 - math.floor(fuel_time / fuel_totaltime * 100)
		fuel_state = fuel_percent .. "%"
		swap_node(pos, ACTIVE)
	else
		if not inv:is_empty("fuel") then
			fuel_state = "0%"
		end
		swap_node(pos, INACTIVE)
		core.get_node_timer(pos):stop()
	end

	meta:set_float("fuel_totaltime", fuel_totaltime)
	meta:set_float("fuel_time", fuel_time)
	meta:set_float("src_time", src_time)
	meta:set_string("src_recipe", src_recipe)
	meta:set_string("formspec", formspec(fuel_percent, item_percent))
	meta:set_string("infotext", (active and "Dual Furnace active" or
		"Dual Furnace inactive") .. "\n(Item: " .. item_state ..
		"; Fuel: " .. fuel_state .. ")")
	return active
end

grug_smelting.timer = dual_furnace_timer

local function start_timer(pos)
	core.get_node_timer(pos):start(1.0)
end

local function register(name, active)
	local groups = {cracky = 2}
	local front = "grug_smelting_dual_furnace_front.png"
	if active then
		groups.not_in_creative_inventory = 1
		front = {
			name = "grug_smelting_dual_furnace_front_active.png",
			backface_culling = false,
			animation = {type = "vertical_frames", aspect_w = 16,
				aspect_h = 16, length = 1.5},
		}
	end
	local def = {
		description = "Dual Furnace",
		tiles = {
			"default_furnace_top.png", "default_furnace_bottom.png",
			"default_furnace_side.png", "default_furnace_side.png",
			"default_furnace_side.png", front,
		},
		paramtype2 = "facedir",
		groups = groups,
		is_ground_content = false,
		sounds = default.node_sound_stone_defaults(),
		drop = INACTIVE,
		can_dig = can_dig,
		on_timer = dual_furnace_timer,
		on_metadata_inventory_move = start_timer,
		on_metadata_inventory_put = start_timer,
		on_metadata_inventory_take = start_timer,
		on_blast = function(blast_pos)
			local drops = {}
			default.get_inventory_drops(blast_pos, "input", drops)
			default.get_inventory_drops(blast_pos, "output", drops)
			default.get_inventory_drops(blast_pos, "fuel", drops)
			drops[#drops + 1] = INACTIVE
			core.remove_node(blast_pos)
			return drops
		end,
		allow_metadata_inventory_put = allow_put,
		allow_metadata_inventory_move = allow_move,
		allow_metadata_inventory_take = allow_take,
	}
	if active then
		def.light_source = 8
	else
		-- Only the placeable node builds its inventory; the active node is
		-- only ever swapped in over one that already has it.
		def.on_construct = function(pos)
			local meta = core.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size("input", grug_smelting.INPUT_SLOTS)
			inv:set_size("output", 2)
			inv:set_size("fuel", 1)
			dual_furnace_timer(pos, 0)
		end
	end
	default.set_inventory_action_loggers(def, "dual furnace")
	core.register_node(name, def)
end

register(INACTIVE, false)
register(ACTIVE, true)
