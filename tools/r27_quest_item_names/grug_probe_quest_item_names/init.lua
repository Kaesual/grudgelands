-- Disposable engine probe (Round 27 Lane Q). Never shipped:
-- tools/r27_quest_item_names/run.sh stages it through tools/luanti_headless.sh.
--
-- After every mod (and every on_mods_loaded tooltip override) has run, it
-- audits grug_core.item_name over the REAL item registry and renders every
-- registered quest through the real dialogue, quest-log and tracker code
-- with a player stand-in (a headless server has no client).

local P = "[quest_item_names_probe] "
local failures, checks = 0, 0
local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		if failures <= 40 then core.log("error", P .. "FAIL " .. msg) end
	end
	return ok
end

local STAT_PATTERNS = {"%%", "HP/", "%f[%a]HP%f[%A]", "Regenerat", "Restores", "Damage",
	"Durability", "Requires level", "Usable by", "^%s*Level", "%d+ uses", "Grants ",
	"Cannot eat", "Tier ", "Quality"}
local function stat_hit(text)
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		for _, pattern in ipairs(STAT_PATTERNS) do
			if line:find(pattern) then return pattern .. " in " .. ("%q"):format(line) end
		end
	end
	return nil
end
local function clean(text)
	return type(text) == "string" and text ~= "" and not text:find("\n", 1, true) and
		not text:find("\27", 1, true)
end
local function unescape(text) return (text:gsub("\\(.)", "%1")) end
local function element(form, prefix, from)
	local start = form:find(prefix, from or 1, true)
	if not start then return nil end
	local i, out = start + #prefix, {}
	while i <= #form do
		local c = form:sub(i, i)
		if c == "\\" then out[#out + 1] = form:sub(i, i + 1); i = i + 2
		elseif c == "]" then break
		else out[#out + 1] = c; i = i + 1 end
	end
	return unescape(table.concat(out)), i
end
local function lines_of(text)
	local out = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = line end
	return out
end
local function show(text) return (text:gsub("\27", "\\27"):gsub("\n", "\\n")) end

local function run()
	local Q = grug_quests
	-- 1. Every registered item: one plain line.
	local multiline, total = 0, 0
	for name, def in pairs(core.registered_items) do
		total = total + 1
		local got = grug_core.item_name(name)
		if type(def.description) == "string" and def.description:find("\n", 1, true) then
			multiline = multiline + 1
		end
		check(clean(got), "item name not one plain line: " .. name .. " -> " .. show(tostring(got)))
	end
	log(("registered items: %d, with multi-line tooltips: %d"):format(total, multiline))

	-- A probe-only quest after validation: a tool to bring, a food and a
	-- tool as rewards (no shipped quest rewards items yet).
	Q.register_npc("probe_giver", {settlement = "probe", socket = "quest", title = "Probe Giver"})
	Q.register_quest("zz_probe_rewards", {title = "Probe Rewards", description = "Probe.",
		npc = "probe_giver", objectives = {{type = "item", item = "grug_materials:pick_stone", count = 1}},
		rewards = {xp = 1, copper = 1, items = {"mobs:meat_raw 3", "grug_materials:axe_wood"}}})

	-- 2. Every quest item and reward item: name only, no stat line.
	local ids, items, seen = {}, {}, {}
	for id, def in pairs(Q.registered_quests) do
		ids[#ids + 1] = id
		for _, objective in ipairs(def.objectives) do
			if objective.item and not seen[objective.item] then
				seen[objective.item] = true; items[#items + 1] = objective.item
			end
		end
		for _, item in ipairs(def.rewards.items) do
			local name = ItemStack(item):get_name()
			if not seen[name] then seen[name] = true; items[#items + 1] = name end
		end
	end
	table.sort(ids)
	table.sort(items)
	for _, item in ipairs(items) do
		local got = grug_core.item_name(item)
		local description = core.registered_items[item].description or ""
		check(clean(got) and not stat_hit(got), "quest item name: " .. item .. " -> " .. show(got))
		log(("quest item %s: name %q; tooltip %s"):format(item, got, show(description)))
	end

	-- 3. Every quest through the real formatting code.
	local meta = {}
	local player = {}
	function player:get_player_name() return "probe_player" end
	function player:is_player() return true end
	function player:get_hp() return 20 end
	function player:get_pos() return vector.new(0, 0, 0) end
	function player:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end}
	end
	function player:get_inventory()
		return {get_list = function() return {} end, get_stack = function() return ItemStack("") end}
	end
	local faction, race = "accord", "human"
	local saved = {grug_factions.get_faction, grug_classes.get_race, grug_xp.get_level,
		core.show_formspec, sfinv.make_formspec}
	grug_factions.get_faction = function() return faction end
	grug_classes.get_race = function() return race end
	grug_xp.get_level = function() return 60 end
	local form
	core.show_formspec = function(_, _, text) form = text end
	sfinv.make_formspec = function(_, _, content) return content end
	local ok, err = pcall(function()
		local page = sfinv.pages["grug_quests:quests"]
		local sample = {}
		for _, id in ipairs(ids) do
			local def = Q.registered_quests[id]
			faction, race = def.faction or "accord", def.race or "human"
			check(not stat_hit(def.description), "hand-written stats: " .. id .. " " .. tostring(stat_hit(def.description)))
			local completed = {}
			for _, prior in ipairs(def.prerequisites) do completed[prior] = true end
			meta["grug_quests:state"] = core.serialize({active = {}, completed = completed, tracked = {}, hud = true})
			local selected
			for index, row in ipairs(Q.npc_quests(player, def.npc)) do if row.id == id then selected = index end end
			local npc = Q.registered_npcs[def.npc]
			local entity = {_grug_start = npc.settlement, _grug_socket = npc.socket, object = {
				is_valid = function() return true end, get_pos = function() return vector.new(0, 0, 0) end}}
			form = nil
			local detail = selected and Q.open_npc(player, entity, selected) and form and
				element(form, "textarea[4.7,0.9;6.8,6.4;description;;")
			if check(detail, "dialogue rendered: " .. id) then
				local want = #lines_of(def.description) + 1 + #def.objectives + 1 + 1 + #def.rewards.items
				check(#lines_of(detail) == want and not stat_hit(detail) and not detail:find("\27", 1, true),
					"dialogue: " .. id .. " " .. show(detail))
			end
			meta["grug_quests:state"] = core.serialize({active = {[id] = {}}, completed = completed,
				tracked = {id}, hud = true})
			local log_form = page.get(page, player, {grug_quest_selected = id})
			local _, after = element(log_form, "textarea[3.85,1.05;6.25,1.35;;;")
			local objectives = element(log_form, "textarea[3.85,2.35;6.25,1.55;;;", after) or ""
			local rewards = element(log_form, "textarea[3.85,4.00;6.25,0.75;;;") or ""
			check(#lines_of(objectives) == #def.objectives and not stat_hit(objectives) and
				clean(rewards) and not stat_hit(rewards), "quest log: " .. id .. " " .. show(objectives) ..
				" | " .. show(rewards))
			local hud = Q.hud_line(Q.journal(player).quests[1], 400)
			check(clean(hud) and not stat_hit(hud), "HUD: " .. id .. " " .. show(hud))
			local item = def.objectives[1].item
			if item and not sample[item] or id == "zz_probe_rewards" then
				if item then sample[item] = true end
				local stack_lines = {}
				for _, reward in ipairs(def.rewards.items) do
					local stack = ItemStack(reward)
					stack_lines[#stack_lines + 1] = show(stack:get_description()) .. " × " .. stack:get_count()
				end
				log(("sample %s (%s)"):format(id, tostring(item)))
				if item then
					log("  before dialogue objective: " .. show("Bring " ..
						(core.registered_items[item].description or item)))
				end
				if #stack_lines > 0 then log("  before dialogue rewards: " .. table.concat(stack_lines, " / ")) end
				log("  after dialogue: " .. show(table.concat(lines_of(detail or ""), " / ", #lines_of(def.description) + 2)))
				log("  after quest log: " .. show(objectives) .. " | " .. show(rewards))
				log("  after HUD: " .. show(hud))
			end
		end
	end)
	grug_factions.get_faction, grug_classes.get_race, grug_xp.get_level,
		core.show_formspec, sfinv.make_formspec = unpack(saved)
	check(ok, "probe run: " .. tostring(err))
	log(("quests rendered: %d, quest items: %d"):format(#ids, #items))
	log(("RESULT %s (%d checks, %d failures)"):format(failures == 0 and "PASS" or "FAIL",
		checks, failures))
	core.request_shutdown("probe done", false, 0)
end

core.register_on_mods_loaded(function() core.after(1, run) end)
