-- 0.49.1 lane ANIM portable test (fix-0.49.1-plan.md ruling 7, §4 ANIM):
-- the furnace's fire and arrow as animated images, the form re-sent only at
-- a change of state. Through tools/r44_ch/harness.lua (the REAL
-- grug_inventory ui.lua and its station view) plus the real
-- grug_inventory/furnace_progress.lua, default/node_formspec.lua,
-- default/furnace.lua, grug_jobs/automatic.lua and grug_jobs/workspaces.lua
-- under a small fake engine (cooking: test:ore 10 s, test:meat 3 s; fuel:
-- test:log 15 s, test:leaves 2 s, coal 80 s):
--   A  the helper: the frame start at given fractions, the frame length
--      over the duration, the buffer's minimum length, the still pictures;
--      the strips' sizes match the helper's frame counts;
--   K  the change check: frame starts ignored, more fuel left (a new fuel)
--      or less cooked (a new item) is a change;
--   P  the plain furnace (furnace.lua's timer, node_formspec.refresh) and
--   W  the workspace furnace and dual furnace (personal and shared; the
--      one-second pass): scripted burns where the fuel ends mid-item, an
--      item ends mid-fuel, a short fuel burns, the output is full, and an
--      idle furnace stands open. The form is re-sent exactly at the changes
--      of state; between re-sends no animation runs out of its buffer
--      (never empty, never restarting); at an item's end the fire goes on
--      where it was, at a new fuel the arrow does; the cooking results are
--      those of the processing alone (automatic.advance without a form)
--      and the expected counts.
--   M  bytes: the workspace furnace's formspec bytes over a burning minute
--      for a player with four bags (printed; `measure` below).
--
-- Usage (repo root): luajit tools/r491_anim/portable_test.lua [repo]
--        luajit tools/r491_anim/portable_test.lua REPO measure
--   `measure` runs only M against REPO's files (an older tree too: it then
--   counts that tree's every-second re-shows; the coordinator's "before").

local repo = arg and arg[1] or "."
local MEASURE_ONLY = arg and arg[2] == "measure"
local H = dofile(repo .. "/tools/r44_ch/harness.lua")(repo)
dofile(repo .. "/mods/PLAYER/grug_inventory/inbox.lua")
do
	local file = io.open(repo .. "/mods/PLAYER/grug_inventory/furnace_progress.lua")
	if file then
		file:close()
		grug_inventory.furnace_progress = dofile(repo .. "/mods/PLAYER/grug_inventory/furnace_progress.lua")
	end
end
local FP = grug_inventory.furnace_progress

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end
local function list_text(t)
	local out = {}
	for i, v in ipairs(t) do out[i] = tostring(v) end
	return table.concat(out, ",")
end

--
-- The fake engine around the harness
--

local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
local noop = function() end
vector = {
	new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end,
	equals = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
	offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end,
}

local function node_inventory()
	local lists = {}
	local inv = {}
	function inv:set_size(list, size)
		lists[list] = lists[list] or {}
		for i = 1, size do lists[list][i] = lists[list][i] or ItemStack("") end
	end
	function inv:get_size(list) return #(lists[list] or {}) end
	function inv:get_list(list)
		if not lists[list] then return nil end
		local out = {}
		for i, stack in ipairs(lists[list]) do out[i] = ItemStack(stack:to_string()) end
		return out
	end
	function inv:get_lists() return lists end
	function inv:set_list(list, values)
		lists[list] = {}
		for i, v in ipairs(values) do
			lists[list][i] = ItemStack(type(v) == "table" and v:to_string() or v)
		end
	end
	function inv:get_stack(list, i)
		return ItemStack(lists[list] and lists[list][i] and lists[list][i]:to_string() or "")
	end
	function inv:set_stack(list, i, stack)
		lists[list][i] = ItemStack(type(stack) == "table" and stack:to_string() or stack)
	end
	function inv:is_empty(list)
		for _, s in ipairs(lists[list] or {}) do
			if not s:is_empty() then return false end
		end
		return true
	end
	function inv:add_item(list, stack)
		stack = ItemStack(type(stack) == "table" and stack:to_string() or stack)
		local l = lists[list]
		for pass = 1, 2 do
			for i = 1, #l do
				if not stack:is_empty() and (l[i]:is_empty() == (pass == 2)) then
					stack = l[i]:add_item(stack)
				end
			end
		end
		return stack
	end
	function inv:room_for_item(list, stack)
		local copy = {}
		for i, s in ipairs(lists[list]) do copy[i] = ItemStack(s:to_string()) end
		local rest = ItemStack(type(stack) == "table" and stack:to_string() or stack)
		for pass = 1, 2 do
			for i = 1, #copy do
				if not rest:is_empty() and (copy[i]:is_empty() == (pass == 2)) then
					rest = copy[i]:add_item(rest)
				end
			end
		end
		return rest:is_empty()
	end
	return inv
end

-- core.serialize / deserialize for the process records.
local function serialize(value)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for k in pairs(value) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local parts = {}
		for _, k in ipairs(keys) do
			parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(value[k])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end
core.serialize = function(value) return "return " .. serialize(value) end
core.deserialize = function(text)
	if type(text) ~= "string" or text == "" then return nil end
	local fn = loadstring(text)
	return fn and fn() or nil
end

local nodes, metas, players, timers = {}, {}, {}, {}
local function meta_at(pos)
	local k = key(pos)
	if not metas[k] then
		local store, inv = {}, node_inventory()
		metas[k] = {
			get_string = function(_, f) return store[f] or "" end,
			set_string = function(_, f, v) store[f] = v end,
			get_int = function(_, f) return math.floor(tonumber(store[f]) or 0) end,
			set_int = function(_, f, v) store[f] = v end,
			get_float = function(_, f) return tonumber(store[f]) or 0 end,
			set_float = function(_, f, v) store[f] = v end,
			get_inventory = function() return inv end,
			mark_as_private = function() end,
			to_table = function() return {fields = store} end,
		}
	end
	return metas[k]
end

local now = 1000
local shown = {}
local registered_nodes = {}
local receivers, globalsteps, mods_loaded = {}, {}, {}
local detached = {}
core.registered_nodes = registered_nodes
core.show_formspec = function(name, formname, formspec)
	shown[#shown + 1] = {name = name, form = formname, formspec = formspec, at = now}
end
core.close_formspec = function(name, formname) core.show_formspec(name, formname, "") end
core.get_node_or_nil = function(pos)
	local name = nodes[key(pos)]
	return name and {name = name, param2 = 0} or nil
end
core.get_node = function(pos) return core.get_node_or_nil(pos) or {name = "air"} end
core.swap_node = function(pos, node) nodes[key(pos)] = node.name end
core.get_meta = meta_at
core.get_player_by_name = function(name) return players[name] end
core.get_node_timer = function(pos)
	local k = key(pos)
	return {
		start = function() timers[k] = true end,
		stop = function() timers[k] = nil end,
		is_started = function() return timers[k] == true end,
	}
end
core.get_gametime = function() return now end
core.get_us_time = function() return now * 1000000 end
core.after = function() end
core.sound_play = function() end
core.sound_fade = function() end
core.hash_node_position = function(pos) return key(pos) end
core.find_node_near = function() return nil end
core.item_drop = function() end
core.get_translator = function() return function(s) return s end end
core.register_node = function(name, def)
	registered_nodes[name:gsub("^:", "")] = def
end
core.override_item = function(name, fields)
	for k, v in pairs(fields) do registered_nodes[name][k] = v end
end
core.register_on_player_receive_fields = function(fn) receivers[#receivers + 1] = fn end
core.register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end
core.register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end
core.create_detached_inventory = function(name, callbacks)
	local inv = node_inventory()
	detached[name] = {inv = inv, callbacks = callbacks}
	return inv
end
core.remove_detached_inventory = function(name) detached[name] = nil end

-- Cooking and fuel recipes.
local COOK = {["test:ore"] = {"test:bar", 10}, ["test:meat"] = {"test:steak", 3}}
local FUEL = {["test:log"] = 15, ["test:leaves"] = 2, ["default:coal_lump"] = 80}
core.registered_items["test:log"] = {groups = {tree = 1}}
core.registered_items["test:leaves"] = {groups = {leaves = 1}}
core.registered_items["test:junk"] = {stack_max = 99}
core.get_craft_result = function(input)
	local first = input.items[1]
	local stack = ItemStack(type(first) == "table" and first:to_string() or first or "")
	local after = ItemStack(stack:to_string())
	after:take_item(1)
	if input.method == "cooking" and COOK[stack:get_name()] then
		local row = COOK[stack:get_name()]
		return {time = row[2], item = ItemStack(row[1]), replacements = {}},
			{items = {after}}
	elseif input.method == "fuel" and FUEL[stack:get_name()] then
		return {time = FUEL[stack:get_name()], item = ItemStack(""), replacements = {}},
			{items = {after}}
	end
	return {time = 0, item = ItemStack(""), replacements = {}}, {items = {ItemStack(stack:to_string())}}
end

local function new_player(name, bags)
	local p = H.player(name, "warrior", bags)
	function p:get_hp() return 20 end
	players[name] = p
	return p
end
local function near(player, pos)
	player.get_pos = function() return {x = pos.x + 1, y = pos.y, z = pos.z} end
end

--
-- The real form files
--

default = setmetatable({
	get_translator = function(s) return s end,
	get_inventory_drops = noop,
	set_inventory_action_loggers = noop,
}, {__index = function() return noop end})
dofile(repo .. "/mods/BASE/default/node_formspec.lua")
dofile(repo .. "/mods/BASE/default/furnace.lua")

grug_core.interaction_protected = function() return false end
local public = {}
grug_jobs = {
	station_info = function(station)
		return station == "furnace" and {display_name = "Furnace", node = "default:furnace"} or
			{display_name = "Dual Furnace", node = "grug_smelting:dual_furnace"}
	end,
	is_public_station = function(_, pos) return public[key(pos)] == true end,
	furnace_take_sound = function() return "take" end,
}
grug_smelting = {match = function(a, b)
	local pair = {a, b}
	table.sort(pair)
	if pair[1] == "test:ore" and pair[2] == "test:tin" then
		return {output = "test:alloy 2", time = 10}
	end
end}
local automatic = dofile(repo .. "/mods/PLAYER/grug_jobs/automatic.lua")

local function run_globalsteps()
	for _, step in ipairs(globalsteps) do step(1.0) end
end

-- The parts of a shown form: every animated element and still strip frame.
local function parse(fs)
	local form = {anim = {}, still = {}}
	for name, texture, frames, duration, start in fs:gmatch(
			"animated_image%[[^;]*;[^;]*;([^;]*);([^;]*);(%d+);(%d+);(%d+)%]") do
		form.anim[name] = {texture = texture, frames = tonumber(frames),
			duration = tonumber(duration), start = tonumber(start)}
	end
	for which, frames, frame in fs:gmatch(
			"image%[[^;]*;[^;]*;grug_inventory_furnace_(%a+)%.png%^%[verticalframe:(%d+):(%d+)%]") do
		form.still[which] = {frames = tonumber(frames), frame = tonumber(frame)}
	end
	form.fire_off = fs:find("default_furnace_fire_bg.png]", 1, true) ~= nil
	return form
end

--
-- M: bytes per minute of an open burning workspace furnace (four bags).
--

local function measure()
	local name = "measure"
	local player = new_player(name, {16, 8, 16, 8})
	local pos = {x = 900, y = 0, z = 0}
	nodes[key(pos)] = "default:furnace"
	-- (The station mark install_node gives; an older tree is measured
	-- without running its on_mods_loaded.)
	for _, node in ipairs({"default:furnace", "default:furnace_active"}) do
		registered_nodes[node]._grug_station = "furnace"
	end
	near(player, pos)
	public[key(pos)] = true
	local workspaces = grug_jobs.workspaces
	workspaces.open(pos, player)
	local ctx_inv
	for dname, d in pairs(detached) do
		if dname:find("_" .. name .. "_", 1, true) then ctx_inv = d end
	end
	ctx_inv.inv:set_stack("fuel", 1, "default:coal_lump 5")
	ctx_inv.inv:set_stack("src", 1, "test:ore 30")
	ctx_inv.callbacks.on_put(ctx_inv.inv, "src", 1, ItemStack("test:ore 30"), player)
	run_globalsteps() -- the start
	local first = #shown
	local bytes, count = 0, 0
	for _ = 1, 60 do
		now = now + 1
		run_globalsteps()
	end
	for i = first + 1, #shown do
		if shown[i].name == name then
			bytes, count = bytes + #shown[i].formspec, count + 1
		end
	end
	local size = #(shown[#shown] and shown[#shown].formspec or "")
	print(("R491 ANIM MEASURE workspace furnace, 4 bags, coal + ore 10 s, 60 s open: " ..
		"%d re-sends, %d bytes (last form %d bytes)"):format(count, bytes, size))
	return count, bytes
end

-- workspaces.lua with the real automatic.lua (its on_mods_loaded installs
-- the station nodes; furnace.lua's plain nodes are kept for P first).
local function load_workspaces()
	local real_dofile = dofile
	core.get_modpath = function(mod) return repo .. "/mods/PLAYER/" .. mod end
	grug_jobs.workspaces = real_dofile(repo .. "/mods/PLAYER/grug_jobs/workspaces.lua")
end

if MEASURE_ONLY then
	load_workspaces()
	measure()
	os.exit(0)
end

--
-- A: the helper
--

do
	local F, A = FP.FIRE, FP.ARROW
	local function anim(text) return parse(text).anim end
	-- Fire over a 15 s log: frame starts at given fractions burnt.
	for _, row in ipairs({{15, 1}, {7.5, 8}, {0.5, 15}, {0, 15}}) do
		local a = anim(FP.fire(0, 0, 1, 1, row[1], 15, true))[F.name]
		eq(a and a.start, row[2], ("A fire %.1f of 15 s left: frame start"):format(row[1]))
		eq(a and a.duration, 1000, "A fire 15 s: 1000 ms per frame")
		eq(a and a.frames, F.frames, "A fire: every strip frame")
	end
	-- Arrow over a 10 s item.
	for _, row in ipairs({{0, 1}, {5, 12}, {9.9, 22}, {10, 22}}) do
		local a = anim(FP.arrow(0, 0, 1, 1, row[1], 10, true))[A.name]
		eq(a and a.start, row[2], ("A arrow %.1f of 10 s: frame start"):format(row[1]))
		eq(a and a.duration, math.floor(10000 / A.fill + 0.5), "A arrow 10 s: ms per frame")
	end
	-- The buffer: as long as the duration, at least two seconds (the
	-- one-second tick plus a second of lag).
	eq(FP.MIN_BUFFER, 2, "A the minimum buffer in seconds")
	for _, total in ipairs({1, 2, 3, 15, 80}) do
		local f = anim(FP.fire(0, 0, 1, 1, total, total, true))[F.name]
		local a = anim(FP.arrow(0, 0, 1, 1, 0, total, true))[A.name]
		local fire_buffer = (F.frames - F.fill) * f.duration
		local arrow_buffer = (A.frames - A.fill) * a.duration
		check(fire_buffer >= math.max(total, 2) * 1000 - F.fill,
			("A fire %d s: buffer %d ms"):format(total, fire_buffer))
		check(arrow_buffer >= math.max(total, 2) * 1000 - A.fill,
			("A arrow %d s: buffer %d ms"):format(total, arrow_buffer))
	end
	-- Still pictures.
	check(parse(FP.fire(0, 0, 1, 1, 0, 0, false)).fire_off, "A no fuel: the empty fire")
	check(parse(FP.fire(0, 0, 1, 1, 0, 0, true)).fire_off, "A no fuel, burning flag: still empty")
	local still = parse(FP.fire(0, 0, 1, 1, 5, 15, false)).still.fire
	eq(still and still.frame, 10, "A a held fire: the frame of its fraction")
	still = parse(FP.fire(0, 0, 1, 1, 0, 15, false)).still.fire
	eq(still and still.frame, F.fill - 1, "A a burnt-out held fire: the lowest flame, never empty")
	local burnt = anim(FP.fire(0, 0, 1, 1, 0, 15, true))[F.name]
	eq(burnt and burnt.start, F.fill, "A a burnt-out fuel not yet replaced: the lowest flame")
	still = parse(FP.arrow(0, 0, 1, 1, 10, 10, false)).still.arrow
	eq(still and still.frame, A.fill, "A a done item held (output full): the full arrow")
	still = parse(FP.arrow(0, 0, 1, 1, 4, 10, false)).still.arrow
	eq(still and still.frame, math.floor(0.4 * A.fill), "A a held item: the frame of its fraction")
	still = parse(FP.arrow(0, 0, 1, 1, 0, 0, false)).still.arrow
	eq(still and still.frame, 0, "A no item: the empty arrow")
	-- The strips' sizes (PNG IHDR) match the helper's frame counts.
	for _, row in ipairs({{F, 16, 16}, {A, 49, 49}}) do
		local file = io.open(repo .. "/mods/PLAYER/grug_inventory/textures/" .. row[1].texture, "rb")
		local data = file and file:read(24) or ""
		if file then file:close() end
		local function u32(at)
			local a, b, c, d = data:byte(at, at + 3)
			return ((a or 0) * 256 + (b or 0)) * 65536 + (c or 0) * 256 + (d or 0)
		end
		eq(u32(17), row[2], row[1].texture .. ": frame width")
		eq(u32(21), row[3] * row[1].frames, row[1].texture .. ": every frame in the strip")
	end
end

--
-- K: the change check
--

do
	local context = {}
	local fs1 = "x" .. FP.fire(0, 0, 1, 1, 14, 15, true) .. FP.arrow(1, 0, 1, 1, 1, 10, true)
	local fs2 = "x" .. FP.fire(0, 0, 1, 1, 13, 15, true) .. FP.arrow(1, 0, 1, 1, 2, 10, true)
	check(fs1 ~= fs2, "K the frame starts move between builds")
	eq(FP.changed(context, fs1, 14, 1), true, "K the first build is a change")
	eq(FP.changed(context, fs2, 13, 2), false, "K only the frames moved: no change")
	eq(FP.changed(context, fs2, 13, 2), false, "K the same build again: no change")
	eq(FP.changed(context, fs2 .. "y", 12, 3), true, "K other text changed: a change")
	eq(FP.changed(context, fs2 .. "y", 14, 4), true, "K more fuel left (a new fuel): a change")
	eq(FP.changed(context, fs2 .. "y", 13, 0.5), true, "K less cooked (a new item): a change")
	local other = {}
	eq(FP.changed(other, fs2, 13, 2), true, "K per viewer: another session's first build")
end

--
-- The scripted burns: the shows, and the animation between them.
--

-- After a show at `at` with element `a`, the frame the client draws at
-- `later` (0-based, wrapping like guiAnimatedImage).
local function frame_at(a, at, later)
	local frame = a.start - 1 + math.floor((later - at) * 1000 / a.duration)
	return frame, frame >= a.frames
end

-- Checks over the shows of `name` since index `from`: no animated element
-- wraps before the next show (or `until_t`), and at each re-send the
-- element that did not change state goes on where it was (within a frame).
local function check_animation(label, name, from, until_t)
	local list = {}
	for i = from + 1, #shown do
		if shown[i].name == name and shown[i].formspec ~= "" then list[#list + 1] = shown[i] end
	end
	for index, show in ipairs(list) do
		local form = parse(show.formspec)
		local next_at = list[index + 1] and list[index + 1].at or until_t
		for element, a in pairs(form.anim) do
			local _, wrapped = frame_at(a, show.at, next_at)
			check(not wrapped, ("%s: %s shown at %d runs past its buffer before %d"):format(
				label, element, show.at, next_at))
		end
		local nxt = list[index + 1] and parse(list[index + 1].formspec)
		if nxt then
			for element, a in pairs(form.anim) do
				local b = nxt.anim[element]
				if b and b.duration == a.duration then
					local predicted = frame_at(a, show.at, next_at)
					local fill = element == FP.FIRE.name and FP.FIRE.fill or FP.ARROW.fill
					predicted = math.min(predicted, fill - 1)
					-- The same fuel or item: no jump. A new one restarts.
					if b.start - 1 >= predicted - 1 then
						check(math.abs(b.start - 1 - predicted) <= 1,
							("%s: %s goes on at the re-send at %d (frame %d, predicted %d)"):format(
								label, element, next_at, b.start - 1, predicted))
					end
				end
			end
		end
	end
	return list
end

local function shows_of(name, from)
	local at = {}
	for i = from + 1, #shown do
		if shown[i].name == name and shown[i].formspec ~= "" then at[#at + 1] = shown[i].at end
	end
	return at
end

--
-- P: the plain furnace (furnace.lua's node timer and node_formspec.refresh)
--

local plain_results = {}
local function plain_case(label, inputs, seconds, expected, prepare)
	local name = "p_" .. label:gsub("%W", "")
	local player = new_player(name, {16})
	local pos = {x = #plain_results * 3 + 3, y = 0, z = 0}
	plain_results[#plain_results + 1] = label
	nodes[key(pos)] = "default:furnace"
	local def = registered_nodes["default:furnace"]
	def.on_construct(pos)
	near(player, pos)
	local start = now
	def.on_rightclick(pos, {name = "default:furnace"}, player, ItemStack(""))
	local inv = meta_at(pos):get_inventory()
	if prepare then prepare(inv) end
	for list, item in pairs(inputs) do inv:set_stack(list, 1, item) end
	def.on_metadata_inventory_put(pos, "src", 1, ItemStack(inputs.src or ""), player)
	local from = #shown
	for _ = 1, seconds do
		now = now + 1
		if timers[key(pos)] then
			local node_def = registered_nodes[nodes[key(pos)]]
			if not node_def.on_timer(pos, 1.0) then timers[key(pos)] = nil end
		end
	end
	local at = shows_of(name, from)
	for i, t in ipairs(at) do at[i] = t - start end
	eq(list_text(at), list_text(expected), "P " .. label .. ": re-sent at (s)")
	check_animation("P " .. label, name, from, now)
	return inv, pos
end

do
	-- The fuel ends mid-item (at 15 s: the plain furnace lights the next one
	-- a tick later), items end mid-fuel (10, 20 s), the last item at 30 s,
	-- the furnace goes out at 31 s.
	local inv = plain_case("logs and ore", {src = "test:ore 3", fuel = "test:log 2"}, 40,
		{1, 10, 16, 20, 30, 31})
	eq(inv:get_stack("dst", 1):to_string(), "test:bar 3", "P logs and ore: three bars")
	eq(inv:get_stack("fuel", 1):to_string(), "", "P logs and ore: both logs burnt")
	-- A short fuel (2 s leaves) and 3 s items.
	inv = plain_case("leaves and meat", {src = "test:meat 2", fuel = "test:leaves 4"}, 12,
		{1, 3, 5, 6, 7})
	eq(inv:get_stack("dst", 1):to_string(), "test:steak 2", "P leaves and meat: two steaks")
	-- The output full after one bar: the second waits from 20 s, held
	-- (fire and arrow still), no re-send while it waits.
	inv = plain_case("output full", {src = "test:ore 3", fuel = "test:log 3"}, 35, {1, 10, 16, 20},
		function(inv)
			inv:set_stack("dst", 1, "test:bar 98")
			for i = 2, 4 do inv:set_stack("dst", i, "test:junk 99") end
		end)
	local last = parse(shown[#shown].formspec)
	eq(last.still.arrow and last.still.arrow.frame, FP.ARROW.fill, "P output full: the arrow held full")
	check(last.still.fire ~= nil and last.anim[FP.FIRE.name] == nil, "P output full: the fire held")
	-- An idle furnace open: nothing is re-sent.
	plain_case("idle", {}, 20, {})
end

--
-- W: the workspace furnaces (the one-second pass)
--

load_workspaces()

local ws_serial = 0
-- Opens a workspace and puts `inputs`; runs `seconds` (node timer for a
-- shared station, then the one-second pass). Returns the station's lists.
local function ws_case(label, case, inputs, seconds, expected, prepare, during)
	ws_serial = ws_serial + 1
	local name = "w_" .. label:gsub("%W", "")
	local player = new_player(name, {16, 8, 16, 8})
	local pos = {x = 500 + ws_serial * 3, y = 0, z = 0}
	nodes[key(pos)] = case.node
	public[key(pos)] = case.personal or nil
	near(player, pos)
	local def = registered_nodes[case.node]
	if def.on_construct then def.on_construct(pos) end
	local start = now
	check(grug_jobs.workspaces.open(pos, player), "W " .. label .. ": opens")
	local inv, put
	if case.personal then
		local d
		for dname, entry in pairs(detached) do
			if dname:find("_" .. name .. "_", 1, true) then d = entry end
		end
		inv = d.inv
		put = function(list) d.callbacks.on_put(inv, list, 1, inv:get_stack(list, 1), player) end
	else
		inv = meta_at(pos):get_inventory()
		put = function(list) def.on_metadata_inventory_put(pos, list, 1, inv:get_stack(list, 1), player) end
	end
	if prepare then prepare(inv) end
	for _, row in ipairs(inputs) do
		inv:set_stack(row[1], row[3] or 1, row[2])
		put(row[1])
	end
	local from = #shown
	for second = 1, seconds do
		now = now + 1
		if not case.personal and timers[key(pos)] then
			if not registered_nodes[nodes[key(pos)]].on_timer(pos, 1.0) then timers[key(pos)] = nil end
		end
		run_globalsteps()
		if during then during(second, inv, put, player, pos) end
	end
	local at = shows_of(name, from)
	for i, t in ipairs(at) do at[i] = t - start end
	eq(list_text(at), list_text(expected), "W " .. label .. ": re-sent at (s)")
	check_animation("W " .. label, name, from, now)
	grug_jobs.workspaces.open(pos, player) -- re-open: the form as the player sees it now
	return inv
end

local FURNACE = {node = "default:furnace"}
local PERSONAL = {node = "default:furnace", personal = true}
local DUAL = {node = "grug_smelting:dual_furnace"}
registered_nodes["grug_smelting:dual_furnace"] = {_grug_station = "dual_furnace"}
registered_nodes["grug_smelting:dual_furnace_active"] = {_grug_station = "dual_furnace"}
for _, fn in ipairs(mods_loaded) do fn() end

-- The processing alone, for the cooking results: automatic.advance once a
-- second over the same inputs, no form.
local function reference(station, sizes, inputs, seconds, prepare)
	local inv = node_inventory()
	for list, size in pairs(sizes) do inv:set_size(list, size) end
	if prepare then prepare(inv) end
	local state = {}
	for _, row in ipairs(inputs) do
		inv:set_stack(row[1], row[3] or 1, row[2])
		automatic.advance(station, inv, state, 0)
	end
	for _ = 1, seconds do automatic.advance(station, inv, state, 1) end
	return inv
end
local function same_lists(label, a, b, lists)
	for _, list in ipairs(lists) do
		local x, y = {}, {}
		for i, s in ipairs(a:get_list(list)) do x[i] = s:to_string() end
		for i, s in ipairs(b:get_list(list)) do y[i] = s:to_string() end
		eq(table.concat(x, "|"), table.concat(y, "|"), label .. ": " .. list ..
			" as the processing alone")
	end
end

local FURNACE_SIZES = automatic.sizes.furnace
for _, case in ipairs({{"personal", PERSONAL}, {"shared", FURNACE}}) do
	local tag, kind = case[1], case[2]
	-- Logs and ore: start, an item at 10, the second log at 15 (mid-item),
	-- items at 20 and 30, where the fuel ends too.
	local inputs = {{"fuel", "test:log 2"}, {"src", "test:ore 3"}}
	local inv = ws_case(tag .. " logs and ore", kind, inputs, 40, {1, 10, 15, 20, 30})
	same_lists("W " .. tag .. " logs and ore", inv, reference("furnace", FURNACE_SIZES, inputs, 40),
		{"src", "fuel", "dst"})
	eq(inv:get_stack("dst", 1):to_string(), "test:bar 3", "W " .. tag .. " logs and ore: three bars")
	-- A short fuel: 2 s leaves, 3 s items.
	inputs = {{"fuel", "test:leaves 4"}, {"src", "test:meat 2"}}
	inv = ws_case(tag .. " leaves and meat", kind, inputs, 12, {1, 2, 3, 4, 6})
	same_lists("W " .. tag .. " leaves and meat", inv,
		reference("furnace", FURNACE_SIZES, inputs, 12), {"src", "fuel", "dst"})
	-- An idle furnace open: nothing is re-sent.
	ws_case(tag .. " idle", kind, {}, 30, {})
end

-- The output full after one bar (shared): held at 10 s, no re-send while
-- the coal burns on; the bars taken at 20 s: it cooks again (re-sent at the
-- next pass).
do
	local prepare = function(inv)
		inv:set_stack("dst", 1, "test:bar 98")
		for i = 2, 4 do inv:set_stack("dst", i, "test:junk 99") end
	end
	ws_case("output full", FURNACE, {{"fuel", "default:coal_lump 1"}, {"src", "test:ore 3"}}, 40,
		{1, 10, 21, 30, 40}, prepare, function(second, inv, put, player, pos)
			if second == 20 then
				inv:set_stack("dst", 1, "")
				registered_nodes["default:furnace_active"].on_metadata_inventory_take(pos, "dst", 1,
					ItemStack("test:bar 99"), player)
			end
		end)
	local last = parse(shown[#shown].formspec)
	check(last.anim[FP.FIRE.name] ~= nil, "W output full: the coal still burns (animated)")
end

-- The dual furnace (shared): ore + tin, 10 s each; the coal burns on after
-- the inputs are used up, its end re-sent at 80 s.
do
	local inputs = {{"fuel", "default:coal_lump 1"}, {"input", "test:ore 2"}, {"input", "test:tin 2", 2}}
	local inv = ws_case("dual furnace", DUAL, inputs, 85, {1, 10, 20, 80})
	same_lists("W dual furnace", inv, reference("dual_furnace", automatic.sizes.dual_furnace,
		inputs, 85), {"input", "fuel", "output"})
	eq(inv:get_stack("output", 1):to_string(), "test:alloy 4", "W dual furnace: two alloys of two")
end

-- A player's own click re-shows at once; a pure scroll event does not.
do
	local name = "w_click"
	local player = new_player(name, {16, 8, 16, 8})
	local pos = {x = 800, y = 0, z = 0}
	nodes[key(pos)] = "default:furnace"
	registered_nodes["default:furnace"].on_construct(pos)
	near(player, pos)
	grug_jobs.workspaces.open(pos, player)
	local before = #shown
	for _, fn in ipairs(receivers) do
		if fn(player, "grug_jobs:workspace", {grug_inv_scroll_station = "CHG:10",
			grug_furnace_fire = "3"}) then break end
	end
	eq(#shown, before, "W a pure scroll event (with the animation's field) re-sends nothing")
	for _, fn in ipairs(receivers) do
		if fn(player, "grug_jobs:workspace", {something = "x"}) then break end
	end
	eq(#shown, before + 1, "W a player's click re-shows")
	check(shown[#shown].formspec:find("vertical;grug_inv_scroll_station;10]", 1, true) ~= nil,
		"W the re-show keeps the scroll position")
end

-- M: the numbers.
local count, bytes = measure()
check(count > 0 and count <= 10, "M a burning minute re-sends a few times, not every second")
print(("R491 ANIM bytes per minute (measured): %d"):format(bytes))

if failures > 0 then
	print(("R491 ANIM PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R491 ANIM PORTABLE PASS checks=%d"):format(checks))
