--
-- TEMPORARY boot probe for the WP13 wave-3 fishing/axe increment. Staged into
-- a throwaway game copy by `tools/luanti_headless.sh` for one boot and never
-- merged: everything it prints is something the offline fixtures assert, read
-- back out of the ENGINE's own registry so that "the KAT says so" and "the
-- server agrees" are two statements and not one.
--
-- Every line starts `[fishprobe]`.
--

local function say(...)
	core.log("action", "[fishprobe] " .. table.concat({...}, " "))
end

-- Captured HERE and not inside a callback: `core.get_current_modname()` only
-- answers while a mod is loading and returns nil from `on_mods_loaded`.
local MODPATH = core.get_modpath(core.get_current_modname())

core.register_on_mods_loaded(function()
	--
	-- 1. THE ITEMS, as the engine registered them.
	--
	for _, name in ipairs({"grug_fishing:rod", "grug_fishing:cooked_fish",
			"grug_mobs:raw_fish", "default:axe_stone", "default:stick"}) do
		local def = core.registered_items[name]
		if not def then
			say("item", name, "MISSING")
		else
			local groups = {}
			for group, value in pairs(def.groups or {}) do
				groups[#groups + 1] = group .. "=" .. value
			end
			table.sort(groups)
			say("item", name, "image=" .. tostring(def.inventory_image),
				"liquids_pointable=" .. tostring(def.liquids_pointable),
				"range=" .. tostring(def.range),
				"sell=" .. tostring(def._grug_sell_price),
				"groups=" .. table.concat(groups, ","))
		end
	end

	--
	-- 2. THE WIELD POSE the shipped seam computes for each of them. This is the
	-- playtest-round-5 ruling in one line per item: the axe rolled, the rod a
	-- diagonal tool rather than an anonymous icon.
	--
	for _, name in ipairs({"default:axe_stone", "grug_gear:greataxe_steel",
			"grug_gear:sword_steel", "default:pick_bronze",
			"default:shovel_stone", "grug_fishing:rod", "default:stick",
			"grug_mobs:raw_fish"}) do
		local pose = grug_visuals.pose_for(name, core.get_item_group)
		local wield = grug_visuals.wield_transform(1, pose)
		say("pose", name, pose,
			"rot=" .. wield.rot.x .. "," .. wield.rot.y .. "," .. wield.rot.z,
			"pos=" .. string.format("%.3f,%.3f,%.3f", wield.pos.x, wield.pos.y,
				wield.pos.z))
	end

	--
	-- 3. THE CATCH TABLE, and that every name in it is a real registration.
	--
	local total = 0
	for _, entry in ipairs(grug_fishing.WORLD_CATCH) do
		total = total + entry.weight
		say("catch", entry.name, "x" .. entry.count, "w" .. entry.weight,
			"registered=" .. tostring(core.registered_items[entry.name] ~= nil))
	end
	say("catch_total", tostring(total), "declared",
		tostring(grug_fishing.CATCH_TOTAL), "bite",
		grug_fishing.MIN_WAIT .. ".." .. grug_fishing.MAX_WAIT)

	--
	-- 4. THE RECIPES, resolved by the engine's own craft registry rather than
	-- by reading our own register_craft calls back.
	--
	for _, name in ipairs({"grug_fishing:rod", "grug_fishing:cooked_fish"}) do
		local recipes = core.get_all_craft_recipes(name) or {}
		say("recipes", name, "count=" .. #recipes)
		for index, recipe in ipairs(recipes) do
			local items = {}
			for _, entry in pairs(recipe.items or {}) do
				items[#items + 1] = entry
			end
			table.sort(items)
			say("recipe", name, "#" .. index,
				"method=" .. tostring(recipe.method),
				"items=" .. table.concat(items, "+"))
		end
	end

	--
	-- 5. THE ANGLER'S ACTIVITY, read out of grug_mobs' own table.
	--
	local activity = grug_mobs.start_npc_activity("fish")
	if activity then
		say("activity", "fish", "anim=" .. tostring(activity.anim),
			"item=" .. tostring(activity.item),
			"registered=" ..
			tostring(core.registered_items[activity.item] ~= nil))
	else
		say("activity", "fish", "MISSING")
	end

	say("registry_done")
end)

--
-- 6. THE ANGLER, IN THE WORLD.
--
-- `run_npc_probe.sh`'s start programme inventories the FIRST registered
-- settlement, and that one has no `fish` socket, so it cannot answer the one
-- question this lane has to answer in an engine: does a villager standing on an
-- angler socket actually hold the rod? This phase does, and only that.
--
-- It forceloads the blocks around the socket the capital/start authored with
-- `activity = "fish"`, waits for the placement engine's own heartbeat to fill
-- it, and then reads the two fields grug_visuals writes on the entity -- the
-- wield entity's item and its pose -- rather than inferring them from the
-- ACTIVITY table it already printed above.
--
--
-- THE WATCH GATE, and the one switch this probe has.
--
-- `start_villagers.lua`'s work tick reaches its dressing block only past
-- `watched(self, pos)`, which asks `grug_mobs.nearest_player_d2` -- and that
-- returns nil with nobody connected (levels.lua: `visible = false -- nobody
-- connected`). A headless boot has no player, so on a FRESH world the dressing
-- block is never reached at all and every work resident stands empty-handed
-- whatever the wield seam does.
--
-- That is a property of the PROBE, not of the game, and the only honest way to
-- show it is to remove the one difference. `unwatch.lua` is NOT shipped in this
-- directory: the runner copies the probe to a scratch path and writes the file
-- in beside it for the second boot of the pair, so the same probe produces both
-- halves of the experiment and the shipped bytes never carry the override.
--
local watch_override = false

local function load_unwatch()
	local chunk = loadfile(MODPATH .. "/unwatch.lua")
	if not chunk then
		return false
	end
	chunk()
	return true
end

local ANGLER_SETTLEMENTS = {"kapok", "kezamba"}
local FORCE_REACH = 32
local DEADLINE = 200
local REPORT_EVERY = 10

local function forceload_area(anchor)
	local blocks = 0
	for dx = -FORCE_REACH, FORCE_REACH, 16 do
		for dz = -FORCE_REACH, FORCE_REACH, 16 do
			for dy = -16, 16, 16 do
				if core.forceload_block({x = anchor.x + dx, y = anchor.y + dy,
						z = anchor.z + dz}, true, -1) then
					blocks = blocks + 1
				end
			end
		end
	end
	return blocks
end

local targets = {}

core.register_on_mods_loaded(function()
	watch_override = load_unwatch()
	say("watch_override", tostring(watch_override))
	for _, key in ipairs(ANGLER_SETTLEMENTS) do
		local sockets = grug_core.settlement_sockets_at(key) or {}
		for _, socket in ipairs(sockets) do
			if socket.activity == "fish" then
				-- `socket.pos` is the WORLD-space vector grug_core computes
				-- (settlement_sockets.lua, "World space, decided here and
				-- nowhere else"); `socket.x/y/z` are the blueprint's own local
				-- coordinates and would point at the world origin.
				targets[#targets + 1] = {key = key, id = socket.id,
					pos = {x = socket.pos.x, y = socket.pos.y,
						z = socket.pos.z}}
				say("angler_socket", key, tostring(socket.id),
					core.pos_to_string(socket.pos),
					"local=" .. socket.x .. "," .. socket.y .. "," .. socket.z)
			end
		end
	end
	if #targets == 0 then
		say("angler_socket", "NONE FOUND")
	end
end)

local elapsed = 0
local reported = 0
local resolved = {}
local finished = false

core.register_globalstep(function(dtime)
	if finished then
		return
	end
	elapsed = elapsed + dtime
	if elapsed < reported + REPORT_EVERY then
		return
	end
	reported = elapsed

	local pending = 0
	for _, target in ipairs(targets) do
		if not resolved[target.id] then
			pending = pending + 1
			if not target.forced then
				target.forced = forceload_area(target.pos)
				say("forceload", target.key, target.id,
					"blocks=" .. target.forced)
			end
			local objects = core.get_objects_inside_radius(target.pos, 24)
			for _, object in ipairs(objects) do
				local entity = object:get_luaentity()
				if entity and entity._grug_work_activity == "fish" then
					-- The entity arriving is not the answer; the WIELD ENTITY
					-- arriving is. `sync_wield` leaves its fields empty when
					-- `add_entity` fails on a block that is not loaded yet and
					-- retries on the next pass, so this keeps looking until the
					-- hand is filled or the deadline runs out.
					say("angler", target.key, target.id,
						"t=" .. math.floor(elapsed),
						"entity=" .. tostring(entity.name),
						"activity=" .. tostring(entity._grug_work_activity),
						"wield_item=" .. tostring(entity._grug_wield_item),
						"wield_pose=" .. tostring(entity._grug_wield_pose),
						"wield_entity=" ..
						tostring(entity._grug_wield_obj ~= nil))
					if entity._grug_wield_item then
						resolved[target.id] = true
						pending = pending - 1
					end
					break
				end
			end
		end
	end
	say("wait", "t=" .. math.floor(elapsed), "pending=" .. pending,
		"players=" .. #core.get_connected_players(),
		"watch_override=" .. tostring(watch_override))
	if pending == 0 or elapsed >= DEADLINE then
		for _, target in ipairs(targets) do
			if not resolved[target.id] then
				say("angler", target.key, target.id,
					"NO ROD IN HAND within " .. math.floor(elapsed) .. "s")
			end
		end
		finished = true
		say("done")
	end
end)
