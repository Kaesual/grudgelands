-- Round 28 Lane A3 measurement probe. Writes one TSV row per registered mesh
-- entity (name, mesh, visual_size, collisionbox, selectionbox, mobs_redo
-- rotate, stand/walk/fly frame ranges) to <world>/r28a3_entities.tsv for
-- tools/r28_a3/mesh_bounds.py.

local function box_str(b)
	if type(b) ~= "table" then return "nil" end
	return string.format("%g,%g,%g,%g,%g,%g%s", b[1] or 0, b[2] or 0, b[3] or 0,
		b[4] or 0, b[5] or 0, b[6] or 0, b.rotate and ",rotate" or "")
end

core.register_on_mods_loaded(function()
	local names = {}
	for name, def in pairs(core.registered_entities) do
		local p = def.initial_properties or def
		if p.visual == "mesh" then names[#names + 1] = name end
	end
	table.sort(names)
	local out = {}
	for _, name in ipairs(names) do
		local def = core.registered_entities[name]
		local p = def.initial_properties or def
		local vs = p.visual_size or {x = 1, y = 1}
		local anim = def.animation or {}
		local ranges = {}
		for _, clip in ipairs({"stand", "walk", "fly"}) do
			local s, e = anim[clip .. "_start"], anim[clip .. "_end"]
			if s and e then ranges[#ranges + 1] = s .. "-" .. e end
		end
		out[#out + 1] = table.concat({name, tostring(p.mesh), tostring(vs.x),
			tostring(vs.y), box_str(p.collisionbox), box_str(p.selectionbox),
			tostring(def.rotate or 0), table.concat(ranges, ",")}, "\t")
	end
	local f = io.open(core.get_worldpath() .. "/r28a3_entities.tsv", "w")
	f:write(table.concat(out, "\n") .. "\n")
	f:close()
	core.log("action", "[r28a3] dumped " .. #out .. " mesh entities")
end)
