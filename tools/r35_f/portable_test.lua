-- Round 35 Lane F portable test (LuaJIT): the small fixes of round35-plan.md
-- §2.2-§2.4.
--
--   luajit tools/r35_f/portable_test.lua [repo]
--
-- Loads the REAL files under small stubs. Checks:
--   B  the break hook (grug_repair/runtime.lua): a weapon worn by actions, an
--      armour piece worn by hits, a tool's after_use and a hoe's on_use each
--      play "gear_break" exactly once, at the use that wears the stack into
--      broken, never on a later use of the broken item and never in
--      creative; gear_break is a declared hook of grug_sounds, and its spec
--      names a mono file on tools/r35_f/approved.txt that ships in
--      grug_sounds (approval gate; tools/r34_s1a fails on an unlisted .ogg);
--   L  the broken look (grug_gear/permissions.lua): drained of colour,
--      darkened and cracked in one balanced modifier, empty stays empty;
--   H  the empty hand (grug_abilities/init.lua, skin_token and apply_skin
--      copied out of the source): an empty slot shows wieldhand.png at the
--      hand's scale, written once; a weapon source shows the weapon at its
--      own scale; going back to empty restores the hand;
--   D  dig sounds (grug_materials/dig_sounds.lua): every grug_resource and
--      grug_loose node without a dig sound gets the stone or crumbly one, a
--      node's own dig sound and other groups stay, both files ship (the
--      engine probe tools/r35_f/engine.sh checks every registered node);
--   F  flint: a curated removal, gravel drops only gravel, no price row and
--      no other mention under mods/ outside the vendored default mod;
--   Q  the quest dialog and log (grug_quests/npc.lua, grug_map/quest_box.lua
--      since Round 44): one colour per
--      status as the entry's colour, "(R)" for repeatable, no "(available)"
--      or "[Repeatable]" text, the dialog 16 units wide with a 7-unit list,
--      a legend and a tooltip, the description a read-only textarea (no
--      textarea in our mods has a name), the quest log uses the same entries.
-- Prints "R35 F PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end
local function read(path)
	local handle = io.open(path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end
local function exists(path)
	local handle = io.open(path, "rb")
	if handle then handle:close() end
	return handle ~= nil
end
local function lines_of(command)
	local out = {}
	local pipe = assert(io.popen(command))
	for line in pipe:lines() do out[#out + 1] = line end
	pipe:close()
	return out
end
local function copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and copy(v) or v end
	return out
end
table.copy = table.copy or copy

------------------------------------------------------------------------------
-- Fake engine pieces shared by the sections.
------------------------------------------------------------------------------
local function new_meta()
	local store = {}
	local meta = {store = store}
	function meta:get_string(k) return store[k] or "" end
	function meta:set_string(k, v) if v == "" then store[k] = nil else store[k] = v end end
	function meta:get_int(k) return tonumber(store[k]) or 0 end
	function meta:set_int(k, v) store[k] = tostring(v) end
	function meta:set_tool_capabilities(caps) store.caps = caps end
	return meta
end
local registered_items = {}
function ItemStack(name)
	local stack = {name = name, wear = 0, meta = new_meta()}
	function stack:get_name() return self.name end
	function stack:is_empty() return self.name == "" end
	function stack:get_wear() return self.wear end
	function stack:set_wear(w) self.wear = w end
	function stack:get_meta() return self.meta end
	function stack:get_definition() return registered_items[self.name] or {} end
	function stack:get_tool_capabilities() return {} end
	return stack
end

------------------------------------------------------------------------------
-- B: the break hook.
------------------------------------------------------------------------------
do
	local plays, creative_on = {}, false
	local mods_loaded, outgoing, incoming = {}, nil, nil
	core = {
		get_mod_storage = function() return {get_string = function() return "" end, set_string = function() end} end,
		is_creative_enabled = function() return creative_on end,
		register_on_leaveplayer = function() end,
		register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
		registered_items = registered_items,
		override_item = function(name, redef)
			for k, v in pairs(redef) do registered_items[name][k] = v end
		end,
		serialize = function() return "caps" end,
		get_item_group = function() return 0 end,
	}
	grug_sounds = {play = function(event, target) plays[#plays + 1] = {event = event, target = target}; return true end}
	grug_core = {
		equipment_is_broken = function(stack) return stack and stack.get_wear and stack:get_wear() >= 65535 or false end,
		register_on_settled_outgoing_action = function(fn) outgoing = fn end,
		register_on_settled_incoming_hit = function(fn) incoming = fn end,
		run_settled_outgoing_action = function() end,
	}
	local equipment = {grug_weapon = true, grug_offhand = true, grug_head = true, grug_chest = true,
		grug_legs = true, grug_feet = true}
	grug_inventory = {
		BAG_COUNT = 0,
		content_list = function() return "bag" end,
		melee_list = function() return "grug_weapon" end,
		is_equipment_list = function(list) return equipment[list] == true end,
		equipment_changed = function() end,
	}
	grug_gear = {reference_purchase_price = function() return 1 end}
	grug_repair = {
		eligible = function(stack) return stack and not stack:is_empty() and stack:get_name() ~= "test:skill" end,
		maximum_durability = function() return 3 end,
		refresh_stack = function() end,
		refresh_durability = function() end,
		decorate_description = function(_, description) return description end,
	}
	local lists = {grug_weapon = {ItemStack("test:sword")}, grug_offhand = {ItemStack("")},
		grug_head = {ItemStack("")}, grug_chest = {ItemStack("test:chest")}, grug_legs = {ItemStack("")},
		grug_feet = {ItemStack("")}}
	local inv = {
		get_stack = function(_, list, i) return lists[list][i] end,
		set_stack = function(_, list, i, stack) lists[list][i] = stack end,
		get_list = function(_, list) return lists[list] end,
	}
	local player = {get_player_name = function() return "alice" end, get_inventory = function() return inv end,
		is_player = function() return true end}
	registered_items["test:sword"] = {description = "Sword", type = "craft"}
	registered_items["test:chest"] = {description = "Chest", type = "craft"}
	registered_items["test:pick"] = {description = "Pick", type = "tool", _grug_tool_uses = 2}
	registered_items["test:hoe"] = {description = "Hoe", type = "tool", on_use = function(stack)
		stack:set_wear(math.min(65535, stack:get_wear() + 40000)); return stack end}

	assert(loadfile(ROOT .. "/mods/ITEMS/grug_repair/runtime.lua"))()
	for _, fn in ipairs(mods_loaded) do fn() end
	local function breaks() local n = 0; for _, p in ipairs(plays) do if p.event == "gear_break" then n = n + 1 end end; return n end

	-- A weapon worn by three actions (lifetime 3) breaks at the third.
	local action = 0
	local function act() action = action + 1; outgoing(player, {id = "a" .. action}, "damage") end
	act(); act()
	eq(breaks(), 0, "B no cue while the weapon still holds")
	act()
	eq(lists.grug_weapon[1]:get_wear(), 65535, "B the third action breaks the weapon")
	eq(breaks(), 1, "B one cue at the break")
	eq(plays[#plays].target, player, "B the cue plays on the player (positional on its object)")
	act(); act()
	eq(breaks(), 1, "B no cue on later uses of the broken weapon")

	-- Armour worn by hits (the only candidate is the chest).
	for _ = 1, 5 do incoming(player) end
	eq(lists.grug_chest[1]:get_wear(), 65535, "B hits break the chest piece")
	eq(breaks(), 2, "B the chest's break plays once, later hits stay silent")

	-- A tool's after_use (2 uses).
	local pick, digparams = ItemStack("test:pick"), {wear = 100}
	local after_use = registered_items["test:pick"].after_use
	pick = after_use(pick, player, nil, digparams)
	eq(breaks(), 2, "B the first dig leaves the pick whole and silent")
	pick = after_use(pick, player, nil, digparams)
	eq(grug_core.equipment_is_broken(pick), true, "B the second dig breaks the pick")
	eq(breaks(), 3, "B the pick's break plays once")
	after_use(pick, player, nil, digparams)
	eq(breaks(), 3, "B a broken pick stays silent")

	-- A hoe's on_use.
	local hoe = ItemStack("test:hoe")
	local on_use = registered_items["test:hoe"].on_use
	hoe = on_use(hoe, player, {})
	eq(breaks(), 3, "B the first till leaves the hoe whole")
	hoe = on_use(hoe, player, {})
	eq(breaks(), 4, "B the hoe's break plays once")
	on_use(hoe, player, {})
	eq(breaks(), 4, "B a broken hoe stays silent")

	-- Creative never wears, so never breaks.
	creative_on = true
	lists.grug_weapon[1] = ItemStack("test:sword")
	for _ = 1, 5 do act() end
	eq(lists.grug_weapon[1]:get_wear(), 0, "B creative does not wear")
	eq(breaks(), 4, "B creative plays no break cue")

	-- The hook in grug_sounds and the approval gate.
	core = {get_us_time = function() return 0 end, sound_play = function() end,
		register_on_joinplayer = function() end, register_on_leaveplayer = function() end}
	grug_sounds = nil
	assert(loadfile(ROOT .. "/mods/CORE/grug_sounds/init.lua"))()
	local declared = false
	for _, name in ipairs(grug_sounds.HOOKS) do if name == "gear_break" then declared = true end end
	check(declared, "B gear_break is a declared hook")
	local spec = grug_sounds.EVENTS.gear_break
	if spec then
		local approved = read(ROOT .. "/tools/r35_f/approved.txt") or ""
		local listed = approved:find("\n" .. spec.name .. "%.ogg") or approved:find("^" .. spec.name .. "%.ogg") or
			approved:find("\n" .. spec.name .. "%.1%.ogg")
		check(listed ~= nil, "B gear_break's file is on tools/r35_f/approved.txt: " .. spec.name)
		check(not spec.personal and (spec.distance or 16) <= 12,
			"B gear_break is positional with a short hearing distance")
		local path = ROOT .. "/mods/CORE/grug_sounds/sounds/" .. spec.name .. ".ogg"
		local data = read(path)
		check(data ~= nil, "B gear_break's file ships: " .. spec.name)
		-- The identification header: the channel count of the Ogg Vorbis file.
		local start = data and 28 + data:byte(27)
		eq(data and data:byte(start + 11), 1, "B gear_break's file is mono")
	else
		check(false, "B gear_break has a spec (the user picked R35 B1.2)")
	end
end

------------------------------------------------------------------------------
-- L: the broken look.
------------------------------------------------------------------------------
do
	grug_gear = {}
	core = {}
	assert(loadfile(ROOT .. "/mods/ITEMS/grug_gear/permissions.lua"))()
	local image = grug_gear.broken_image("grug_gear_sword_steel.png^[colorize:#ff0000:40")
	check(image:sub(1, 1) == "(" and image:find(")^[hsl:", 1, true) ~= nil, "L desaturated and darkened as a whole")
	local hsl_s, hsl_l = image:match("%^%[hsl:%-?%d+:(%-?%d+):(%-?%d+)")
	check(tonumber(hsl_s) and tonumber(hsl_s) < 0 and tonumber(hsl_l) < 0, "L saturation and lightness lowered")
	check(image:find("^[cracko:", 1, true) ~= nil, "L cracked on opaque pixels only")
	check(image:find("[hsl:", 1, true) < image:find("[cracko:", 1, true), "L the crack comes last")
	local balance = 0
	for c in image:gmatch("[()]") do balance = balance + (c == "(" and 1 or -1) end
	eq(balance, 0, "L balanced parentheses")
	eq(grug_gear.broken_image(""), "", "L an empty image stays empty")
	eq(grug_gear.broken_image(nil), nil, "L no image stays nil")
end

------------------------------------------------------------------------------
-- H: the empty hand.
------------------------------------------------------------------------------
do
	local source = read(ROOT .. "/mods/PLAYER/grug_abilities/init.lua")
	local version = tonumber(source:match("\nlocal SKIN_VERSION = (%d+)"))
	check(version and version >= 4, "H SKIN_VERSION bumped for the hand (got " .. tostring(version) .. ")")
	local chunk = {}
	for _, pattern in ipairs({"\n(local SKIN_TOKEN_KEY = [^\n]+)",
			"\n(local function skin_token%(src%).-\nend)\n",
			"\n(local EMPTY_HAND_IMAGE = [^\n]+)", "\n(local EMPTY_HAND_SCALE = [^\n]+)",
			"\n(local function apply_skin%(stack, def, src%).-\nend)\n"}) do
		local body = source:match(pattern)
		check(body ~= nil, "H found in grug_abilities/init.lua: " .. pattern)
		chunk[#chunk + 1] = body or ""
	end
	local code = "local SKIN_VERSION = " .. tostring(version) .. "\n" ..
		"local function skin_wield_image(src) if src == '' or src:find('BAD', 1, true) then return nil end return src end\n" ..
		table.concat(chunk, "\n") .. "\nreturn apply_skin"
	local apply_skin = assert(loadstring(code))()
	local stack = ItemStack("grug_abilities:strike")
	local meta = stack:get_meta()
	eq(apply_skin(stack, {}, ""), true, "H a fresh stack with an empty slot is written once")
	eq(meta:get_string("wield_image"), "wieldhand.png", "H the empty slot shows the bare hand")
	eq(meta:get_string("wield_scale"), "(1, 1, 2.5)", "H at the hand's scale")
	eq(meta:get_string("inventory_image"), "", "H the inventory keeps the skill icon")
	eq(apply_skin(stack, {}, ""), false, "H the same empty slot writes nothing again")
	eq(apply_skin(stack, {}, "grug_gear_sword_steel.png"), true, "H a weapon rewrites the skin")
	eq(meta:get_string("wield_image"), "grug_gear_sword_steel.png", "H the weapon in hand")
	eq(meta:get_string("wield_scale"), "", "H the weapon at its own scale")
	eq(apply_skin(stack, {}, ""), true, "H emptying the slot rewrites the skin")
	eq(meta:get_string("wield_image"), "wieldhand.png", "H back to the bare hand")
	apply_skin(stack, {}, "BAD(")
	eq(meta:get_string("wield_image"), "", "H an uncomposable source keeps the registered orb")
	check(exists(ROOT .. "/mods/BASE/default/textures/wieldhand.png"), "H wieldhand.png ships")
end

------------------------------------------------------------------------------
-- D: dig sounds.
------------------------------------------------------------------------------
do
	local nodes = {
		["test:ore"] = {groups = {grug_resource = 2, level = 1}, sounds = {footstep = {name = "f"}}},
		["test:sand"] = {groups = {grug_loose = 3, crumbly = 3, sand = 1}},
		["test:gravel"] = {groups = {grug_loose = 2}, sounds = {dig = {name = "default_gravel_dig", gain = 0.35}}},
		["test:stone"] = {groups = {cracky = 3}, sounds = {}},
		["test:block"] = {groups = {cracky = 1}},
	}
	local shared = nodes["test:ore"].sounds
	local callbacks = {}
	core = {
		registered_nodes = nodes,
		register_on_mods_loaded = function(fn) callbacks[#callbacks + 1] = fn end,
		override_item = function(name, redef) for k, v in pairs(redef) do nodes[name][k] = v end end,
	}
	grug_materials = {}
	assert(loadfile(ROOT .. "/mods/ITEMS/grug_materials/dig_sounds.lua"))()
	eq(#callbacks, 1, "D one pass after every mod")
	callbacks[1]()
	eq(nodes["test:ore"].sounds.dig.name, "default_dig_cracky", "D an ore plays the stone dig sound")
	eq(nodes["test:ore"].sounds.dig.gain, 0.5, "D at gain 0.5")
	eq(nodes["test:ore"].sounds.footstep.name, "f", "D the other sounds stay")
	eq(shared.dig, nil, "D a shared sounds table is copied, not edited")
	eq(nodes["test:sand"].sounds.dig.name, "default_dig_crumbly", "D sand plays the crumbly dig sound")
	eq(nodes["test:gravel"].sounds.dig.name, "default_gravel_dig", "D a node's own dig sound stays")
	eq(nodes["test:stone"].sounds.dig, nil, "D other groups keep the engine's group sound")
	eq(nodes["test:block"].sounds, nil, "D a node outside both groups is untouched")
	check(nodes["test:ore"].sounds.dig ~= grug_materials.RESOURCE_DIG_SOUND, "D each node gets its own table")
	for _, spec in ipairs({grug_materials.RESOURCE_DIG_SOUND, grug_materials.LOOSE_DIG_SOUND}) do
		local dir = ROOT .. "/mods/BASE/default/sounds/"
		check(exists(dir .. spec.name .. ".ogg") or exists(dir .. spec.name .. ".1.ogg"),
			"D the file ships: " .. spec.name)
	end
	check(read(ROOT .. "/mods/ITEMS/grug_materials/init.lua"):find('dofile(modpath .. "/dig_sounds.lua")', 1, true),
		"D grug_materials loads dig_sounds.lua")
end

------------------------------------------------------------------------------
-- F: flint.
------------------------------------------------------------------------------
do
	local curation = read(ROOT .. "/mods/ITEMS/grug_materials/content_curation.lua")
	check(curation:find('local REMOVED_UNUSED = {"default:flint"}', 1, true) and
		curation:find("append_removals(REMOVED_UNUSED)", 1, true), "F flint is a curated removal")
	check(curation:find('core.override_item("default:gravel", {drop = "default:gravel"})', 1, true),
		"F gravel drops only gravel")
	check(read(ROOT .. "/mods/ITEMS/grug_materials/audit.lua"):find('"default:gravel"', 1, true),
		"F the audit checks the gravel drop")
	local stray = lines_of("grep -rln --include=*.lua --include=*.json --include=*.txt 'default:flint' '" ..
		ROOT .. "/mods' | grep -v '/mods/BASE/default/' | grep -v 'grug_materials/content_curation.lua'")
	eq(#stray, 0, "F no other mention of default:flint under mods/ (" .. table.concat(stray, " ") .. ")")
end

------------------------------------------------------------------------------
-- Q: the quest dialog and log.
------------------------------------------------------------------------------
do
	local shown
	core = {
		formspec_escape = function(text)
			return (text:gsub("\\", "\\\\"):gsub("%[", "\\["):gsub("%]", "\\]"):gsub(";", "\\;"):gsub(",", "\\,"))
		end,
		colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
		register_on_player_receive_fields = function() end,
		register_on_leaveplayer = function() end,
		register_entity = function() end,
		show_formspec = function(_, _, form) shown = form end,
	}
	vector = {distance = function() return 1 end}
	grug_core = {register_tag_visibility = function() end, item_name = function() return "Item" end}
	grug_factions = {serves = function() return true end}
	grug_sounds = {play = function() end}
	grug_money = {format = function(c) return c .. "c" end}
	grug_quests = {
		npc_by_socket = {["s/1"] = "giver"},
		registered_npcs = {giver = {title = "Old Maren", faction = "accord"}},
		registered_quests = {},
		quest_text = function() return "Text" end,
		cooldown_text = function() return "1 h" end,
		objective_action = function() return "Defeat" end,
		objective_levels_text = function() return "" end,
		reward_xp = function() return 10 end,
	}
	local rows = {
		{id = "q1", title = "Break Ranks at the Shattered Line Throng War Camp", status = "available"},
		{id = "q2", title = "Bounty: Threads, Across", status = "ready", repeatable = true},
		{id = "q3", title = "In Progress", status = "active"},
		{id = "q4", title = "Later", status = "locked", reason = "Requires level 12"},
	}
	for _, row in ipairs(rows) do
		grug_quests.registered_quests[row.id] = {npc = "giver", turnin_npc = "giver", objectives = {},
			rewards = {copper = 5, items = {}}, repeatable = row.repeatable and {cooldown = 3600} or nil}
	end
	grug_quests.npc_quests = function() return rows end
	assert(loadfile(ROOT .. "/mods/PLAYER/grug_quests/npc.lua"))()
	local Q = grug_quests
	local colors = {}
	for _, status in ipairs({"available", "ready", "active", "locked"}) do
		local color = Q.STATUS_COLORS[status]
		check(type(color) == "string" and color:match("^#%x%x%x%x%x%x$") ~= nil, "Q a colour for " .. status)
		check(not colors[color], "Q one colour per status: " .. status)
		colors[color] = true
		local entry = Q.list_entry("A, Title", status, false)
		eq(entry, color .. "A\\, Title", "Q the entry is the status colour and the escaped title: " .. status)
	end
	eq(Q.list_entry("Bounty", "ready", true), Q.STATUS_COLORS.ready .. "Bounty (R)", "Q repeatable ends in (R)")
	local legend = Q.status_legend()
	for _, status in ipairs({"available", "ready", "active", "locked"}) do
		check(legend:find(Q.STATUS_COLORS[status], 1, true) ~= nil, "Q the legend shows " .. status)
	end
	check(legend:find("(R)", 1, true) ~= nil, "Q the legend explains (R)")
	check(Q.status_tooltip():find("(R): repeatable", 1, true) ~= nil, "Q the tooltip explains (R)")

	local player = {get_player_name = function() return "alice" end, is_player = function() return true end,
		get_hp = function() return 20 end, get_pos = function() return {x = 0, y = 0, z = 0} end}
	local entity = {_grug_start = "s", _grug_socket = "1", object = {is_valid = function() return true end,
		get_pos = function() return {x = 0, y = 0, z = 0} end}}
	eq(Q.open_npc(player, entity), true, "Q the dialog opens")
	local form = shown or ""
	check(form:find("size[16,", 1, true) ~= nil, "Q the dialog is 16 units wide")
	local list_w = tonumber(form:match("textlist%[[%d.]+,[%d.]+;([%d.]+),[%d.]+;quests;"))
	check(list_w and list_w >= 7, "Q the quest list is at least 7 units wide (got " .. tostring(list_w) .. ")")
	local list = form:match("textlist%[(.-);false%]") or ""
	check(list ~= "" and not list:find("(available)", 1, true) and not list:find("Repeatable", 1, true),
		"Q no status or [Repeatable] text in the list")
	check(form:find(Q.STATUS_COLORS.available .. "Break Ranks", 1, true) ~= nil, "Q the available entry is coloured")
	check(form:find(Q.STATUS_COLORS.ready .. "Bounty: Threads\\, Across (R)", 1, true) ~= nil,
		"Q the ready repeatable entry is coloured and ends in (R)")
	check(form:find("tooltip[quests;", 1, true) ~= nil, "Q the list has a tooltip")
	check(form:find(legend, 1, true) ~= nil, "Q the dialog shows the legend")
	local description = form:match("(textarea%[[^%]]-;)")
	check(description ~= nil and form:find("textarea%[[%d.]+,[%d.]+;[%d.]+,[%d.]+;;;") ~= nil,
		"Q the description is a read-only textarea (no name)")
	-- 0.45.1: the dialog opens on the first quest ready to complete (row 2
	-- here), so it offers Complete, not row 1's Accept.
	check(form:find("button[7.8,8.4;2,0.7;turnin;Complete]", 1, true) ~= nil and
		form:find("accept;Accept]", 1, true) == nil, "Q Complete for the preselected ready quest")

	-- No textarea in our mods has a name (a named one is editable).
	local named, seen = {}, 0
	for _, path in ipairs(lines_of("grep -rlF --include=*.lua 'textarea[' '" .. ROOT ..
			"/mods' | grep -v '/mods/BASE/'")) do
		local text = read(path)
		for args in text:gmatch("textarea%[([^%]\"]*)") do
			seen = seen + 1
			local name = args:match("^[^;]*;[^;]*;([^;]*);")
			if name and name ~= "" then named[#named + 1] = path .. ": " .. name end
		end
	end
	check(seen >= 10, "Q the textarea scan sees the game's text fields (got " .. seen .. ")")
	eq(#named, 0, "Q no named textarea in our mods (" .. table.concat(named, ", ") .. ")")

	-- The quest log is the map window's quest box since Round 44.
	local ui = read(ROOT .. "/mods/PLAYER/grug_map/quest_box.lua")
	check(ui:find("grug_quests.list_entry(", 1, true) ~= nil, "Q the quest log uses the same entries")
	check(ui:find("tooltip[grug_quest_list;", 1, true) ~= nil, "Q the quest log list has the tooltip")
	check(not ui:find("[Repeatable]", 1, true) and not ui:find("[Ready]", 1, true),
		"Q the quest log has no [Repeatable] or [Ready] text")
	-- The list spans the window's quest column (at least COLUMN_MIN wide)
	-- less the box padding on both sides.
	local column = tonumber(read(ROOT .. "/mods/PLAYER/grug_map/window.lua"):match(
		"\nlocal COLUMN_MIN, COLUMN_SHARE = ([%d.]+),"))
	local pad = tonumber(ui:match("\nlocal PAD, GAP, ROW_H, BUTTON_H = ([%d.]+),"))
	local log_w = column and pad and column - 2 * pad
	check(log_w and log_w > 3.45, "Q the quest log list is wider than before (got " .. tostring(log_w) .. ")")
end

if failures > 0 then
	print(("R35 F PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R35 F PORTABLE PASS checks=%d"):format(checks))
