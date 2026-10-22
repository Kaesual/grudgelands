-- Disposable probe for tools/building_templates: writes the part of every
-- registered node definition the template tools need (the viewer's drawing
-- fields, the validator's walkable/box/light/group fields) and the alias table
-- to <world>/template_nodes.json once all mods are loaded, then asks the server
-- to shut down. Staged only through `PROBE=` of tools/luanti_headless.sh (see
-- tools/building_templates/node_dump/refresh.sh); never shipped.

local FIELDS = {"drawtype", "tiles", "overlay_tiles", "special_tiles",
	"node_box", "connects_to", "connect_sides", "mesh", "paramtype",
	"paramtype2", "visual_scale", "use_texture_alpha", "color", "palette",
	"waving", "place_param2", "light_source", "liquidtype", "leveled",
	"groups", "walkable", "collision_box", "selection_box", "climbable",
	"buildable_to"}

core.register_on_mods_loaded(function()
	local nodes = {}
	for name, def in pairs(core.registered_nodes) do
		local out = {}
		-- def[key] goes through the registration defaults (__index), so a
		-- field the mod left out is written with the engine's default.
		for _, key in ipairs(FIELDS) do
			local value = def[key]
			if type(value) ~= "function" and type(value) ~= "userdata" then
				out[key] = value
			end
		end
		if type(def.description) == "string" and def.description ~= "" then
			-- The first line only: the name the editor's item list shows.
			local text = core.strip_colors(
				core.get_translated_string("en", def.description))
			out.description = text:match("^[^\n]*")
		end
		nodes[name] = out
	end
	local payload = assert(core.write_json({nodes = nodes,
		aliases = core.registered_aliases}))
	local path = core.get_worldpath() .. "/template_nodes.json"
	local file = assert(io.open(path, "w"))
	file:write(payload)
	file:close()
	core.log("action", "[grug_template_node_dump] wrote " .. path)
	core.after(0, function() core.request_shutdown("template node dump done") end)
end)
