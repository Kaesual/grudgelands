-- Round 26 Lane I portable test: the status icon registry and the HUD icon row
-- (rulings 17-22). Loads the REAL grug_core/hud_layout.lua, status_icons.lua,
-- status.lua, movement.lua, combat_hud.lua, grug_inventory/pages.lua and
-- grug_parties/ui.lua under a minimal `core` stub.
--
-- Checks:
--   * every registered status id (and variant) resolves to an existing 64x64
--     texture; every frame and class icon exists; no delivered grug_status_*
--     art is left unregistered;
--   * frame kinds match the user decisions (buff / debuff / neutral), and a
--     registered id keeps its kind whatever the caller passes;
--   * every status id the game sets (set_status literals, the mount constant,
--     status-source ids, talent windows) is registered, and every talent
--     window names a real talent;
--   * countdown / value captions, the food item-image path and its fallback;
--   * the row: order, hidden values, the ten-slot limit (debuffs kept first),
--     GUI-scaled captions, expiry, movement
--     flags as a source, idle refreshes writing nothing, the combat icon;
--   * the Character page Effects tab (content, empty state, refresh policy,
--     tab switch) and the Party page member table with class icons.
--
-- Usage (repo root): luajit tools/r26_status_icons/portable_test.lua

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

--
-- Files on disk.
--
local function lines_of(command)
	local pipe = assert(io.popen(command))
	local out = {}
	for line in pipe:lines() do out[#out + 1] = line end
	pipe:close()
	return out
end

local textures = {} -- basename -> path
for _, path in ipairs(lines_of("find mods -path '*/textures/*.png'")) do
	textures[path:match("([^/]+)$")] = path
end

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

local function read_file(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

--
-- Minimal engine surface.
--
local us_time = 1000000000
local joins, leaves, deaths, steps = {}, {}, {}, {}
local players = {}
core = {
	get_us_time = function() return us_time end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_on_dieplayer = function(fn) deaths[#deaths + 1] = fn end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	get_connected_players = function() return players end,
	get_player_by_name = function(name)
		for _, p in ipairs(players) do
			if p:get_player_name() == name then return p end
		end
	end,
	is_player = function(obj) return type(obj) == "table" and obj.is_player ~= nil end,
	add_particlespawner = function() end,
	log = function() end,
}

local function fake_player(name)
	local p = {name = name, huds = {}, next_id = 0, writes = 0, hp = 20}
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_hp() return self.hp end
	function p:get_pos() return nil end
	function p:get_properties() return {} end
	function p:get_physics_override() return self.physics or {} end
	function p:set_physics_override(o) self.physics = o end
	function p:hud_add(def)
		self.next_id = self.next_id + 1
		local copy = {}
		for k, v in pairs(def) do copy[k] = v end
		self.huds[self.next_id] = copy
		return self.next_id
	end
	function p:hud_change(id, key, value)
		self.writes = self.writes + 1
		self.huds[id][key] = value
	end
	function p:hud_remove(id) self.huds[id] = nil end
	return p
end

grug_core = {}
function grug_core.mono_time() return core.get_us_time() / 1e6 end
local fighting = false
function grug_core.in_combat() return fighting end

dofile("mods/CORE/grug_core/hud_layout.lua")
dofile("mods/CORE/grug_core/status_icons.lua")
dofile("mods/CORE/grug_core/status.lua")
dofile("mods/CORE/grug_core/movement.lua")
dofile("mods/CORE/grug_core/combat_hud.lua")

local icons = grug_core.status_icons
local layout = grug_core.hud_layout

--
-- 1. Registry: textures, sizes, frame kinds.
--
local EXPECTED_KIND = {
	food = "buff", elixir = "buff", alchemy_swiftness = "buff",
	alchemy_cave = "buff", mount = "buff",
	move_immune = "buff", scout_sprint = "buff", sidestep = "buff",
	mend = "buff", shield = "buff",
	talent_unbroken = "buff", talent_ruination = "buff",
	talent_whitehot = "buff", talent_turn_aside = "buff",
	talent_last_word = "buff", talent_untouchable = "buff",
	poisoned = "debuff", slowed = "debuff", rooted = "debuff",
	stunned = "debuff", scorched = "debuff", dragon_wrath = "debuff",
	in_combat = "neutral", pvp_tagged = "neutral", pvp_contested = "neutral",
}

local function texture_ok(name, label)
	local path = textures[name]
	check(path ~= nil, label .. ": texture " .. tostring(name) .. " exists")
	if path then
		local w, h = png_size(path)
		check(w == 64 and h == 64, label .. ": " .. name .. " is 64x64 (got " ..
			tostring(w) .. "x" .. tostring(h) .. ")")
	end
end

local registered, used_art = 0, {}
for id, def in pairs(icons.STATUS) do
	registered = registered + 1
	eq(def.kind, EXPECTED_KIND[id], "kind of " .. id)
	texture_ok(def.icon, id)
	used_art[def.icon] = true
	for variant, texture in pairs(def.variants or {}) do
		texture_ok(texture, id .. "/" .. variant)
		used_art[texture] = true
	end
end
for id in pairs(EXPECTED_KIND) do
	check(icons.STATUS[id] ~= nil, "expected status " .. id .. " is registered")
end
for kind, frame in pairs(icons.FRAME) do
	texture_ok(frame, "frame " .. kind)
end
check(textures[icons.GENERIC_FOOD] ~= nil, "generic food icon exists")
-- Every delivered status emblem is used by some id or variant.
for name in pairs(textures) do
	if name:match("^grug_status_") and not name:match("^grug_status_frame_") then
		check(used_art[name], "delivered art " .. name .. " is registered")
	end
end
-- Class icons: one per registered class (grug_classes register_class ids).
local class_ids = {}
for _, file in ipairs(lines_of("ls mods/PLAYER/grug_classes/*.lua")) do
	for id in read_file(file):gmatch("register_class%(%s*{%s*id%s*=%s*\"([%w_]+)\"") do
		class_ids[#class_ids + 1] = id
	end
end
eq(#class_ids, 4, "four registered classes")
for _, id in ipairs(class_ids) do
	eq(icons.class_icon(id), "grug_class_" .. id .. ".png", "class icon " .. id)
	texture_ok(icons.class_icon(id), "class " .. id)
end
eq(icons.class_icon(nil), "", "no class, no icon")
eq(icons.class_icon("bard"), "", "unknown class, no icon")

-- Textures: picture + frame of the id's kind.
eq(icons.texture("poisoned"),
	"grug_status_poisoned.png^grug_status_frame_debuff.png", "debuff texture")
eq(icons.texture("in_combat"),
	"grug_status_in_combat.png^grug_status_frame_neutral.png", "neutral texture")
eq(icons.texture("elixir", "focus"),
	"grug_status_elixir_focus.png^grug_status_frame_buff.png", "elixir variant")
eq(icons.texture("mount", "flight"),
	"grug_status_mount_flight.png^grug_status_frame_buff.png", "mount variant")
eq(icons.texture("sidestep"),
	"grug_abilities_skill_sidestep.png^grug_status_frame_buff.png",
	"ability buff reuses its skill icon")

--
-- 2. Every status id the game sets is registered.
--
local set_ids = {}
for _, file in ipairs(lines_of("find mods -name '*.lua' -not -path '*/BASE/*'")) do
	local text = read_file(file)
	for id in text:gmatch("set_status%(%s*[%w_%.]+%s*,%s*\"([%w_]+)\"") do
		set_ids[id] = file
	end
	if text:find("register_status_source", 1, true) and
			not file:match("status%.lua$") then
		for id in text:gmatch("id%s*=%s*\"([%w_]+)\"") do
			set_ids[id] = file
		end
	end
end
-- The mount status id is a named constant in grug_mounts/entity.lua.
local mount_id = read_file("mods/PLAYER/grug_mounts/entity.lua")
	:match("local STATUS_ID = \"([%w_]+)\"")
set_ids[mount_id or "?mount"] = "mods/PLAYER/grug_mounts/entity.lua"
local talents_text = read_file("mods/PLAYER/grug_classes/talents.lua") ..
	read_file("mods/PLAYER/grug_classes/scout_talents.lua")
for talent, status_id in pairs(icons.TALENT_WINDOWS) do
	set_ids[status_id] = "status_icons.lua TALENT_WINDOWS"
	check(talents_text:find("id = \"" .. talent .. "\"", 1, true) ~= nil,
		"talent window " .. talent .. " is a registered talent")
end
local used = 0
for id, file in pairs(set_ids) do
	used = used + 1
	check(icons.STATUS[id] ~= nil, "status id " .. id .. " (" .. file ..
		") is registered")
end
check(set_ids.potion_cooldown == nil, "no potion cooldown status (ruling 21)")
-- Death ends poison chains like leaving does (review L3; the status table
-- clears on death, so a chain ticking on after a respawn would be invisible).
check(read_file("mods/ENTITIES/grug_mobs/verbs.lua"):find(
	"core.register_on_dieplayer(cancel_poison)", 1, true) ~= nil,
	"poison chains stop on death")
for _, expected in ipairs({"food", "elixir", "alchemy_swiftness",
		"alchemy_cave", "mount", "scout_sprint", "sidestep", "mend", "shield",
		"poisoned", "scorched", "dragon_wrath", "stunned", "rooted", "slowed", "move_immune",
		"talent_turn_aside", "talent_unbroken", "talent_ruination",
		"talent_whitehot", "talent_last_word", "talent_untouchable"}) do
	check(set_ids[expected] ~= nil, "status " .. expected .. " is set somewhere")
end

--
-- 3. Captions.
--
local S = 1e6
eq(icons.countdown(0), "0s", "countdown 0")
eq(icons.countdown(0.2 * S), "1s", "countdown rounds up")
eq(icons.countdown(45 * S), "45s", "countdown seconds")
eq(icons.countdown(59.5 * S), "1:00", "countdown 59.5 s reads 1:00")
eq(icons.countdown(299.2 * S), "5:00", "countdown food start")
eq(icons.countdown(61 * S), "1:01", "countdown M:SS")
eq(icons.countdown(600 * S), "10m", "countdown minutes")
eq(icons.countdown(900 * S), "15m", "countdown elixir")
eq(icons.countdown(3601 * S), "2h", "countdown hours round up")
eq(icons.countdown(172800 * S), "2d", "countdown days")
eq(icons.countdown(-5 * S), "0s", "countdown never negative")
eq(icons.caption(12.7, false, 5 * S), "12", "value wins over countdown")
eq(icons.caption(nil, true, 0), "", "untimed without value is blank")
eq(icons.caption(nil, false, 9 * S), "9s", "timed without value counts down")

--
-- 4. Food: the item's own picture, else the generic icon.
--
local bread = icons.item_icon({inventory_image = "grug_cooking_bread.png"})
eq(bread, "[fill:16x16:#151f2d^(grug_cooking_bread.png)^[resize:64x64",
	"food item image on the plate")
eq(icons.texture("food", nil, bread), bread .. "^grug_status_frame_buff.png",
	"food item image keeps the buff frame")
eq(icons.item_icon({inventory_image = "", wield_image = "x.png"}),
	"[fill:16x16:#151f2d^(x.png)^[resize:64x64", "wield image fallback")
eq(icons.item_icon({inventory_image = "", tiles = {"meat.png"}}), nil,
	"node-only food is not straightforward")
eq(icons.item_icon(nil), nil, "no definition")
eq(icons.texture("food", nil, nil),
	"grug_status_food.png^grug_status_frame_buff.png", "generic food fallback")
-- The real grug_food call site passes the eaten item's definition.
check(read_file("mods/ITEMS/grug_food/init.lua"):find(
	"status_icons.item_icon(item_definition)", 1, true) ~= nil,
	"grug_food passes the item definition")

--
-- 5. The row, through the real status.lua.
--
local alice = fake_player("alice")
players[1] = alice
for _, fn in ipairs(joins) do fn(alice) end
local slots = 0
for _, def in pairs(alice.huds) do
	if def.type == "image" then slots = slots + 1 end
end
eq(slots, layout.STATUS_LIMIT, "one image per slot at join")

local function step(dt)
	us_time = us_time + dt * S
	for _, fn in ipairs(steps) do fn(dt) end
end
local function shown_ids()
	local out = {}
	for index, entry in ipairs(grug_core.status_display(alice)) do
		out[index] = entry.id
	end
	return table.concat(out, ",")
end

-- A registered id keeps its registered kind whatever the caller says.
local record = grug_core.set_status(alice, "poisoned", {duration = 6, kind = "buff"})
eq(record and record.kind, "debuff", "registry kind wins")
check(grug_core.set_status(alice, "unregistered_x", {duration = 1, kind = "weird"}) == nil,
	"unknown kind rejected")
grug_core.clear_status(alice, "unregistered_x")
grug_core.set_status(alice, "food", {duration = 300, icon = bread})
grug_core.set_status(alice, "sidestep", {expiry_us = us_time + 4 * S})
grug_core.set_status(alice, "scout_sprint", {duration = 10,
	value = function() return false end})
grug_core.set_status(alice, "shield", {duration = 15, value = function() return 42 end})
grug_core.set_status(alice, "mount", {untimed = true, variant = "flight"})
grug_core.set_root(alice, 3)
grug_core.set_move_modifier(alice, "mob_web", {speed = -0.4}, 8)
eq(shown_ids(), "food,mount,shield,sidestep,poisoned,rooted,slowed",
	"row order: buffs, debuffs; hidden value takes no slot")
local display = grug_core.status_display(alice)
eq(display[1].texture, bread .. "^grug_status_frame_buff.png", "food slot texture")
eq(display[1].caption, "5:00", "food caption")
eq(display[2].texture, "grug_status_mount_flight.png^grug_status_frame_buff.png",
	"mount variant slot")
eq(display[2].caption, "", "untimed mount has no caption")
eq(display[3].caption, "42", "shield shows its value")
eq(display[6].caption, "3s", "root countdown from the aggregator")
eq(display[7].caption, "8s", "slow countdown from the aggregator")

-- Immunity: the root drops, penalties go inert, one move_immune icon.
grug_core.set_move_immunity(alice, 4)
eq(shown_ids(), "food,mount,move_immune,shield,sidestep,poisoned",
	"immunity replaces root and slow")
grug_core.set_stun(alice, 1.5)
check(shown_ids():find("stunned", 1, true) ~= nil, "stun shows")

-- The HUD writes what the display says, then nothing while nothing moves.
step(0.5)
local textures_on_hud = {}
for _, def in pairs(alice.huds) do
	if def.type == "image" and def.text ~= "" then
		textures_on_hud[#textures_on_hud + 1] = def.text
	end
end
eq(#textures_on_hud, #grug_core.status_display(alice), "one drawn slot per status")
alice.writes = 0
for _, fn in ipairs(steps) do fn(0.5) end -- no time passes
eq(alice.writes, 0, "idle refresh writes nothing")

-- Expiry: sidestep (4 s), the stun (1.5 s) and immunity (4 s) run out.
step(4.5)
local after = shown_ids()
check(not after:find("sidestep", 1, true), "sidestep expired")
check(not after:find("stunned", 1, true), "stun expired")
check(not after:find("move_immune", 1, true), "immunity expired")
-- The web (8 s) outlived the immunity and is live again.
check(after:find("slowed", 1, true) ~= nil, "slow returns after immunity")

-- Ten-slot limit: debuffs keep their slots before buffs do (review L2),
-- and the kept set is still drawn buffs first.
grug_core.set_status(alice, "poisoned", {duration = 60})
grug_core.set_status(alice, "pvp_tagged", {duration = 60})
for index = 10, 23 do
	grug_core.set_status(alice, "extra_" .. index, {duration = 60, kind = "buff"})
end
local capped = grug_core.status_display(alice)
eq(#capped, layout.STATUS_LIMIT, "row capped at the limit")
local capped_ids = {}
for index, entry in ipairs(capped) do capped_ids[index] = entry.id end
local capped_text = table.concat(capped_ids, ",")
check(capped_text:find("poisoned", 1, true) ~= nil, "poison kept over buffs")
check(capped_text:find("slowed", 1, true) ~= nil, "slow kept over buffs")
check(capped_text:find("pvp_tagged", 1, true) ~= nil, "neutral kept over buffs")
eq(capped[#capped].id, "pvp_tagged", "kept set drawn buffs, debuffs, neutral")
eq(capped[1].kind, "buff", "buffs still drawn first")

-- Death clears stored statuses and the aggregator.
for _, fn in ipairs(deaths) do fn(alice) end
eq(shown_ids(), "", "death clears the row")

--
-- 6. Layout.
--
local skill_top = layout.rows.skill.top
local icon, caption = layout.status_slot(1, 1)
eq(icon.x, 0, "single slot centred")
check(caption.y + layout.STATUS_CAPTION <= skill_top,
	"caption line ends above the skill row")
check(icon.y + layout.STATUS_ICON / 2 < caption.y, "caption below the icon")
local first = layout.status_slot(1, 10)
local last = layout.status_slot(10, 10)
eq(first.x, -last.x, "row symmetric")
check(layout.STATUS_PITCH > layout.STATUS_ICON, "icons do not touch")
eq(layout.STATUS_ICON, 40, "status icons are 40 px (user decision)")
-- Ten slots fit a 1024 px wide window at HUD scale 1 with room to spare.
check(last.x + layout.STATUS_ICON / 2 - (first.x - layout.STATUS_ICON / 2) <= 520,
	"ten-slot row at most 520 px wide")
-- The whole row (icons and captions) stays above the combat icon, which is
-- centred on the life bar right of the column.
local combat_top = layout.anchors.combat.offset.y - layout.COMBAT_ICON / 2
check(caption.y + layout.STATUS_CAPTION < combat_top,
	"row ends above the combat icon")
check(caption.y + layout.STATUS_CAPTION < layout.rows.breath.top,
	"row ends above the breath bar")
local party_icon = layout.party_icon_offset(1, 3)
local party_label = layout.party_row_offset(1, 3, false)
eq(party_icon.y, party_label.y, "class icon level with the name line")
eq(layout.party_icon_size(), 26, "class icon spans name and bar")
eq(party_label.x - party_icon.x, layout.party_icon_size() + layout.PARTY_ICON_GAP,
	"name starts right of the class icon")
-- GUI scaling above HUD scaling (review L5): text grows, HUD units do not.
local big = {real_gui_scaling = 1.5, real_hud_scaling = 1}
eq(layout.party_icon_size(big), 36, "class icon grows with the label slot")
eq(layout.party_row_offset(1, 3, false, big).x - layout.party_icon_offset(1, 3, big).x,
	36 + layout.PARTY_ICON_GAP, "name clears the larger icon")
local big_icon, big_caption = layout.status_slot(1, 2, big)
local big_second = layout.status_slot(2, 2, big)
check(big_caption.y + math.ceil(layout.STATUS_CAPTION * 1.5) <= skill_top,
	"scaled captions end above the skill row")
check(big_second.x - big_icon.x >= math.ceil(layout.STATUS_CAPTION_WIDTH * 1.5),
	"scaled pitch fits the wider captions")
local same_icon = layout.status_slot(1, 2, {real_gui_scaling = 2, real_hud_scaling = 2})
eq(same_icon.y, layout.status_slot(1, 2).y, "equal scalings keep the default row")

--
-- 7. Combat icon next to the health bar (ruling 19).
--
fighting = true
local before = alice.next_id
step(0.3)
local combat = alice.huds[alice.next_id]
check(alice.next_id == before + 1 and combat ~= nil, "combat icon added")
eq(combat and combat.type, "image", "combat state is an image")
eq(combat and combat.text,
	"grug_status_in_combat.png^grug_status_frame_neutral.png", "combat icon texture")
eq(combat and combat.offset.x, layout.anchors.combat.offset.x,
	"combat icon at the old text anchor")
fighting = false
step(0.3)
check(alice.huds[before + 1] == nil, "combat icon removed out of combat")

--
-- 8. Registry text for the Effects tab: every id has a name; coarse times.
--
for id, def in pairs(icons.STATUS) do
	check(type(def.name) == "string" and def.name ~= "", "name of " .. id)
	check(type(def.detail) == "string", "detail of " .. id)
end
eq(icons.remaining_text(299 * S), "5 min left", "effects time minutes")
eq(icons.remaining_text(59 * S), "under 1 min left", "effects time under a minute")
eq(icons.remaining_text(900 * S), "15 min left", "effects time elixir")
eq(icons.remaining_text(7200 * S), "2 h left", "effects time hours")
eq(icons.remaining_text(nil, true), "active", "effects time untimed")

--
-- 9. Character page: Stats / Effects tabs (grug_inventory/pages.lua).
--
local function fs_escape(text)
	return (tostring(text):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
		:gsub(";", "\\;"):gsub(",", "\\,"))
end
core.formspec_escape = fs_escape
core.colorize = function(color, text) return "(c@" .. color .. ")" .. text end
core.get_item_group = function() return 0 end
core.log = function() end
core.explode_table_event = function(text)
	local kind, row, column = text:match("^(%u+):(%d+):(%d+)$")
	return {type = kind or "INV", row = tonumber(row) or 0, column = tonumber(column) or 0}
end
local pages, contexts, set_pages, resent = {}, {}, {}, 0
sfinv = {
	pages = pages, pages_unordered = {}, contexts = contexts,
	register_page = function(name, def)
		def.name = name
		pages[name] = def
		sfinv.pages_unordered[#sfinv.pages_unordered + 1] = def
	end,
	make_formspec = function(_, _, content) return content end,
	set_page = function(_, name) set_pages[#set_pages + 1] = name end,
	get_page = function(player) return contexts[player:get_player_name()].page end,
	get_or_create_context = function(player)
		local name = player:get_player_name()
		contexts[name] = contexts[name] or {}
		return contexts[name]
	end,
	set_player_inventory_formspec = function() resent = resent + 1 end,
}
grug_inventory = {equipment_slots = {}, BOX_COLOR = "#00000040", -- ui.lua's
	selected_button_style = function(field, selected)
		return "style[" .. field .. ";" .. tostring(selected) .. "]"
	end,
	-- The gear box beside every mode (Round 44): no slots, no bags, no quiver.
	BAG_COUNT = 0, SHIFT_LIST = "grug_shift", has_quiver = function() return false end,
	wrap_text = function(text) return text end}
grug_classes = grug_classes or {}
grug_classes.get_class = grug_classes.get_class or function() return "warrior" end
function alice:get_inventory() return {get_size = function() return 0 end} end
grug_xp = {register_on_level_change = function() end, get_level = function() return 5 end}
grug_money = {register_on_change = function() end}
function grug_core.register_on_equipment_change() end
dofile("mods/PLAYER/grug_inventory/pages.lua")
local character = pages["grug_inventory:character"]
check(character ~= nil, "character page registered")
local context = {page = "grug_inventory:character"}
contexts.alice = context

-- Empty state.
context.grug_character_tab = "effects"
local page = character:get(alice, context)
check(page:find("No active effects", 1, true) ~= nil, "effects empty state")
check(page:find("style[grug_character_effects;true]", 1, true) ~= nil,
	"effects button styled selected")
check(page:find("button[1.25,0.35;1.20,0.70;grug_character_stats;Stats]", 1, true) ~= nil,
	"stats mode button")

-- Several effects: icon with frame, name, time, detail.
local bread_def = {description = "Bread\nRestores HP", inventory_image = "grug_cooking_bread.png"}
grug_core.set_status(alice, "food", {duration = 300, label = "Bread",
	detail = "+6% HP/5s", icon = icons.item_icon(bread_def)})
grug_core.set_status(alice, "elixir", {duration = 900, label = "Elixir of Focus III",
	detail = "+5% maximum Mana", variant = "focus"})
grug_core.set_status(alice, "shield", {duration = 15, label = "Shield",
	value = function() return 42 end})
grug_core.set_status(alice, "mount", {untimed = true, label = "Expert Riding",
	detail = "+100% speed, flying", variant = "flight"})
grug_core.set_move_modifier(alice, "mob_web", {speed = -0.4}, 30)
page = character:get(alice, context)
local function has(text, label) check(page:find(text, 1, true) ~= nil, label) end
has(";0.80,0.80;" .. fs_escape(bread .. "^grug_status_frame_buff.png") .. "]",
	"food row shows the item image on its frame")
has("image[0.40,1.30;0.80,0.80;" ..
	fs_escape("grug_status_elixir_focus.png^grug_status_frame_buff.png") .. "]",
	"first row: row order (elixir before food)")
has(fs_escape("Bread  (c@#f0c75e)5 min left"), "food name and time")
has("+6% HP/5s", "food detail")
has(fs_escape("Elixir of Focus III  (c@#f0c75e)15 min left"), "elixir name and time")
has("+5% maximum Mana", "elixir detail")
has(fs_escape("Absorbs damage: 42 left"), "shield value in the detail")
has(fs_escape("Expert Riding  (c@#f0c75e)active"), "untimed mount")
has(fs_escape("grug_status_slowed.png^grug_status_frame_debuff.png"), "slow debuff frame")
has("40% slower", "slow detail from the aggregator")
check(page:find("Maximum HP", 1, true) == nil, "effects tab hides the stats")

-- Refresh policy: re-sent only while the effects mode is selected and its
-- printed text changed (Return home has no home here).
resent = 0
for _, fn in ipairs(steps) do fn(1) end
eq(resent, 0, "unchanged effects: nothing re-sent")
grug_core.set_status(alice, "poisoned", {duration = 30})
for _, fn in ipairs(steps) do fn(1) end
eq(resent, 1, "a new effect re-sends the page once")
context.grug_character_tab = "stats"
grug_core.clear_status(alice, "poisoned")
for _, fn in ipairs(steps) do fn(1) end
eq(resent, 1, "stats tab: effect changes re-send nothing")

-- Tab switch.
set_pages = {}
character:on_player_receive_fields(alice, context, {grug_character_effects = "Effects"})
eq(context.grug_character_tab, "effects", "effects button selects the tab")
eq(set_pages[1], "grug_inventory:character", "tab switch rebuilds the page")

--
-- 10. Party page: the member table carries class icons (ruling 22).
--
grug_factions = {get_faction = function() return "accord" end}
grug_parties = {
	register_on_change = function() end,
	invitations_enabled = function() return true end,
	hud_enabled = function() return true end,
	health_color_mode = function() return "by_class" end,
	pending = function() return {} end,
	view = function() return {leader = "alice", members = {
		{name = "alice", online = true, level = 5, hp = 20, hp_max = 20, class = "warrior"},
		{name = "bob", online = true, level = 5, hp = 10, hp_max = 20, class = "priest"},
		{name = "cyd", online = false, level = 4},
	}} end,
}
core.register_on_mods_loaded = function() end
dofile("mods/PLAYER/grug_parties/ui.lua")
local group = pages["grug_parties:group"]
local group_context = {}
local group_fs = group:get(alice, group_context)
check(group_fs:find("tablecolumns[image,align=center,0=blank.png,1=grug_class_warrior.png," ..
	"2=grug_class_mage.png,3=grug_class_priest.png,4=grug_class_scout.png;text", 1, true) ~= nil,
	"member table declares the class icons")
check(group_fs:find("table[0.20,4.58;6.35,2.55;grug_party_members;1," ..
	fs_escape("* alice [Lv 5]  20/20 HP") .. ",3," .. fs_escape("bob [Lv 5]  10/20 HP") ..
	",0," .. fs_escape("cyd [Lv 4]  Offline") .. ";1]", 1, true) ~= nil,
	"member rows carry class indices (offline: blank)")
group:on_player_receive_fields(alice, group_context, {grug_party_members = "CHG:2:2"})
eq(group_context.grug_party_member, "bob", "table selection picks the member")

print(("%d registered ids, %d ids set in code, %d checks, %d failures"):format(
	registered, used, checks, failures))
if failures > 0 then
	print("R26 STATUS ICONS PORTABLE FAIL")
	os.exit(1)
end
print("R26 STATUS ICONS PORTABLE PASS checks=" .. checks)
