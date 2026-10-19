-- Round 52 lane GRAPH: loads grug_classes' graph files (talent_graph.lua,
-- talent_graph_preview.lua, talent_graph_ui.lua) into the stub world of
-- tools/r44_ts/harness.lua, after it, the way grug_classes/init.lua dofiles
-- them after talents_ui.lua. The engine calls they need beyond the harness
-- are stubbed and recorded:
--
--   local G = dofile(repo .. "/tools/r52_graph/graph_loader.lua")(repo, extra)
--
-- `extra` lists texture file names to pretend are shipped, besides the real
-- files of the two texture folders the page looks for. Returns {commands
-- (name -> chat command def), shown (every show_formspec call: {name,
-- formname, fs}), receive (the page's field handler), leave (its leave
-- handler), privileged (name -> true: who has `server`), textures (the
-- listing the page saw)}.

return function(repo, extra)
	local G = {commands = {}, shown = {}, privileged = {}, textures = {}}
	local saved = {}
	for _, key in ipairs({"get_modpath", "get_current_modname", "register_chatcommand",
			"register_on_player_receive_fields", "register_on_leaveplayer"}) do
		saved[key] = core[key]
	end
	local function exists(path)
		local handle = io.open(path, "rb")
		if handle then handle:close() end
		return handle ~= nil
	end
	-- The listing of a textures folder: every file the page could look for
	-- that exists there, plus `extra`.
	function core.get_dir_list(path)
		local mod = path:match("/([%w_]+)/textures$")
		local graph, list = grug_classes.graph, {}
		local wanted = {}
		for _, id in ipairs(graph.node_ids) do
			local def = graph.nodes[id]
			if mod == "grug_abilities" and def.ability then
				wanted[#wanted + 1] = "grug_abilities_skill_" .. def.ability .. ".png"
			elseif mod == "grug_classes" and not def.ability then
				wanted[#wanted + 1] = "grug_classes_talent_" .. id .. ".png"
			end
		end
		if mod == "grug_classes" then
			for _, tree_id in ipairs(graph.tree_ids) do
				wanted[#wanted + 1] = "grug_classes_tree_" .. tree_id .. ".png"
			end
		end
		for _, file in ipairs(wanted) do
			if exists(path .. "/" .. file) then list[#list + 1] = file end
		end
		for _, file in ipairs(extra or {}) do
			if file:match("^" .. (mod or "") .. "_") then list[#list + 1] = file end
		end
		for _, file in ipairs(list) do G.textures[file] = true end
		return list
	end
	function core.show_formspec(name, formname, fs)
		G.shown[#G.shown + 1] = {name = name, formname = formname, fs = fs}
	end
	function core.check_player_privs(name, privs)
		return privs.server == true and G.privileged[name] == true
	end
	core.get_modpath = function(mod) return repo .. "/mods/PLAYER/" .. mod end
	core.get_current_modname = function() return "grug_classes" end
	core.register_chatcommand = function(name, def) G.commands[name] = def end
	core.register_on_player_receive_fields = function(fn) G.receive = fn end
	core.register_on_leaveplayer = function(fn) G.leave = fn end
	for _, file in ipairs({"talent_graph.lua", "talent_graph_preview.lua",
			"talent_graph_ui.lua"}) do
		dofile(repo .. "/mods/PLAYER/grug_classes/" .. file)
	end
	for key, value in pairs(saved) do core[key] = value end
	return G
end
