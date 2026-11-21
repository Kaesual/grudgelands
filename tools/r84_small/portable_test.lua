-- Round 84 lane SMALL portable test (round84-plan.md §4 SMALL).
--
--   luajit tools/r84_small/portable_test.lua [repo]
--
-- Loads the REAL grug_achievements (core.lua, catalog.lua, init.lua) and the
-- REAL grug_food init.lua on small fake engines. Checks:
--   C  the cloak picker (default 14): No cloak first, then by the shown name,
--      case-insensitive, articles counted ("The Unbought Banner" under T),
--      equal names in catalogue order; the selected cloak is marked at its
--      sorted place; a name chosen from the sorted list selects that cloak;
--      unlocked_cloaks keeps the catalogue order;
--   T  every food sets the engine's touch gesture (default 16): pointed at
--      nothing a long tap places (the RMB hold), at a node a short tap places
--      (doors, chests, planting), at an object a short tap places too
--      (talking to an NPC, user ruling 2026-11-21); the modes are the
--      engine's names (c_content.cpp es_TouchInteractionMode:
--      long_dig_short_place, short_dig_long_place, user); no field is "user", so the player's touch_punch_gesture never
--      decides; food stays without on_use; the tooltip names the touch
--      gesture in the Help text's words;
--   P  (0.84.1) the food click on release (a short tap at an object) at a
--      dropped item makes one pickup attempt through
--      grug_inventory.pick_up_pointed and nothing else (no entity
--      right-click, no wield write, a full inventory included); at an NPC
--      it still runs the entity's right-click.
-- The death wear's level floor (ruling 5) is checked in tools/r70_death.
-- Prints "R84 SMALL PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."

local checks, failures = 0, 0
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
local function noop() end
local function permissive(t)
	return setmetatable(t, {__index = function() return noop end})
end

------------------------------------------------------------------------------
-- C  the cloak picker
------------------------------------------------------------------------------
do
	local function new_meta()
		local data = {}
		return {
			get_string = function(_, key) return data[key] or "" end,
			set_string = function(_, key, value) data[key] = value ~= "" and value or nil end,
			get_int = function(_, key) return tonumber(data[key]) or 0 end,
			set_int = function(_, key, value) data[key] = tostring(value) end,
		}
	end
	core = permissive({ -- luacheck: ignore (global stub)
		get_modpath = function() return repo .. "/mods/PLAYER/grug_achievements" end,
		get_current_modname = function() return "grug_achievements" end,
		global_exists = function(name) return rawget(_G, name) ~= nil end,
		formspec_escape = function(text) return (text:gsub("[\\%[%];,]", "\\%0")) end,
		colorize = function(_, text) return text end,
		get_mod_storage = function() return new_meta() end,
	})
	grug_sounds = permissive({CLICK_STYLE = ""}) -- luacheck: ignore
	grug_jobs = permissive({}) -- luacheck: ignore
	grug_core = permissive({}) -- luacheck: ignore
	grug_inventory = permissive({}) -- luacheck: ignore
	grug_visuals = permissive({}) -- luacheck: ignore
	grug_mobs = permissive({registered_cadence = {}}) -- luacheck: ignore
	grug_pvp = permissive({stats = function() return {} end}) -- luacheck: ignore
	sfinv = permissive({contexts = {}}) -- luacheck: ignore
	dofile(repo .. "/mods/CORE/grug_core/ui.lua")
	dofile(repo .. "/mods/PLAYER/grug_achievements/init.lua")
	local A = grug_achievements
	local R, book = A.rules, A.book

	local meta = new_meta()
	local player = {get_meta = function() return meta end,
		get_player_name = function() return "rowan" end, is_player = function() return true end}
	-- Every non-account cloak of the catalogue owned.
	local all = {}
	for _, cloak in ipairs(book.cloaks) do
		if not book.default[cloak.id] and not cloak.account then all[#all + 1] = cloak.id end
	end
	meta:set_string(R.KEY_CLOAKS, table.concat(all, ","))

	local function items(fs)
		local list = fs:match("^dropdown%[[^;]*;[^;]*;grug_cloak;(.*);%d+%]$")
		local out = {}
		for name in (list or ""):gmatch("[^,]+") do out[#out + 1] = name end
		return out, tonumber(fs:match(";(%d+)%]$"))
	end
	local function place_of(list, name)
		for index, entry in ipairs(list) do
			if entry == name then return index end
		end
	end

	local owned = A.unlocked_cloaks(player)
	eq(owned[1], "none", "C unlocked_cloaks keeps the catalogue order: No cloak")
	eq(owned[2], "plain_grey", "C ...then the plain grey cloak")
	eq(owned[3], book.cloaks[3].id, "C ...then the catalogue's third")

	local list, index = items(A.cloak_dropdown(player, 0, 0, 4))
	eq(#list, #owned, "C the picker lists every owned cloak")
	eq(list[1], "No cloak", "C No cloak comes first")
	eq(index, 1, "C No cloak is worn and marked")
	local sorted = true
	for i = 3, #list do
		if list[i - 1]:lower() > list[i]:lower() then sorted = false end
	end
	check(sorted, "C the rest is in name order: " .. table.concat(list, " | "))
	local banner = place_of(list, "The Unbought Banner")
	check(banner ~= nil, "C The Unbought Banner is listed")
	check(banner and place_of(list, "Snout") < banner and banner < place_of(list, "Trail Green"),
		"C ...under T, between Snout and Trail Green (the article counts)")
	check(place_of(list, "Plain grey cloak") > place_of(list, "Hunter's Green"),
		"C the plain grey cloak sorts by its name, not by being a default")

	-- Case does not count; equal names keep the catalogue order.
	local trail, deep = book.cloak.hunter_2, book.cloak.hunter_3
	local trail_name, deep_name = trail.name, deep.name
	trail.name, deep.name = "aardvark", "Aardvark"
	list = items(A.cloak_dropdown(player, 0, 0, 4))
	eq(list[2], "aardvark", "C lower case sorts with upper case (catalogue order first)")
	eq(list[3], "Aardvark", "C ...and the equal name after it")
	trail.name, deep.name = trail_name, deep_name

	-- The worn cloak is marked at its sorted place; a name from the list
	-- selects that cloak.
	check(A.choose_cloak_by_name(player, "Trail Green"), "C Trail Green chosen by name")
	eq(A.selected_cloak(player), "hunter_2", "C ...selects hunter_2")
	list, index = items(A.cloak_dropdown(player, 0, 0, 4))
	eq(list[index], "Trail Green", "C the mark sits on Trail Green's sorted place")
	check(index ~= place_of(owned, "hunter_2"), "C ...which is not its catalogue place")
	check(A.choose_cloak_by_name(player, "The Unbought Banner"), "C The Unbought Banner chosen")
	eq(A.selected_cloak(player), "unbought_banner", "C ...selects it")
	list, index = items(A.cloak_dropdown(player, 0, 0, 4))
	eq(list[index], "The Unbought Banner", "C ...and is marked")
	check(not A.choose_cloak_by_name(player, "The Unbought Banner"), "C the same name changes nothing")
	check(A.choose_cloak_by_name(player, "No cloak"), "C No cloak chosen back")
	eq(select(2, items(A.cloak_dropdown(player, 0, 0, 4))), 1, "C ...marked first again")
end

------------------------------------------------------------------------------
-- T  food on touch screens
------------------------------------------------------------------------------
do
	local overrides = {}
	local registered = {}
	core = permissive({ -- luacheck: ignore (global stub)
		registered_items = setmetatable(registered,
			{__index = function(_, name) return {description = name} end}),
		override_item = function(name, def) overrides[name] = def end,
		get_modpath = function() return repo .. "/mods/ITEMS/grug_food" end,
		get_current_modname = function() return "grug_food" end,
		get_us_time = function() return 0 end,
	})
	minetest = core -- luacheck: ignore
	vector = permissive({}) -- luacheck: ignore
	grug_core = permissive({status_icons = {item_icon = function() return "" end}}) -- luacheck: ignore
	grug_abilities = permissive({}) -- luacheck: ignore
	grug_gathering = permissive({p9g_sources = function() -- luacheck: ignore
		return {{key = "potato", raw_item = "t:potato"}}
	end})
	grug_sounds = permissive({}) -- luacheck: ignore
	grug_traders = permissive({}) -- luacheck: ignore
	grug_classes = permissive({}) -- luacheck: ignore
	grug_gear = permissive({}) -- luacheck: ignore
	assert(loadfile(repo .. "/mods/ITEMS/grug_food/init.lua"))()

	local MODES = {long_dig_short_place = true, short_dig_long_place = true, user = true}
	local foods = 0
	for _, row in ipairs(grug_food.converted) do
		foods = foods + 1
		local def = overrides[row.name]
		local touch = def and def.touch_interaction
		check(type(touch) == "table", row.name .. ": a touch gesture table")
		touch = touch or {}
		eq(touch.pointed_nothing, "short_dig_long_place", row.name .. ": nothing: a long tap places")
		eq(touch.pointed_node, "long_dig_short_place", row.name .. ": node: a short tap places")
		eq(touch.pointed_object, "long_dig_short_place", row.name .. ": object: a short tap talks")
		for key, mode in pairs(touch) do
			check(MODES[mode] == true, row.name .. ": " .. key .. " is an engine mode")
		end
		eq(def and def.on_use, false, row.name .. ": no on_use (an item that cannot be used)")
		check(def and def.description:find("\nHold RMB for 1.5 s to eat one portion.\n" ..
			"On a touch screen, long-press the sky or anything out of reach instead.", 1, true) ~= nil,
			row.name .. ": the tooltip names the touch gesture")
	end
	check(foods >= 14, "T every current food and the gathering food registered (" .. foods .. ")")
	check(overrides["t:potato"] ~= nil, "T a gathering food carries it too")

	-- P (0.84.1): the click on release (a short tap at an object on a touch
	-- screen, a short RMB click on desktop) at a dropped item picks it up
	-- through the one pickup path and does nothing else; at any other
	-- entity it still runs that entity's right-click.
	local pickups, clicks, writes, takes = {}, {}, 0, true
	grug_inventory = {pick_up_pointed = function(player, pointed) -- luacheck: ignore
		pickups[#pickups + 1] = {player = player, pointed = pointed}
		return takes
	end}
	local wielded = "default:apple"
	local player = {
		get_wielded_item = function() return {get_name = function() return wielded end} end,
		set_wielded_item = function() writes = writes + 1 end,
		get_player_name = function() return "rowan" end,
	}
	local function object(name)
		local entity = name and {name = name}
		return {type = "object", ref = {get_luaentity = function() return entity end}}
	end
	local function rightclick(entity) clicks[#clicks + 1] = entity.name end
	local function click(pointed)
		pickups, clicks, writes = {}, {}, 0
		return grug_food.click(player, pointed, rightclick)
	end

	local drop = object("__builtin:item")
	eq(click(drop), true, "P a drop: the click is handled")
	eq(#pickups, 1, "P a drop: one pickup attempt")
	check(pickups[1] and pickups[1].player == player and pickups[1].pointed == drop,
		"P a drop: the pickup gets the player and the pointed drop")
	eq(#clicks, 0, "P a drop: no entity right-click")
	eq(writes, 0, "P a drop: the wielded stack is not written back (the pickup may merge into it)")

	takes = false -- a full inventory: the pickup takes nothing
	eq(click(drop), true, "P a drop, inventory full: handled")
	eq(#pickups, 1, "P a drop, inventory full: still one attempt")
	eq(#clicks + writes, 0, "P a drop, inventory full: nothing else happens")
	takes = true

	eq(click(object("grug_traders:vendor")), true, "P an NPC: the click is handled")
	eq(#pickups, 0, "P an NPC: no pickup")
	eq(clicks[1], "grug_traders:vendor", "P an NPC: its own right-click runs (talks)")

	click(object(nil))
	eq(#pickups + #clicks, 0, "P an object gone since the press: nothing")

	wielded = "t:not_food"
	eq(click(drop), false, "P no food in hand: not a food click")
	eq(#pickups, 0, "P no food in hand: no pickup")
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R84 SMALL PORTABLE FAIL") end
print("R84 SMALL PORTABLE PASS checks=" .. checks)
