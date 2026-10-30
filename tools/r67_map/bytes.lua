-- Round 67 lane MAP: the map window's bytes per send in a party of five
-- (the player and four members), so a base tree and the branch can be
-- compared (goal 6: the party check from 2 s to 1 s):
--   luajit tools/r67_map/bytes.lua REPO
-- Runs REPO's own tools/r44_mq fixture for its scene (its checks pass or
-- fail as usual; only its first rendered player and the window module are
-- kept), loading REPO's grug_core/ui_window.lua next to ui.lua, then puts
-- the player into a party of five and prints, per screen profile and
-- layer at zoom 1: the form's length, its tooltip count and the bytes a
-- minute a walking party costs at the window's PARTY_US (one send per
-- check). Numbers are comparisons, never targets.
local repo = arg and arg[1] or "."
local real_dofile = dofile
local W, player
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
local fixture = repo .. "/tools/r44_mq/portable_test.lua"
arg = {[0] = fixture, repo}
local quiet = print
print = function() end
local ok, err = pcall(real_dofile, fixture)
print = quiet
if not ok then print("r44_mq: " .. tostring(err):sub(1, 80)) end
dofile = real_dofile
assert(W and player, "the map window was not rendered")

-- Four members spread around the player, each a moving arrow with a name.
local members, others = {player:get_player_name()}, {}
for i = 1, 4 do
	local name = "member" .. i
	members[#members + 1] = name
	local pos = {x = 200 * i - 500, y = 10, z = 150 * i - 300}
	others[name] = {
		get_player_name = function() return name end,
		get_pos = function() return {x = pos.x, y = pos.y, z = pos.z} end,
		get_look_horizontal = function() return i end,
	}
end
local by_name = core.get_player_by_name
core.get_player_by_name = function(name) return others[name] or by_name(name) end
grug_parties.in_party = function() return true end
grug_parties.view = function()
	local rows = {}
	for _, name in ipairs(members) do rows[#rows + 1] = {name = name, online = true} end
	return {members = rows}
end

local function information(w, h)
	local slot = math.max(0.5555 * 96, math.min(w, h) / 15)
	return {size = {x = w, y = h}, max_formspec_size = {x = w / slot, y = h / slot},
		real_gui_scaling = 1, real_hud_scaling = 1}
end
local per_minute = 60e6 / W.PARTY_US
print(("PARTY_US %.1f s: at most %d sends a minute in a walking party"):format(W.PARTY_US / 1e6,
	per_minute))
print(("%-11s %-9s %7s %8s %10s"):format("profile", "layer", "bytes", "tooltips", "bytes/min"))
for _, size in ipairs({{1920, 1080}, {3840, 2160}}) do
	local info = information(size[1], size[2])
	for _, layer in ipairs({"quests", "trainers", "towns", "none"}) do
		local state = W.new_state()
		state.layer = layer
		local form = W.formspec(player, state, info)
		print(("%-11s %-9s %7d %8d %10d"):format(("%dx%d"):format(size[1], size[2]), layer, #form,
			state.tooltip_count or -1, #form * per_minute))
	end
end
