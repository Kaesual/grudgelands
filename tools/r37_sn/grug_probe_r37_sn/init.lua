-- Round 37 SN probe: the sound names of grug_sounds' specs against the files
-- of every loaded mod's sounds/ folder (a server never warns about a missing
-- sound; the client would), and the registered Rift Spawn's sounds table.
core.register_on_mods_loaded(function()
	local files = {}
	for _, mod in ipairs(core.get_modnames()) do
		local dir = core.get_modpath(mod) .. "/sounds"
		for _, file in ipairs(core.get_dir_list(dir, false) or {}) do
			local base = file:match("^(.-)%.ogg$")
			if base then files[base] = true; files[base:gsub("%.%d+$", "")] = true end
		end
	end
	local missing, events = 0, 0
	for event, spec in pairs(grug_sounds.EVENTS) do
		events = events + 1
		if not files[spec.name] then
			missing = missing + 1
			core.log("action", "[r37sn] MISSING " .. event .. " -> " .. spec.name)
		end
	end
	local rift = core.registered_entities["grug_mobs:rift_spawn"]
	local sounds = rift and rift.sounds or {}
	core.log("action", ("[r37sn] RESULT DONE events=%d missing=%d fuse=%s explode=%s"):format(
		events, missing, tostring(sounds.fuse), tostring(sounds.explode)))
end)
