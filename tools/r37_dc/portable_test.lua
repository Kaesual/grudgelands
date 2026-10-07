-- Round 37 lane DC portable test (README for players, the visible version,
-- the New World dialog):
--   A. game.conf carries `version = 0.<round>.<patch>` and hides the two
--      mapgen keys the engine's New World dialog knows (mg_flags,
--      mgv7_spflags) while the seed stays;
--   B. Help -> About (grug_inventory/help.lua on stubs) shows that version,
--      read from game.conf; a game.conf without one logs a warning and shows
--      the heading alone;
--   C. CHANGELOG.md's newest entry names the same version;
--   D. settingtypes.txt keeps every setting line (key, name, type, default)
--      byte-identical and its menu descriptions name no code internals;
--   E. every relative link and anchor in README.md and CHANGELOG.md resolves.
--
-- Usage (repo root): luajit tools/r37_dc/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local function read(path)
	local f = assert(io.open(path, "rb"), "cannot read " .. path)
	local text = f:read("*a")
	f:close()
	return text
end

-- The engine's Settings reads `key = value` lines; enough of it for game.conf.
local function parse_conf(text)
	local values = {}
	for line in text:gmatch("[^\n]+") do
		local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
		if key and not line:match("^%s*#") then values[key] = value end
	end
	return values
end

-- A. game.conf ----------------------------------------------------------------
local conf = parse_conf(read(repo .. "/game.conf"))
local version = conf.version
check(type(version) == "string" and version:match("^0%.%d+%.%d+$") ~= nil,
	"A game.conf version is 0.<round>.<patch>")
local hidden = {}
for key in (conf.disallowed_mapgen_settings or ""):gmatch("[^,%s]+") do hidden[key] = true end
check(hidden.mg_flags and hidden.mgv7_spflags, "A the mapgen flag checkboxes are hidden")
check(not hidden.seed, "A the seed field stays")
check(conf.allowed_mapgens == "v7" and conf.default_mapgen == "v7", "A v7 only")

-- B. Help -> About ---------------------------------------------------------------
local function load_help(game_conf_text)
	local page, warnings = nil, {}
	_G.core = {
		formspec_escape = function(s)
			return (tostring(s):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
				:gsub(";", "\\;"):gsub(",", "\\,"))
		end,
		get_game_info = function() return {id = "grudgelands", path = "GAMEPATH"} end,
		log = function(level, text)
			if level == "warning" then warnings[#warnings + 1] = text end
		end,
	}
	_G.Settings = function(path)
		assert(path == "GAMEPATH/game.conf", "Settings path " .. tostring(path))
		local values = parse_conf(game_conf_text)
		return {get = function(_, key) return values[key] end}
	end
	_G.sfinv = {
		register_page = function(name, def) if name == "grug_inventory:help" then page = def end end,
		make_formspec = function(_, _, content) return content end,
		set_page = function() end,
	}
	_G.grug_inventory = {selected_button_style = function() return "" end}
	dofile(repo .. "/mods/PLAYER/grug_inventory/help.lua")
	assert(page, "help page registered")
	return page:get({}, {grug_help_section = "about"}), grug_inventory.GAME_VERSION, warnings
end

local about, shown, warnings = load_help(read(repo .. "/game.conf"))
check(shown == version and #warnings == 0, "B help.lua reads game.conf's version")
-- The hypertext is formspec-escaped: the comma arrives as "\\,".
check(about:find("About Grudgelands\\, version " .. version .. "</b>", 1, true) ~= nil,
	"B Help -> About shows the version")
about, shown, warnings = load_help("title = Grudgelands\n")
check(shown == nil and #warnings == 1, "B a missing version warns")
check(about:find("<b>About Grudgelands</b>", 1, true) ~= nil and
	not about:find("version", 1, true), "B the heading stands alone without a version")
about, shown, warnings = load_help("title = Grudgelands\nversion = 0.37<b>\n")
check(shown == nil and #warnings == 1, "B a malformed version is refused")

-- C. CHANGELOG.md ----------------------------------------------------------------
local changelog = read(repo .. "/CHANGELOG.md")
local newest = changelog:match("\n## ([^\n]+)")
check(newest ~= nil and newest:find(version, 1, true) ~= nil,
	"C the newest CHANGELOG entry names " .. version)

-- D. settingtypes.txt ----------------------------------------------------------------
-- The setting lines as of Round 37's base (9dc5f717), plus the hosting
-- platform's map reset counter (Round 41 lane UP): only descriptions change.
local SETTINGS = {
	"grug_atmosphere_enabled (Enable Grudgelands atmosphere presets) bool true",
	"grug_atmosphere_zones (Drive the atmosphere from the player's zone) bool true",
	"grug_nametag_aggressive_foreground (Aggressive nametag foreground) string #ff4b4b",
	"grug_nametag_aggressive_background (Aggressive nametag background) string #00000040",
	"grug_nametag_neutral_foreground (Neutral nametag foreground) string #ffd447",
	"grug_nametag_neutral_background (Neutral nametag background) string #00000040",
	"grug_nametag_guard_foreground (Guard nametag foreground) string #b76cff",
	"grug_nametag_guard_background (Guard nametag background) string #00000040",
	"grug_nametag_npc_foreground (NPC nametag foreground) string #d8c5ff",
	"grug_nametag_npc_background (NPC nametag background) string #00000040",
	"grug_nametag_player_foreground (Player nametag foreground) string #ffffff",
	"grug_nametag_player_background (Player nametag background) string #00000040",
	"grug_nametag_critter_foreground (Critter nametag foreground) string #ffffff",
	"grug_nametag_critter_background (Critter nametag background) string #00000040",
	"grug_injured_mob_hp_bars (Show injured mob health bars) bool true",
	"grug_prepare_full_world (Prepare full world before entry) bool false",
	"grug_mapgen_terrain_audit (Log capital plot terrain findings at start) bool false",
	"grug_map_quality (World map quality) enum normal normal,high",
	"grug_mob_damage_scale (Non-player attack damage multiplier) float 1.5 0 10",
	"grug_particle_scale (Particle amount scale) float 1.0 0 2",
	"grug_tree_regrowth (Regrow trees from saplings) bool true",
	"grug_reset_world (Map reset counter, set by the hosting platform) int 0 0",
}
local INTERNALS = {"grug_", "globalstep", "observer", "set_lighting", "set_atmosphere",
	"packet", "sprite", "hysteresis", "DoT", "Player/"}
local setting_lines, in_body = {}, false
for line in read(repo .. "/settingtypes.txt"):gmatch("[^\n]+") do
	if line:match("^%[") then in_body = true end
	if line:match("^#") then
		-- Only the comments below the first category reach the menu.
		if in_body then
			for _, word in ipairs(INTERNALS) do
				check(not line:find(word, 1, true), "D no code internal '" .. word .. "' in: " .. line)
			end
		end
	elseif not line:match("^%[") and line:match("%S") then
		setting_lines[#setting_lines + 1] = line
	end
end
check(#setting_lines == #SETTINGS, "D " .. #SETTINGS .. " setting lines")
for index, line in ipairs(SETTINGS) do
	check(setting_lines[index] == line, "D setting line unchanged: " .. line)
end

-- E. links ----------------------------------------------------------------
-- GitHub's heading anchors: lower case, punctuation but '-' and '_' dropped,
-- spaces to '-'.
local function anchors_of(text)
	local set = {}
	for heading in text:gmatch("\n#+ ([^\n]+)") do
		set[(heading:lower():gsub("[^%w%s%-_]", ""):gsub("%s", "-"))] = true
	end
	return set
end
local function exists(path)
	local f = io.open(path, "rb")
	if f then f:close() return true end
	return false
end
for _, doc in ipairs({"README.md", "CHANGELOG.md"}) do
	local text = read(repo .. "/" .. doc)
	local links = {}
	for target in text:gmatch("%]%(([^)%s]+)%)") do links[#links + 1] = target end
	for target in text:gmatch('src="([^"]+)"') do links[#links + 1] = target end
	for _, target in ipairs(links) do
		if not target:match("^%a+:") then
			local file, anchor = target:match("^([^#]*)#?(.*)$")
			local path = file == "" and doc or file
			check(exists(repo .. "/" .. path), "E " .. doc .. " link target " .. target)
			if anchor ~= "" and path:match("%.md$") then
				check(anchors_of("\n" .. read(repo .. "/" .. path))[anchor],
					"E " .. doc .. " anchor " .. target)
			end
		end
	end
end

print(("r37_dc portable test: %d checks PASS"):format(checks))
