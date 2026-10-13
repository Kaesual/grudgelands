-- Round 47 lane OR engine probe (disposable, never shipped): the dig matrix.
--
-- After every mod has loaded, asks the engine's own core.get_dig_params for
-- every pick, axe and shovel (a `grug_pick_tier`, `grug_axe_tier` or
-- `grug_shovel_tier` group) and the hand over every registered node that a
-- tool's own capabilities dig or that carries a `level` group. One TSV row
-- per node: name, level, cracky, grug_resource, grug_stratum, grug_loose,
-- choppy, then per tool the dig time ("-" = not diggable by the tool's own
-- capabilities; the hand fallback is its own column). The table goes to
-- <world>/r47_or_dig_matrix.tsv; tools/r47_or/dig_table.py compares two of
-- them. Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r47_or_probe] "

local function tool_names()
	local names = {}
	for name, def in pairs(core.registered_tools) do
		local groups = def.groups or {}
		if (groups.grug_pick_tier or 0) > 0 or (groups.grug_axe_tier or 0) > 0 or
				(groups.grug_shovel_tier or 0) > 0 then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

local function format_time(params)
	if not params or not params.diggable then return "-" end
	return ("%.4f"):format(params.time)
end

local function survey()
	local tools = tool_names()
	local caps = {}
	for index, name in ipairs(tools) do
		caps[index] = ItemStack(name):get_tool_capabilities()
	end
	local hand = ItemStack(""):get_tool_capabilities()
	local header = {"node", "level", "cracky", "grug_resource", "grug_stratum",
		"grug_loose", "choppy", "hand"}
	for _, name in ipairs(tools) do header[#header + 1] = name end
	local rows = {table.concat(header, "\t")}
	local names = {}
	for name in pairs(core.registered_nodes) do names[#names + 1] = name end
	table.sort(names)
	local leveled = 0
	for _, name in ipairs(names) do
		local def = core.registered_nodes[name]
		local groups = def.groups or {}
		local cells, any = {}, (groups.level or 0) > 0
		for index = 1, #tools do
			local params = core.get_dig_params(groups, caps[index])
			cells[index] = format_time(params)
			if params and params.diggable then any = true end
		end
		if any and def.diggable ~= false then
			if (groups.level or 0) > 0 then leveled = leveled + 1 end
			local row = {name, groups.level or 0, groups.cracky or 0,
				groups.grug_resource or 0, groups.grug_stratum or 0,
				groups.grug_loose or 0, groups.choppy or 0,
				format_time(core.get_dig_params(groups, hand))}
			for index = 1, #cells do row[#row + 1] = cells[index] end
			for index = 1, #row do row[index] = tostring(row[index]) end
			rows[#rows + 1] = table.concat(row, "\t")
		end
	end
	local path = core.get_worldpath() .. "/r47_or_dig_matrix.tsv"
	local ok = core.safe_file_write(path, table.concat(rows, "\n") .. "\n")
	core.log("action", PREFIX .. ("tools=%d nodes=%d leveled=%d written=%s"):format(
		#tools, #rows - 1, leveled, tostring(ok)))
	core.log("action", PREFIX .. "RESULT " .. (ok and #rows > 1 and "PASS" or "FAIL"))
	core.request_shutdown("r47 or probe done", false, 0)
end

core.after(1, survey)
