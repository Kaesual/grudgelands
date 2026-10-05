-- Round 35 lane F engine probe, staged by tools/r35_f/engine.sh only.
local function out(text) core.log("action", "[r35f] " .. text) end

core.register_on_mods_loaded(function()
	core.after(0, function()
		-- Every sound file of every mod: base names and their .N variants.
		local files = {}
		for _, mod in ipairs(core.get_modnames()) do
			for _, file in ipairs(core.get_dir_list(core.get_modpath(mod) .. "/sounds", false) or {}) do
				local base = file:match("^(.+)%.ogg$")
				if base then files[base] = true; files[base:gsub("%.%d+$", "")] = true end
			end
		end
		local nodes, failures = 0, 0
		local names = {}
		for name in pairs(core.registered_nodes) do names[#names + 1] = name end
		table.sort(names)
		for _, name in ipairs(names) do
			local def = core.registered_nodes[name]
			local groups = def.groups or {}
			if (groups.grug_resource or 0) > 0 or (groups.grug_loose or 0) > 0 then
				nodes = nodes + 1
				local dig = def.sounds and def.sounds.dig
				local sound = type(dig) == "table" and dig.name or dig
				local ok = type(sound) == "string" and files[sound] == true
				if not ok then failures = failures + 1 end
				out(("DIG %s %s %s gain=%s"):format(ok and "OK" or "FAIL", name, tostring(sound),
					tostring(type(dig) == "table" and dig.gain or "?")))
			end
		end
		out(("DIG nodes=%d failures=%d"):format(nodes, failures))
		local flint = rawget(core.registered_items, "default:flint") ~= nil
		local gravel = core.registered_nodes["default:gravel"].drop
		out(("FLINT registered=%s gravel_drop=%s"):format(tostring(flint), core.serialize(gravel):gsub("^return ", "")))
		local titles = 0
		for id, def in pairs(grug_quests.registered_quests) do
			titles = titles + 1
			out(("TITLE %d %s %s%s"):format(#def.title, id, def.title, def.repeatable and " [R]" or ""))
		end
		out(("RESULT DONE titles=%d dig_failures=%d flint=%s"):format(titles, failures, tostring(flint)))
	end)
end)
