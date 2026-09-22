local repo = assert(arg[1], "repository path required")
local checks = 0
local function check(value, message)
	checks = checks + 1
	if not value then error(message, 0) end
end

-- Preference persistence and canonical online class projection through init.lua.
local data, players, meta = {}, {}, {}
local joins, class_callbacks = {}, {}
local core = {
	get_current_modname = function() return "grug_parties" end,
	get_modpath = function() return repo .. "/mods/PLAYER/grug_parties" end,
	get_mod_storage = function() return {
		get_string = function(_, key) return data[key] or "" end,
		set_string = function(_, key, value) data[key] = value end,
	} end,
	serialize = function() return "stored" end,
	deserialize = function() return {next_id = 0, groups = {}} end,
	get_us_time = function() return 0 end,
	get_player_by_name = function(name) return players[name] end,
	chat_send_player = function() end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function() end,
	register_globalstep = function() end,
}
local function make_player(name, class_id)
	meta[name] = meta[name] or {}
	local player = {name = name, faction = "accord", class_id = class_id}
	function player:is_player() return true end
	function player:get_player_name() return self.name end
	function player:get_hp() return 50 end
	function player:get_properties() return {hp_max = 100} end
	function player:get_meta()
		local values = meta[name]
		return {
			get_int = function(_, key) return values[key] or 0 end,
			set_int = function(_, key, value) values[key] = value end,
			get_string = function(_, key) return values[key] or "" end,
			set_string = function(_, key, value) values[key] = value end,
		}
	end
	players[name] = player
	for i = 1, #joins do joins[i](player) end
	return player
end
local env = setmetatable({core = core, dofile = function() end,
	grug_factions = {
		get_faction = function(player) return player.faction end,
		register_on_faction_chosen = function() end,
	},
	grug_classes = {
		get_class = function(player) return player.class_id end,
		register_on_class_chosen = function(fn) class_callbacks[#class_callbacks + 1] = fn end,
	},
}, {__index = _G})
local chunk = assert(loadfile(repo .. "/mods/PLAYER/grug_parties/init.lua"))
setfenv(chunk, env)
chunk()
local api = env.grug_parties
local viewer, warrior = make_player("Viewer", "mage"), make_player("Warrior", "warrior")
check(api.health_color_mode(viewer) == "all_green", "default color mode differs")
check(api.set_health_color_mode(viewer, "by_class"), "valid color mode refused")
check(api.health_color_mode(viewer) == "by_class", "color mode was not persisted")
local reconnected = make_player("Viewer", "mage")
check(api.health_color_mode(reconnected) == "by_class",
	"color mode did not survive reconnect")
check(not api.set_health_color_mode(viewer, "invalid"), "invalid color mode accepted")
check(api.invite(viewer, "Warrior") and api.accept(warrior, "Viewer"),
	"party setup failed")
local view = api.view(viewer)
check(view.members[1].class == "mage" and view.members[2].class == "warrior",
	"online class projection differs")
players.Warrior = nil
view = api.view(viewer)
check(not view.members[2].online and view.members[2].hp == nil
	and view.members[2].class == nil, "offline row fabricated live state")

-- Load the real Group page and submit the dropdown through its receive-fields
-- path. Preference writes stay owned by the production API above.
local page, context = nil, {page = "grug_parties:group"}
core.formspec_escape = function(value)
	return tostring(value):gsub("\\", "\\\\"):gsub("%]", "\\]")
		:gsub("%[", "\\["):gsub(";", "\\;"):gsub(",", "\\,")
end
core.get_connected_players = function() return {reconnected} end
core.explode_textlist_event = function() return {type = "INV", index = 0} end
core.register_on_mods_loaded = function() end
local sfinv = {
	pages = {}, pages_unordered = {},
	register_page = function(_, definition) page = definition end,
	make_formspec = function(_, _, content) return content end,
	get_page = function() return context.page end,
	set_page = function() end,
}
local ui_env = setmetatable({core = core, grug_factions = env.grug_factions,
	grug_parties = api, sfinv = sfinv}, {__index = _G})
local ui_chunk = assert(loadfile(repo .. "/mods/PLAYER/grug_parties/ui.lua"))
setfenv(ui_chunk, ui_env)
ui_chunk()
page:on_enter(viewer, context)
local form = page:get(viewer, context)
check(form:find("label[5.18,0.22;Health colors]", 1, true)
	and form:find("dropdown[7.10,0.12;3.10;grug_party_health_colors;All green,By class;2;true]",
		1, true), "by-class dropdown selection or geometry differs")
local dropdown_x, dropdown_y, dropdown_w = form:match(
	"dropdown%[([%d.]+),([%d.]+);([%d.]+);grug_party_health_colors;")
check(dropdown_x and tonumber(dropdown_x) + tonumber(dropdown_w) <= 10.20
	and tonumber(dropdown_y) < 0.78,
	"health color dropdown overlaps roster columns")
page:on_player_receive_fields(viewer, context, {grug_party_health_colors = "1"})
check(api.health_color_mode(viewer) == "all_green",
	"dropdown index 1 did not select all-green")
page:on_player_receive_fields(viewer, context, {grug_party_health_colors = "2"})
check(api.health_color_mode(viewer) == "by_class",
	"dropdown index 2 did not select by-class")
page:on_player_receive_fields(viewer, context, {grug_party_health_colors = "bad"})
check(api.health_color_mode(viewer) == "by_class"
	and context.grug_party_notice ==
		"Refused: Invalid player or health color preference.",
	"invalid dropdown value was not refused without mutation")

-- Production HUD palette and unchanged-write suppression.
local hooks, changes = {}, {}
local hud_core = {
	register_on_joinplayer = function(fn) hooks.join = fn end,
	register_on_leaveplayer = function() end,
	register_globalstep = function(fn) hooks.step = fn end,
	get_connected_players = function() return {viewer} end,
	get_player_by_name = function(name) return name == "Viewer" and viewer or nil end,
	get_player_window_information = function() return nil end,
}
local hud_party = {
	hud_enabled = function() return true end,
	health_color_mode = function() return "by_class" end,
	view = function() return {leader = "Viewer", members = {
		{name = "Viewer", online = true, hp = 50, hp_max = 100, class = "warrior"},
		{name = "Mage", online = true, hp = 50, hp_max = 100, class = "mage"},
		{name = "Priest", online = true, hp = 50, hp_max = 100, class = "priest"},
		{name = "Scout", online = true, hp = 50, hp_max = 100, class = "scout"},
		{name = "Offline", online = false},
	}} end,
	register_on_change = function(fn) hooks.change = fn end,
}
local hud_env = setmetatable({core = hud_core, grug_core = {},
	grug_parties = hud_party}, {__index = _G})
local layout_chunk = assert(loadfile(repo .. "/mods/CORE/grug_core/hud_layout.lua"))
setfenv(layout_chunk, hud_env)
layout_chunk()
viewer.elements, viewer.next_id = {}, 0
function viewer:hud_add(def)
	self.next_id = self.next_id + 1
	self.elements[self.next_id] = def
	return self.next_id
end
function viewer:hud_change(id, property, value)
	self.elements[id][property] = value
	changes[#changes + 1] = property
end
function viewer:hud_remove(id) self.elements[id] = nil end
local hud_chunk = assert(loadfile(repo .. "/mods/PLAYER/grug_parties/hud.lua"))
setfenv(hud_chunk, hud_env)
hud_chunk()
check(hud_party.health_bar_color("all_green", "warrior") == 0x4caf50,
	"all-green mode differs")
check(hud_party.health_bar_color("by_class", "warrior") == 0xa66a3f
	and hud_party.health_bar_color("by_class", "mage") == 0x4a9bd8
	and hud_party.health_bar_color("by_class", "priest") == 0xf2f2f2
	and hud_party.health_bar_color("by_class", "scout") == 0x6b7d32,
	"class palette differs")
hooks.join(viewer)
changes = {}
hooks.step(0.6)
check(#changes == 0, "unchanged HUD emitted writes")

print("round17-party\t" .. checks)
