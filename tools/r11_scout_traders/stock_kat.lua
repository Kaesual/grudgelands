-- Targeted real-module KAT for the Round 11 Bowyer/Tanner stock integration.
-- Usage: luajit -e 'io.write(dofile("tools/r11_scout_traders/stock_kat.lua")("."))'

return function(repo)
	local saved = {}
	local globals = {"core", "PcgRandom", "ItemStack", "grug_gear",
		"grug_traders", "grug_items"}
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
	ItemStack = function(name)
		return {get_meta = function()
			return {set_int = function() end, set_string = function() end}
		end}
	end

	local definitions = setmetatable({}, {__index = function() return {groups = {}} end})
	local callbacks = {}
	core = {
		registered_items = definitions,
		register_on_mods_loaded = function(fn) callbacks[#callbacks + 1] = fn end,
		global_exists = function(name) return rawget(_G, name) ~= nil end,
		colorize = function(_, text) return text end,
		log = function() end,
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
		local saw_bow, saw_omission = false, false
		for hour = 0, 39 do
			now = 1700000000 + hour * 3600
			local generic = grug_traders.bracket_stock(bowyer.salt, bracket)
			check(#generic == 16, "shared bracket shelf count changed")
			local bows = grug_traders.vendor_bracket_stock(bowyer, bracket)
			check(#bows <= 1, "Bowyer exposed a non-bow or duplicate bow")
			if #bows == 1 then
				check(bows[1].item == grug_gear.weapon_item("bow", bracket),
					"Bowyer exposed a non-bow")
				saw_bow = true
			else
				saw_omission = true
			end
			local leather = grug_traders.vendor_bracket_stock(tanner, bracket)
			check(#leather == 4, "Tanner must expose four leather slots")
			for _, entry in ipairs(leather) do
				check(definitions[entry.item].groups.grug_armor_class == 2,
					"Tanner exposed a non-leather item")
			end
		end
		check(saw_bow and saw_omission, "bow did not participate in rotation")
	end

	restore()
	return "r11 scout trader stock KAT: ok\n"
end
