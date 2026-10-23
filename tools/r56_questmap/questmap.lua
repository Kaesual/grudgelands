-- Round 56 lane QUESTMAP: one self-contained HTML page of every shipped
-- quest and its chains, the input for the quest rework (round56-plan §4, §8).
--
--   luajit tools/r56_questmap/questmap.lua [REPO] [--out FILE] [--data DIR] [--intro TEXT]
--
-- --data DIR (Round 57): the quest files of DIR/data/zones instead of the
-- shipped ones (a lane's draft, a fixture's sample; model.lua).
-- --intro TEXT (Round 58): a paragraph under the title (how to read a
-- lane's page).
-- REPO defaults to the current directory; FILE to
-- ~/projects/grudgelands-orchestration/r56/questmap/index.html (the folder
-- must exist). The quests come from the real loader (model.lua), the flags
-- from flags.lua; page.html is the page with its CSS and JS, the data goes in
-- as one JSON block. No network, nothing written into the repository.
-- Loaded by dofile from another script it returns build(repo, out), which
-- writes the page and returns its text and the summary line.
local function build(repo, out, data_root, intro)
	local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")
	local model = dofile(repo .. "/tools/r56_questmap/model.lua")(repo, data_root)
	local F = dofile(repo .. "/tools/r56_questmap/flags.lua")
	local facts = F.analyse(model.quests, model.zones)

	-- Every quest it needs, sorted by depth then id (the facts keep the count).
	local by_id = {}
	for _, quest in ipairs(model.quests) do by_id[quest.id] = quest end
	local function all_before(quest)
		local set, list = {}, {}
		local function visit(id)
			for _, prior in ipairs(by_id[id] and by_id[id].requires or {}) do
				if not set[prior] then
					set[prior] = true
					list[#list + 1] = prior
					visit(prior)
				end
			end
		end
		visit(quest.id)
		table.sort(list, function(a, b)
			local da, db = facts.by_id[a].depth, facts.by_id[b].depth
			if da ~= db then return da < db end
			return a < b
		end)
		return list
	end

	for _, quest in ipairs(model.quests) do
		local f = facts.by_id[quest.id]
		for _, key in ipairs({"ancestors", "depth", "unlocks", "kill_chain", "family_zones", "family_starts",
				"reward_items", "flags"}) do
			quest[key] = f[key]
		end
		quest.all_before = all_before(quest)
		local peers = {}
		if f.family and f.family_zones >= 2 then
			for _, id in ipairs(facts.families[f.family]) do
				if id ~= quest.id then peers[#peers + 1] = id end
			end
		end
		quest.family_peers = peers
	end

	-- Families that span two or more zones, the largest first.
	local families = {}
	for key, ids in pairs(facts.families) do
		local zones, n = {}, 0
		for _, id in ipairs(ids) do
			if not zones[by_id[id].zone] then zones[by_id[id].zone] = true; n = n + 1 end
		end
		if n >= 2 then families[#families + 1] = {key = key, ids = ids, zones = n} end
	end
	table.sort(families, function(a, b)
		if a.zones ~= b.zones then return a.zones > b.zones end
		if #a.ids ~= #b.ids then return #a.ids > #b.ids end
		return a.key < b.key
	end)

	for _, zone in ipairs(model.zones) do
		for _, hub in ipairs(zone.hubs) do
			for _, giver in ipairs(hub.givers) do
				giver.name = model.npcs[giver.npc] and model.npcs[giver.npc].name or giver.npc
			end
		end
	end

	local commit
	do
		local handle = io.popen('git -C "' .. repo .. '" rev-parse --short HEAD 2>/dev/null')
		commit = handle and handle:read("*l") or nil
		if handle then handle:close() end
	end

	local data = json.encode({
		meta = {commit = commit or false, intro = intro or false, draft = data_root ~= nil},
		limits = facts.limits,
		zones = model.zones,
		quests = model.quests,
		families = families,
	})
	-- Safe inside <script>: no "</" can close the element early.
	data = data:gsub("</", "<\\/")

	local handle = assert(io.open(repo .. "/tools/r56_questmap/page.html", "r"))
	local page = handle:read("*a")
	handle:close()
	local at = assert(page:find("__QUESTMAP_DATA__", 1, true), "page.html has no data marker")
	page = page:sub(1, at - 1) .. data .. page:sub(at + #"__QUESTMAP_DATA__")

	local file = assert(io.open(out, "w"))
	file:write(page)
	file:close()
	local flagged = {}
	for _, quest in ipairs(model.quests) do
		for _, name in ipairs(quest.flags) do flagged[name] = (flagged[name] or 0) + 1 end
	end
	local parts = {}
	for _, name in ipairs({"start_twin", "repeated", "reward_is_request", "kill_chain", "deep"}) do
		parts[#parts + 1] = name .. " " .. (flagged[name] or 0)
	end
	local summary = (("questmap: %d quests, %d zones, %d repeated families; %s; %d load warnings -> %s (%d bytes)")
		:format(#model.quests, #model.zones, #families, table.concat(parts, ", "), #model.warnings, out, #page))
	for _, message in ipairs(model.warnings) do summary = summary .. "\n  " .. message end
	return page, summary
end

if not (arg and arg[0] and arg[0]:find("questmap%.lua$")) then return build end
local repo, out, data_root, intro = ".", nil, nil, nil
local i = 1
while arg[i] do
	if arg[i] == "--out" then
		out = arg[i + 1]
		i = i + 1
	elseif arg[i] == "--data" then
		data_root = arg[i + 1]
		i = i + 1
	elseif arg[i] == "--intro" then
		intro = arg[i + 1]
		i = i + 1
	else
		repo = arg[i]
	end
	i = i + 1
end
local _, summary = build(repo, out or ((os.getenv("HOME") or ".") ..
	"/projects/grudgelands-orchestration/r56/questmap/index.html"), data_root, intro)
print(summary)
