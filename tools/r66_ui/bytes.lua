-- Round 66 lane UI: the form strings of the inventory pages and the map
-- window on screens whose viewport ceiling did not grow, as a length and a
-- hash per screen profile, so the same command measures a tree before and
-- after the lane (the outputs must be identical):
--   luajit tools/r66_ui/bytes.lua REPO          the Inventory page and every
--                                               Character page mode (the
--                                               tools/r44_ch harness)
--   luajit tools/r66_ui/bytes.lua REPO map      the Map & Quests window at
--                                               every layer and zoom (the
--                                               tools/r44_mq fixture's scene)
-- Both load REPO's grug_core/ui_window.lua (the harnesses do not). Profiles:
-- 1280x720, 1920x1080 and 2560x1440 at GUI scale 1, 1.5, 2 and density 1, 2;
-- 3840x2160 is printed as well and is expected to differ.
local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local repo, part = arg and arg[1] or ".", arg and arg[2] or "pages"
local function hash(text)
	local h = 5381
	for i = 1, #text do h = (h * 33 + text:byte(i)) % 2147483647 end
	return ("%08x"):format(h)
end
local function information(w, h, gui, density)
	local slot = math.max(0.5555 * 96 * density * gui, math.min(w, h) / 15 * gui)
	return {size = {x = w, y = h}, max_formspec_size = {x = w / slot, y = h / slot},
		real_gui_scaling = gui * density, real_hud_scaling = gui * density}
end
local PROFILES = {}
for _, size in ipairs({{1280, 720}, {1920, 1080}, {2560, 1440}, {3840, 2160}}) do
	for _, scale in ipairs({{1, 1}, {1.5, 1}, {2, 1}, {1, 2}}) do
		PROFILES[#PROFILES + 1] = {size[1], size[2], scale[1], scale[2]}
	end
end
local function each_profile(fn)
	for _, p in ipairs(PROFILES) do
		fn(("%dx%d gui %g density %g"):format(p[1], p[2], p[3], p[4]), information(p[1], p[2], p[3], p[4]))
	end
end
local function line(tag, name, text)
	print(("%-34s %-22s %7d %s"):format(tag, name, #text, hash(text)))
end

if part == "pages" then
	local H = dofile(here .. "/../r44_ch/harness.lua")(repo)
	dofile(repo .. "/mods/CORE/grug_core/ui_window.lua")
	H.status_effects = {{id = "food", name = "Hearty Stew", texture = "grug_food_stew.png",
		detail = "+2% HP/5s", remaining_us = 600000000}}
	local scout = H.player("scout", "scout", {32, 32, 32, 32})
	H.put(scout, "grug_weapon", 1, "grug_gear:bow_bronze")
	-- Since Round 66 EQUIP: a blocked offhand (a Mage's Staff) and the equip
	-- notice in place of the gear box heading (absent before: same bytes as
	-- an unblocked page then).
	local mage = H.player("mage", "mage", {8})
	H.put(mage, "grug_weapon", 1, "grug_gear:staff_bronze")
	each_profile(function(tag, info)
		H.window_info.scout, H.window_info.mage = info, info
		for _, mode in ipairs({"stats", "effects", "achievements"}) do
			line(tag, "character " .. mode, H.page(scout, mode))
		end
		line(tag, "character blocked", H.page(mage, "stats"))
		sfinv.get_or_create_context(mage).grug_equip_notice = {expires = math.huge,
			text = "Staff is two-handed: take Spellbook out first."}
		line(tag, "character notice", H.page(mage, "stats"))
		sfinv.get_or_create_context(mage).grug_equip_notice = nil
		local context = sfinv.get_or_create_context(scout)
		context.page = "grug_inventory:inventory"
		local ok, form = pcall(sfinv.get_formspec, scout, context)
		if ok then line(tag, "inventory", form) end
	end)
	return
end

-- The map window: run the R44 MQ fixture for its scene (its checks pass or
-- fail as usual), loading ui_window.lua next to ui.lua and keeping the
-- window module and the first player the fixture renders.
local W, player
local real_dofile = dofile
function dofile(path)
	local result = real_dofile(path)
	if path:match("grug_core/ui%.lua$") then real_dofile(repo .. "/mods/CORE/grug_core/ui_window.lua") end
	if path:match("grug_map/window%.lua$") then
		W = result
		local formspec = W.formspec
		function W.formspec(p, ...)
			player = player or p
			return formspec(p, ...)
		end
	end
	return result
end
arg = {[0] = here .. "/../r44_mq/portable_test.lua", repo}
local ok, err = pcall(real_dofile, here .. "/../r44_mq/portable_test.lua")
if not ok then print("r44_mq: " .. tostring(err)) end
dofile = real_dofile
assert(W and player, "the map window was not rendered")
each_profile(function(tag, info)
	for _, layer in ipairs({"quests", "trainers", "towns", "zones"}) do
		for _, zoom in ipairs({1, 4}) do
			local state = W.new_state()
			state.layer, state.zoom = layer, zoom
			line(tag, ("map %s %dx"):format(layer, zoom), W.formspec(player, state, info))
		end
	end
end)
