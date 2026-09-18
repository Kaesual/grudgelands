return function(root)
	if type(root) ~= "string" or root:sub(1, 1) ~= "/" then
		error("absolute repository root required", 0)
	end
	local mutation = os.getenv("R8_ALCH_MUTATION") or ""
	local function check(ok, label)
		if not ok then error("R8-ALCH stand KAT: " .. label, 0) end
	end
	local nodes, lbm, receive_fields
	local timer_starts = 0
	local craft_allowed = false
	local craft_checks, craft_records = 0, 0
	local recipe = {profession = "alchemist", tier = 3,
		station = "brewing_stand"}
	local function stack(name, count)
		return {
			get_name = function() return name end,
			get_count = function() return count or 1 end,
		}
	end
	local sizes, strings = {}, {}
	local stacks = {output = {stack("grug_alchemy:potion_greater_healing", 3)}}
	local inventory = {
		get_size = function(_, listname) return sizes[listname] or 0 end,
		set_size = function(_, listname, size) sizes[listname] = size end,
		get_stack = function(_, listname, index)
			return stacks[listname] and stacks[listname][index] or stack("", 0)
		end,
	}
	local metadata = {
		get_inventory = function() return inventory end,
		get_string = function(_, key) return strings[key] or "" end,
		set_string = function(_, key, value) strings[key] = value end,
	}
	core = {
		register_node = function(name, def) nodes = nodes or {} nodes[name] = def end,
		register_lbm = function(def) lbm = def end,
		register_on_player_receive_fields = function(fn) receive_fields = fn end,
		get_craft_result = function() return {time = 0}, {items = {}} end,
		get_meta = function() return metadata end,
		get_item_group = function(name, group)
			return (name == "grug_cooking:carrot" or
				name == "grug_cooking:cassava") and
				group == "grug_cooking_root" and 1 or 0
		end,
		is_protected = function() return false end,
		get_node_timer = function()
			return {start = function() timer_starts = timer_starts + 1 end}
		end,
	}
	default = {
		get_hotbar_bg = function() return "" end,
		node_sound_metal_defaults = function() return {} end,
		set_inventory_action_loggers = function() end,
	}
	vector = {offset = function(pos) return pos end}
	grug_jobs = {
		recipe_for_output = function(_, station)
			check(station == "brewing_stand", "station-specific output lookup")
			return recipe
		end,
		can_craft_recipe = function()
			craft_checks = craft_checks + 1
			return craft_allowed
		end,
		record_craft = function(_, profession, tier)
			check(profession == "alchemist" and tier == 3,
				"recorded recipe identity")
			craft_records = craft_records + 1
		end,
	}
	grug_brewing = {}
	dofile(root .. "/mods/ITEMS/grug_brewing/node.lua")
	local inactive = nodes[grug_brewing.NODE]
	local active = nodes[grug_brewing.NODE_ACTIVE]
	check(inactive and active and inactive.drop == grug_brewing.NODE and
		active.drop == grug_brewing.NODE, "node pair")
	local boxes = inactive.node_box.fixed
	if mutation == "geometry" then boxes = {} end
	check(inactive.drawtype == "nodebox" and #boxes == 3 and
		active.light_source == 6, "stand geometry")
	local form = grug_brewing.formspec(nil, 0)
	check(form:find("list%[context;fuel;") and
		form:find("list%[context;reagent;") and
		form:find("list%[context;vial;") and
		form:find("list%[context;output;"), "four inventory roles")
	if mutation ~= "activation" then
		grug_brewing.ensure_inventory({x = 0, y = 0, z = 0})
	end
	check(sizes.reagent == 2 and sizes.vial == 1 and sizes.fuel == 1 and
		sizes.output == 2 and strings.formspec ~= "", "first access activation")
	check(lbm and lbm.run_at_every_load and #lbm.nodenames == 2,
		"blueprint activation")
	check(type(receive_fields) == "function" and
		type(inactive.on_rightclick) == "function", "interactive form")
	grug_brewing.register_recipe({station = "brewing_stand",
		flat_inputs = {"grug_gathering:gravemoss",
			"group:grug_cooking_root", "vessels:glass_bottle"},
		output = "grug_alchemy:potion_mana",
		output_name = "grug_alchemy:potion_mana", time = 5})
	local carrot = grug_brewing.match("grug_gathering:gravemoss",
		"grug_cooking:carrot", "vessels:glass_bottle")
	local cassava = grug_brewing.match("grug_cooking:cassava",
		"grug_gathering:gravemoss", "vessels:glass_bottle")
	if mutation == "root_alternative" then cassava = nil end
	check(carrot and cassava and carrot.output_name ==
		"grug_alchemy:potion_mana", "caster-root alternatives")

	local pos = {x = 0, y = 0, z = 0}
	local player = {is_player = function() return true end,
		get_player_name = function() return "tester" end}
	local output = stack("grug_alchemy:potion_greater_healing", 3)
	local denied = inactive.allow_metadata_inventory_take(pos, "output", 1,
		output, player)
	if mutation == "take_veto" then denied = output:get_count() end
	check(denied == 0 and craft_checks == 1 and craft_records == 0,
		"tier veto refuses take")
	craft_allowed = true
	local allowed_first = inactive.allow_metadata_inventory_take(pos, "output", 1,
		output, player)
	local allowed_second = inactive.allow_metadata_inventory_take(pos, "output", 1,
		output, player)
	if mutation == "take_allow_side_effect" then craft_records = craft_records + 1 end
	check(allowed_first == 3 and allowed_second == 3 and craft_checks == 3 and
		craft_records == 0, "repeated allow checks are side-effect free")
	check(inactive.allow_metadata_inventory_move(pos, "output", 1,
		"reagent", 1, 2, player) == 0, "output moves are blocked")
	inactive.on_metadata_inventory_take(pos, "output", 1, output, player)
	check(craft_records == 3 and timer_starts == 1,
		"actual take records exactly the removed count")
	return "R8-ALCH stand KAT PASS nodes=2 nodeboxes=3 inventory=fuel,reagent,vial,output roots=2 take=veto+count\n"
end
