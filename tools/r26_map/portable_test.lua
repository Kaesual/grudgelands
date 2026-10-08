-- Round 26 map follow-ups, portable test (LuaJIT): the Housing Steward map
-- icon and the 8x zoom level of the map.
--
--   luajit tools/r26_map/portable_test.lua [repo]
--
-- Loads the REAL grug_map atlas.lua and providers.lua on a fake engine (the
-- same stub style as tools/r25_home_stone/fixture.lua, section M). Since
-- Round 44 the map is its own window (window.lua): what it draws, its zoom
-- steps and its scroll echo are checked by tools/r44_mq.
-- Checks:
--   S  the Steward marker has its own kind and texture; the texture is a
--      shipped 16x16 PNG with a LICENSE-media row; no other marker uses it
--      (since Round 44 the map window draws no Steward, ruling 12; the
--      minimap does);
--   Z  zoom steps stop at 8 and 1; the 8x scroll range; zooming keeps the
--      view centre (atlas.lua);
--   H  (Round 32) hostile camps, bandits and Mirefolk by their slot, drew a
--      red "X"; since Round 44 every settlement and camp is baked into the
--      base image, so no provider returns a settlement or camp marker;
--   C  (Round 34) the Crownbinder and the Decor Merchant have service
--      markers with their own icons, on the map and the minimap.
-- Prints "R26 MAP PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

local loaded = {}
local player = {
	get_player_name = function() return "tester" end,
	get_pos = function() return {x = 100, y = 10, z = -200} end,
	get_look_horizontal = function() return 0 end,
}
rawset(_G, "core", {
	-- providers.lua reads its own mod's location_view.lua through these.
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
	register_globalstep = function() end,
	register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end,
	get_player_by_name = function() return player end,
	get_us_time = function() return 0 end,
	formspec_escape = function(text)
		return (text:gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
			:gsub(";", "\\;"):gsub(",", "\\,"))
	end,
	registered_entities = {["grug_mobs:king_human"] = {description = "King"}},
})

local STEWARD_POS = {x = 1234, y = 30, z = -987}
local settlements = {{key = "highcourt", race_id = "human", anchor = {x = 1200, z = -950}},
	-- Round 32: a start-zone and a frontier bandit camp, a Mirefolk camp and
	-- a village (by slot, not by key).
	{key = "goldmead_bandit_camp", display_name = "Goldmead Bandit Camp", race_id = "human",
		slot = "bandit_1", anchor = {x = 320, z = -1980}},
	{key = "r20_anchor_050", display_name = "Slatehook Hideout", race_id = "dwarf",
		slot = "bandit_1", anchor = {x = -1824, z = -526}},
	{key = "r20_anchor_067", display_name = "Siltbasket Camp", race_id = "human",
		slot = "mirefolk", anchor = {x = -620, z = -1760}},
	{key = "goldmead_village", display_name = "Goldmead Village", race_id = "human",
		slot = "village_1", anchor = {x = 400, z = -1700}}}
local sockets = {highcourt = {
	{id = "zz_trainer", role = "trainer", profession = "tailor",
		pos = {x = 1236, y = 30, z = -985}},
	{id = "market_counting_house/market_counting_house_gate_idle",
		role = "housing_manager", pos = STEWARD_POS},
	{id = "riding", role = "riding_trainer", pos = {x = 1180, y = 30, z = -940}},
	{id = "throne", role = "king", pos = {x = 1190, y = 30, z = -930}},
	-- Round 34: the capital services (grug_traders/vendors.lua).
	{id = "goldsmith_hall/goldsmith_hall_gate_idle", role = "crownbinder",
		pos = {x = 1250, y = 30, z = -960}},
	{id = "woodcarver_yard/woodcarver_yard_gate_idle", role = "culture_vendor",
		pos = {x = 1260, y = 30, z = -970}},
}}
rawset(_G, "grug_core", {
	settlement_socket_settlements = function() return settlements end,
	settlement_sockets_at = function(key) return sockets[key] or {} end,
	zone_authority_installed = function() return false end,
	faction_ids = {"accord", "throng"},
	start_identities = function() return {{race_id = "human", faction_id = "accord"}} end,
})
rawset(_G, "grug_factions", {get_faction = function() return "accord" end,
	register_on_faction_chosen = function() end})
rawset(_G, "grug_jobs", {PROFESSIONS = {tailor = {name = "Tailor"}}})
rawset(_G, "grug_mobs", {dragon_map_markers = function() return {} end})
rawset(_G, "grug_quests", {registered_npcs = {}, marker_states = function() return {}, 1 end})
rawset(_G, "grug_parties", {view = function() return nil end})
rawset(_G, "grug_home", {get = function() return nil end, locations = function() return {} end,
	known_waypoints = function() return {} end})
rawset(_G, "grug_zones", {at = function() return nil end})
rawset(_G, "grug_inventory", {UI = {width = 10.4, height = 11.1}})
local page
rawset(_G, "sfinv", {register_page = function(_, p) page = p end,
	make_formspec = function(_, _, fs) return fs end, contexts = {},
	set_page = function() end, set_player_inventory_formspec = function() end,
	inventory_suspended = function() return false end})

rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua"),
	-- Round 27: the Map tab reads the minimap switch.
	minimap = {enabled = function() return true end, available = function() return true end}})
local atlas = grug_map.atlas
atlas.set_base_texture("grug_map_base.png")
dofile(repo .. "/mods/PLAYER/grug_map/providers.lua")
for _, fn in ipairs(loaded) do fn() end

-- ---------------------------------------------------------------------------
-- S: the Steward icon
-- ---------------------------------------------------------------------------
local TEXTURE = "grug_map_housing_steward.png"
local steward, users = nil, 0
for _, marker in ipairs(atlas.collect_markers(player)) do
	if marker.label == "Housing Steward" then steward = marker end
	if marker.texture == TEXTURE then users = users + 1 end
end
check(steward ~= nil, "S steward marker present")
steward = steward or {}
check(steward.kind == "steward" and steward.texture == TEXTURE,
	"S steward kind/texture: " .. tostring(steward.kind) .. " " .. tostring(steward.texture))
check(users == 1, "S only the steward uses its icon (" .. users .. ")")
do
	local order = {}
	for index, marker in ipairs(atlas.collect_markers(player)) do order[marker.kind] = index end
	check(order.steward and order.trainer and order.steward > order.trainer,
		"S steward draws above a trainer standing beside it")
end
check(steward.position and steward.position.x == STEWARD_POS.x and
	steward.position.z == STEWARD_POS.z, "S steward at its socket")

local function png_size(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local header = file:read(24)
	file:close()
	if not header or header:sub(2, 4) ~= "PNG" then return nil end
	local function u32(offset)
		local a, b, c, d = header:byte(offset, offset + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	return u32(17), u32(21)
end
local w, h = png_size(repo .. "/mods/PLAYER/grug_map/textures/" .. TEXTURE)
check(w == 16 and h == 16, "S icon is a 16x16 PNG (" .. tostring(w) .. "x" .. tostring(h) .. ")")
do
	local file = io.open(repo .. "/mods/PLAYER/grug_map/LICENSE-media.md", "rb")
	local text = file and file:read("*a") or ""
	if file then file:close() end
	check(text:find(TEXTURE, 1, true) and text:find("render_steward_icon.py", 1, true)
		and text:find("CC0", 1, true), "S LICENSE-media row")
end

-- C (Round 34): the Crownbinder and the Decor Merchant, kind "service" on
-- the Steward's layer, with their own icons (16x16, LICENSE-media row), and
-- the minimap shows the kind.
do
	local found, order = {}, {}
	for index, marker in ipairs(atlas.collect_markers(player)) do
		found[marker.label] = marker
		order[marker.kind] = index
	end
	for label, texture in pairs({Crownbinder = "grug_map_crownbinder.png",
			["Decor Merchant"] = "grug_map_decor_merchant.png"}) do
		local marker = found[label] or {}
		check(marker.kind == "service" and marker.texture == texture and
			marker.faction == "accord", "C " .. label .. " marker, kind and faction")
		local sw, sh = png_size(repo .. "/mods/PLAYER/grug_map/textures/" .. texture)
		check(sw == 16 and sh == 16, "C " .. texture .. " is a 16x16 PNG")
		local file = io.open(repo .. "/mods/PLAYER/grug_map/LICENSE-media.md", "rb")
		local text = file and file:read("*a") or ""
		if file then file:close() end
		check(text:find(texture, 1, true) and text:find("tools/r34_f2/render_icons.py", 1, true),
			"C " .. texture .. " LICENSE-media row")
	end
	check(order.service and order.trainer and order.service > order.trainer,
		"C services draw above a trainer")
	local file = io.open(repo .. "/mods/PLAYER/grug_map/minimap.lua", "rb")
	local minimap = file and file:read("*a") or ""
	if file then file:close() end
	local shown = minimap:match("local SHOWN = (%b{})") or ""
	local priority = minimap:match("local PRIORITY = (%b{})") or ""
	check(shown:find("service = true", 1, true) and priority:find("service = 2", 1, true),
		"C the minimap shows the services with the Steward's priority")
end

-- H: hostile camps and settlements (Round 32, Round 44): baked into the
-- base image, no markers.
do
	local kinds = {}
	for _, marker in ipairs(atlas.collect_markers(player)) do kinds[marker.kind] = true end
	check(not kinds.hostile and not kinds.settlement and not kinds.boss,
		"H no settlement, camp or boss markers (baked since Round 44)")
end
check(atlas.MAX_ZOOM == 8, "Z top level is 8x")
check(atlas.step_zoom(8, true) == 8 and atlas.step_zoom(1, false) == 1 and
	atlas.step_zoom(nil, true) == 2, "Z step_zoom bounds")
check(atlas.scroll_limit(8) == 7000 and atlas.clamp_scroll(99999, 8) == 7000 and
	atlas.zoom_scroll(3500, 8, 4) == 1500, "Z scroll range, clamp and centre-keeping zoom")

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R26 MAP PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
print(("R26 MAP PORTABLE PASS checks=%d"):format(checks))
