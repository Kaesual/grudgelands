-- Round 26 map follow-ups, portable test (LuaJIT): the Housing Steward map
-- icon and the 8x zoom level of the Map tab.
--
--   luajit tools/r26_map/portable_test.lua [repo]
--
-- Loads the REAL grug_map atlas.lua, providers.lua and page.lua on a fake
-- engine (the same stub style as tools/r25_home_stone/fixture.lua, section M).
-- Checks:
--   S  the Steward marker has its own kind and texture; the texture is a
--      shipped 16x16 PNG with a LICENSE-media row; no other marker uses it;
--      the page draws it as an image button at its world position;
--   Z  zoom steps 1 -> 2 -> 4 -> 8 and stops at 8, back down to 1; the page
--      label, base image size, scroll range and thumb follow the level;
--      markers scale with the level; zooming keeps the view centre; scroll
--      values clamp to the 8x range.
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
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
	register_globalstep = function() end,
	register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end,
	get_player_by_name = function() return player end,
	formspec_escape = function(text)
		return (text:gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
			:gsub(";", "\\;"):gsub(",", "\\,"))
	end,
	registered_entities = {["grug_mobs:king_human"] = {description = "King"}},
})

local STEWARD_POS = {x = 1234, y = 30, z = -987}
local settlements = {{key = "highcourt", race_id = "human", anchor = {x = 1200, z = -950}}}
local sockets = {highcourt = {
	{id = "zz_trainer", role = "trainer", profession = "tailor",
		pos = {x = 1236, y = 30, z = -985}},
	{id = "market_counting_house/market_counting_house_gate_idle",
		role = "housing_manager", pos = STEWARD_POS},
	{id = "riding", role = "riding_trainer", pos = {x = 1180, y = 30, z = -940}},
	{id = "throne", role = "king", pos = {x = 1190, y = 30, z = -930}},
}}
rawset(_G, "grug_core", {
	settlement_socket_settlements = function() return settlements end,
	settlement_sockets_at = function(key) return sockets[key] or {} end,
	zone_authority_installed = function() return false end,
})
rawset(_G, "grug_jobs", {PROFESSIONS = {tailor = {name = "Tailor"}}})
rawset(_G, "grug_mobs", {dragon_map_markers = function() return {} end})
rawset(_G, "grug_quests", {registered_npcs = {}, marker_state = function() return nil end})
rawset(_G, "grug_parties", {view = function() return nil end})
rawset(_G, "grug_home", {get = function() return nil end, locations = function() return {} end})
rawset(_G, "grug_zones", {at = function() return nil end})
rawset(_G, "grug_inventory", {UI = {width = 10.4, height = 11.1}})
local page
rawset(_G, "sfinv", {register_page = function(_, p) page = p end,
	make_formspec = function(_, _, fs) return fs end, contexts = {},
	set_page = function() end, set_player_inventory_formspec = function() end,
	inventory_suspended = function() return false end})

rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua"),
	-- Round 27: the Map tab reads the minimap switch.
	minimap = {enabled = function() return true end}})
local atlas = grug_map.atlas
atlas.set_base_texture("grug_map_base.png")
dofile(repo .. "/mods/PLAYER/grug_map/providers.lua")
dofile(repo .. "/mods/PLAYER/grug_map/page.lua")
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

local function button_at(fs, texture)
	local x, y = fs:match("image_button%[([%d.%-]+),([%d.%-]+);0%.34,0%.34;" ..
		texture:gsub("%.", "%%.") .. ";")
	return tonumber(x), tonumber(y)
end

-- ---------------------------------------------------------------------------
-- Z: zoom levels
-- ---------------------------------------------------------------------------
local context = {}
page.on_enter(page, player, context)
local fs1 = page.get(page, player, context)
local x1, y1 = button_at(fs1, TEXTURE)
check(x1 ~= nil, "S steward image button on the page")
check(fs1:find("label[0.15,0.22;World — 1x]", 1, true), "Z label at 1x")
local base_w = tonumber(fs1:match("image%[0,0;([%d.]+),[%d.]+;grug_map_base%.png%]"))
check(base_w and base_w > 5, "Z base image at 1x")

check(atlas.MAX_ZOOM == 8, "Z top level is 8x")
local levels = {}
for _ = 1, 4 do
	page.on_player_receive_fields(page, player, context, {grug_map_zoom_in = "+"})
	levels[#levels + 1] = context.grug_map_zoom
end
check(table.concat(levels, ",") == "2,4,8,8", "Z zoom in steps " .. table.concat(levels, ","))
local fs8 = page.get(page, player, context)
check(fs8:find("label[0.15,0.22;World — 8x]", 1, true), "Z label at 8x")
local base8 = tonumber(fs8:match("image%[0,0;([%d.]+),[%d.]+;grug_map_base%.png%]"))
check(base_w and base8 and near(base8, base_w * 8, 1e-3), "Z base image 8x wide")
check(fs8:find("scrollbaroptions[min=0;max=7000;", 1, true) and
	fs8:find("thumbsize=875;", 1, true), "Z scroll range and thumb at 8x")
local x8, y8 = button_at(fs8, TEXTURE)
check(x1 and x8 and near(x8 + 0.17, (x1 + 0.17) * 8, 0.01) and
	near(y8 + 0.17, (y1 + 0.17) * 8, 0.01), "Z steward position scales 8x")

-- Scrolling clamps to the 8x range; zooming keeps the view centre.
page.on_player_receive_fields(page, player, context,
	{grug_map_scroll_x = "CHG:99999", grug_map_scroll_y = "VAL:3500"})
check(context.grug_map_scroll_x == 7000 and context.grug_map_scroll_y == 3500,
	"Z scroll clamps to 7000")
page.on_player_receive_fields(page, player, context,
	{grug_map_zoom_out = "-", grug_map_scroll_y = "VAL:3500"})
-- View centre in unzoomed viewport units: (scroll + 500) / zoom.
check(context.grug_map_zoom == 4 and near((context.grug_map_scroll_y + 500) / 4,
	(3500 + 500) / 8, 1) and context.grug_map_scroll_x == 3000,
	"Z zoom out keeps the centre (" .. context.grug_map_scroll_x .. "," ..
	context.grug_map_scroll_y .. ")")
for _ = 1, 3 do
	page.on_player_receive_fields(page, player, context, {grug_map_zoom_out = "-"})
end
check(context.grug_map_zoom == 1 and context.grug_map_scroll_x == 0 and
	context.grug_map_scroll_y == 0, "Z back to 1x")
check(atlas.step_zoom(8, true) == 8 and atlas.step_zoom(1, false) == 1 and
	atlas.step_zoom(nil, true) == 2, "Z step_zoom bounds")

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R26 MAP PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
print(("R26 MAP PORTABLE PASS checks=%d"):format(checks))
