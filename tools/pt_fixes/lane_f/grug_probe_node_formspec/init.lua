-- Disposable engine probe (playtest fixes, Lane F). Never shipped:
-- tools/pt_fixes/lane_f/run.sh stages it through tools/luanti_headless.sh.
--
-- Asserts that no node keeps its UI in node metadata ("formspec"), that each
-- converted node opens the same UI from on_rightclick via core.show_formspec
-- (captured, not stubbed away: the shipped wrapper still runs), that field
-- submissions (sign text, spawner settings) reach on_receive_fields through
-- the server-side session and are validated, that open shelves/furnaces are
-- refreshed, and that the vendored furnace chain and the live grug_jobs
-- furnace both still smelt.
--
-- A headless server has no client, so the "player" is a plain table with the
-- accessors the code under test reads.

local P = "[node_formspec_probe] "
local BASE = vector.new(96, 300, 96)
local failures, checks = 0, 0

local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
end

-- The vendored furnace callbacks, captured before grug_jobs replaces them
-- (core.override_item in its on_mods_loaded).
local vendored = {}
do
	local def = core.registered_nodes["default:furnace"]
	vendored.on_construct = def.on_construct
	vendored.on_timer = def.on_timer
	vendored.on_rightclick = def.on_rightclick
end

--
-- Captures
--
local shown, closed = {}, {}
local protected = {}
local fakes = {}

local function fake_player(name, pos)
	local player = {pos = vector.new(pos)}
	function player:get_player_name() return name end
	function player:is_player() return true end
	function player:get_pos() return vector.new(self.pos) end
	function player:get_hp() return 20 end
	function player:get_wielded_item() return ItemStack("") end
	player.is_fake_player = false
	-- Other receive-fields callbacks run before the one under test and read
	-- player meta (faction, class, ...): an empty table-backed store.
	local store = {}
	local meta = {}
	function meta:get_string(k) return store[k] or "" end
	function meta:set_string(k, v) store[k] = v ~= "" and tostring(v) or nil end
	function meta:get_int(k) return math.floor(tonumber(store[k]) or 0) end
	function meta:set_int(k, v) meta:set_string(k, tostring(v)) end
	function meta:get_float(k) return tonumber(store[k]) or 0 end
	function meta:set_float(k, v) meta:set_string(k, tostring(v)) end
	function meta:contains(k) return store[k] ~= nil end
	function player:get_meta() return meta end
	-- Inventory-form ("") handlers read the player inventory.
	local inv = core.create_detached_inventory("grug_probe_node_formspec_" .. name, {})
	inv:set_size("main", 32)
	inv:set_size("craft", 9)
	inv:set_size("craftpreview", 1)
	function player:get_inventory() return inv end
	setmetatable(player, {__index = function(_, key)
		log("fake player: unmodelled method " .. tostring(key) .. " -> nil")
		return function() return nil end
	end})
	fakes[name] = player
	return player
end

local function install_captures()
	local show = core.show_formspec
	core.show_formspec = function(name, formname, formspec)
		shown[#shown + 1] = {name = name, formname = formname, formspec = formspec}
		return show(name, formname, formspec)
	end
	local close = core.close_formspec
	core.close_formspec = function(name, formname)
		closed[#closed + 1] = {name = name, formname = formname}
		return close(name, formname)
	end
	local by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return fakes[name] or by_name(name)
	end
	-- The probe player has no faction or auth entry; grug protection would
	-- refuse it everywhere. Protection is simulated per position instead.
	local is_protected = core.is_protected
	core.is_protected = function(pos, name)
		if fakes[name] then return protected[core.hash_node_position(pos)] == true end
		return is_protected(pos, name)
	end
end

local function last_shown(name)
	for i = #shown, 1, -1 do
		if shown[i].name == name then return shown[i] end
	end
end

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return true end
	end
	return false
end

local function has(s, needle)
	return s ~= nil and s:find(needle, 1, true) ~= nil
end

local function count(s, needle)
	local n, from = 0, 1
	while true do
		local a, b = s:find(needle, from, true)
		if not a then return n end
		n, from = n + 1, b + 1
	end
end

local function meta_formspec_empty(pos, label)
	local value = core.get_meta(pos):get_string("formspec")
	check(value == "", label .. ": meta formspec is empty" ..
		(value == "" and "" or (" (got " .. value:sub(1, 60) .. ")")))
end

local function rightclick(pos, player)
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	check(type(def.on_rightclick) == "function", node.name .. ": has on_rightclick")
	local before = #shown
	local stack = def.on_rightclick(pos, node, player, ItemStack(""), {
		type = "node", under = pos, above = vector.offset(pos, 0, 1, 0)})
	check(stack ~= nil, node.name .. ": on_rightclick returns the itemstack")
	check(#shown == before + 1, node.name .. ": on_rightclick shows exactly one formspec")
	return shown[#shown]
end

local function cookable_and_fuel()
	local names = {}
	for name in pairs(core.registered_items) do names[#names + 1] = name end
	table.sort(names)
	local cook
	for _, name in ipairs({"default:cobble", "grug_materials:iron_lump",
			"default:iron_lump", "default:sand"}) do
		if core.registered_items[name] and core.get_craft_result({method = "cooking",
				width = 1, items = {name}}).time > 0 then cook = name break end
	end
	if not cook then
		for _, name in ipairs(names) do
			if name ~= "" and core.get_craft_result({method = "cooking", width = 1,
					items = {name}}).time > 0 then cook = name break end
		end
	end
	return cook, "default:coal_lump"
end

--
-- Scenarios
--
local NF = "default:node_formspec"

local function run()
	install_captures()
	local nf = default.node_formspec
	check(nf ~= nil and nf.formname == NF, "default.node_formspec is installed")
	local player = fake_player("probe_a", vector.offset(BASE, 0, 1, -2))
	local ploc = function(pos) return "nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z end

	-- Bookshelf: lists, listring, overlay, live refresh on inventory change.
	do
		local pos = vector.offset(BASE, 0, 1, 0)
		core.set_node(pos, {name = "default:bookshelf"})
		meta_formspec_empty(pos, "bookshelf after construct")
		local s = rightclick(pos, player)
		check(s and s.formname == NF, "bookshelf: formname " .. tostring(s and s.formname))
		check(has(s.formspec, "list[" .. ploc(pos) .. ";books;0,0.3;8,2;]"),
			"bookshelf: nodemeta books list")
		check(has(s.formspec, "listring[" .. ploc(pos) .. ";books]") and
			has(s.formspec, "listring[current_player;main]"), "bookshelf: listring")
		check(count(s.formspec, "default_bookshelf_slot.png") == 16, "bookshelf: 16 empty-slot overlays")
		check(not has(s.formspec, "context"), "bookshelf: no context location")
		check(vector.equals(nf.session_pos("probe_a") or vector.zero(), pos), "bookshelf: session bound to pos")
		local def = core.registered_nodes["default:bookshelf"]
		local inv = core.get_meta(pos):get_inventory()
		inv:set_stack("books", 1, "default:book")
		local before = #shown
		def.on_metadata_inventory_put(pos, "books", 1, ItemStack("default:book"), player)
		check(#shown == before + 1, "bookshelf: inventory change re-shows the open form")
		check(count(shown[#shown].formspec, "default_bookshelf_slot.png") == 15,
			"bookshelf: refreshed overlay has 15 empty slots")
		before = #shown
		def.on_metadata_inventory_put(pos, "books", 1, ItemStack("default:book"), player)
		check(#shown == before, "bookshelf: unchanged formspec is not re-sent")
		check(has(core.get_meta(pos):get_string("infotext"), "Bookshelf"), "bookshelf: infotext kept")
		meta_formspec_empty(pos, "bookshelf after update")
		-- A form shown by anyone else ends the session; refresh no longer targets it.
		core.show_formspec("probe_a", "other:form", "size[1,1]")
		check(nf.session_pos("probe_a") == nil, "bookshelf: another form ends the session")
		inv:set_stack("books", 2, "default:book")
		before = #shown
		def.on_metadata_inventory_put(pos, "books", 2, ItemStack("default:book"), player)
		check(#shown == before, "bookshelf: no refresh after the session ended")
		-- Fields of another form also end a session.
		rightclick(pos, player)
		submit(player, "other:form", {foo = "1"})
		check(nf.session_pos("probe_a") == nil, "bookshelf: fields of another form end the session")
		-- Quit ends it too.
		rightclick(pos, player)
		submit(player, NF, {quit = "true"})
		check(nf.session_pos("probe_a") == nil, "bookshelf: quit ends the session")
		-- Closing an unrelated form is ignored by the engine unless it is open.
		rightclick(pos, player)
		core.close_formspec("probe_a", "other:form")
		check(nf.session_pos("probe_a") ~= nil, "bookshelf: closing another form keeps the session")
		-- Fields of the player inventory ("") end it.
		-- (Inventory-page handlers need a full player object; the fake one is
		-- not enough for them, so their errors are tolerated here.)
		for _, fn in ipairs(core.registered_on_player_receive_fields) do
			local ok, consumed = pcall(fn, player, "", {foo = "1"})
			if ok and consumed then break end
		end
		check(nf.session_pos("probe_a") == nil, "bookshelf: inventory fields end the session")
		-- Two viewers, one out of range: the near one is refreshed, the far
		-- one is closed and forgotten.
		local far = fake_player("probe_b", vector.offset(pos, 0, 0, -2))
		rightclick(pos, player)
		rightclick(pos, far)
		far.pos = vector.offset(pos, 40, 0, 0)
		inv:set_stack("books", 3, "default:book")
		before = #shown
		local nclosed = #closed
		def.on_metadata_inventory_put(pos, "books", 3, ItemStack("default:book"), player)
		-- (builtin close_formspec shows "" through show_formspec: skip those)
		local refreshed = {}
		for i = before + 1, #shown do
			if shown[i].formspec ~= "" then refreshed[#refreshed + 1] = shown[i].name end
		end
		check(#refreshed == 1 and refreshed[1] == "probe_a",
			"bookshelf: only the in-range viewer is refreshed")
		check(nf.session_pos("probe_b") == nil and #closed == nclosed + 1 and
			closed[#closed].name == "probe_b", "bookshelf: out-of-range viewer closed")
		check(nf.session_pos("probe_a") ~= nil, "bookshelf: in-range viewer keeps the session")
		-- Digging closes open viewers.
		nclosed = #closed
		core.remove_node(pos)
		check(nf.session_pos("probe_a") == nil and #closed == nclosed + 1,
			"bookshelf: digging closes the open form")
	end

	-- Vessels shelf.
	do
		local pos = vector.offset(BASE, 2, 1, 0)
		core.set_node(pos, {name = "vessels:shelf"})
		meta_formspec_empty(pos, "vessels shelf after construct")
		local s = rightclick(pos, player)
		check(s.formname == NF, "vessels shelf: formname")
		check(has(s.formspec, "list[" .. ploc(pos) .. ";vessels;0,0.3;8,2;]") and
			has(s.formspec, "listring[" .. ploc(pos) .. ";vessels]"), "vessels shelf: nodemeta list + listring")
		check(count(s.formspec, "vessels_shelf_slot.png") == 16, "vessels shelf: 16 empty-slot overlays")
		local def = core.registered_nodes["vessels:shelf"]
		core.get_meta(pos):get_inventory():set_stack("vessels", 3, "vessels:glass_bottle 2")
		local before = #shown
		def.on_metadata_inventory_put(pos, "vessels", 3, ItemStack("vessels:glass_bottle 2"), player)
		check(#shown == before + 1 and count(shown[#shown].formspec, "vessels_shelf_slot.png") == 15,
			"vessels shelf: refresh on inventory change")
		check(has(core.get_meta(pos):get_string("infotext"), "2"), "vessels shelf: infotext counts items")
		meta_formspec_empty(pos, "vessels shelf after update")
		submit(player, NF, {quit = "true"})
	end

	-- Signs (vendored wood/steel and the grug_materials iron copy).
	for i, name in ipairs({"default:sign_wall_wood", "default:sign_wall_steel",
			"grug_materials:iron_sign_wall"}) do
		if core.registered_nodes[name] then
			local pos = vector.offset(BASE, 2 * i, 1, 3)
			core.set_node(pos, {name = name, param2 = 1})
			meta_formspec_empty(pos, name .. " after construct")
			local s = rightclick(pos, player)
			check(s.formname == NF and s.formspec == "field[text;;]", name .. ": empty text field")
			local text = "Grudge [1]; a,b \\ end"
			submit(player, NF, {text = text, quit = "true"})
			local meta = core.get_meta(pos)
			check(meta:get_string("text") == text, name .. ": submitted text stored")
			check(meta:get_string("infotext") ~= "", name .. ": infotext set")
			check(nf.session_pos("probe_a") == nil, name .. ": session closed on quit")
			s = rightclick(pos, player)
			check(s.formspec == "field[text;;" .. core.formspec_escape(text) .. "]",
				name .. ": reopened field carries the escaped stored text")
			-- Protected: refused, text unchanged.
			protected[core.hash_node_position(pos)] = true
			submit(player, NF, {text = "hacked", quit = "true"})
			protected[core.hash_node_position(pos)] = nil
			check(meta:get_string("text") == text, name .. ": protected sign refuses the text")
			-- Out of range: refused and the form is closed.
			rightclick(pos, player)
			player.pos = vector.offset(pos, 30, 0, 0)
			local nclosed = #closed
			submit(player, NF, {text = "far away", quit = "true"})
			player.pos = vector.offset(BASE, 0, 1, -2)
			check(meta:get_string("text") == text and #closed == nclosed + 1,
				name .. ": out-of-range submission refused and form closed")
			-- Node replaced: refused.
			-- (The replacement's own refresh already closes the stale form.)
			rightclick(pos, player)
			nclosed = #closed
			core.set_node(pos, {name = "default:bookshelf"})
			submit(player, NF, {text = "gone", quit = "true"})
			check(core.get_meta(pos):get_string("text") == "" and #closed >= nclosed + 1 and
				nf.session_pos("probe_a") == nil,
				name .. ": replaced node gets no text and the form is closed")
			core.set_node(pos, {name = "air"})
			-- No session at all: swallowed, nothing happens.
			check(submit(player, NF, {text = "stray", quit = "true"}) == true,
				name .. ": sessionless submission is swallowed")
		else
			log("skip " .. name .. " (not registered)")
		end
	end

	-- Mob spawner.
	do
		local pos = vector.offset(BASE, 0, 1, 6)
		core.set_node(pos, {name = "mobs:spawner"})
		meta_formspec_empty(pos, "spawner after construct")
		local meta = core.get_meta(pos)
		local default_command = meta:get_string("command")
		local s = rightclick(pos, player)
		check(s.formname == "mobs:spawner_settings", "spawner: formname")
		check(default_command ~= "" and has(s.formspec, "field[0.5,1.8;9.5,0.8;text;") and
			has(s.formspec, ";" .. core.formspec_escape(default_command) .. "]"),
			"spawner: field carries the stored command")
		check(has(s.formspec, "button_exit[3.5,2.7;3,1;mob_spawner;"), "spawner: Done button")
		local mob
		for name in pairs(mobs.spawning_mobs) do
			if not mob or name < mob then mob = name end
		end
		check(mob ~= nil, "spawner: a spawning mob exists (" .. tostring(mob) .. ")")
		local command = mob .. " 0 15 2 0 0"
		submit(player, "mobs:spawner_settings", {text = command, mob_spawner = "Done", quit = "true"})
		check(meta:get_string("command") == command, "spawner: valid settings stored")
		check(has(meta:get_string("infotext"), mob), "spawner: infotext active")
		s = rightclick(pos, player)
		check(has(s.formspec, ";" .. core.formspec_escape(command) .. "]"), "spawner: reopened with new command")
		submit(player, "mobs:spawner_settings", {text = "nonsense 99", quit = "true"})
		check(meta:get_string("command") == command, "spawner: invalid settings rejected")
		rightclick(pos, player)
		protected[core.hash_node_position(pos)] = true
		submit(player, "mobs:spawner_settings", {text = mob .. " 1 14 1 0 0", quit = "true"})
		protected[core.hash_node_position(pos)] = nil
		check(meta:get_string("command") == command, "spawner: protected spawner refuses settings")
		rightclick(pos, player)
		player.pos = vector.offset(pos, 40, 0, 0)
		submit(player, "mobs:spawner_settings", {text = mob .. " 1 14 1 0 0", quit = "true"})
		player.pos = vector.offset(BASE, 0, 1, -2)
		check(meta:get_string("command") == command, "spawner: out-of-range submission refused")
		meta_formspec_empty(pos, "spawner after updates")
	end

	-- Vendored furnace chain (grug_jobs replaces it at runtime): open, smelt,
	-- live refresh of the progress formspec.
	local cook, fuel = cookable_and_fuel()
	check(cook ~= nil, "a cookable item exists (" .. tostring(cook) .. ")")
	do
		local pos = vector.offset(BASE, 6, 1, 6)
		player.pos = vector.offset(pos, 0, 0, -2)
		core.set_node(pos, {name = "default:furnace"})
		vendored.on_construct(pos)
		meta_formspec_empty(pos, "vendored furnace after construct")
		local node = core.get_node(pos)
		local before = #shown
		vendored.on_rightclick(pos, node, player, ItemStack(""))
		local s = shown[#shown]
		check(#shown == before + 1 and s.formname == NF, "vendored furnace: shows the node formspec")
		for _, list in ipairs({"src;2.75,0.5;1,1;", "fuel;2.75,2.5;1,1;", "dst;4.75,0.96;2,2;"}) do
			check(has(s.formspec, "list[" .. ploc(pos) .. ";" .. list .. "]"), "vendored furnace: list " .. list)
		end
		check(has(s.formspec, "listring[" .. ploc(pos) .. ";fuel]"), "vendored furnace: listring")
		local inv = core.get_meta(pos):get_inventory()
		inv:set_stack("src", 1, cook .. " 2")
		inv:set_stack("fuel", 1, fuel .. " 2")
		before = #shown
		vendored.on_timer(pos, 1)
		check(core.get_node(pos).name == "default:furnace_active", "vendored furnace: lit")
		check(#shown > before and has(shown[#shown].formspec, "default_furnace_fire_fg.png"),
			"vendored furnace: open viewer refreshed with the active formspec")
		meta_formspec_empty(pos, "vendored furnace while active")
		vendored.on_timer(pos, 60)
		local out = core.get_craft_result({method = "cooking", width = 1, items = {cook}}).item
		check(inv:contains_item("dst", ItemStack(out:get_name())),
			"vendored furnace smelts " .. cook .. " -> " .. out:get_name() ..
			" (dst " .. inv:get_stack("dst", 1):to_string() .. ")")
		meta_formspec_empty(pos, "vendored furnace after smelting")
		submit(player, NF, {quit = "true"})
		core.get_node_timer(pos):stop()
	end

	-- Live furnace (grug_jobs workspace): no meta formspec, opens server-side
	-- and still smelts through its own chain.
	do
		local pos = vector.offset(BASE, 8, 1, 6)
		player.pos = vector.offset(pos, 0, 0, -2)
		core.set_node(pos, {name = "default:furnace"})
		meta_formspec_empty(pos, "live furnace after construct")
		local s = rightclick(pos, player)
		check(s.formname == "grug_jobs:workspace", "live furnace: grug_jobs workspace form (" ..
			tostring(s.formname) .. ")")
		submit(player, "grug_jobs:workspace", {quit = "true"})
		local def = core.registered_nodes["default:furnace"]
		local inv = core.get_meta(pos):get_inventory()
		inv:set_stack("src", 1, cook .. " 2")
		inv:set_stack("fuel", 1, fuel .. " 2")
		def.on_metadata_inventory_put(pos, "fuel", 1, ItemStack(fuel), player)
		core.registered_nodes[core.get_node(pos).name].on_timer(pos, 60)
		local out = core.get_craft_result({method = "cooking", width = 1, items = {cook}}).item
		check(inv:contains_item("dst", ItemStack(out:get_name())),
			"live furnace smelts (dst " .. inv:get_stack("dst", 1):to_string() .. ")")
		meta_formspec_empty(pos, "live furnace after smelting")
		core.get_node_timer(pos):stop()
	end

	-- Repo-wide sweep: construct every registered node once and assert that
	-- none writes a meta formspec.
	do
		local pos = vector.offset(BASE, 12, 1, 12)
		local names = {}
		for name in pairs(core.registered_nodes) do
			if name ~= "air" and name ~= "ignore" then names[#names + 1] = name end
		end
		table.sort(names)
		local offenders, constructed, errors = {}, 0, 0
		for _, name in ipairs(names) do
			local ok = pcall(core.set_node, pos, {name = name})
			if ok then
				constructed = constructed + 1
				if core.get_meta(pos):get_string("formspec") ~= "" then
					offenders[#offenders + 1] = name
				end
			else
				errors = errors + 1
			end
			pcall(core.remove_node, pos)
			core.get_meta(pos):from_table(nil)
		end
		log("sweep: " .. constructed .. " nodes constructed, " .. errors .. " construct errors")
		check(#offenders == 0, "sweep: no node writes a meta formspec on construct" ..
			(#offenders == 0 and "" or (" (" .. table.concat(offenders, ", ") .. ")")))
	end
end

local function finish()
	log(("RESULT %s (%d checks, %d failures)"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("node formspec probe done", false, 0)
end

local function build_arena(minp, maxp)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local c_air = core.get_content_id("air")
	local c_floor = core.get_content_id("default:stone")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				data[area:index(x, y, z)] = y == minp.y and c_floor or c_air
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

core.after(2, function()
	local minp = vector.offset(BASE, -4, 0, -4)
	local maxp = vector.offset(BASE, 20, 6, 20)
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			build_arena(minp, maxp)
			core.after(0.5, function()
				local ok, err = pcall(run)
				check(ok, "probe ran without error" .. (ok and "" or (" (" .. tostring(err) .. ")")))
				core.after(0.5, finish)
			end)
		end)
	end)
end)
