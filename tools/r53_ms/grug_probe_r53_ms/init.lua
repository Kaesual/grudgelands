-- Disposable engine probe (Round 53 lane INTEG: the migration step 0.53.0 end
-- to end). Never shipped: tools/r53_ms/e2e.py stages it through
-- tools/luanti_headless.sh, under the 0.52.1 game for the setup boot and
-- under this checkout's game after the tool. It asserts nothing: it writes
-- what the game saw to <world>/r43_it_obs.json (Round 43 IT's file names:
-- e2e.py boots through tools/r43_it/it.py) and e2e.py checks it.
--   at load     which of the round's ability ids are registered (the kit
--               swaps e2e.py checks once the class lanes have merged);
--   each join   first of all join callbacks (before grug_core's migration
--               runner): the marker, grug_classes' player meta, the lists
--               and the HP as loaded; in a "setup" phase the character is
--               then built (below); 3 s after the join the same as the game
--               left them, every chat line the player got since the join
--               (core.chat_send_player, wrapped here) and the hotbars'
--               skills with their unlock state;
--   then        once every character the plan names has left again, it
--               writes the file and shuts the server down.
-- The setup (0.52.1): warrior, mage, priest, scout and sleeper (a second
-- Mage, which stays offline after the setup) get the first faction, its
-- first race, their class and level 30, spend their talent points (every
-- spendable talent in id order), stand at their race start and hold full HP.
-- Then the step's subjects are placed (each listed in the observation's
-- `layout`): the retired skills on the shown hotbar (main), on the other
-- layout (grug_hotbar_store) and in a Small Bag; the Mage's Strike and Ice
-- Nova on both layouts; the Priest's Strike and Smite on the shown hotbar;
-- the stored talent windows of 0.52.1 and the used free respec. walker gets
-- no class and an apple.

local P = "[r53_ms_probe] "
local world = core.get_worldpath()
local wv = grug_core.world_version
local MARKER = "grug_core:migrate:0.53.0"
local STORE = "grug_hotbar_store"
local BAG = "grug_bag1_content"
local LISTS = {"main", STORE, "grug_bag1", BAG}
local IDS = {"strike", "fiery_spark", "smite", "ice_nova", "ice_wave", "loose",
	"cinderfall", "glacial_ward", "pinning_shot"}

local function log(msg) core.log("action", P .. msg) end

local function read(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text
end

local plan = core.parse_json(read(world .. "/r43_it_plan.json") or "") or {}
local expected = plan.joins or {}
local phase = plan.phase or "?"
local setup = phase:match("^setup") ~= nil

local obs = {phase = phase, game = wv.game,
	load = {new_world = wv.new_world, from = wv.from}, joins = {}, leaves = 0,
	registered = {}}

-- Every chat line per player, with the seconds since that player's join.
local joined_at, chat = {}, {}
local send = core.chat_send_player
core.chat_send_player = function(name, text, ...)
	chat[name] = chat[name] or {}
	local t = joined_at[name] and (core.get_us_time() - joined_at[name]) / 1e6 or -1
	table.insert(chat[name], {t = math.floor(t * 100 + 0.5) / 100,
		text = core.strip_colors(tostring(text))})
	return send(name, text, ...)
end

core.register_on_mods_loaded(function()
	for _, id in ipairs(IDS) do
		obs.registered[id] = grug_abilities.registered[id] ~= nil
	end
end)

local function skills(player, list)
	local out = {}
	local inv = player:get_inventory()
	for index = 1, math.min(8, inv:get_size(list)) do
		local id = inv:get_stack(list, index):get_name():match("^grug_abilities:(.+)$")
		if id then
			out[#out + 1] = {list = list, slot = index, id = id,
				unlocked = grug_abilities.registered[id] ~= nil and
					grug_abilities.is_unlocked(player, id) or false}
		end
	end
	return out
end

local function state(player)
	local inv = player:get_inventory()
	local lists, sizes = {}, {}
	for _, list in ipairs(LISTS) do
		sizes[list] = inv:get_size(list)
		local out = {}
		for index = 1, inv:get_size(list) do
			out[index] = inv:get_stack(list, index):get_name()
		end
		lists[list] = out
	end
	local meta = {}
	for key, value in pairs(player:get_meta():to_table().fields) do
		if key:match("^grug_classes:") or key:match("^grug_core:migrate:") then
			meta[key] = value
		end
	end
	local hp = {hp = player:get_hp(), hp_max = player:get_properties().hp_max}
	if grug_classes.get_class(player) then
		local b = grug_classes.get_pool_breakdown(player, "hp")
		hp.base, hp.factor, hp.talent, hp.final = b.base, b.class_factor, b.talent_percent,
			b.final
	end
	local hotbars = skills(player, "main")
	for _, s in ipairs(skills(player, STORE)) do hotbars[#hotbars + 1] = s end
	return {marker = player:get_meta():get_string(MARKER),
		class = grug_classes.get_class(player) or "",
		level = grug_xp.get_level(player), meta = meta, sizes = sizes, lists = lists,
		hp = hp, hotbars = hotbars,
		spent = grug_classes.talent_points_spent and grug_classes.talent_points_spent(player),
		available = grug_classes.talent_points_available and
			grug_classes.talent_points_available(player)}
end

-- The 0.52.1 build.
local function sorted(set)
	local out = {}
	for key in pairs(set) do out[#out + 1] = key end
	table.sort(out)
	return out
end

local function skill(player, id)
	return grug_abilities.stack_for(player, id) or ItemStack("grug_abilities:" .. id)
end

local function find(inv, list, id)
	for index = 1, inv:get_size(list) do
		if inv:get_stack(list, index):get_name() == "grug_abilities:" .. id then return index end
	end
end

local function free_hotbar(inv)
	for index = 1, 8 do
		if inv:get_stack("main", index):is_empty() then return index end
	end
	error("no free hotbar slot")
end

local CLASS = {warrior = "warrior", mage = "mage", priest = "priest", scout = "scout",
	sleeper = "mage"}
local WINDOWS = {warrior = {"talent_ready:ruination", "unbroken_ready"},
	mage = {"talent_ready:whitehot"}, priest = {"talent_ready:last_word"},
	scout = {"untouchable_ready"}}

local function build(player)
	local name = player:get_player_name()
	local inv = player:get_inventory()
	local layout = {}
	local function place(list, index, stack, role)
		inv:set_stack(list, index, stack)
		layout[#layout + 1] = {list = list, slot = index, item = stack:get_name(), role = role}
	end
	local class = CLASS[name]
	if not class then
		place("main", 9, ItemStack("default:apple 3"), "keep")
		return {class = "", layout = layout}
	end
	local faction = sorted(grug_core.factions)[1]
	local races = {}
	for id, def in pairs(grug_classes.registered_races) do
		if def.faction == faction then races[id] = true end
	end
	local race = sorted(races)[1]
	assert(grug_factions.set_faction(player, faction), "set_faction")
	assert(grug_classes.set_race(player, race), "set_race")
	assert(grug_classes.set_class(player, class), "set_class")
	assert(grug_xp.set_xp(player, grug_xp.xp_for_level(30)), "set_xp")
	local ids = sorted(grug_classes.registered_talents)
	local spent, progress = 0, true
	while progress do
		progress = false
		for _, id in ipairs(ids) do
			if grug_classes.spend_talent(player, id) then
				spent, progress = spent + 1, true
			end
		end
	end
	local spawn = grug_core.start_position(faction, race)
	if spawn then
		player:set_pos(spawn)
		grug_core.map_reset.record(player)
	end
	-- The other layout and a Small Bag (4 slots since 0.48.0).
	if inv:get_size(STORE) < 8 then inv:set_size(STORE, 8) end
	inv:set_size("grug_bag1", 1)
	place("grug_bag1", 1, ItemStack("grug_inventory:bag_small"), "keep")
	inv:set_size(BAG, 4)
	place(BAG, 4, ItemStack("default:torch 7"), "keep")
	if name == "mage" then
		place("main", free_hotbar(inv), skill(player, "cinderfall"), "remove")
		place(STORE, 1, skill(player, "strike"), "strike_b")
		place(STORE, 2, skill(player, "ice_nova"), "ice_nova_b")
		place(STORE, 3, skill(player, "glacial_ward"), "remove")
		place(BAG, 2, skill(player, "cinderfall"), "remove")
		layout[#layout + 1] = {list = "main", slot = find(inv, "main", "strike"),
			item = "grug_abilities:strike", role = "strike_a"}
		layout[#layout + 1] = {list = "main", slot = find(inv, "main", "ice_nova"),
			item = "grug_abilities:ice_nova", role = "ice_nova_a"}
	elseif name == "sleeper" then
		place("main", free_hotbar(inv), skill(player, "glacial_ward"), "remove")
		place(BAG, 3, skill(player, "cinderfall"), "remove")
	elseif name == "scout" then
		place("main", free_hotbar(inv), skill(player, "pinning_shot"), "remove")
		place(STORE, 4, skill(player, "pinning_shot"), "remove")
		place(BAG, 1, skill(player, "pinning_shot"), "remove")
	elseif name == "priest" then
		for _, id in ipairs({"strike", "smite"}) do
			local at = find(inv, "main", id)
			if not at then
				at = free_hotbar(inv)
				inv:set_stack("main", at, skill(player, id))
			end
			layout[#layout + 1] = {list = "main", slot = at, item = "grug_abilities:" .. id,
				role = id .. "_a"}
		end
	end
	local meta = player:get_meta()
	meta:set_int("grug_classes:respec_used", 1)
	for _, key in ipairs(WINDOWS[class] or {}) do
		meta:set_string("grug_classes:" .. key, tostring(os.time() + 3600))
	end
	player:set_hp(grug_classes.get_max_hp(player))
	return {class = class, faction = faction, race = race, spent = spent,
		spawn = spawn and {x = spawn.x, y = spawn.y, z = spawn.z} or false, layout = layout}
end

local function on_join(player)
	local name = player:get_player_name()
	joined_at[name] = core.get_us_time()
	chat[name] = {}
	local entry = {name = name, loaded = state(player)}
	obs.joins[#obs.joins + 1] = entry
	log("joined " .. name)
	if setup then
		core.after(0.5, function()
			local current = core.get_player_by_name(name)
			if not current then return end
			local ok, result = pcall(build, current)
			entry.built_ok = ok
			entry.build = ok and result or {error = tostring(result)}
			log("built " .. name .. (ok and "" or (": " .. tostring(result))))
		end)
	end
	core.after(3, function()
		local current = core.get_player_by_name(name)
		if current then
			entry.settled = state(current)
			entry.chat = chat[name]
		end
	end)
end
-- First of all join callbacks, before grug_core's migration runner.
local joins = core.registered_on_joinplayers
local count = #joins
core.register_on_joinplayer(on_join)
assert(#joins == count + 1)
core.register_on_mods_loaded(function()
	table.insert(joins, 1, table.remove(joins, count + 1))
end)

local finished = false
local function finish(reason)
	if finished then return end
	finished = true
	obs.finish = reason
	assert(core.safe_file_write(world .. "/r43_it_obs.json", core.write_json(obs)))
	log("observations written: " .. reason)
	core.after(0.5, function() core.request_shutdown("r53 ms probe done") end)
end

core.register_on_leaveplayer(function(player)
	obs.leaves = obs.leaves + 1
	log("left " .. player:get_player_name())
	if obs.leaves >= #expected then
		core.after(1, finish, "every planned character left")
	end
end)

core.after(0, function()
	if #expected == 0 then core.after(3, finish, "no joins planned") end
	core.after(200, finish, "timeout: not every planned character joined and left")
end)
