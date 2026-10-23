-- Round 57 VENDORMAT probe (never shipped). Once the server runs:
--   1. walks every shelf a vendor can show -- the core stock (race and
--      general Quartermasters), every profession shelf, and the gear tab of
--      every bracket for every registered vendor through
--      vendor_bracket_stock -- and flags any leather, cloth, ore or bar
--      (by group, by the material registries, by the mob catalogue and by
--      name), with Thread and the two wools required where they belong;
--   2. compares every item's resolved value (sell_value, milli-copper) as
--      the shelves are now with the value after the eight retired entries
--      (Round 57 ruling 28) are put back and the prices resolved again, then
--      takes them off and resolves once more. Lists every difference; one
--      in Leather, Light Leather or Linen Scrap fails (they pay their loot
--      class). The Bronze Bar and the goods made from it are expected to
--      move: off the shelves the bar pays its inputs (coordinator, Round 57).
-- Ends with "RESULT PASS" or "RESULT FAIL".

local function log(text)
	core.log("action", "[r57_vendormat_probe] " .. text)
end

-- The retired entries with their old prices (stock.lua at main a90990d5).
local RETIRED = {
	{"butcher", "mobs:leather", 8}, {"butcher", "grug_mobs:light_leather", 6},
	{"tailor", "grug_mobs:linen_scrap", 3},
	{"smith", "grug_materials:bronze_bar", 7},
	{"armourer", "grug_materials:bronze_bar", 7},
	{"tanner", "mobs:leather", 8}, {"tanner", "grug_mobs:light_leather", 6},
	{"embalmer", "grug_mobs:linen_scrap", 3},
}
local FOUR = {"mobs:leather", "grug_mobs:light_leather", "grug_mobs:linen_scrap",
	"grug_materials:bronze_bar"}

local MATERIAL_GROUPS = {"grug_leather_grade", "grug_tailor_bolt",
	"grug_tailor_bundle", "grug_metal_rod"}
local NAME_PATTERNS = {"leather", "linen", "cloth", "silk", "pelt", "hide",
	"_bar$", "lump", "ingot", "_ore$", "stone_with_", "^wool:"}
-- The ruling keeps these (Thread is a job supply; the wools are bed decor).
local KEPT = {["wool:white"] = "tailor", ["wool:brown"] = "tailor"}

local function material_reason(item, sets)
	if sets.ore[item] then return "ore/mined resource" end
	if sets.bar[item] then return "bar/storage block" end
	if sets.cloth[item] then return "catalogue leather/cloth" end
	for _, g in ipairs(MATERIAL_GROUPS) do
		if core.get_item_group(item, g) > 0 then return "group " .. g end
	end
	-- Equipment (the gear tab's leather and cloth armour) is no material.
	if core.get_item_group(item, "grug_gear") > 0 then return nil end
	for _, p in ipairs(NAME_PATTERNS) do
		if item:find(p) then return "name ~ " .. p end
	end
	return nil
end

local function material_sets()
	local sets = {ore = {}, bar = {}, cloth = {}}
	for _, r in ipairs(grug_materials.RESOURCES) do
		sets.ore[r.raw_item] = true
		if r.natural_node then sets.ore[r.natural_node] = true end
		if r.cut_item then sets.ore[r.cut_item] = true end
	end
	for _, m in ipairs(grug_materials.PROCESSED_MATERIALS) do
		sets.bar[m.item] = true
		if m.block_node then sets.bar[m.block_node] = true end
	end
	local data = grug_mobs.read_data_json("items.json") or {}
	for _, row in ipairs(data.items or data) do
		local text = ((row.id or "") .. " " .. (row.name or "")):lower()
		for _, word in ipairs({"leather", "cloth", "linen", "silk", "hide", "pelt", "wool"}) do
			if text:find(word) then sets.cloth[row.id] = true end
		end
	end
	return sets
end

local function audit_shelves()
	local ok = true
	local sets = material_sets()
	local shelves = {{"core", grug_traders.stock}}
	local kinds = {}
	for kind in pairs(grug_traders.profession_stock) do kinds[#kinds + 1] = kind end
	table.sort(kinds)
	for _, kind in ipairs(kinds) do
		shelves[#shelves + 1] = {kind, grug_traders.profession_stock[kind]}
	end
	local vendors = {}
	for name in pairs(grug_traders.vendors or {}) do vendors[#vendors + 1] = name end
	table.sort(vendors)
	local gear_rows = 0
	for _, name in ipairs(vendors) do
		local vendor = grug_traders.vendors[name]
		if grug_traders.sells_gear(vendor) then
			for bracket = 1, #grug_gear.BRACKETS do
				local entries = grug_traders.vendor_bracket_stock(vendor, bracket)
				gear_rows = gear_rows + #entries
				shelves[#shelves + 1] = {name .. " gear " .. bracket, entries}
			end
		end
	end
	for _, row in ipairs(shelves) do
		local label, list = row[1], row[2]
		local names = {}
		for _, entry in ipairs(list) do
			names[#names + 1] = entry.item
			local reason = material_reason(entry.item, sets)
			if reason and KEPT[entry.item] ~= label then
				ok = false
				log("FINDING " .. label .. " offers " .. entry.item .. " (" .. reason .. ")")
			end
		end
		if not label:find(" gear ") then
			log(("shelf %s (%d): %s"):format(label, #names, table.concat(names, " ")))
		end
	end
	log("gear tab rows over every vendor and bracket: " .. gear_rows ..
		" (all from grug_gear's T1 catalog)")
	local function offers(list, item)
		for _, entry in ipairs(list) do if entry.item == item then return true end end
		return false
	end
	for _, row in ipairs(shelves) do
		local label = row[1]
		if not label:find(" gear ") and label ~= "culture" and
				not offers(row[2], "grug_professions:thread") then
			ok = false
			log("FINDING " .. label .. " lacks Thread")
		end
	end
	for _, wool in ipairs({"wool:white", "wool:brown"}) do
		if not offers(grug_traders.profession_stock.tailor, wool) then
			ok = false
			log("FINDING tailor lacks " .. wool)
		end
	end
	return ok
end

local function snapshot()
	local values = {}
	for name in pairs(core.registered_items) do
		values[name] = grug_traders.sell_value(name)
	end
	return values
end

local function offer(item)
	local copper, lot = grug_traders.sell_offer(item)
	return copper .. "c/" .. tostring(lot)
end

core.after(0, function()
	local ok = audit_shelves()
	local now = snapshot()
	local now_offer = {}
	for _, item in ipairs(FOUR) do now_offer[item] = offer(item) end
	-- Back to the old shelves.
	for _, r in ipairs(RETIRED) do
		local shelf = grug_traders.profession_stock[r[1]]
		table.insert(shelf, 1, {item = r[2], price = r[3], category = "goods"})
	end
	grug_traders.resolve_prices()
	local old = snapshot()
	for _, item in ipairs(FOUR) do
		log(("buy-back %s: old shelves %s, now %s"):format(item, offer(item), now_offer[item]))
	end
	-- And off again.
	for _, r in ipairs(RETIRED) do
		local shelf = grug_traders.profession_stock[r[1]]
		for i = #shelf, 1, -1 do
			if shelf[i].item == r[2] then table.remove(shelf, i) break end
		end
	end
	grug_traders.resolve_prices()
	local again = snapshot()
	local names = {}
	for name in pairs(now) do names[#names + 1] = name end
	table.sort(names)
	local diffs, drift = 0, 0
	for _, name in ipairs(names) do
		if old[name] ~= now[name] then
			diffs = diffs + 1
			log(("value differs %s: old shelves %s mc, now %s mc"):format(name,
				tostring(old[name]), tostring(now[name])))
		end
		if again[name] ~= now[name] then drift = drift + 1 end
	end
	log(("items compared %d, values that differ %d, re-resolve drift %d"):format(
		#names, diffs, drift))
	if drift > 0 then ok = false end
	for _, item in ipairs({"mobs:leather", "grug_mobs:light_leather", "grug_mobs:linen_scrap"}) do
		if old[item] ~= now[item] then ok = false end
	end
	log(ok and "RESULT PASS" or "RESULT FAIL")
end)
