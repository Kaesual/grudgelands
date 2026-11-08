-- Disposable boot check of Round 72 lane GUARDNAV (the lane's smoke boot):
-- `PROBE=tools/r72_guardnav/grug_check_r72_guardnav tools/luanti_headless.sh 150`.
-- Logs, after every mod loaded, which registered grug mobs carry the switch
-- `_grug_reach_reset` on their prototype (aggro.lua grug_mobs.reach_reset reads it),
-- the leader sub-types among them, and whether the navigation's strict rule is
-- installed. Lines carry "[r72guardnav-defs]".
core.register_on_mods_loaded(function()
	local on, leaders, others = {}, 0, 0
	local leader_rows = 0
	for _, sub in pairs(grug_mobs.subtypes) do
		if sub.leader then leader_rows = leader_rows + 1 end
	end
	for name, def in pairs(core.registered_entities) do
		if name:sub(1, 10) == "grug_mobs:" and def._grug_reach_reset then
			local role = name:sub(11)
			local sub = grug_mobs.subtypes[role]
			if sub then
				if sub.leader then leaders = leaders + 1 else others = others + 1 end
			else
				on[#on + 1] = name
			end
		end
	end
	table.sort(on)
	core.log("action", "[r72guardnav-defs] switched on (not sub-types): " .. table.concat(on, " "))
	core.log("action", ("[r72guardnav-defs] leader sub-types switched on: %d of %d, other sub-types: %d")
		:format(leaders, leader_rows, others))
	for _, name in ipairs({"grug_mobs:wolf", "grug_mobs:boar", "grug_mobs:bandit",
			"grug_mobs:king_human", "grug_mobs:general_accord", "grug_mobs:bodyguard_accord"}) do
		local def = core.registered_entities[name]
		core.log("action", ("[r72guardnav-defs] %s %s"):format(name,
			def and tostring(def._grug_reach_reset == true) or "not registered"))
	end
	core.log("action", "[r72guardnav-defs] strict rule installed: "
		.. tostring(mobs.grug_nav.strict == grug_mobs.reach_reset))
end)
