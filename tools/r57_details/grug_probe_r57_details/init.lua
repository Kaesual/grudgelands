-- Round 57 lane DETAILS engine probe (never shipped; staged with PROBE=).
-- At the first server step: build the source index of the loaded game with
-- the real grug_jobs/sources.lua and log the same numbers the portable
-- fixture prints, the gaps and the digest of every source line.
local modpath = core.get_modpath(core.get_current_modname())
local digest = dofile(modpath .. "/digest.lua")
core.after(0, function()
	local S = grug_jobs.sources or dofile(core.get_modpath("grug_jobs") .. "/sources.lua")
	local started = core.get_us_time()
	local index = S.build(S.game_data())
	local micros = core.get_us_time() - started
	local tokens, seen = {}, {}
	local function note(token)
		if not seen[token] then seen[token] = true; tokens[#tokens + 1] = token end
	end
	for _, record in ipairs(grug_jobs.recipes) do
		for _, entry in ipairs(record.ingredients) do note(grug_jobs.ingredient_token(entry)) end
	end
	for _, ref in ipairs(grug_professions.enchant_data.referenced_items(grug_professions.ENCHANT_DATA)) do
		note(ref.item)
	end
	table.sort(tokens)
	local gaps = {}
	for _, token in ipairs(tokens) do
		if not index.has_source(token) then gaps[#gaps + 1] = token end
	end
	local with, total = 0, 0
	for _, list in pairs(index.by_item) do with = with + 1; total = total + #list end
	local registered = 0
	for _ in pairs(core.registered_items) do registered = registered + 1 end
	local text = digest(index)
	core.log("action", ("[r57probe] items=%d recipes=%d with=%d sources=%d tokens=%d gaps=%s " ..
		"build_ms=%.1f digest=%s"):format(registered, #grug_jobs.recipes, with, total, #tokens,
		table.concat(gaps, ","), micros / 1000, core.sha256(text)))
	local handle = io.open(core.get_worldpath() .. "/r57probe_sources.txt", "w")
	if handle then handle:write(text); handle:close() end
end)
