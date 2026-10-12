-- Round 46 lane RP portable test (LuaJIT): repair only in towns, and the
-- mender's map marker (round46-plan.md §4.11, ruling 16).
--
--   luajit tools/r46_rp/portable_test.lua [repo]
--
-- Loads the REAL grug_repair service.lua and providers.lua, and the REAL
-- grug_map atlas.lua and providers.lua, on a fake engine. Checks:
--   P  the providers: "trainer" is the only provider kind; no station API
--      (can_open_station, open_station); a station provider is refused; a
--      teaching trainer and the mender still repair for their own faction
--      and refuse the other; the mender's click opens its titled repair form
--      through the real quote;
--   M  the map: the mender's marker is a service with grug_map_repair.png
--      and the mender's title, of its settlement's faction; the teaching
--      trainer keeps its trainer icon; a socket of an unknown profession or
--      one that spawns nothing gets no repair marker; the texture is a
--      16x16 PNG with its LICENSE-media row; the marker row has no tooltip
--      of its own (the window and the minimap draw services without one:
--      tools/r44_mq, tools/r27_minimap);
--   H  Help says repairs are made only in towns; the furnace dialog
--      (grug_jobs/workspaces.lua) has no repair path (its runtime:
--      tools/r37_ix F).
-- Prints "R46 RP PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function eq(got, want, label)
	check(got == want, label .. " (got " .. tostring(got) .. ", expected " .. tostring(want) .. ")")
end
local function read(path)
	local file = io.open(repo .. "/" .. path, "rb")
	local text = file and file:read("*a") or ""
	if file then file:close() end
	return text
end

-- ---------------------------------------------------------------------------
-- fake engine
-- ---------------------------------------------------------------------------
local loaded, receivers, shown = {}, {}, {}
local function vec(x, y, z) return {x = x, y = y, z = z} end
rawset(_G, "vector", {new = function(p) return vec(p.x, p.y, p.z) end})
rawset(_G, "core", {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
	register_on_player_receive_fields = function(fn) receivers[#receivers + 1] = fn end,
	register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end,
	register_globalstep = function() end,
	get_us_time = function() return 0 end,
	formspec_escape = function(text) return (text:gsub("[%[%];,\\]", "\\%0")) end,
	show_formspec = function(name, formname, spec)
		shown[#shown + 1] = {name = name, form = formname, spec = spec}
	end,
})

local function new_list(size)
	local list = {}
	for i = 1, size do
		list[i] = {is_empty = function() return true end, get_wear = function() return 0 end}
	end
	return list
end
local function new_player(name, faction, pos)
	local inventory = {main = new_list(4)}
	return {name = name, faction = faction, pos = pos, hp = 20,
		is_player = function() return true end,
		get_player_name = function(self) return self.name end,
		get_hp = function(self) return self.hp end,
		get_pos = function(self) return self.pos end,
		get_look_horizontal = function() return 0 end,
		get_inventory = function()
			return {get_list = function(_, list) return inventory[list] end}
		end}
end

-- Two settlements: Highcourt (human, accord) with a tailor trainer, the
-- mender on its Cooking socket, a socket of an unknown profession and a
-- Cooking socket that spawns nothing; Gor Drazhak (orc, throng) with its
-- mender.
local settlements = {{key = "highcourt", race_id = "human"}, {key = "gor_drazhak", race_id = "orc"}}
local sockets = {
	highcourt = {
		{id = "t_tailor", role = "trainer", profession = "tailor", pos = vec(10, 5, 10)},
		{id = "t_cooking", role = "trainer", profession = "cooking", pos = vec(20, 5, 10)},
		{id = "t_unknown", role = "trainer", profession = "nonsense", pos = vec(30, 5, 10)},
		{id = "t_quiet", role = "trainer", profession = "cooking", pos = vec(40, 5, 10), spawn = false},
	},
	gor_drazhak = {
		{id = "t_cooking", role = "trainer", profession = "cooking", pos = vec(-20, 5, -10)},
	},
}
local MENDER = "Grudge-Free Repairs"
rawset(_G, "grug_core", {
	settlement_socket_settlements = function() return settlements end,
	settlement_sockets_at = function(key) return sockets[key] or {} end,
	faction_ids = {"accord", "throng"},
	start_identities = function()
		return {{race_id = "human", faction_id = "accord"}, {race_id = "orc", faction_id = "throng"}}
	end,
})
rawset(_G, "grug_classes", {registered_races = {human = {faction = "accord"}, orc = {faction = "throng"}}})
rawset(_G, "grug_factions", {get_faction = function(p) return p.faction end})
rawset(_G, "grug_jobs", {
	PROFESSIONS = {tailor = {name = "Tailor"}, cooking = {name = "Cooking"}},
	MENDER_TITLE = MENDER,
	GREETINGS = {mender = "Welcome."},
	trainer_teaches = function(p) return p == "tailor" end,
})
rawset(_G, "grug_inventory", {equipment_slots = {}, BAG_COUNT = 0,
	content_list = function(i) return "bag" .. i end,
	wrap_text = function(text) return text end})
rawset(_G, "grug_money", {format = function(copper) return copper .. "c" end})

-- ---------------------------------------------------------------------------
-- P: the providers
-- ---------------------------------------------------------------------------
rawset(_G, "grug_repair", {})
dofile(repo .. "/mods/ITEMS/grug_repair/service.lua")
local kinds = {}
do
	local register = grug_repair.register_provider
	grug_repair.register_provider = function(kind, permitted)
		kinds[#kinds + 1] = kind
		return register(kind, permitted)
	end
	dofile(repo .. "/mods/ITEMS/grug_repair/providers.lua")
	grug_repair.register_provider = register
end
eq(table.concat(kinds, ","), "trainer", "P the trainer is the only provider kind")
eq(grug_repair.can_open_station, nil, "P no can_open_station")
eq(grug_repair.open_station, nil, "P no open_station")

local ann = new_player("ann", "accord", vec(15, 5, 10))
local orc = new_player("grosh", "throng", vec(15, 5, 10))
eq(grug_repair.provider_permitted(ann, {kind = "station", pos = vec(11, 5, 11)}), false,
	"P a station provider is refused")

-- A trainer-socket NPC as grug_mobs/start_npcs.lua places it.
local function npc(settlement, socket)
	local entity = {_grug_start = settlement, _grug_socket = socket.id,
		_grug_socket_role = "trainer", _grug_profession = socket.profession}
	entity.object = {get_pos = function() return socket.pos end,
		get_luaentity = function() return entity end}
	return entity
end
local tailor = npc("highcourt", sockets.highcourt[1])
local mender = npc("highcourt", sockets.highcourt[2])
eq(grug_repair.can_open_trainer(ann, tailor), true, "P the tailor trainer repairs")
eq(grug_repair.can_open_trainer(ann, mender), true, "P the mender repairs")
eq(grug_repair.can_open_trainer(orc, mender), false, "P the mender refuses the other faction")
ann.pos = vec(20, 5, 30)
eq(grug_repair.can_open_trainer(ann, mender), false, "P the mender refuses a player 20 nodes away")
ann.pos = vec(19, 5, 11)
eq(grug_repair.open_trainer(ann, mender), true, "P the mender's click opens the repair form")
local last = shown[#shown] or {}
check((last.form or ""):find("^grug_repair:service:") ~= nil, "P ...the repair form")
check((last.spec or ""):find(MENDER, 1, true) ~= nil, "P ...titled with the mender's title")
check((last.spec or ""):find("Nothing needs repair.", 1, true) ~= nil, "P ...through the real quote")

-- ---------------------------------------------------------------------------
-- M: the map
-- ---------------------------------------------------------------------------
rawset(_G, "grug_parties", {view = function() return nil end})
rawset(_G, "grug_quests", {registered_npcs = {}, marker_states = function() return {}, 1 end})
rawset(_G, "grug_home", {get = function() return nil end, locations = function() return {} end,
	known_waypoints = function() return {} end, claim_waypoint = function() return nil end})
rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")})
local atlas = grug_map.atlas
dofile(repo .. "/mods/PLAYER/grug_map/providers.lua")
for _, fn in ipairs(loaded) do fn() end

local TEXTURE = "grug_map_repair.png"
local function markers_of(player)
	local by_label, repair = {}, {}
	for _, marker in ipairs(atlas.collect_markers(player, {service = true})) do
		by_label[marker.label] = marker
		if marker.texture == TEXTURE then repair[#repair + 1] = marker end
	end
	return by_label, repair
end
local by_label, repair = markers_of(ann)
local marker = by_label[MENDER] or {}
eq(marker.kind, "service", "M the mender is marked as a service")
eq(marker.texture, TEXTURE, "M ...with the repair icon")
eq(marker.faction, "accord", "M ...of its settlement's faction")
check(marker.position and marker.position.x == 20 and marker.position.z == 10,
	"M ...at its socket")
eq(marker.tooltip, nil, "M ...and no tooltip of its own")
eq(#repair, 1, "M one repair marker for the accord (no unknown or quiet socket)")
local trainer = by_label["Tailor Trainer"] or {}
check(trainer.kind == "trainer" and trainer.texture == "grug_map_trainer_tailor.png",
	"M the repairing trainer keeps its trainer icon")
local _, throng_repair = markers_of(orc)
check(#throng_repair == 1 and throng_repair[1].position.x == -20,
	"M the throng sees only its own mender")

local png = read("mods/PLAYER/grug_map/textures/" .. TEXTURE)
local function u32(offset)
	local a, b, c, d = png:byte(offset, offset + 3)
	return ((a * 256 + b) * 256 + c) * 256 + d
end
check(png:sub(2, 4) == "PNG" and u32(17) == 16 and u32(21) == 16 and png:byte(26) == 6,
	"M the icon is a 16x16 RGBA PNG")
local licence = read("mods/PLAYER/grug_map/LICENSE-media.md")
local row = licence:match("\n(| `textures/grug_map_repair%.png` |[^\n]*)") or ""
check(row:find("GPT-6 Astra", 1, true) and row:find("AI-assisted", 1, true) and
	row:find("CC0-1.0", 1, true) and row:find("tools/r46_art/repair/", 1, true),
	"M the LICENSE-media row (author, AI-assisted, CC0, source)")

-- ---------------------------------------------------------------------------
-- H: help and the furnace dialog
-- ---------------------------------------------------------------------------
check(read("mods/PLAYER/grug_inventory/help.lua"):find("Repairs are made only in towns", 1, true),
	"H Help: repairs only in towns")
local workspaces = read("mods/PLAYER/grug_jobs/workspaces.lua")
check(workspaces ~= "" and not workspaces:find("grug_repair", 1, true) and
	not workspaces:find("grug_jobs_repair", 1, true), "H the furnace dialog has no repair path")

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R46 RP PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
print(("R46 RP PORTABLE PASS checks=%d"):format(checks))
