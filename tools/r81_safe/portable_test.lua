-- Round 81 lane SAFE: server safety from the 2026-11 audit.
--   T  grug_core/text.lua: the raw field cut, cut-then-trim and the text box
--      cleaner (X6-01, X6-V1) give the old answers for every ordinary input
--      and stay cheap on a crafted 640 KiB field; the UTF-8 byte-length rule.
--   F  the withdraw dialog (grug_money/coins.lua) and the Claim Stone form
--      (grug_housing/stone_form.lua) cut every raw field first.
--   U  the mail cleaner (grug_mail/model.lua), the bridge's C.plain and the
--      account cleaner drop a malformed UTF-8 run (P5-01); valid UTF-8 gives
--      byte-identical output.
--   P  an error inside an ability punch is reported through
--      grug_core.severe.report after the flag restore (C1-09, ruling 11).
--   W  the water guard keeps water out of the world-protection layer with the
--      barrier revert (C1-01, ruling 3); towns, claims' arrival cubes,
--      planned flow and other liquids as before.
-- Usage: luajit tools/r81_safe/portable_test.lua <repository path>
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
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function read(rel)
	local handle = assert(io.open(ROOT .. "/" .. rel, "rb"), rel)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function ms(fn)
	local started = os.clock()
	local results = {fn()}
	return (os.clock() - started) * 1000, unpack(results)
end

local T = dofile(ROOT .. "/mods/CORE/grug_core/text.lua")
grug_core = {text = T}

-- An adversarial field: a long run of blanks between two letters, the
-- shape whose trim is quadratic.
local function blanks(total)
	return "x" .. (" "):rep(total - 2) .. "y"
end
local HUGE = blanks(640 * 1024)

------------------------------------------------------------------------------
-- T: the text helpers.
------------------------------------------------------------------------------
do
	-- The rules as they were (grug_jobs/ui.lua, grug_inventory/help.lua,
	-- string.trim on the raw value), as references.
	local function old_clean(value, limit)
		local text = tostring(value):sub(1, 4 * limit):gsub("[%c]", "")
		return (text:match("^%s*(.-)%s*$") or ""):sub(1, limit)
	end
	local function old_trim(value) return tostring(value or ""):match("^%s*(.-)%s*$") end
	local corpus = {"", " ", "12", "  12  ", "\t12\n", "iron bar", " apple wood planks ",
		"a\0b", "x\27(c@#f00)y", "caf\195\169", "\226\130\172 5", ("x"):rep(50),
		("  "):rep(10) .. "zed" .. ("  "):rep(10), "1 2", "-3", "1e3"}
	for i = 1, 200 do
		local parts = {}
		for j = 1, (i % 37) do
			parts[j] = string.char((i * 31 + j * 17) % 256)
		end
		corpus[#corpus + 1] = table.concat(parts)
	end
	for index, value in ipairs(corpus) do
		for _, limit in ipairs({3, 8, 40}) do
			eq(T.clean_field(value, limit), old_clean(value, limit),
				"T clean_field equals the old rule, input " .. index .. " limit " .. limit)
		end
		if #value <= 32 then
			eq(T.cut_trim(value, 32), old_trim(value), "T cut_trim equals the old trim, input " .. index)
		end
	end
	eq(T.cut(nil, 5), "", "T cut of nil is empty")
	eq(T.cut(1234567, 3), "123", "T cut takes numbers as text")
	eq(T.cut_trim(nil, 32), "", "T cut_trim of nil is empty")
	eq(T.cut_trim("  carol  ", 80), "carol", "T cut_trim trims")

	-- The crafted field: one trim of the cut value, against the old trim of a
	-- value 80 times smaller (8 KiB; the old trim of 640 KiB would take hours).
	local cut_ms, cut = ms(function() return T.cut_trim(HUGE, 32) end)
	local clean_ms, cleaned = ms(function() return T.clean_field(HUGE, 40) end)
	local old_ms = ms(function() return old_trim(blanks(8 * 1024)) end)
	eq(cut, "x", "T a crafted field is cut before the trim")
	eq(cleaned, "x", "T clean_field cuts a crafted field first")
	check(cut_ms < 50 and clean_ms < 50, "T the cut trims stay cheap on 640 KiB")
	print(("T measure: cut_trim(640 KiB) %.3f ms, clean_field(640 KiB) %.3f ms; " ..
		"old trim of an 8 KiB run %.1f ms"):format(cut_ms, clean_ms, old_ms))

	-- The UTF-8 byte-length rule.
	for _, case in ipairs({{"A", true}, {"\0", true}, {"\195\169", true}, {"\226\130\172", true},
			{"\240\159\152\128", true}, {"A\128", false}, {"\226", false}, {"\226\130", false},
			{"\195\169\128", false}, {"\240\159\152", false}, {"A" .. ("\128"):rep(99), false}}) do
		eq(T.utf8_whole(case[1]), case[2], "T utf8_whole of " .. #case[1] .. " bytes lead " ..
			case[1]:byte())
	end
	eq(T.utf8_size(65), 1, "T one byte below 128")
	eq(T.utf8_size(0xC3), 2, "T two bytes for C3")
	eq(T.utf8_size(0xE2), 3, "T three bytes for E2")
	eq(T.utf8_size(0xF0), 4, "T four bytes for F0")
end

------------------------------------------------------------------------------
-- F: the form handlers cut first.
------------------------------------------------------------------------------
do
	-- No trim or event parse on a raw field is left in the two handlers.
	local coins = read("mods/PLAYER/grug_money/coins.lua")
	local stone = read("mods/PLAYER/grug_housing/stone_form.lua")
	check(not coins:find(":trim()", 1, true), "F coins.lua has no trim of a raw field")
	check(not stone:find(":trim()", 1, true), "F stone_form.lua has no trim of a raw field")
	check(stone:find("explode_textlist_event%(%s*grug_core%.text%.cut%(fields%.perm_list") ~= nil,
		"F the Claim Stone list event is parsed from the cut field")
	check(stone:find("session.typed = grug_core.text.cut(fields.perm_name", 1, true) ~= nil,
		"F the Claim Stone keeps only the cut name")

	-- The withdraw dialog, loaded on stand-ins.
	local handlers, shown = {}, nil
	core = setmetatable({
		register_on_player_receive_fields = function(fn) handlers[#handlers + 1] = fn end,
		show_formspec = function(_, _, formspec) shown = formspec end,
		formspec_escape = function(text) return text end,
		colorize = function(_, text) return text end,
	}, {__index = function(_, key)
		if type(key) == "string" and key:match("^register_") then return function() end end
	end})
	grug_core.ui = setmetatable({}, {__index = function() return function() return "" end end})
	grug_money = {format = function(copper) return tostring(copper) .. "c" end,
		get = function() return 0 end}
	dofile(ROOT .. "/mods/PLAYER/grug_money/coins.lua")
	local parse = grug_money.parse_amount
	eq(parse("1", "2", "3"), 10203, "F 1g 2s 3c")
	eq(parse("", " 5 ", ""), 500, "F trimmed fields")
	eq(parse(nil, nil, "7"), 7, "F missing fields count 0")
	eq(parse("5" .. (" "):rep(100), "", ""), 50000, "F trailing blanks past the cut")
	local elapsed, total, reason = ms(function() return parse(HUGE, "", "") end)
	check(total == nil and reason ~= nil, "F a crafted field is refused")
	check(elapsed < 50, "F the crafted field is refused at once")
	local player = {get_player_name = function() return "ann" end}
	for _, fn in ipairs(handlers) do
		fn(player, "grug_money:withdraw", {grug_money_confirm = "", grug_money_gold = HUGE,
			grug_money_silver = "abc"})
	end
	check(shown ~= nil and #shown < 2000, "F the refusal shows the cut fields, not 640 KiB" ..
		" (" .. tostring(shown and #shown) .. " bytes)")
	check(shown and shown:find("Gold;x" .. (" "):rep(31) .. "]", 1, true) ~= nil,
		"F the gold field is shown as cut")
	grug_core.ui, grug_money, core = nil, nil, nil
end

------------------------------------------------------------------------------
-- U: the UTF-8 rule in the three cleaners.
------------------------------------------------------------------------------
do
	-- The mail cleaner as it was, as the reference for valid UTF-8.
	local CHAR = "[%z\1-\127\194-\244][\128-\191]*"
	local function old_mail_clean(M, text, max, multiline)
		text = tostring(text or ""):gsub("\r\n?", "\n")
		local kept = {}
		for char in text:gmatch(CHAR) do
			if char == "\n" then
				kept[#kept + 1] = multiline and "\n" or " "
			elseif char == "\t" then
				kept[#kept + 1] = " "
			elseif not (#char == 1 and (char:byte() < 32 or char:byte() == 127)) then
				kept[#kept + 1] = char
			end
		end
		text = table.concat(kept):match("^%s*(.-)%s*$")
		if not max then return text end
		return M.truncate(text, max)
	end
	local M = dofile(ROOT .. "/mods/PLAYER/grug_mail/model.lua")
	local valid = {"", "Hello", "  padded  ", "line\r\nbreak\rold\nmac", "tab\there",
		"\27(c@#ff0000)red\27E", "caf\195\169 \226\130\172 \240\159\152\128",
		("\226\130\172"):rep(70), "ctrl\1\2\127chars", ("w "):rep(3000)}
	for index, text in ipairs(valid) do
		for _, args in ipairs({{nil, true}, {nil, false}, {60, false}, {M.BODY_MAX, true}}) do
			eq(M.clean(text, args[1], args[2]), old_mail_clean(M, text, args[1], args[2]),
				"U mail clean keeps valid text " .. index .. " byte-identical")
		end
	end
	local stuffed = "A" .. ("\128"):rep(39999)
	eq(M.clean(stuffed, nil, true), "", "U a lead byte with 39,999 continuation bytes is dropped")
	local body, refusal = M.check_body("Hi " .. stuffed .. " there")
	eq(body, "Hi  there", "U check_body stores the text without the malformed run")
	eq(refusal, nil, "U and accepts it")
	eq(M.clean("A" .. ("\128"):rep(239), M.SUBJECT_MAX, false), "",
		"U a 240-byte subject that counted as one character is dropped")
	eq(M.clean("x\226y", nil, false), "xy", "U a lone lead byte is dropped")
	eq(M.clean("\195\169\128", nil, false), "", "U a character with a stray continuation goes")
	local full = ("\240\159\152\128"):rep(M.BODY_MAX)
	local kept, none = M.check_body(full)
	check(kept == full and none == nil, "U 4,000 four-byte characters are still accepted")
	local _, too_long = M.check_body(full .. "x")
	check(too_long ~= nil, "U and 4,001 refused")

	-- The bridge's C.plain goes through the mail cleaner.
	grug_mail = {model = M}
	local C = dofile(ROOT .. "/mods/PLAYER/grug_bridge/commands.lua")
	eq(C.plain("\27(T@grug)Ban\27E reason " .. stuffed), "Ban reason",
		"U C.plain drops escapes and the malformed run")
	eq(C.plain("caf\195\169"), "caf\195\169", "U C.plain keeps valid UTF-8")
	grug_mail = nil

	-- The account cleaner shares the rule.
	local store = {}
	local A = dofile(ROOT .. "/mods/PLAYER/grug_accounts/model.lua")({
		storage = {get_string = function(_, k) return store[k] or "" end,
			set_string = function(_, k, v) store[k] = v end},
		serialize = function() return "" end, deserialize = function() return nil end,
		log = function() end, online_id = function() return nil end})
	eq(A.clean("Jan\226 H\195\169\128 \226\130\172", 64), "Jan H \226\130\172",
		"U the account cleaner drops malformed runs")
	eq(A.clean("  Caf\195\169 \240\159\152\128  ", 64), "Caf\195\169 \240\159\152\128",
		"U the account cleaner keeps valid UTF-8")
	eq(A.clean(("\226\130\172"):rep(70), 64), ("\226\130\172"):rep(64),
		"U the account cleaner cuts at 64 characters")
end

------------------------------------------------------------------------------
-- P: an ability punch that raises is reported (C1-09).
------------------------------------------------------------------------------
do
	core = setmetatable({
		get_us_time = function() return 1000000 end,
		get_mod_storage = function()
			local s = {}
			return {get_string = function(_, k) return s[k] or "" end,
				set_string = function(_, k, v) s[k] = v end}
		end,
		log = function() end,
		is_player = function(obj) return type(obj) == "table" and obj.is_player ~= nil and obj:is_player() end,
	}, {__index = function(_, key)
		if type(key) == "string" and key:match("^register_") then return function() end end
	end})
	vector = {new = function(x, y, z) return {x = x, y = y, z = z} end}
	grug_sounds = {play = function() end}
	grug_core = {text = T, particles = {play = function() end}}
	assert(loadfile(ROOT .. "/mods/CORE/grug_core/combat.lua"))()
	local reports = {}
	grug_core.severe = {report = function(source, summary, details, key)
		reports[#reports + 1] = {source = source, summary = summary, details = details, key = key,
			flag = grug_core.in_ability_punch}
	end}
	grug_core.scale_player_damage = function(_, _, amount) return amount end
	grug_core.get_crit_chance = function() return 0 end
	grug_core.is_tracked_mob = function() return false end
	grug_core.mark_in_combat = function() end
	grug_core.get_player_level = function() return 10 end
	local attacker = {is_player = function() return true end,
		get_player_name = function() return "ann" end}
	local target = {is_player = function() return false end, get_hp = function() return 10 end,
		get_luaentity = function() return nil end, get_pos = function() return {x = 0, y = 0, z = 0} end,
		punch = function() error("boom in on_punch", 0) end}
	local wrapped = {is_player = function() return false end, get_hp = function() return 10 end,
		get_luaentity = function() return nil end, get_pos = function() return {x = 0, y = 0, z = 0} end,
		punch = function()
			error("Runtime error from mod 'grug_mobs' in callback luaentity_Punch(): " ..
				"/srv/game/mods/ENTITIES/mobs/api.lua:2931: attempt to index a nil value\n" ..
				"stack traceback:\n\t[C]: in function 'error'\n\t.../grug_mobs/init.lua:40: in function", 0)
		end}
	local sited = {is_player = function() return false end, get_hp = function() return 10 end,
		get_luaentity = function() return nil end, get_pos = function() return {x = 0, y = 0, z = 0} end,
		punch = function() error("boom at a site") end}
	local before = grug_core.in_ability_punch
	eq(grug_core.deal_ability_damage(attacker, target, 7), 0, "P a failed punch deals nothing")
	eq(#reports, 1, "P the failure is reported once")
	local report = reports[1] or {}
	eq(report.source, "grug_core", "P the report's source")
	eq(report.summary, "ability punch failed", "P the report's summary")
	eq(report.details, "boom in on_punch", "P the error text is the details")
	eq(report.key, "grug_core:ability_punch:other", "P an error without a site keys as other")
	eq(report.flag, before, "P the flag is restored before the report")
	eq(grug_core.in_ability_punch, before, "P and stays restored")
	grug_core.deal_ability_damage(attacker, sited, 7)
	local site = reports[2] or {}
	check(site.details and site.details:find(": boom at a site$") ~= nil, "P the log keeps the whole text")
	check(site.key and site.key:find("^grug_core:ability_punch:[^\n:]+portable_test%.lua:%d+$") ~= nil,
		"P the key is the error site (" .. tostring(site.key) .. ")")
	grug_core.deal_ability_damage(attacker, wrapped, 7)
	local engine = reports[3] or {}
	eq(engine.key, "grug_core:ability_punch:/srv/game/mods/ENTITIES/mobs/api.lua:2931",
		"P the engine-wrapped on_punch error keys by its site")
	check(engine.details and engine.details:find("^Runtime error from mod") ~= nil,
		"P the log keeps the engine's whole text")
	core, vector, grug_sounds = nil, nil, nil
	grug_core = {text = T}
end

------------------------------------------------------------------------------
-- W: the water guard and the world-protection layer (C1-01).
------------------------------------------------------------------------------
do
	local nodes, swaps, liquid, mods_loaded = {}, {}, {}, {}
	local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
	local registered = {}
	core = {
		registered_nodes = registered,
		is_protected = function() return false end,
		register_node = function(name, def) registered[name] = def end,
		override_item = function(name, redef)
			for k, v in pairs(redef) do registered[name][k] = v end
		end,
		register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
		register_on_liquid_transformed = function(fn) liquid[#liquid + 1] = fn end,
		get_node_or_nil = function(pos) return nodes[key(pos)] or {name = "air"} end,
		swap_node = function(pos, node)
			nodes[key(pos)] = {name = node.name}
			swaps[#swaps + 1] = {pos = pos, name = node.name}
		end,
	}
	-- x >= 100: a town; 10..19: a road; 20..29: a POI core; z == 5 a planned
	-- step; the rest home ground.
	local feature_calls = 0
	grug_core = {text = T, zone_authority_installed = function() return true end,
		world_feature_at = function(pos)
			feature_calls = feature_calls + 1
			if pos.x >= 10 and pos.x <= 19 then return "road" end
			if pos.x >= 20 and pos.x <= 29 then return "poi" end
			return nil
		end}
	grug_zones = {territory_rule_at = function(pos)
		return pos.x >= 100 and "hard_protected" or "accord_home"
	end}
	dofile(ROOT .. "/mods/CORE/grug_core/protection.lua")
	for _, name in ipairs({"default:water_source", "default:river_water_source",
			"default:lava_source"}) do
		core.register_node(name, {liquidtype = "source"})
	end
	for _, name in ipairs({"default:water_flowing", "default:river_water_flowing",
			"default:lava_flowing"}) do
		core.register_node(name, {liquidtype = "flowing"})
	end
	core.register_node("default:torch", {floodable = true})
	dofile(ROOT .. "/mods/CORE/grug_core/water_guard.lua")
	grug_core.register_planned_water_flow(function(pos) return pos.z == 5 end)
	local cube_calls = 0
	local cubes = {}
	grug_core.register_world_alteration_guard(function(pos)
		cube_calls = cube_calls + 1
		return not cubes[key(pos)]
	end)
	for _, fn in ipairs(mods_loaded) do fn() end
	local BARRIER = grug_core.WATER_BARRIER

	local function P(x, z) return {x = x, y = 10, z = z or 0} end
	local function refused(pos, liquid_name)
		return registered["default:torch"].on_flood(pos, {name = "default:torch"},
			{name = liquid_name or "default:water_flowing"}) == true
	end
	-- Air at pos was flooded: the transformed callback decides what stays.
	local function flood_air(pos, liquid_name)
		nodes[key(pos)] = {name = liquid_name or "default:river_water_flowing"}
		for _, fn in ipairs(liquid) do fn({pos}, {{name = "air"}}) end
		return nodes[key(pos)].name
	end

	-- Open home ground: as before.
	check(not refused(P(0)), "W water floods a torch on open ground")
	eq(flood_air(P(0)), "default:river_water_flowing", "W water stays in open air")
	-- The road and the POI core: refused, reverted to the barrier.
	for _, case in ipairs({{12, "a road"}, {25, "a POI core"}}) do
		local pos = P(case[1])
		check(refused(pos), "W water does not flood a torch on " .. case[2])
		eq(flood_air(pos), BARRIER, "W flooded air on " .. case[2] .. " becomes the barrier")
		check(registered[BARRIER].on_flood(pos, {name = BARRIER},
			{name = "default:water_flowing"}) == true,
			"W the barrier on " .. case[2] .. " refuses the next flow")
	end
	-- Water already on a road (from before Round 81) drains away: a drain and
	-- a level drop stand, and a later flood into that air meets the barrier.
	local function transformed(pos, now, before)
		nodes[key(pos)] = {name = now}
		local count = #swaps
		for _, fn in ipairs(liquid) do fn({pos}, {{name = before}}) end
		return nodes[key(pos)].name, #swaps - count
	end
	local name, swapped = transformed(P(14), "air", "default:water_flowing")
	check(name == "air" and swapped == 0, "W existing water on a road drains away")
	name, swapped = transformed(P(15), "default:water_flowing", "default:water_source")
	check(name == "default:water_flowing" and swapped == 0, "W a level drop on a road stands")
	name, swapped = transformed(P(25), "air", "default:river_water_source")
	check(name == "air" and swapped == 0, "W existing water in a POI core drains away")
	eq(flood_air(P(14)), BARRIER, "W the drained cell refuses the next flood with the barrier")
	-- A drain in a town is restored, as before.
	name = transformed(P(110), "air", "default:water_flowing")
	eq(name, "default:water_flowing", "W a drain in a town is restored")
	-- A drain in an arrival cube is restored, as before.
	cubes[key(P(-9))] = true
	name = transformed(P(-9), "air", "default:water_flowing")
	eq(name, "default:water_flowing", "W a drain in an arrival cube is restored")
	-- Planned flow wins on the layer as it does in towns.
	check(not refused(P(12, 5)), "W planned flow passes on a road")
	eq(flood_air(P(12, 5)), "default:river_water_flowing", "W planned flow stays on a road")
	check(not refused(P(120, 5)), "W planned flow passes in a town")
	-- Towns as before.
	check(refused(P(120)), "W water stays out of a town")
	eq(flood_air(P(120)), BARRIER, "W flooded air in a town becomes the barrier")
	-- An arrival cube on open ground: refused, plain air revert, as before.
	cubes[key(P(-8))] = true
	check(refused(P(-8)), "W an arrival cube refuses water")
	eq(flood_air(P(-8)), "air", "W flooded air in a cube on open ground is plain air again")
	-- An arrival cube refuses planned flow too, as before.
	cubes[key(P(-8, 5))] = true
	check(refused(P(-8, 5)), "W a cube wins over planned flow")
	-- Lava: only the alteration guards, as before.
	check(not refused(P(12), "default:lava_flowing"), "W lava is not stopped by a road")
	eq(flood_air(P(12), "default:lava_flowing"), "default:lava_flowing", "W lava stays on a road")
	check(refused(P(-8), "default:lava_flowing"), "W lava is stopped by a cube")
	-- The revert decision.
	local revert = grug_core.water_guard_revert_node
	eq(revert(P(12), {name = "air"}).name, BARRIER, "W revert: air on a road becomes the barrier")
	eq(revert(P(0), {name = "air"}).name, "air", "W revert: air on open ground stays air")
	eq(revert(P(12), {name = "default:water_source"}).name, "default:water_source",
		"W revert: water stays water")
	-- Calls: the cube guard is asked once per decision (it was asked twice
	-- for a refused position on open ground), the layer only on alterable
	-- ground.
	cube_calls, feature_calls = 0, 0
	refused(P(-8))
	eq(cube_calls, 1, "W the cube guard is asked once for a refused flow")
	refused(P(120))
	eq(feature_calls, 0, "W a town never asks the layer")
	refused(P(0))
	eq(feature_calls, 1, "W open ground asks the layer once")
	-- Before the zone authority: fail closed.
	grug_core.zone_authority_installed = function() return false end
	check(refused(P(0)), "W before the zone authority water is refused")
	core, grug_zones = nil, nil
end

if failures > 0 then
	error(("R81 SAFE PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R81 SAFE PORTABLE PASS checks=%d"):format(checks))
