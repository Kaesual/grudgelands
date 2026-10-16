-- Disposable engine probe (Round 50 lane PTOOL: the migration tool's
-- pre-reset pass). Never shipped: tools/r50_ptool/make_world.sh stages it
-- through tools/luanti_headless.sh. Two phases, chosen by this mod's storage:
--
--   build   (empty storage) two claims through grug_housing's own model
--           (registry.lua create, activate, add_fuel), then containers with
--           known contents placed in them with core.set_node (so their
--           on_construct sizes the lists) and filled with set_stack: a
--           chest, a locked chest, a lit furnace with input, fuel and output
--           and a personal workspace record, a bookshelf with written books,
--           a vessels shelf, a chest of 32 written books of 10000
--           characters, an empty chest, a sign (metadata without a list),
--           chests on the area's border and just outside it, and a chest in
--           the other claim. Writes r50_ptool_probe.json (every placed
--           container's lists as ItemStack:to_string, the claims) and shuts
--           the server down; the blocks are saved at the shutdown.
--   verify  (key `verify` set by the test, with the tool's recovered entries
--           copied into this mod's storage as `entry:<key>`): every entry
--           is read with ItemStack(s) and get_meta(), its lists with
--           core.deserialize, and compared stack by stack (ItemStack ==:
--           name, count, wear and meta) with what the build placed (the
--           build record; the test holds the map's blocks to it as well);
--           writes r50_ptool_verify.txt with PASS/FAIL and INFO lines.

local P = "[r50_ptool_probe] "
local storage = core.get_mod_storage()
local world = core.get_worldpath()
local model = grug_housing.model

local function log(msg) core.log("action", P .. msg) end

local function write_file(name, text)
	local f = assert(io.open(world .. "/" .. name, "wb"))
	f:write(text)
	f:close()
end

local function read_file(name)
	local f = io.open(world .. "/" .. name, "rb")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text
end

local A = {x = 1000, y = 150, z = 1000}   -- claim of "builder"
local B = {x = 1300, y = 150, z = 1000}   -- claim of "neighbor"
local REGIONS = {
	{{x = 990, y = 140, z = 990}, {x = 1060, y = 160, z = 1010}},
	{{x = 1005, y = -105, z = 995}, {x = 1015, y = -95, z = 1005}},
	{{x = 1295, y = 140, z = 995}, {x = 1305, y = 160, z = 1005}},
}

local function at(base, dx, dy, dz)
	return {x = base.x + dx, y = base.y + dy, z = base.z + dz}
end

local function book(title, text)
	local stack = ItemStack("default:book_written")
	stack:get_meta():from_table({fields = {
		title = title, owner = "builder", text = text,
		description = "\"" .. title .. "\" by builder", page = "1",
		page_max = tostring(math.ceil(select(2, text:gsub("\n", "")) / 14 + 1)),
	}})
	return stack
end

-- Readable text of exactly `size` bytes: words, a newline every few lines,
-- now and then a quote, a backslash and a non-ASCII letter.
local function long_text(seed, size)
	local words = {"the", "stone", "keeps", "\"old\"", "Gr\195\188\195\159e", "road", "a\\b",
		"of", "the", "Accord", "and", "Throng", "winter", "barley", "ten", "copper"}
	local out, length, n = {}, 0, seed
	while length < size do
		n = (n * 1103515245 + 12345) % 2147483648
		local word = words[n % #words + 1]
		local sep = (n % 9 == 0) and "\n" or " "
		out[#out + 1] = word .. sep
		length = length + #word + 1
	end
	return table.concat(out):sub(1, size)
end

local placed = {}

local function place(name, pos, fill)
	core.set_node(pos, {name = name})
	local meta = core.get_meta(pos)
	if fill then fill(meta, meta:get_inventory()) end
	placed[#placed + 1] = {pos = pos, name = name}
end

local function build()
	-- The stone nodes first: the game removes a claim whose loaded stone is
	-- gone (stone.lua, the check every 5 s).
	core.set_node(A, {name = grug_housing.STONE_ITEM})
	core.set_node(B, {name = grug_housing.STONE_ITEM})
	local a = model.create("builder", A)
	model.activate(a, 20)
	model.add_fuel(a, 1, model.LUMP_SECONDS * 3 / 2)
	local b = model.create("neighbor", B)
	model.activate(b, 5)

	place("default:chest", at(A, 2, 0, 0), function(_, inv)
		inv:set_stack("main", 1, "default:dirt 99")
		inv:set_stack("main", 5, "default:torch 50")
		local sword = ItemStack("grug_gear:sword_iron")
		sword:set_wear(1234)
		local meta = sword:get_meta()
		meta:set_string("grug_quality", "rare")
		meta:set_string("grug_ilvl", "12")
		meta:set_string("description", "Iron Sword\nRare \"quoted\" Gr\195\188\195\159e\tend")
		inv:set_stack("main", 10, sword)
		inv:set_stack("main", 32, "default:cobble 7")
	end)
	place("default:chest_locked", at(A, 3, 0, 0), function(meta, inv)
		meta:set_string("owner", "builder")
		meta:set_string("infotext", "Locked Chest (owned by builder)")
		inv:set_stack("main", 2, "default:coal_lump 33")
		inv:set_stack("main", 3, book("Ledger \"one\"", "Line one\nLine \\two\n\tGr\195\188\195\159e"))
	end)
	place("default:furnace", at(A, 4, 0, 0), function(meta, inv)
		inv:set_stack("src", 1, "default:cobble 12")
		inv:set_stack("fuel", 1, "default:coal_lump 5")
		inv:set_stack("dst", 1, "default:stone 4")
		meta:set_float("fuel_time", 3.5)
		meta:set_float("fuel_totaltime", 40)
		local key = "grug_jobs:workspace:builder"
		meta:mark_as_private(key)
		meta:set_string(key, core.serialize({
			lists = {src = {"default:cobble 3"}, fuel = {"default:coal_lump 2"},
				dst = {"", "default:stone 1"}},
			process = {fuel = 0, progress = 0},
		}))
	end)
	core.swap_node(at(A, 4, 0, 0), {name = "default:furnace_active"})
	placed[#placed].name = "default:furnace_active"
	place("default:bookshelf", at(A, 5, 0, 0), function(_, inv)
		inv:set_stack("books", 1, book("Short", "A short book."))
		inv:set_stack("books", 4, "default:book 3")
		inv:set_stack("books", 16, book("Long", long_text(7, 10000)))
	end)
	place("vessels:shelf", at(A, 6, 0, 0), function(_, inv)
		inv:set_stack("vessels", 1, "vessels:glass_bottle 5")
		inv:set_stack("vessels", 9, "vessels:drinking_glass 3")
	end)
	place("default:chest", at(A, 7, 0, 0), function(_, inv)
		for slot = 1, 32 do
			inv:set_stack("main", slot, book("Volume " .. slot, long_text(slot, 10000)))
		end
	end)
	place("default:chest", at(A, 8, 0, 0), nil)              -- empty
	core.set_node(at(A, 9, 0, 0), {name = "default:sign_wall_wood", param2 = 2})
	core.get_meta(at(A, 9, 0, 0)):set_string("text", "no list here")
	place("default:chest", at(A, 50, 0, 0), function(_, inv)   -- the border
		inv:set_stack("main", 1, "default:dirt 1")
	end)
	place("default:chest", at(A, 51, 0, 0), function(_, inv)   -- outside
		inv:set_stack("main", 1, "default:dirt 2")
	end)
	place("default:chest", {x = 1010, y = -100, z = 1000}, function(_, inv)  -- MIN_Y
		inv:set_stack("main", 1, "default:dirt 3")
	end)
	place("default:chest", {x = 1010, y = -101, z = 1000}, function(_, inv)  -- below
		inv:set_stack("main", 1, "default:dirt 4")
	end)
	place("default:chest", at(B, 2, 0, 0), function(_, inv)
		inv:set_stack("main", 1, "default:apple 6")
		inv:set_stack("main", 2, "default:torch 8")
	end)

	local record = {claims = {}, containers = {}}
	for _, claim in ipairs({a, b}) do
		record.claims[#record.claims + 1] = {id = claim.id, owner = claim.owner,
			center = claim.center, paid_until = claim.paid_until}
	end
	for _, entry in ipairs(placed) do
		local lists = {}
		for name, stacks in pairs(core.get_meta(entry.pos):get_inventory():get_lists()) do
			local values = {}
			for index, stack in ipairs(stacks) do values[index] = stack:to_string() end
			lists[name] = values
		end
		record.containers[#record.containers + 1] = {pos = entry.pos,
			node = core.get_node(entry.pos).name, lists = lists}
	end
	write_file("r50_ptool_probe.json", core.write_json(record))
	log("built " .. #placed .. " containers, claims " .. a.id .. " and " .. b.id)
	storage:set_string("built", "1")
end

local function emerge(index, done)
	local region = REGIONS[index]
	if not region then return done() end
	core.emerge_area(region[1], region[2], function(_, _, remaining)
		if remaining == 0 then emerge(index + 1, done) end
	end)
end

-- verify ------------------------------------------------------------------

local function verify()
	local lines, failures = {}, 0
	local function check(ok, what)
		lines[#lines + 1] = (ok and "PASS " or "FAIL ") .. what
		if not ok then failures = failures + 1 end
	end
	local record = core.parse_json(read_file("r50_ptool_probe.json") or "null")
	check(record ~= nil, "the build record is there")
	local originals = {}
	for _, c in ipairs(record and record.containers or {}) do
		originals[#originals + 1] = {pos = c.pos, node = c.node, lists = c.lists, used = false}
	end
	local function same_lists(a, b)
		for name, stacks in pairs(a) do
			local other = b[name] or {}
			if #other ~= #stacks then return false end
			for i = 1, #stacks do
				if ItemStack(stacks[i]) ~= ItemStack(other[i]) then return false end
			end
		end
		for name, stacks in pairs(b) do
			-- core.write_json writes an empty list as null.
			if not a[name] and #stacks > 0 then return false end
		end
		return true
	end
	local entries = {}
	for _, key in ipairs(storage:get_keys()) do
		local name = key:match("^entry:(.+)$")
		if name then entries[#entries + 1] = name end
	end
	table.sort(entries)
	local largest, packed, charcoal = 0, 0, 0
	for _, key in ipairs(entries) do
		local text = storage:get_string("entry:" .. key)
		local stack = ItemStack(text)
		local again = ItemStack(stack:to_string())
		check(again == stack, key .. ": to_string reads back as the same stack")
		if stack:get_name() == "grug_smelting:charcoal" then
			charcoal = charcoal + stack:get_count()
		else
			packed = packed + 1
			largest = math.max(largest, #text)
			local meta = stack:get_meta()
			local node = meta:get_string("node")
			local lists = core.deserialize(meta:get_string("lists"))
			check(stack:get_name() == "grug_housing:packed_container" and stack:get_count() == 1
				and type(lists) == "table" and meta:get_string("seq") ~= "",
				key .. ": a packed container with node, lists and seq (" .. node .. ")")
			local found
			for _, c in ipairs(originals) do
				if not c.used and c.node == node and type(lists) == "table" and
						same_lists(c.lists, lists) then
					found = c
					break
				end
			end
			if found then
				found.used = true
				check(true, key .. ": equals the placed " .. found.node .. " at " ..
					core.pos_to_string(found.pos) .. " stack by stack")
			elseif node == "default:chest" and lists and lists.main and #lists.main == 3 then
				-- The furnace's personal workspace record, packed into a chest
				-- (its lists in name order: dst, fuel, src).
				local want = {"default:stone 1", "default:coal_lump 2", "default:cobble 3"}
				local same = true
				for i = 1, 3 do
					if ItemStack(lists.main[i]) ~= ItemStack(want[i]) then same = false end
				end
				check(same, key .. ": the workspace record's three stacks in a chest")
			else
				check(false, key .. ": matches no placed container (" .. node .. ")")
			end
		end
	end
	check(packed > 0, "packed entries: " .. packed)
	for _, c in ipairs(originals) do
		if not c.used then
			lines[#lines + 1] = "INFO not packed " .. c.node .. " " .. core.pos_to_string(c.pos)
		end
	end
	lines[#lines + 1] = "INFO charcoal " .. charcoal .. " largest_entry_bytes " .. largest
	lines[#lines + 1] = "RESULT " .. (failures == 0 and "PASS" or "FAIL") ..
		" failures=" .. failures
	write_file("r50_ptool_verify.txt", table.concat(lines, "\n") .. "\n")
	log("verify done, failures " .. failures)
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		if storage:get_string("verify") == "1" then
			verify()
			core.after(1, function() core.request_shutdown("r50 ptool verify done") end)
		elseif storage:get_string("built") == "" then
			emerge(1, function()
				build()
				core.after(2, function() core.request_shutdown("r50 ptool probe done") end)
			end)
		end
	end)
end)
