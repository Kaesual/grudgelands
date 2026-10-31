-- Disposable engine probe (Round 68 lane TEXT): the compatibility path. A
-- 0.67.0 world has sign texts and chest labels in node meta and no text
-- entity. Boot 1 writes such nodes (meta only, no refresh) into a
-- persistently forceloaded block and shuts down; boot 2 (the same world,
-- tools/luanti_headless.sh ROOT=) finds the block activated at start and
-- logs the text entities the LBM made. Never shipped.

local P = "[r68lbm] "
local storage = core.get_mod_storage()
local POS = {x = 8, y = 200, z = 8}
local function log(msg) core.log("action", P .. msg) end

local function count()
	local n, names = 0, {}
	for _, obj in ipairs(core.get_objects_inside_radius(POS, 4)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "grug_text:text" then
			n = n + 1
			names[#names + 1] = core.pos_to_string(ent._grug_pos)
		end
	end
	return n, table.concat(names, " ")
end

-- Mapgen calls are refused during init: start a moment after the load.
core.after(1, function()
	local phase = storage:get_int("phase")
	if phase == 0 then
		core.emerge_area(POS, vector.add(POS, 4), function(_, _, remaining)
			if remaining > 0 then return end
			core.set_node(vector.offset(POS, 0, 0, 1), {name = "default:stone"})
			core.set_node(POS, {name = "default:sign_wall_wood", param2 = 4})
			core.get_meta(POS):set_string("text", "Written in 0.67.0")
			core.get_meta(POS):set_string("infotext", '"Written in 0.67.0"')
			local chest = vector.offset(POS, 2, 0, 0)
			core.set_node(chest, {name = "default:chest_locked_steel", param2 = 0})
			core.get_meta(chest):set_string("grug_label", "Old label")
			local sign2 = vector.offset(POS, -2, 0, 0)
			core.set_node(sign2, {name = "grug_materials:iron_sign_wall", param2 = 1})
			core.forceload_block(POS, false)
			storage:set_int("phase", 1)
			local n = count()
			log(("boot 1: nodes written with meta only; %d entities now"):format(n))
			core.after(2, function() core.request_shutdown("probe boot 1 done", false, 0) end)
		end)
	else
		core.after(7, function()
			local n, names = count()
			log(("boot 2: %d text entities after activation (expect 2: the sign and the chest; " ..
				"the empty iron sign none): %s"):format(n, names))
			log("boot 2 infotext: " .. core.get_meta(POS):get_string("infotext"))
			core.forceload_free_block(POS, false)
			core.request_shutdown("probe boot 2 done", false, 0)
		end)
	end
end)
