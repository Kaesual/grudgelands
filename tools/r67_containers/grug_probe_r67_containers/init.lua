-- Disposable Round 67 CONTAINERS probe (tools/r67_containers): logs
-- "R67 PROBE <check> PASS|FAIL <detail>" lines and "R67 PROBE DONE".
local C = default.containers
local function out(name, ok, detail)
	core.log("action", ("R67 PROBE %s %s %s"):format(name, ok and "PASS" or "FAIL", detail or ""))
end

local nodes_checks

local BASES = {"default:chest", "default:chest_locked", "default:bookshelf", "vessels:shelf"}

core.register_on_mods_loaded(function()
	for _, base in ipairs(BASES) do
		for tier = 1, 3 do
			local name = C.tier_name(base, tier)
			local def = core.registered_nodes[name]
			out("registered " .. name, def ~= nil and C.info(name) ~= nil,
				def and def.description or "")
			local recipes = grug_jobs.recipes_for_output(name)
			out("recipes " .. name, #recipes == 1, tostring(#recipes))
		end
	end
end)

core.after(2, function()
	-- The prices (resolved after load), the interaction guard on the shelves.
	for _, base in ipairs(BASES) do
		for tier = 1, 3 do
			local name = C.tier_name(base, tier)
			out("price " .. name, grug_traders.price_known(name),
				tostring(grug_traders.sell_price(name)))
		end
	end
	local report = grug_housing.interaction_guard_report or {fields = {}}
	local wrapped = {}
	for _, name in ipairs(report.fields) do wrapped[name] = true end
	out("guard on the shelves' fields", wrapped["default:bookshelf_abyssal"] and
		wrapped["vessels:shelf_steel"], tostring(#report.fields))

	-- A real node: an old 16-slot bookshelf grows; a chest upgrades.
	core.emerge_area({x = 0, y = 30000, z = 0}, {x = 4, y = 30000, z = 0},
		function(_, _, remaining)
			if remaining == 0 then core.after(0, nodes_checks) end
		end)
end)

nodes_checks = function()
	local pos = {x = 0, y = 30000, z = 0}
	core.set_node(pos, {name = "default:bookshelf"})
	local inv = core.get_meta(pos):get_inventory()
	inv:set_size("books", 16)
	inv:set_stack("books", 16, "default:book 2")
	C.ensure_size(pos)
	out("shelf grows", inv:get_size("books") == 32 and
		inv:get_stack("books", 16):to_string() == "default:book 2",
		inv:get_size("books") .. " " .. inv:get_stack("books", 16):to_string())

	local chest = {x = 2, y = 30000, z = 0}
	core.set_node(chest, {name = "default:chest", param2 = 3})
	local cinv = core.get_meta(chest):get_inventory()
	cinv:set_stack("main", 32, "default:book 5")
	core.get_meta(chest):set_string(C.LABEL_KEY, "Probe")
	C.update_infotext(chest)
	local player_inv = core.create_detached_inventory("r67_probe")
	player_inv:set_size("main", 32)
	player_inv:set_stack("main", 10, "grug_materials:steel_bar 9")
	local fake = {
		get_player_name = function() return "r67probe" end,
		get_inventory = function() return player_inv end,
		get_pos = function() return chest end,
	}
	-- The rights are the portable fixture's; here the engine's swap_node and
	-- set_size on a real node, so the stand-in player may build there.
	local is_protected = core.is_protected
	core.is_protected = function() return false end
	local ok, why = C.upgrade(chest, fake)
	core.is_protected = is_protected
	local node = core.get_node(chest)
	out("upgrade", ok and node.name == "default:chest_steel" and node.param2 == 3 and
		cinv:get_size("main") == 64 and cinv:get_stack("main", 32):to_string() == "default:book 5" and
		player_inv:get_stack("main", 10):get_count() == 1 and
		core.get_meta(chest):get_string("infotext") == "Probe\nSteel-Reinforced Chest",
		("%s %s %s %d %q"):format(tostring(ok), tostring(why), node.name,
			cinv:get_size("main"), core.get_meta(chest):get_string("infotext")))
	grug_inventory.sort_list(cinv, "main")
	out("chest sort", cinv:get_stack("main", 1):to_string() == "default:book 5",
		cinv:get_stack("main", 1):to_string())
	core.log("action", "R67 PROBE DONE")
end
