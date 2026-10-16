-- Disposable engine probe (Round 50 lane PACCEPT: the map-reset packing end
-- to end). Never shipped: tools/r50_paccept/e2e.py stages it through
-- tools/luanti_headless.sh, first under the real 0.48.1 game (phase
-- "setup"), then under this checkout's 0.50.0 game after the tool packed
-- the claims and the map was emptied (phase "accept"). It reads
-- <world>/paccept_plan.json, signals <world>/paccept_ready once its map
-- regions are loaded (e2e.py joins only then) and writes what it saw to
-- <world>/paccept_obs.json; e2e.py checks it. The probe asserts nothing.
--
-- setup (0.48.1)  picks two building sites outside the world's protection
--   (towns, roads, landmarks), loads them (claim one's whole column from
--   y -100: a claim's real block count) and lays a floor. Every joining
--   player becomes a created character (faction, race, class: the world's
--   protection holds everything against a player without a faction). When
--   "keeper" joins: a Claim Stone (registry model.create, as placing does), activated
--   through grug_housing.activate with 5 lumps from the inventory, then fuel
--   through grug_housing.add_fuel (one anthracite, 1.5 lumps, and 82 coal
--   lumps: 88.5 lumps, about 27 days, so the charcoal rounds up and the
--   world stays a fuelled fixture for weeks); in the claim a filled
--   chest (a quality sword with wear), a locked chest (after_place_node:
--   owner keeper) with a written book, a furnace lit through its own put
--   callback with input, fuel and output, a bookshelf with a written book
--   (lines, quotes, a backslash, a tab, non-ASCII), a vessels shelf, a
--   chest holding this probe's own item (unregistered under 0.50.0), an
--   empty chest, an empty furnace and a cellar chest at y -95; outside
--   every claim a chest. "neighbor" gets a
--   claim (5 + 55 lumps) and a chest; "drifter" nothing. At the shutdown, before
--   the engine saves (server.cpp: on_shutdown runs before the map save),
--   every container's lists and node are written to
--   <world>/paccept_receipt.json with the claims.
-- accept (0.50.0)  records the waiting entries and the stored contents
--   (`recovered:*`, `packed:*`, ruling 14) as loaded (after the game's
--   first-start clean-up), captures the join notices (grug_core.feed,
--   key grug_housing_recovered) and the stone forms; reloads the sites and
--   lays the floor again; it signals ready once the world preparation is
--   ready. For each player in plan.flow, once the map reset's relocation
--   to the race start is done (the real path for a created character): a new
--   draft stone (model.create), its form (Belongings must not show), a tab
--   click on it, activation through the form's own button with lumps from
--   the inventory, the Belongings tab, every slot taken as the engine moves
--   it (detached allow_take, the player inventory's allow/on put callbacks,
--   on_take), every packed container placed through its item's on_place on
--   the floor (its stored contents present before, deleted after), and each
--   placed node read back and matched against the
--   receipt (ItemStack ==: name, count, wear, meta; items this version does
--   not register count as removed). plan.recheck names containers a
--   previous boot placed: read back again (a second boot changes nothing).

local P = "[r50_paccept_probe] "
local world = core.get_worldpath()
local FORM = "grug_housing:stone"
local NOTICE_KEY = "grug_housing_recovered"
local RELIC = "grug_probe_r50_paccept:relic"
-- Every character is a created one, as on a played world: the world's
-- protection holds everything against a player without a faction.
local FACTION, RACE, CLASS = "accord", "human", "warrior"

local function log(msg) core.log("action", P .. msg) end

local function read_file(name)
	local f = io.open(world .. "/" .. name, "rb")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text
end

local function write_file(name, text)
	assert(core.safe_file_write(world .. "/" .. name, text), P .. "cannot write " .. name)
end

local plan = core.parse_json(read_file("paccept_plan.json") or "") or {}
local phase = plan.phase or "?"
local SETUP = phase == "setup"
local expected_joins = plan.joins or {}

-- The item 0.50.0 does not know: registered only while the 0.48.1 world is
-- built (the probe is staged again for the 0.50.0 boots).
if SETUP then
	core.register_craftitem(RELIC, {
		description = "Probe Relic (unknown after the upgrade)",
		inventory_image = "default_stick.png",
	})
end

local obs = {phase = phase, joins = {}, leaves = 0, errors = {}}

local function fail(what, err)
	obs.errors[#obs.errors + 1] = what .. ": " .. tostring(err)
	log("ERROR-PROBE " .. what .. ": " .. tostring(err))
end

local function guarded(what, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then fail(what, err) end
	return ok
end

-- Sites --------------------------------------------------------------------

local CANDIDATES = {}
for i = 0, 11 do
	for j = 0, 3 do
		CANDIDATES[#CANDIDATES + 1] = {x = 1200 + 400 * i, z = -1800 + 600 * j}
	end
end

-- Every column the site uses, as offsets from its centre: the floor and the
-- chest outside claim one (x + 60).
local function free_site(x, z, outside)
	if not grug_core.world_protected_for_faction then return true end
	for dx = -4, 12, 2 do
		for dz = -4, 4, 2 do
			if grug_core.world_protected_for_faction({x = x + dx, y = 0, z = z + dz}, FACTION) then
				return false
			end
		end
	end
	if outside then
		for dz = -2, 2, 2 do
			if grug_core.world_protected_for_faction({x = x + 60, y = 0, z = z + dz}, FACTION) then
				return false
			end
		end
	end
	return true
end

local function choose_sites()
	local one, two
	for _, c in ipairs(CANDIDATES) do
		if not one then
			if free_site(c.x, c.z, true) then one = {x = c.x, z = c.z} end
		elseif not two and (math.abs(c.x - one.x) > 250 or math.abs(c.z - one.z) > 250) then
			if free_site(c.x, c.z, false) then two = {x = c.x, z = c.z} end
		end
	end
	assert(one and two, "no free building site among the candidates")
	return one, two
end

local function surface_y(x, z, top, bottom)
	for y = top, bottom, -1 do
		local node = core.get_node({x = x, y = y, z = z})
		local def = core.registered_nodes[node.name]
		if node.name ~= "air" and node.name ~= "ignore" and def and
				(def.walkable or (def.liquidtype or "none") ~= "none") then
			return y
		end
	end
	return bottom
end

-- A stone floor at y - 1 and air above it, x -4..12 and z -4..4 around c.
local function floor_at(c, x0, x1, z0, z1)
	for dx = x0, x1 do
		for dz = z0, z1 do
			core.set_node({x = c.x + dx, y = c.y - 1, z = c.z + dz}, {name = "default:stone"})
			for dy = 0, 4 do
				core.set_node({x = c.x + dx, y = c.y + dy, z = c.z + dz}, {name = "air"})
			end
		end
	end
end

local function emerge_all(regions, done)
	local index = 0
	local function nextone()
		index = index + 1
		local r = regions[index]
		if not r then return done() end
		core.emerge_area(r[1], r[2], function(_, _, remaining)
			if remaining == 0 then nextone() end
		end)
	end
	nextone()
end

local sites

local function lists_of(inv)
	local out = {}
	for name, stacks in pairs(inv:get_lists()) do
		local values = {}
		for index, stack in ipairs(stacks) do values[index] = stack:to_string() end
		out[name] = values
	end
	return out
end

-- Setup (0.48.1) -----------------------------------------------------------

local placed = {}
local claims = {}

local USED_ITEMS = {"default:dirt", "default:torch", "default:cobble", "default:apple",
	"default:coal_lump", "default:book", "default:book_written", "default:stick",
	"default:stone", "vessels:glass_bottle", "vessels:drinking_glass",
	"grug_gear:sword_iron", "grug_materials:anthracite", "default:chest",
	"default:chest_locked", "default:furnace", "default:bookshelf", "vessels:shelf"}

local function book(title, text, owner)
	local stack = ItemStack("default:book_written")
	local lines = select(2, text:gsub("\n", "")) + 1
	stack:get_meta():from_table({fields = {
		title = title, owner = owner, text = text,
		description = "\"" .. title .. "\" by " .. owner,
		page = "1", page_max = tostring(math.ceil(lines / 14)),
	}})
	return stack
end

local LEDGER = "Ledger of the \"old\" claim\n" ..
	"Line two: Gr\195\188\195\159e, na\195\175ve caf\195\169, \194\189 \226\156\147\n" ..
	"\tA tab, a back\\slash and 'single' quotes\n\n" ..
	"Last line \226\128\148 \230\151\165\230\156\172"

local function place(id, owner, name, pos, player, fill)
	core.set_node(pos, {name = name})
	local def = core.registered_nodes[name]
	if def.after_place_node and player then
		def.after_place_node(pos, player, ItemStack(name),
			{type = "node", under = {x = pos.x, y = pos.y - 1, z = pos.z}, above = pos})
	end
	local meta = core.get_meta(pos)
	if fill then fill(meta:get_inventory(), meta, pos) end
	placed[#placed + 1] = {id = id, owner = owner, pos = pos}
end

local function build_keeper(player)
	local name = player:get_player_name()
	local C = sites.one
	for _, item in ipairs(USED_ITEMS) do
		assert(core.registered_items[item], "0.48.1 does not register " .. item)
	end
	player:set_pos({x = C.x + 6, y = C.y, z = C.z + 2})
	core.set_node(C, {name = grug_housing.DRAFT_STONE})
	local model = grug_housing.model
	local claim = model.create(name, C)
	grug_housing.sync_stone_node(claim)
	local inv = player:get_inventory()
	inv:add_item("main", "default:coal_lump " .. grug_housing.ACTIVATION_LUMPS)
	local ok, message = grug_housing.activate(player)
	assert(ok, "activate: " .. tostring(message))
	assert(grug_housing.add_fuel(claim, 1, "grug_materials:anthracite") == 1, "anthracite")
	assert(grug_housing.add_fuel(claim, 82, "default:coal_lump") == 82, "coal")
	claims[#claims + 1] = claim.id

	local y = C.y
	place("chest", name, "default:chest", {x = C.x + 3, y = y, z = C.z}, player, function(cinv)
		cinv:set_stack("main", 1, "default:dirt 99")
		cinv:set_stack("main", 5, "default:torch 50")
		local sword = ItemStack("grug_gear:sword_iron")
		if grug_items and grug_items.crafted_output then grug_items.crafted_output(sword, player) end
		if grug_items and grug_items.roll_enchants then
			pcall(grug_items.roll_enchants, sword, 20, 2, 4242)
		end
		sword:set_wear(4321)
		cinv:set_stack("main", 10, sword)
		cinv:set_stack("main", 20, "default:apple 12")
		cinv:set_stack("main", 32, "default:cobble 7")
	end)
	place("locked_chest", name, "default:chest_locked", {x = C.x + 4, y = y, z = C.z}, player,
		function(cinv)
			cinv:set_stack("main", 2, "default:coal_lump 33")
			cinv:set_stack("main", 3, book("Accounts", LEDGER, name))
		end)
	place("furnace", name, "default:furnace", {x = C.x + 5, y = y, z = C.z}, player,
		function(cinv, _, pos)
			cinv:set_stack("src", 1, "default:cobble 30")
			cinv:set_stack("fuel", 1, "default:coal_lump 6")
			-- The furnace's own put callback lights it (its node timer).
			local def = core.registered_nodes["default:furnace"]
			if def.on_metadata_inventory_put then
				def.on_metadata_inventory_put(pos, "src", 1, ItemStack("default:cobble 30"), player)
			else
				core.get_node_timer(pos):start(1.0)
			end
		end)
	place("bookshelf", name, "default:bookshelf", {x = C.x + 6, y = y, z = C.z}, player,
		function(cinv)
			cinv:set_stack("books", 1, book("Ledger \"one\"", LEDGER, name))
			cinv:set_stack("books", 4, "default:book 3")
		end)
	place("vessels_shelf", name, "vessels:shelf", {x = C.x + 7, y = y, z = C.z}, player,
		function(cinv)
			cinv:set_stack("vessels", 1, "vessels:glass_bottle 5")
			cinv:set_stack("vessels", 9, "vessels:drinking_glass 3")
		end)
	place("relic_chest", name, "default:chest", {x = C.x + 8, y = y, z = C.z}, player,
		function(cinv)
			cinv:set_stack("main", 1, RELIC .. " 2")
			cinv:set_stack("main", 2, "default:stick 5")
		end)
	-- Empty containers (Round 50 ruling 13: packed as plain node items).
	place("empty_chest", name, "default:chest", {x = C.x + 9, y = y, z = C.z}, player, nil)
	place("empty_furnace", name, "default:furnace", {x = C.x + 10, y = y, z = C.z}, player, nil)
	place("cellar_chest", name, "default:chest", {x = C.x + 10, y = -95, z = C.z}, player,
		function(cinv)
			cinv:set_stack("main", 7, "default:torch 3")
		end)
	local O = sites.outside
	place("outside_chest", name, "default:chest", {x = O.x, y = O.y, z = O.z}, player,
		function(cinv)
			cinv:set_stack("main", 1, "default:dirt 2")
			cinv:set_stack("main", 2, "default:apple 1")
		end)
	log("built keeper's claim " .. claim.id .. " at " .. core.pos_to_string(C))
end

local function build_neighbor(player)
	local name = player:get_player_name()
	local C = sites.two
	player:set_pos({x = C.x + 6, y = C.y, z = C.z + 2})
	core.set_node(C, {name = grug_housing.DRAFT_STONE})
	local claim = grug_housing.model.create(name, C)
	grug_housing.sync_stone_node(claim)
	player:get_inventory():add_item("main", "default:coal_lump " .. grug_housing.ACTIVATION_LUMPS)
	local ok, message = grug_housing.activate(player)
	assert(ok, "activate: " .. tostring(message))
	assert(grug_housing.add_fuel(claim, 55, "default:coal_lump") == 55, "coal")
	claims[#claims + 1] = claim.id
	place("neighbor_chest", name, "default:chest", {x = C.x + 3, y = C.y, z = C.z}, player,
		function(cinv)
			cinv:set_stack("main", 1, "default:apple 6")
			cinv:set_stack("main", 2, "default:torch 8")
		end)
	log("built neighbor's claim " .. claim.id .. " at " .. core.pos_to_string(C))
end

local function write_receipt()
	local record = {game = grug_core.world_version and grug_core.world_version.game or "?",
		sites = sites, claims = {}, containers = {}}
	for _, id in ipairs(claims) do
		local c = grug_housing.model.claim_by_id(id)
		record.claims[#record.claims + 1] = {id = c.id, owner = c.owner, center = c.center,
			placed_at = c.placed_at, activated_at = c.activated_at, paid_until = c.paid_until}
	end
	for _, entry in ipairs(placed) do
		core.load_area(entry.pos)
		local meta = core.get_meta(entry.pos)
		local fields = meta:to_table().fields or {}
		record.containers[#record.containers + 1] = {id = entry.id, owner = entry.owner,
			pos = entry.pos, node = core.get_node(entry.pos).name,
			lists = lists_of(meta:get_inventory()),
			owner_meta = fields.owner or "",
			fuel_time = fields.fuel_time or "", fuel_totaltime = fields.fuel_totaltime or "",
			timer = core.get_node_timer(entry.pos):is_started()}
	end
	write_file("paccept_receipt.json", core.write_json(record))
	log("receipt written: " .. #record.containers .. " containers, " .. #record.claims .. " claims")
end

-- Accept (0.50.0) ----------------------------------------------------------

local forms, notices = {}, {}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, FORM, fields) then return true end
	end
	return false
end

-- The engine's put into a player list: the first non-nil answer of the
-- allow callbacks (RUN_CALLBACKS_MODE_OR_SC), else the whole count.
local function allow_put(player, inv, index, stack)
	local info = {listname = "main", index = index, stack = ItemStack(stack)}
	for _, fn in ipairs(core.registered_allow_player_inventory_actions) do
		local r = fn(player, "put", inv, info)
		if r then return type(r) == "number" and r or stack:get_count() end
	end
	return stack:get_count()
end

local function on_put(player, inv, index, stack)
	local info = {listname = "main", index = index, stack = ItemStack(stack)}
	for _, fn in ipairs(core.registered_on_player_inventory_actions) do
		fn(player, "put", inv, info)
	end
end

local function first_empty(inv)
	for index = 1, inv:get_size("main") do
		if inv:get_stack("main", index):is_empty() then return index end
	end
	return nil
end

local function known(name)
	return name == "" or core.registered_items[name] ~= nil or
		(core.registered_aliases or {})[name] ~= nil
end

-- The receipt's lists as this version should restore them: unregistered
-- items gone.
local function expected_lists(container)
	local out, removed = {}, {}
	for name, stacks in pairs(container.lists or {}) do
		local values = {}
		for index, item in ipairs(stacks) do
			local stack = ItemStack(item)
			if known(stack:get_name()) then
				values[index] = item
			else
				values[index] = ""
				removed[#removed + 1] = item
			end
		end
		out[name] = values
	end
	return out, removed
end

local function same_lists(want, got)
	for name, stacks in pairs(want) do
		local other = got[name] or {}
		for index = 1, math.max(#stacks, #other) do
			if ItemStack(stacks[index] or "") ~= ItemStack(other[index] or "") then
				return false, ("%s[%d]: want %q got %q"):format(name, index,
					stacks[index] or "", other[index] or "")
			end
		end
	end
	for name, stacks in pairs(got) do
		if not want[name] then
			for index, item in ipairs(stacks) do
				if item ~= "" then return false, ("%s[%d] extra %q"):format(name, index, item) end
			end
		end
	end
	return true
end

local function base_node(node)
	local def = core.registered_nodes[node]
	if def and type(def.drop) == "string" and def.drop ~= "" then
		return ItemStack(def.drop):get_name()
	end
	return node
end

-- The receipt's container that a placed node restores, by contents.
local function match(owner, node, lists, used)
	for _, c in ipairs(plan.receipt and plan.receipt.containers or {}) do
		if c.owner == owner and not used[c.id] and base_node(c.node) == node then
			local want = expected_lists(c)
			if same_lists(want, lists) then return c end
		end
	end
	return nil
end

local function recovered_rows()
	local rows = {}
	local store = grug_housing.storage
	if not store then return rows end
	for _, key in ipairs(store:get_keys()) do
		if key:match("^recovered:") or key:match("^packed:") or key == "pack_seq" then
			rows[key] = store:get_string(key)
		end
	end
	return rows
end

local function tab_labels(form)
	local header = form:match("tabheader%[([^%]]*)%]")
	if not header then return {} end
	local labels = header:match("^[^;]*;[^;]*;([^;]*);")
	local out = {}
	for label in (labels or ""):gmatch("[^,]+") do out[#out + 1] = label end
	return out
end

local function read_back(pos)
	local meta = core.get_meta(pos)
	return {node = core.get_node(pos).name, lists = lists_of(meta:get_inventory()),
		owner = meta:get_string("owner"), timer = core.get_node_timer(pos):is_started()}
end

local function flow(player, entry)
	local name = player:get_player_name()
	local site = plan.sites[name]
	local res = {site = site}
	entry.flow = res
	player:set_pos({x = site.x + 6, y = site.y, z = site.z + 2})
	core.set_node(site, {name = grug_housing.DRAFT_STONE})
	local claim = grug_housing.model.create(name, site)
	grug_housing.sync_stone_node(claim)
	res.draft = grug_housing.is_draft(claim)

	-- The draft: no Belongings, also after a tab click.
	forms[name] = nil
	res.opened_draft = grug_housing.open_stone_interface(player, claim)
	local draft_form = forms[name] or ""
	res.draft_form_shown = draft_form ~= ""
	res.draft_belongings = draft_form:find("Belongings", 1, true) ~= nil
	res.draft_recovered_list = draft_form:find("grug_housing_recovered_", 1, true) ~= nil
	submit(player, {stone_tab = "3"})
	local after_tab = forms[name] or ""
	res.draft_belongings_after_tab = after_tab:find("Belongings", 1, true) ~= nil or
		after_tab:find("grug_housing_recovered_", 1, true) ~= nil
	local dname = "grug_housing_recovered_" .. name
	local dinv = core.get_inventory({type = "detached", name = dname})
	local cb = core.detached_inventories[dname]
	res.draft_list_size = dinv and dinv:get_size("recovered") or -1

	-- Activation through the form's button, lumps from the inventory.
	player:get_inventory():add_item("main", "default:coal_lump " .. grug_housing.ACTIVATION_LUMPS)
	submit(player, {activate = "Activate"})
	res.active = grug_housing.is_active(claim) and not grug_housing.is_draft(claim)
	local labels = tab_labels(forms[name] or "")
	res.tabs = labels
	local index
	for i, label in ipairs(labels) do
		if label:match("^Belongings") then index = i end
	end
	res.belongings_label = index and labels[index] or ""
	res.waiting = grug_housing.recovered.count(name)
	if not index then return end
	submit(player, {stone_tab = tostring(index)})
	local belongings = forms[name] or ""
	res.belongings_list = belongings:find("detached:" .. dname .. ";recovered", 1, true) ~= nil
	dinv = core.get_inventory({type = "detached", name = dname})
	cb = core.detached_inventories[dname]
	res.slots = dinv and dinv:get_size("recovered") or 0

	-- Every slot taken as the engine moves it into the player's main list.
	local pinv = player:get_inventory()
	res.taken = {}
	for i = 1, res.slots do
		local stack = dinv:get_stack("recovered", i)
		if not stack:is_empty() then
			local count = stack:get_count()
			local slot = first_empty(pinv)
			local t = {slot = i, name = stack:get_name(), count = count,
				node = stack:get_meta():get_string("node"),
				description = stack:get_meta():get_string("description"),
				image = stack:get_meta():get_string("inventory_image"),
				ref = stack:get_meta():get_string("ref"),
				has_lists = stack:get_meta():get_string("lists") ~= "",
				bytes = #stack:to_string()}
			t.allowed = cb.allow_take(dinv, "recovered", i, ItemStack(stack), player)
			t.put = slot and allow_put(player, pinv, slot, stack) or 0
			if t.allowed == count and t.put == count then
				dinv:set_stack("recovered", i, ItemStack(""))
				pinv:set_stack("main", slot, stack)
				cb.on_take(dinv, "recovered", i, ItemStack(stack), player)
				on_put(player, pinv, slot, stack)
				t.main_slot = slot
			end
			res.taken[#res.taken + 1] = t
		end
	end
	res.left = grug_housing.recovered.count(name)

	-- A packed item cannot be dropped (ruling 6): the drop is refused.
	for _, t in ipairs(res.taken) do
		if t.main_slot and t.name == "grug_housing:packed_container" then
			local stack = pinv:get_stack("main", t.main_slot)
			local def = core.registered_items[stack:get_name()]
			local back = def.on_drop(ItemStack(stack), player, player:get_pos())
			res.drop_refused = back ~= nil and ItemStack(back):to_string() == stack:to_string()
			break
		end
	end

	-- Every packed container placed on the floor and read back.
	res.placed = {}
	local used, k = {}, 0
	for _, t in ipairs(res.taken) do
		if t.main_slot and t.name == "grug_housing:packed_container" then
			k = k + 1
			local target = {x = site.x + 2 + k, y = site.y, z = site.z - 3}
			local under = {x = target.x, y = target.y - 1, z = target.z}
			local stack = pinv:get_stack("main", t.main_slot)
			local def = core.registered_items[stack:get_name()]
			local p = {packed_node = t.node, pos = target, ref = t.ref,
				protected = core.is_protected(target, name)}
			-- Ruling 14: the contents wait under the item's reference until
			-- the placement, which deletes them.
			local store = grug_housing.storage
			p.ref_before = t.ref ~= "" and store:get_string(t.ref) ~= ""
			local result = def.on_place(ItemStack(stack), player,
				{type = "node", under = under, above = target})
			result = ItemStack(result)
			pinv:set_stack("main", t.main_slot, result)
			p.consumed = result:is_empty()
			p.ref_after = t.ref ~= "" and store:get_string(t.ref) ~= ""
			local back = read_back(target)
			p.node, p.owner, p.timer = back.node, back.owner, back.timer
			local c = match(name, back.node, back.lists, used)
			if c then
				used[c.id] = true
				p.match = c.id
				local _, removed = expected_lists(c)
				p.removed = removed
			else
				p.lists = back.lists
			end
			res.placed[#res.placed + 1] = p
		end
	end
	res.charcoal = 0
	for _, t in ipairs(res.taken) do
		if t.name == "grug_smelting:charcoal" and t.main_slot then
			res.charcoal = res.charcoal + t.count
		end
	end
	-- The form again: nothing waits, no Belongings tab.
	forms[name] = nil
	grug_housing.open_stone_interface(player, claim)
	local final = forms[name] or ""
	res.final_belongings = final:find("Belongings", 1, true) ~= nil
	core.close_formspec(name, FORM)
	-- Three seconds later: the furnace still unlit, every node unchanged.
	core.after(3, function()
		res.later = {}
		for _, p in ipairs(res.placed) do
			local again = read_back(p.pos)
			local c
			for _, rc in ipairs(plan.receipt.containers) do
				if rc.id == p.match then c = rc end
			end
			res.later[#res.later + 1] = {id = p.match, node = again.node, timer = again.timer,
				same = c ~= nil and same_lists(expected_lists(c), again.lists) or false}
		end
	end)
	log("flow done for " .. name .. ": " .. #res.taken .. " taken, " .. #res.placed .. " placed")
end

-- Containers an earlier boot placed: read back against the receipt.
local function recheck()
	obs.recheck = {}
	for _, r in ipairs(plan.recheck or {}) do
		local back = read_back(r.pos)
		local c
		for _, rc in ipairs(plan.receipt.containers) do
			if rc.id == r.id then c = rc end
		end
		local ok, why = false, "no receipt entry"
		if c then ok, why = same_lists(expected_lists(c), back.lists) end
		obs.recheck[#obs.recheck + 1] = {id = r.id, node = back.node, same = ok,
			why = why or ""}
	end
end

-- Lifecycle ------------------------------------------------------------------

local ready = false

local function prepare()
	if SETUP then
		if grug_core.zone_authority_installed and not grug_core.zone_authority_installed() then
			return core.after(1, prepare)
		end
		local one, two = choose_sites()
		emerge_all({
			{{x = one.x - 50, y = -100, z = one.z - 50}, {x = one.x + 50, y = 160, z = one.z + 50}},
			{{x = one.x + 56, y = -20, z = one.z - 4}, {x = one.x + 64, y = 160, z = one.z + 4}},
			{{x = two.x - 8, y = -20, z = two.z - 8}, {x = two.x + 14, y = 160, z = two.z + 8}},
		}, function()
			one.y = surface_y(one.x, one.z, 160, -20) + 1
			two.y = surface_y(two.x, two.z, 160, -20) + 1
			local outside = {x = one.x + 60, z = one.z}
			outside.y = surface_y(outside.x, outside.z, 160, -20) + 1
			sites = {one = one, two = two, outside = outside}
			floor_at(one, -4, 12, -4, 4)
			floor_at(two, -4, 12, -4, 4)
			floor_at(outside, -1, 1, -1, 1)
			obs.sites = sites
			ready = true
			write_file("paccept_ready", "1")
			log("sites ready: " .. core.pos_to_string(one) .. " " .. core.pos_to_string(two) ..
				" outside " .. core.pos_to_string(outside))
		end)
	else
		local regions = {}
		for _, site in pairs(plan.sites or {}) do
			regions[#regions + 1] = {{x = site.x - 6, y = site.y - 3, z = site.z - 6},
				{x = site.x + 14, y = site.y + 6, z = site.z + 6}}
		end
		emerge_all(regions, function()
			for _, site in pairs(plan.sites or {}) do
				if plan.lay_floor then floor_at(site, -4, 12, -4, 4) end
			end
			guarded("recheck", recheck)
			-- Joins wait for the world preparation, so the relocation of a
			-- character after the map reset follows at once.
			local function signal()
				if not grug_core.world_preparation_status().ready then
					return core.after(1, signal)
				end
				ready = true
				write_file("paccept_ready", "1")
				log("sites ready, the world preparation is ready")
			end
			signal()
		end)
	end
end

core.register_on_mods_loaded(function()
	if not SETUP then
		obs.at_load = recovered_rows()
		local feed = grug_core.feed
		grug_core.feed = function(player, kind, text, key, ...)
			if key == NOTICE_KEY and player and player.get_player_name then
				local name = player:get_player_name()
				notices[name] = notices[name] or {}
				table.insert(notices[name], text)
			end
			return feed(player, kind, text, key, ...)
		end
		local show = core.show_formspec
		core.show_formspec = function(name, formname, formspec)
			if formname == FORM then forms[name] = formspec end
			return show(name, formname, formspec)
		end
	end
	core.after(0, prepare)
end)

local BUILD = {keeper = build_keeper, neighbor = build_neighbor}
local flow_for = {}
for _, name in ipairs(plan.flow or {}) do flow_for[name] = true end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local entry = {name = name}
	obs.joins[#obs.joins + 1] = entry
	if not SETUP then
		entry.waiting_at_join = grug_housing.recovered.count(name)
	end
	log("joined " .. name)
	if SETUP then
		-- A created, arrived character (the meta character creation stores).
		local meta = player:get_meta()
		meta:set_string("grug_factions:faction", FACTION)
		meta:set_string("grug_classes:race", RACE)
		meta:set_string("grug_classes:class", CLASS)
		meta:set_string("grug_classes:arriving", "")
	end
	local waited = 0
	local function act()
		local current = core.get_player_by_name(name)
		if not current then return fail(name, "left before the probe acted") end
		if not ready then return fail(name, "the sites were not ready at the join") end
		if SETUP and BUILD[name] then
			entry.built = guarded("build " .. name, BUILD[name], current)
		elseif not SETUP and flow_for[name] then
			-- The map reset's relocation to the race start comes first.
			local held = grug_core.map_reset.needs_relocation(current) or
				grug_core.player_in_creation_stasis(name)
			if held and waited < 30 then
				waited = waited + 0.5
				return core.after(0.5, act)
			end
			entry.relocation_wait = waited
			entry.pos_before_flow = vector.round(current:get_pos())
			entry.flowed = guarded("flow " .. name, flow, current, entry)
		end
	end
	core.after(1, act)
end)

local finished = false
local function finish(reason)
	if finished then return end
	finished = true
	obs.finish = reason
	if not SETUP then obs.at_end = recovered_rows() end
	write_file("paccept_obs.json", core.write_json(obs))
	log("observations written: " .. reason)
	core.after(0.5, function() core.request_shutdown("r50 paccept probe done") end)
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	obs.leaves = obs.leaves + 1
	for _, entry in ipairs(obs.joins) do
		if entry.name == name then entry.notices = notices[name] or {} end
	end
	log("left " .. name)
	if obs.leaves >= #expected_joins then core.after(1, finish, "every planned player left") end
end)

if SETUP then
	core.register_on_shutdown(function()
		if #placed > 0 then guarded("receipt", write_receipt) end
	end)
end

core.after(0, function()
	if #expected_joins == 0 then
		core.after(1, function()
			if ready then return finish("no joins planned") end
			core.after(20, finish, "no joins planned")
		end)
	end
	core.after(240, finish, "timeout: not every planned player joined and left")
end)
