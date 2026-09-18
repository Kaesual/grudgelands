return function(root)
	if type(root) ~= "string" or root:sub(1, 1) ~= "/" then
		error("absolute repository root required", 0)
	end
	local mutation = os.getenv("R8_ALCH_MUTATION") or ""
	local function check(ok, label)
		if not ok then error("R8-ALCH stand KAT: " .. label, 0) end
	end
	local nodes, lbm, receive_fields
	local sizes, strings = {}, {}
	local inventory = {
		get_size = function(_, listname) return sizes[listname] or 0 end,
		set_size = function(_, listname, size) sizes[listname] = size end,
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
	}
	default = {
		get_hotbar_bg = function() return "" end,
		node_sound_metal_defaults = function() return {} end,
		set_inventory_action_loggers = function() end,
	}
	vector = {offset = function(pos) return pos end}
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
	return "R8-ALCH stand KAT PASS nodes=2 nodeboxes=3 inventory=fuel,reagent,vial,output\n"
end
