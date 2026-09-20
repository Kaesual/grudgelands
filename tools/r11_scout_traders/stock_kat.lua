-- Targeted real-module KAT for the Round 11 Bowyer/Tanner stock integration.
-- Usage: luajit -e 'io.write(dofile("tools/r11_scout_traders/stock_kat.lua")("."))'

return function(repo)
	local saved = {}
	local globals = {"core", "PcgRandom", "ItemStack", "grug_gear",
		"grug_traders", "grug_items", "grug_xp", "grug_money", "vector"}
	for _, name in ipairs(globals) do saved[name] = rawget(_G, name) end
	local old_time = os.time
	local function restore()
		os.time = old_time
		for _, name in ipairs(globals) do rawset(_G, name, saved[name]) end
	end
	local function fail(message)
		restore()
		error("r11 scout traders: " .. message, 0)
	end
	local function check(value, message) if not value then fail(message) end end

	local now = 1700000000
	os.time = function() return now end
	PcgRandom = function(seed)
		local state = math.floor(seed) % 2147483647
		if state == 0 then state = 1 end
		return {next = function(_, minimum, maximum)
			state = (state * 48271) % 2147483647
			return minimum + state % (maximum - minimum + 1)
		end}
	end
	local function make_stack(name)
		local stack = {name = name, values = {}}
		function stack:get_name() return self.name end
		function stack:get_meta()
			local owner = self
			return {
				set_int = function(_, key, value) owner.values[key] = value end,
				set_string = function(_, key, value) owner.values[key] = value end,
				get_int = function(_, key) return tonumber(owner.values[key]) or 0 end,
			}
		end
		return stack
	end
	ItemStack = make_stack

	local definitions = setmetatable({}, {__index = function() return {groups = {}} end})
	local callbacks = {}
	local formspec, message, receive_fields
	core = {
		registered_items = definitions,
		register_on_mods_loaded = function(fn) callbacks[#callbacks + 1] = fn end,
		global_exists = function(name) return rawget(_G, name) ~= nil end,
		colorize = function(_, text) return text end,
		log = function() end,
		formspec_escape = function(text) return text end,
		show_formspec = function(_, _, value) formspec = value end,
		close_formspec = function() end,
		chat_send_player = function(_, value) message = value end,
		register_on_player_receive_fields = function(fn) receive_fields = fn end,
		register_on_leaveplayer = function() end,
	}
	grug_traders = {}
	grug_gear = {BRACKETS = {}, catalog = {}}
	local materials = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal"}
	local slots = {"head", "chest", "legs", "feet"}
	local prices = {}
	function grug_gear.weapon_item(family, bracket)
		return "grug_gear:" .. family .. "_" .. materials[bracket]
	end
	function grug_gear.get_price(name) return prices[name] or 40 end
	function grug_gear.bracket_for_level() return 1 end
	function grug_gear.initialize_weapon_tooltip() end
	for bracket = 1, 6 do
		grug_gear.BRACKETS[bracket] = {ilvl = bracket * 10,
			min_level = (bracket - 1) * 10 + 1, max_level = bracket * 10}
		local fixed, extras, all = {}, {}, {}
		local sword = grug_gear.weapon_item("sword", bracket)
		fixed[#fixed + 1], all[#all + 1] = sword, sword
		definitions[sword] = {groups = {grug_gear = 1}}
		for _, line in ipairs({"metal", "cloth", "leather"}) do
			for _, slot in ipairs(slots) do
				local name = "grug_gear:" .. slot .. "_" .. line .. "_" .. materials[bracket]
				fixed[#fixed + 1], all[#all + 1] = name, name
				definitions[name] = {groups = {grug_gear = 1,
					grug_armor_class = line == "leather" and 2 or (line == "metal" and 3 or 1)}}
			end
		end
		for _, family in ipairs({"dagger", "greataxe", "staff", "wand", "bow"}) do
			local name = grug_gear.weapon_item(family, bracket)
			extras[#extras + 1], all[#all + 1] = name, name
			definitions[name] = {groups = {grug_gear = 1,
				grug_bow = family == "bow" and 1 or nil}}
		end
		grug_gear.catalog[bracket] = {fixed = fixed, extras = extras, all = all}
	end

	dofile(repo .. "/mods/ENTITIES/grug_traders/stock.lua")
	for _, callback in ipairs(callbacks) do callback() end
	local roll_calls = 0
	grug_items = {roll_enchants = function(stack, ilvl, source)
		roll_calls = roll_calls + 1
		check(stack:get_name() ~= "", "quality roller received an empty stack")
		check(ilvl > 0 and source == "world", "quality roller handoff differs")
	end}

	local arrow_count = 0
	for _, entry in ipairs(grug_traders.profession_stock.bowyer) do
		if entry.item == "grug_gear:arrow" then arrow_count = arrow_count + 1 end
		check(entry.item ~= "grug_mobs:arrow", "obsolete arrow bundle remains on Bowyer shelf")
	end
	check(arrow_count == 1, "Bowyer does not supply exactly one player-arrow offer")

	local bowyer = {salt = 28, bracket_filter = "bow"}
	local tanner = {salt = 31, bracket_filter = "leather"}
	check(grug_traders.PROFESSION_BRACKETS.bowyer == "bow",
		"Bowyer entity entitlement is not wired to the bow view")
	check(grug_traders.PROFESSION_BRACKETS.tanner == "leather",
		"Tanner entity entitlement is not wired to the leather view")
	for bracket = 1, 6 do
		local saw_bow, saw_omission, saw_uncommon_leather = false, false, false
		for hour = 0, 399 do
			now = 1700000000 + hour * 3600
			local generic = grug_traders.bracket_stock(bowyer.salt, bracket)
			check(#generic == 17, "shared bracket shelf count changed")
			local bows = grug_traders.vendor_bracket_stock(bowyer, bracket)
			check(#bows <= 2, "Bowyer exposed more than Common plus Uncommon")
			if #bows > 0 then
				for _, entry in ipairs(bows) do
					check(entry.item == grug_gear.weapon_item("bow", bracket),
						"Bowyer exposed a non-bow")
				end
				saw_bow = true
			else
				saw_omission = true
			end
			local leather = grug_traders.vendor_bracket_stock(tanner, bracket)
			check(#leather == 4 or #leather == 5,
				"Tanner must expose four Commons plus at most one Uncommon")
			for _, entry in ipairs(leather) do
				check(definitions[entry.item].groups.grug_armor_class == 2,
					"Tanner exposed a non-leather item")
				if entry.uncommon then
					saw_uncommon_leather = true
					check(entry.price == grug_gear.get_price(entry.item) * 3,
						"Uncommon Tanner price is not x3")
					local stack = grug_traders.make_stack(entry)
					check(stack:get_meta():get_int("grug_quality") == 2,
						"Uncommon stack lacks quality metadata")
				end
			end
		end
		check(saw_bow and saw_omission, "bow did not participate in rotation")
		check(saw_uncommon_leather, "quality branch never reached Tanner view")
	end
	check(roll_calls > 0, "quality roller was never called")

	-- Load the actual trade consumer and drive its registered formspec callback.
	-- This proves the filtered view is used for rendering and recomputed before
	-- money changes, rather than testing the stock helper in isolation.
	local vendors = {bowyer = {kind = "bowyer", stock = "bowyer", brackets = true,
		salt = 28, bracket_filter = "bow", nametag = "Bowyer"},
		tanner = {kind = "tanner", stock = "tanner", brackets = true,
			salt = 31, bracket_filter = "leather", nametag = "Tanner"}}
	function grug_traders.get_vendor(name) return vendors[name] end
	function grug_traders.can_trade() return true end
	function grug_traders.has_discount() return false end
	function grug_traders.apply_discount(price) return price end
	vector = {distance = function() return 0 end}
	grug_xp = {get_level = function() return 1 end}
	local charged, added = 0, {}
	grug_money = {
		MAX = 100000,
		get = function() return 1000 end,
		take = function(_, price) charged = charged + price return true end,
		add = function(_, price) charged = charged - price end,
		format = function(price) return price .. "c" end,
	}
	local inventory = {
		room_for_item = function() return true end,
		add_item = function(_, _, stack) added[#added + 1] = stack end,
		get_size = function() return 0 end,
	}
	local player = {
		is_player = function() return true end,
		get_player_name = function() return "kat" end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
		get_inventory = function() return inventory end,
	}
	dofile(repo .. "/mods/ENTITIES/grug_traders/trade.lua")
	check(type(receive_fields) == "function", "trade consumer did not register")

	-- Tanner always has four Common rows. Render its tab, then buy the first;
	-- the callback recomputes through vendor_bracket_stock before charging.
	grug_traders.open(player, "tanner", {x = 0, y = 0, z = 0})
	receive_fields(player, "grug_traders:trade", {tab_1 = true})
	check(formspec:find("grug_gear:head_leather_bronze", 1, true),
		"trade render omitted Tanner leather")
	receive_fields(player, "grug_traders:trade", {buy_1 = true})
	check(charged == 40 and #added == 1 and
		definitions[added[1]:get_name()].groups.grug_armor_class == 2,
		"trade buy did not deliver the recomputed Tanner offer")

	-- Render a Bowyer hour that contains its bow, then advance to an omitted
	-- hour before clicking. Recalculation must reject the stale displayed row.
	local shown_hour, omitted_hour
	for hour = 0, 399 do
		now = 1700000000 + hour * 3600
		if #grug_traders.vendor_bracket_stock(vendors.bowyer, 1) > 0 then
			shown_hour = now
		else
			omitted_hour = now
		end
	end
	check(shown_hour and omitted_hour, "trade rollover setup lacks both bow states")
	now = shown_hour
	grug_traders.open(player, "bowyer", {x = 0, y = 0, z = 0})
	receive_fields(player, "grug_traders:trade", {tab_1 = true})
	check(formspec:find("grug_gear:bow_bronze", 1, true),
		"trade render omitted stocked Bowyer bow")
	local before_charge, before_added = charged, #added
	now = omitted_hour
	receive_fields(player, "grug_traders:trade", {buy_1 = true})
	check(charged == before_charge and #added == before_added and
		formspec:find("The vendor's stock has changed.", 1, true),
		"trade buy accepted a stale filtered offer")

	restore()
	return "r11 scout trader stock KAT: ok\n"
end
