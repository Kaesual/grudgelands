-- Disposable engine probe (Round 88 lane STATS): the Character page's Stats
-- mode for screenshots. Never shipped: tools/r88_stats/capture.sh stages it
-- through tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r66_equip's probe.
--
-- A Dwarf Warrior at level 30 in authored level-30 gear (grug_items.make_stack,
-- one or two enchants per piece), later turned Scout with leather gear.
-- Shots per class (W_ / S_): hp (the page as it opens), str (Strength
-- selected), armor (Armor selected); for the Warrior effects (the cloak
-- picker in another mode) and str_hover (the pointer on the Strength row:
-- the script moves it to the logged HOVER point, form units); for the Scout
-- dex (Dexterity, the Scout's attribute).
-- Every shot also logs whether the detail's source lines add up to the
-- shown value on the real gear ("SUMS ok" or the failing stat).

local P = "[r88stats] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r88stats_settle") or "") or 2
local CHARACTER = "grug_inventory:character"
local LEVEL = 30

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r88stats_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function pre(stat) return {channel = "prefix", stat = stat} end
local function suf(stat) return {channel = "suffix", stat = stat} end
local GEAR = {
	warrior = {
		{"grug_head", grug_gear.armor_item("head", "metal", 3), {pre("str"), suf("max_hp_percent")}},
		{"grug_chest", grug_gear.armor_item("chest", "metal", 3), {pre("str"), suf("armor_rating")}},
		{"grug_legs", grug_gear.armor_item("legs", "metal", 3), {pre("str")}},
		{"grug_feet", grug_gear.armor_item("feet", "metal", 3), {suf("max_hp_percent")}},
		{"grug_weapon", grug_gear.weapon_item("sword", 3), {pre("str"), suf("crit_percent")}},
		{"grug_offhand", "grug_gear:shield_" .. grug_gear.MATERIALS[3].metal.key,
			{pre("str"), suf("armor_rating")}},
		{"grug_trinket1", grug_gear.trinket_item("battlebeat", 3), {pre("str"), suf("crit_percent")}},
	},
	scout = {
		{"grug_head", grug_gear.armor_item("head", "leather", 3), {pre("dex"), suf("crit_percent")}},
		{"grug_chest", grug_gear.armor_item("chest", "leather", 3), {pre("dex"), suf("dodge_percent")}},
		{"grug_legs", grug_gear.armor_item("legs", "leather", 3), {suf("dodge_percent")}},
		{"grug_feet", grug_gear.armor_item("feet", "leather", 3), {pre("dex"), suf("max_hp_percent")}},
		{"grug_weapon", grug_gear.weapon_item("bow", 3), {pre("dex"), suf("crit_percent")}},
		{"grug_offhand", grug_gear.weapon_item("dagger", 3), {pre("dex")}},
		{"grug_trinket1", grug_gear.trinket_item("reclaimers_mark", 3), {pre("dex"), suf("crit_percent")}},
		{"grug_trinket2", grug_gear.trinket_item("apothecary_loop", 3), {suf("max_hp_percent")}},
	},
}

local function equip(player, class_id)
	local inv = player:get_inventory()
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		inv:set_stack(slot.list, 1, ItemStack(""))
	end
	for index = 9, inv:get_size("main") do inv:set_stack("main", index, ItemStack("")) end
	for _, row in ipairs(GEAR[class_id]) do
		local stack, reason = grug_items.make_stack(row[2], LEVEL, row[3], player)
		if not stack then
			log("MISSING " .. tostring(row[2]) .. ": " .. tostring(reason))
		else
			inv:set_stack(row[1], 1, stack)
		end
	end
	grug_inventory.equipment_changed(player)
end

-- The fixture's sum rule (tools/r88_stats), on the real accessors.
local function sums(player)
	local bad = {}
	for _, entry in ipairs(grug_inventory.stat_sheet.sheet(player)) do
		if entry ~= "gap" and entry.id ~= "rage" then
			local result
			if entry.id == "hp" or entry.id == "mana" then
				local base, factor, percent = 0, 1, 0
				for _, line in ipairs(entry.sources) do
					if line.kind == "base" then base = line.n
					elseif line.kind == "factor" then factor = line.n
					elseif line.kind == "percent" then percent = percent + line.n end
				end
				result = math.floor(base * factor * (1 + percent / 100) + 0.5)
			else
				local sum, factor = 0, 1
				for _, line in ipairs(entry.sources) do
					if line.kind == "factor" then factor = line.n else sum = sum + line.n end
					if line[2] == "Other sources" or line[2] == "Other equipment" then
						bad[#bad + 1] = entry.id .. ":other"
					end
				end
				result = sum * factor
			end
			if math.abs(result - entry.amount) > 1e-6 then
				bad[#bad + 1] = ("%s:%s~=%s"):format(entry.id, tostring(result), tostring(entry.amount))
			end
		end
	end
	return #bad == 0 and "ok" or table.concat(bad, " ")
end

local function describe(player)
	local parts = {}
	for _, entry in ipairs(grug_inventory.stat_sheet.sheet(player)) do
		if entry ~= "gap" then parts[#parts + 1] = entry.id .. "=" .. entry.value end
	end
	return table.concat(parts, " ")
end

local function show_page(player, mode, stat)
	local context = sfinv.get_or_create_context(player)
	context.grug_character_tab = mode
	sfinv.set_page(player, CHARACTER)
	context.grug_stat = stat
	local fs = sfinv.get_formspec(player, context)
	core.show_formspec(NAME, "r88stats:character", fs)
	log(("SUMS %s"):format(sums(player)))
	return fs
end

-- The pointer target of the hover shot, in whole-form units: the row's
-- centre plus the navigation header the page's container sits under.
local function hover_point(fs)
	local w, h = fs:match("size%[([%d.]+),([%d.]+)%]")
	local pad = fs:match("padding%[([%d.]+),") or "0.05"
	local header = fs:match("container%[0,([%d.]+)%]") or "0"
	local x, y = fs:match("button%[([%d.]+),([%d.]+);[%d.]+,[%d.]+;grug_stat_str;%]")
	log(("HOVER %.3f %.3f %s %s %s"):format(tonumber(x) + 1.0,
		tonumber(y) + 0.25 + tonumber(header), w, h, pad))
end

local function shots_for(prefix, extra)
	local list = {
		{name = prefix .. "hp", run = function(player) show_page(player, "stats", nil) end},
		{name = prefix .. "str", run = function(player) show_page(player, "stats", "str") end},
		{name = prefix .. "armor", run = function(player) show_page(player, "stats", "armor") end},
	}
	for _, shot in ipairs(extra or {}) do list[#list + 1] = shot end
	return list
end

local SHOTS = shots_for("W_", {
	{name = "W_effects", run = function(player) show_page(player, "effects", nil) end},
	{name = "W_str_hover", run = function(player)
		hover_point(show_page(player, "stats", nil))
	end},
})
-- r88stats_extreme (fix round 2): the Scout's row in its widest case, a
-- full quiver (500/500) and the longest home name: a default "<owner>'s Home"
-- of a 20-letter player name (27; a chosen name has at most 24, housing.md).
local EXTREME = core.settings:get_bool("r88stats_extreme", false)
local scout_turn = {name = "S_turn", silent = true, run = function(player)
	grug_classes.set_class(player, "scout")
	equip(player, "scout")
	if EXTREME then
		local inv = player:get_inventory()
		for index = 1, inv:get_size(grug_inventory.QUIVER_LIST) do
			inv:set_stack(grug_inventory.QUIVER_LIST, index, ItemStack("grug_gear:arrow 100"))
		end
		local get = grug_home.get
		grug_home.get = function(p)
			local row = get(p)
			if not row then return nil end
			local copy = {}
			for key, value in pairs(row) do copy[key] = value end
			copy.label = "Wolfgangmountainhawk's Home"
			return copy
		end
		log("extreme quiver=" .. grug_inventory.quiver_count(player))
	end
	log("scout " .. describe(player))
end}
SHOTS[#SHOTS + 1] = scout_turn
for _, shot in ipairs(shots_for("S_", {
	{name = "S_dex", run = function(player) show_page(player, "stats", "dex") end},
})) do SHOTS[#SHOTS + 1] = shot end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_dwarf = "Dwarf"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		grug_xp.set_xp(player, grug_xp.xp_for_level(LEVEL))
		equip(player, "warrior")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		log(("READY level %d %s"):format(grug_xp.get_level(player), describe(player)))
		state.phase = "shoot"
		state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.ran then
			state.ran = true
			shot.run(player)
			log("ran " .. shot.name)
		end
		if shot.silent then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
			return
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
